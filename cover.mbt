///|
fn Schema::minimal(
  self : Schema,
  budget : Meter,
) -> Array[FD] raise DesignError {
  // These operations reuse MoonConcept's generic implication reduction.
  let count = self.dependencies().length()
  budget.charge(1)
  budget.charge_product([
    count + 1,
    count + 1,
    self.attribute_count(),
    self.attribute_count(),
  ])
  let reduced = self.theory.split_conclusions().reduce_premises().irredundant() catch {
      _ => raise Invalid("upstream cover reduction failed")
    }
  reduced
  .implications()
  .filter(r => !subset(r.conclusion, r.premise))
  .map(r => { left: r.premise, right: r.conclusion, })
}

///|
pub fn Schema::minimal_cover(
  self : Schema,
  limits~ : Limits = default_limits(),
) -> Array[FD] raise DesignError {
  self.minimal(meter(limits))
}

///|
pub fn Schema::grouped_cover(
  self : Schema,
  limits~ : Limits = default_limits(),
) -> Array[FD] raise DesignError {
  let out : Array[FD] = []
  for fd in self.minimal_cover(limits~) {
    let mut found = false
    for i in 0..<out.length() {
      if out[i].left == fd.left {
        out[i] = { left: out[i].left, right: union(out[i].right, fd.right), }
        found = true
        break
      }
    }
    if !found {
      out.push(fd)
    }
  }
  out
}

///|
pub fn Schema::equivalent(
  self : Schema,
  other : Schema,
  limits~ : Limits = default_limits(),
) -> Bool raise DesignError {
  if self.attributes() != other.attributes() {
    raise Invalid("equivalence requires same ordered attribute labels")
  }
  let budget = meter(limits)
  for fd in self.dependencies() {
    if !subset(fd.right, other.close(fd.left, budget)) {
      return false
    }
  }
  for fd in other.dependencies() {
    if !subset(fd.right, self.close(fd.left, budget)) {
      return false
    }
  }
  true
}

///|
pub(all) struct TheoryDelta {
  removed_constraints : Array[FD]
  added_constraints : Array[FD]
  equivalent : Bool
} derive(Eq, Debug)

///|
pub fn Schema::compare_theory(
  self : Schema,
  proposed : Schema,
  limits~ : Limits = default_limits(),
) -> TheoryDelta raise DesignError {
  if self.attributes() != proposed.attributes() {
    raise Invalid("theory comparison requires same ordered labels")
  }
  let budget = meter(limits)
  let removed_constraints = []
  let added_constraints = []
  for fd in self.dependencies() {
    if !subset(fd.right, proposed.close(fd.left, budget)) {
      removed_constraints.push(fd)
    }
  }
  for fd in proposed.dependencies() {
    if !subset(fd.right, self.close(fd.left, budget)) {
      added_constraints.push(fd)
    }
  }
  {
    removed_constraints,
    added_constraints,
    equivalent: removed_constraints.is_empty() && added_constraints.is_empty(),
  }
}

///|
pub extend TheoryDelta with Eq::{equal, not_equal}

///|
pub extend TheoryDelta with Debug::{to_repr}
