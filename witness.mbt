///|
pub fn Schema::verify_chase_trace(
  self : Schema,
  relations : Array[Array[Int32]],
  result : ChaseResult,
  limits~ : Limits = default_limits(),
) -> Bool raise DesignError {
  // Recompute deterministically rather than trusting user-supplied tableau symbols.
  // Structural validation alone cannot establish provenance.
  let expected = self.lossless_chase(relations, limits~)
  expected == result
}

///|
pub(all) struct LossyWitness {
  instance : Table
  spurious_row : Array[String]
  projected_presence : Array[Bool]
  chase : ChaseResult
} derive(Debug)

///|
pub fn Schema::lossy_counterexample(
  self : Schema,
  relations : Array[Array[Int32]],
  limits~ : Limits = default_limits(),
) -> LossyWitness? raise DesignError {
  let parts = self.fragments(relations, true)
  let budget = meter(limits)
  let chase = self.chase_of(parts, budget)
  if chase.lossless {
    return None
  }
  let rows = chase.final_tableau.map(row => {
    row.map(symbol => "v" + symbol.to_string())
  })
  let instance = table(self, full(self.attribute_count()), rows, limits~)
  let spurious_row = full(self.attribute_count()).map(symbol => {
    "v" + symbol.to_string()
  })
  let projected_presence = []
  for part in parts {
    let values = part.map(a => spurious_row[a])
    let projected = instance.project_with(part, budget)
    projected_presence.push(projected.data.contains(values))
  }
  // The fixed-point tableau obeys every FD; its distinguished tuple is absent
  // but occurs in every fragment, hence lies in their natural join.
  if instance.data.contains(spurious_row) || !projected_presence.all(v => v) {
    raise Invalid("internal chase counterexample failed")
  }
  Some({ instance, spurious_row, projected_presence, chase, })
}

///|
pub fn Schema::verify_lossy_counterexample(
  self : Schema,
  relations : Array[Array[Int32]],
  witness : LossyWitness,
  limits~ : Limits = default_limits(),
) -> Bool raise DesignError {
  let parts = self.fragments(relations, true)
  witness.instance.check_schema(self)
  if witness.instance.columns != full(self.attribute_count()) ||
    witness.spurious_row.length() != self.attribute_count() {
    return false
  }
  if witness.instance.data.contains(witness.spurious_row) {
    return false
  }
  if !witness.instance.audit_dependencies(self, limits~).violations.is_empty() {
    return false
  }
  let budget = meter(limits)
  for part in parts {
    let projected = witness.instance.project_with(part, budget)
    let values = part.map(a => witness.spurious_row[a])
    budget.charge(1 + projected.data.length() * (part.length() + 1))
    if !projected.data.contains(values) {
      return false
    }
  }
  true
}

///|
pub extend LossyWitness with Debug::{to_repr}
