///|
pub(all) struct DependencyLocality {
  dependency : FD
  containing_relations : Array[Int32]
  jointly_preserved : Bool
} derive(Eq, Debug)

///|
pub fn Schema::dependency_locality(
  self : Schema,
  relations : Array[Array[Int32]],
  limits~ : Limits = default_limits(),
) -> Array[DependencyLocality] raise DesignError {
  let parts = self.fragments(relations, true)
  let budget = meter(limits)
  let preservation = self.preservation_of(parts, budget)
  let out = []
  for fd in self.dependencies() {
    let containing_relations = []
    let scope = union(fd.left, fd.right)
    for i in 0..<parts.length() {
      budget.charge(scope.length() + 1)
      if subset(scope, parts[i]) {
        containing_relations.push(i)
      }
    }
    out.push({
      dependency: fd,
      containing_relations,
      jointly_preserved: !preservation.missing.contains(fd),
    })
  }
  out
}

///|
pub(all) struct LayoutDelta {
  unchanged : Array[Array[Int32]]
  removed : Array[Array[Int32]]
  added : Array[Array[Int32]]
  duplicated_attributes_before : Array[Int32]
  duplicated_attributes_after : Array[Int32]
} derive(Eq, Debug)

///|
fn duplicated_attributes(
  parts : Array[Array[Int32]],
  n : Int32,
) -> Array[Int32] {
  let counts = Array::make(n, 0)
  for part in parts {
    for a in part {
      counts[a] += 1
    }
  }
  let out = []
  for a in 0..<n {
    if counts[a] > 1 {
      out.push(a)
    }
  }
  out
}

///|
pub fn Schema::compare_layouts(
  self : Schema,
  before : Array[Array[Int32]],
  after : Array[Array[Int32]],
) -> LayoutDelta raise DesignError {
  let old = self.fragments(before, true)
  let next = self.fragments(after, true)
  {
    unchanged: old.filter(r => next.contains(r)),
    removed: old.filter(r => !next.contains(r)),
    added: next.filter(r => !old.contains(r)),
    duplicated_attributes_before: duplicated_attributes(
      old,
      self.attribute_count(),
    ),
    duplicated_attributes_after: duplicated_attributes(
      next,
      self.attribute_count(),
    ),
  }
}

///|
pub(all) struct MigrationReview {
  before : PlanAudit
  after : PlanAudit
  layout : LayoutDelta
  lost_dependencies : Array[FD]
  gained_dependencies : Array[FD]
  lossless_regression : Bool
  normal_form_regression : Bool
  locality : Array[DependencyLocality]
} derive(Eq, Debug)

///|
pub fn Schema::review_migration(
  self : Schema,
  before : Plan,
  after : Plan,
  limits~ : Limits = default_limits(),
) -> MigrationReview raise DesignError {
  if before.target != after.target {
    raise Invalid("migration comparison requires same target normal form")
  }
  let old = self.audit_plan(before, limits~)
  let next = self.audit_plan(after, limits~)
  let lost_dependencies = next.missing_dependencies.filter(fd => {
    !old.missing_dependencies.contains(fd)
  })
  let gained_dependencies = old.missing_dependencies.filter(fd => {
    !next.missing_dependencies.contains(fd)
  })
  {
    before: old,
    after: next,
    layout: self.compare_layouts(before.relations, after.relations),
    lost_dependencies,
    gained_dependencies,
    lossless_regression: old.lossless && !next.lossless,
    normal_form_regression: old.target_satisfied && !next.target_satisfied,
    locality: self.dependency_locality(after.relations, limits~),
  }
}

///|
pub extend DependencyLocality with Eq::{equal, not_equal}

///|
pub extend DependencyLocality with Debug::{to_repr}

///|
pub extend LayoutDelta with Eq::{equal, not_equal}

///|
pub extend LayoutDelta with Debug::{to_repr}

///|
pub extend MigrationReview with Eq::{equal, not_equal}

///|
pub extend MigrationReview with Debug::{to_repr}
