///|
pub(all) struct TupleViolation {
  dependency_index : Int32
  first_row : Int32
  second_row : Int32
  differing_attributes : Array[Int32]
} derive(Eq, Debug)

///|
pub(all) struct DataAudit {
  checked_dependencies : Array[Int32]
  skipped_dependencies : Array[Int32]
  violations : Array[TupleViolation]
} derive(Eq, Debug)

///|
pub fn Table::audit_dependencies(
  self : Table,
  owner : Schema,
  limits~ : Limits = default_limits(),
) -> DataAudit raise DesignError {
  self.check_schema(owner)
  let budget = meter(limits)
  let fds = owner.dependencies()
  let checked_dependencies = []
  let skipped_dependencies = []
  let violations = []
  for fi in 0..<fds.length() {
    let fd = fds[fi]
    if !subset(union(fd.left, fd.right), self.columns) {
      skipped_dependencies.push(fi)
      continue
    }
    checked_dependencies.push(fi)
    let left = self.positions(fd.left)
    let right = self.positions(fd.right)
    for i in 0..<self.data.length() {
      for j in (i + 1)..<self.data.length() {
        budget.charge(1 + left.length() + right.length())
        if !left.all(a => self.data[i][a] == self.data[j][a]) {
          continue
        }
        let differing_attributes = []
        for k in 0..<right.length() {
          if self.data[i][right[k]] != self.data[j][right[k]] {
            differing_attributes.push(fd.right[k])
          }
        }
        if !differing_attributes.is_empty() {
          budget.result(violations.length() + 1)
          violations.push({
            dependency_index: fi,
            first_row: i,
            second_row: j,
            differing_attributes,
          })
        }
      }
    }
  }
  { checked_dependencies, skipped_dependencies, violations, }
}

///|
pub(all) struct Collision {
  first_row : Int32
  second_row : Int32
  determinant_values : Array[String]
} derive(Eq, Debug)

///|
pub fn Table::key_collisions(
  self : Table,
  key : Array[Int32],
  limits~ : Limits = default_limits(),
) -> Array[Collision] raise DesignError {
  let attrs = indices(key, self.labels.length())
  let positions = self.positions(attrs)
  let budget = meter(limits)
  let out = []
  for i in 0..<self.data.length() {
    for j in (i + 1)..<self.data.length() {
      budget.charge(1 + positions.length())
      if positions.all(a => self.data[i][a] == self.data[j][a]) {
        budget.result(out.length() + 1)
        out.push({
          first_row: i,
          second_row: j,
          determinant_values: positions.map(a => self.data[i][a]),
        })
      }
    }
  }
  out
}

///|
pub(all) struct ColumnProfile {
  attribute : Int32
  distinct_values : Int32
  empty_values : Int32
  maximum_code_units : Int32
} derive(Eq, Debug)

///|
pub fn Table::column_profiles(
  self : Table,
  limits~ : Limits = default_limits(),
) -> Array[ColumnProfile] raise DesignError {
  let budget = meter(limits)
  let out = []
  for i in 0..<self.columns.length() {
    let values : Array[String] = []
    let mut empty_values = 0
    let mut maximum_code_units = 0
    for row in self.data {
      let value = row[i]
      budget.charge(1 + values.length() * (value.length() + 1))
      if !values.contains(value) {
        values.push(value)
      }
      if value.is_empty() {
        empty_values += 1
      }
      if value.length() > maximum_code_units {
        maximum_code_units = value.length()
      }
    }
    out.push({
      attribute: self.columns[i],
      distinct_values: values.length(),
      empty_values,
      maximum_code_units,
    })
  }
  out
}

///|
pub extend TupleViolation with Eq::{equal, not_equal}

///|
pub extend TupleViolation with Debug::{to_repr}

///|
pub extend DataAudit with Eq::{equal, not_equal}

///|
pub extend DataAudit with Debug::{to_repr}

///|
pub extend Collision with Eq::{equal, not_equal}

///|
pub extend Collision with Debug::{to_repr}

///|
pub extend ColumnProfile with Eq::{equal, not_equal}

///|
pub extend ColumnProfile with Debug::{to_repr}
