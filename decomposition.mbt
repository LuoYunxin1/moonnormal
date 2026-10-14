///|
pub(all) struct SplitStep {
  input : Array[Int32]
  dependency : FD
  first : Array[Int32]
  second : Array[Int32]
} derive(Eq, Debug)

///|
pub(all) struct Plan {
  target : NormalForm
  relations : Array[Array[Int32]]
  splits : Array[SplitStep]
  added_key_relation : Bool
} derive(Eq, Debug)

///|
fn remove_contained(relations : Array[Array[Int32]]) -> Array[Array[Int32]] {
  let unique : Array[Array[Int32]] = []
  for relation in relations {
    if !unique.contains(relation) {
      unique.push(relation.copy())
    }
  }
  unique.filter(r => !unique.any(s => r.length() < s.length() && subset(r, s)))
}

///|
fn Schema::first_bcnf(
  self : Schema,
  attrs : Array[Int32],
  budget : Meter,
) -> FD? raise DesignError {
  for seed in subsets(attrs, budget) {
    let closed = intersection(self.close(seed, budget), attrs)
    let gained = difference(closed, seed)
    if !gained.is_empty() && !subset(attrs, closed) {
      return Some({ left: seed, right: gained, })
    }
  }
  None
}

///|
pub fn Schema::decompose_bcnf(
  self : Schema,
  limits~ : Limits = default_limits(),
) -> Plan raise DesignError {
  let budget = meter(limits)
  let pending = [full(self.attribute_count())]
  let relations = []
  let splits = []
  while !pending.is_empty() {
    let attrs = pending.remove(0)
    match self.first_bcnf(attrs, budget) {
      None => {
        budget.result(relations.length() + 1)
        relations.push(attrs)
      }
      Some(fd) => {
        let first = union(fd.left, fd.right)
        let second = difference(attrs, difference(fd.right, fd.left))
        if first.length() >= attrs.length() ||
          second.length() >= attrs.length() ||
          first.is_empty() ||
          second.is_empty() {
          raise Invalid(
            "internal BCNF split did not strictly decrease relation",
          )
        }
        budget.result(splits.length() + 1)
        splits.push({
          input: attrs,
          dependency: fd,
          first: first.copy(),
          second: second.copy(),
        })
        pending.push(first)
        pending.push(second)
      }
    }
  }
  {
    target: BoyceCodd,
    relations: remove_contained(relations),
    splits,
    added_key_relation: false,
  }
}

///|
pub fn Schema::synthesize_3nf(
  self : Schema,
  limits~ : Limits = default_limits(),
) -> Plan raise DesignError {
  let budget = meter(limits)
  let groups : Array[FD] = []
  for fd in self.minimal(budget) {
    let mut found = false
    for i in 0..<groups.length() {
      if groups[i].left == fd.left {
        groups[i] = { left: fd.left, right: union(groups[i].right, fd.right), }
        found = true
        break
      }
    }
    if !found {
      groups.push(fd)
    }
  }
  let mut relations = remove_contained(
    groups.map(fd => union(fd.left, fd.right)),
  )
  let keys = self.keys_of(full(self.attribute_count()), budget)
  let contains_key = relations.any(r => keys.any(k => subset(k, r)))
  let mut added_key_relation = false
  if !contains_key || relations.is_empty() {
    // A dependency-free schema has the entire relation as its sole key.
    // If the key is empty, constant FD relations already cover all attributes.
    let key = keys[0]
    if !key.is_empty() {
      relations.push(key.copy())
    }
    added_key_relation = true
  }
  relations = remove_contained(relations)
  let checked = self.fragments(relations, true)
  budget.result(checked.length())
  { target: Third, relations: checked, splits: [], added_key_relation, }
}

///|
pub(all) struct PlanAudit {
  lossless : Bool
  dependency_preserving : Bool
  target_satisfied : Bool
  missing_dependencies : Array[FD]
  violations : Array[Violation]
  chase : ChaseResult
} derive(Eq, Debug)

///|
pub fn Schema::audit_plan(
  self : Schema,
  plan : Plan,
  limits~ : Limits = default_limits(),
) -> PlanAudit raise DesignError {
  let budget = meter(limits)
  let relations = self.fragments(plan.relations, true)
  let preservation = self.preservation_of(relations, budget)
  let chase = self.chase_of(relations, budget)
  let violations = []
  for attrs in relations {
    for violation in self.violations_of(attrs, plan.target, budget) {
      budget.result(violations.length() + 1)
      violations.push(violation)
    }
  }
  {
    lossless: chase.lossless,
    dependency_preserving: preservation.preserved,
    target_satisfied: violations.is_empty(),
    missing_dependencies: preservation.missing,
    violations,
    chase,
  }
}

///|
pub fn Schema::verify_split_trace(
  self : Schema,
  plan : Plan,
  limits~ : Limits = default_limits(),
) -> Bool raise DesignError {
  let budget = meter(limits)
  if plan.target != BoyceCodd || plan.added_key_relation {
    return false
  }
  let leaves = [full(self.attribute_count())]
  for step in plan.splits {
    let input = indices(step.input, self.attribute_count())
    let first = indices(step.first, self.attribute_count())
    let second = indices(step.second, self.attribute_count())
    let left = indices(step.dependency.left, self.attribute_count())
    let right = indices(step.dependency.right, self.attribute_count())
    if !subset(left, input) || !subset(right, input) || right.is_empty() {
      return false
    }
    if !subset(right, self.close(left, budget)) {
      return false
    }
    if first != union(left, right) ||
      second != difference(input, difference(right, left)) {
      return false
    }
    if first.length() >= input.length() || second.length() >= input.length() {
      return false
    }
    let mut found = None
    for i in 0..<leaves.length() {
      if leaves[i] == input {
        found = Some(i)
        break
      }
    }
    match found {
      None => return false
      Some(i) => {
        let _ = leaves.remove(i)
        leaves.push(first)
        leaves.push(second)
      }
    }
  }
  let expected = remove_contained(leaves)
  let supplied = self.fragments(plan.relations, true)
  expected.length() == supplied.length() &&
  expected.all(r => supplied.contains(r))
}

///|
pub extend SplitStep with Eq::{equal, not_equal}

///|
pub extend SplitStep with Debug::{to_repr}

///|
pub extend Plan with Eq::{equal, not_equal}

///|
pub extend Plan with Debug::{to_repr}

///|
pub extend PlanAudit with Eq::{equal, not_equal}

///|
pub extend PlanAudit with Debug::{to_repr}
