///|
pub struct Table {
  priv labels : Array[String]
  priv columns : Array[Int32]
  priv data : Array[Array[String]]
} derive(Debug)

///|
fn unique_rows(
  rows : Array[Array[String]],
  width : Int32,
  budget : Meter,
) -> Array[Array[String]] raise DesignError {
  let out : Array[Array[String]] = []
  for row in rows {
    budget.charge(1 + out.length() * (width + 1))
    if !out.contains(row) {
      if out.length() + 1 > budget.limits.max_rows {
        raise Budget("tuple row allowance")
      }
      out.push(row.copy())
    }
  }
  out
}

///|
pub fn table(
  owner : Schema,
  columns : Array[Int32],
  rows : Array[Array[String]],
  limits~ : Limits = default_limits(),
) -> Table raise DesignError {
  let budget = meter(limits)
  let attrs = indices(columns, owner.attribute_count())
  if attrs != columns {
    raise Invalid("table columns must be sorted and unique")
  }
  if attrs.is_empty() {
    raise Invalid("table requires nonempty columns")
  }
  if rows.length() > limits.max_rows ||
    rows.length() * attrs.length() > limits.max_cells {
    raise Budget("table input shape allowance")
  }
  let mut units = 0
  for row in rows {
    if row.length() != attrs.length() {
      raise Invalid("tuple width differs from columns")
    }
    for cell in row {
      if cell.length() > 4096 {
        raise Invalid("tuple cell exceeds 4096 code units")
      }
      units += cell.length()
      if units > limits.max_cells * 128 {
        raise Budget("tuple text allowance")
      }
      budget.charge(1 + cell.length())
    }
  }
  {
    labels: owner.attributes(),
    columns: attrs,
    data: unique_rows(rows, attrs.length(), budget),
  }
}

///|
pub fn Table::columns(self : Table) -> Array[Int32] {
  self.columns.copy()
}

///|
pub fn Table::rows(self : Table) -> Array[Array[String]] {
  self.data.map(row => row.copy())
}

///|
pub fn Table::row_count(self : Table) -> Int32 {
  self.data.length()
}

///|
pub fn Table::column_names(self : Table) -> Array[String] {
  self.columns.map(i => self.labels[i])
}

///|
fn Table::check_schema(self : Table, owner : Schema) -> Unit raise DesignError {
  if self.labels != owner.attributes() {
    raise Invalid("table belongs to different ordered schema")
  }
}

///|
fn Table::positions(
  self : Table,
  attrs : Array[Int32],
) -> Array[Int32] raise DesignError {
  let out = []
  for attr in attrs {
    let mut found = None
    for i in 0..<self.columns.length() {
      if self.columns[i] == attr {
        found = Some(i)
        break
      }
    }
    match found {
      None => raise Invalid("requested attribute missing from table")
      Some(i) => out.push(i)
    }
  }
  out
}

///|
fn Table::project_with(
  self : Table,
  attrs : Array[Int32],
  budget : Meter,
) -> Table raise DesignError {
  let positions = self.positions(attrs)
  let projected = self.data.map(row => positions.map(i => row[i]))
  budget.charge(self.data.length() * (attrs.length() + 1))
  {
    labels: self.labels.copy(),
    columns: attrs.copy(),
    data: unique_rows(projected, attrs.length(), budget),
  }
}

///|
pub fn Table::project(
  self : Table,
  columns : Array[Int32],
  limits~ : Limits = default_limits(),
) -> Table raise DesignError {
  let attrs = indices(columns, self.labels.length())
  if attrs.is_empty() {
    raise Invalid("projection requires nonempty columns")
  }
  self.project_with(attrs, meter(limits))
}

///|
fn Table::join_with(
  self : Table,
  other : Table,
  budget : Meter,
) -> Table raise DesignError {
  if self.labels != other.labels {
    raise Invalid("join requires same ordered schema")
  }
  let attrs = union(self.columns, other.columns)
  let common = intersection(self.columns, other.columns)
  let a_positions = self.positions(common)
  let b_positions = other.positions(common)
  let rows : Array[Array[String]] = []
  let from_first = attrs.map(a => self.columns.contains(a))
  let first_positions = self.positions(intersection(attrs, self.columns))
  let second_positions = other.positions(difference(attrs, self.columns))
  for a in self.data {
    for b in other.data {
      budget.charge(
        1 +
        common.length() +
        attrs.length() +
        rows.length() * (attrs.length() + 1),
      )
      let mut agrees = true
      for i in 0..<common.length() {
        if a[a_positions[i]] != b[b_positions[i]] {
          agrees = false
          break
        }
      }
      if !agrees {
        continue
      }
      let row = []
      let mut ai = 0
      let mut bi = 0
      for use_first in from_first {
        if use_first {
          row.push(a[first_positions[ai]])
          ai += 1
        } else {
          row.push(b[second_positions[bi]])
          bi += 1
        }
      }
      if !rows.contains(row) {
        if rows.length() + 1 > budget.limits.max_rows ||
          (rows.length() + 1) * attrs.length() > budget.limits.max_cells {
          raise Budget("join result allowance")
        }
        rows.push(row)
      }
    }
  }
  { labels: self.labels.copy(), columns: attrs, data: rows, }
}

///|
pub fn Table::natural_join(
  self : Table,
  other : Table,
  limits~ : Limits = default_limits(),
) -> Table raise DesignError {
  self.join_with(other, meter(limits))
}

///|
pub fn Table::set_equal(
  self : Table,
  other : Table,
  limits~ : Limits = default_limits(),
) -> Bool raise DesignError {
  if self.labels != other.labels || self.columns != other.columns {
    return false
  }
  let budget = meter(limits)
  budget.charge(1)
  budget.charge_product([
    self.data.length(),
    other.data.length(),
    self.columns.length() + 1,
  ])
  self.data.length() == other.data.length() &&
  self.data.all(row => other.data.contains(row))
}

///|
pub(all) struct Reconstruction {
  exact : Bool
  original_rows : Int32
  reconstructed_rows : Int32
  spurious : Array[Array[String]]
  missing : Array[Array[String]]
  reconstructed : Table
} derive(Debug)

///|
pub fn Table::reconstruct(
  self : Table,
  owner : Schema,
  relations : Array[Array[Int32]],
  limits~ : Limits = default_limits(),
) -> Reconstruction raise DesignError {
  self.check_schema(owner)
  if self.columns != full(owner.attribute_count()) {
    raise Invalid("reconstruction requires a full original relation")
  }
  let parts = owner.fragments(relations, true)
  let budget = meter(limits)
  let mut joined = self.project_with(parts[0], budget)
  for i in 1..<parts.length() {
    joined = joined.join_with(self.project_with(parts[i], budget), budget)
  }
  budget.charge(1)
  budget.charge_product([
    self.data.length(),
    joined.data.length(),
    self.columns.length() + 1,
  ])
  let spurious = joined.data
    .filter(row => !self.data.contains(row))
    .map(row => row.copy())
  let missing = self.data
    .filter(row => !joined.data.contains(row))
    .map(row => row.copy())
  {
    exact: spurious.is_empty() && missing.is_empty(),
    original_rows: self.row_count(),
    reconstructed_rows: joined.row_count(),
    spurious,
    missing,
    reconstructed: joined,
  }
}

///|
pub extend Table with Debug::{to_repr}

///|
pub extend Reconstruction with Debug::{to_repr}
