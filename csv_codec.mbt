///|
priv struct CsvReader {
  mut field : StringBuilder
  mut row : Array[String]
  rows : Array[Array[String]]
  mut units : Int
  budget : Meter
}

///|
fn CsvReader::append(self : CsvReader, c : Char) -> Unit raise DesignError {
  self.field.write_char(c)
  self.units += 1
  self.budget.charge(1)
  if self.units > 4096 { raise Invalid("CSV cell exceeds 4096 characters") }
}

///|
fn CsvReader::finish_field(self : CsvReader) -> Unit raise DesignError {
  if self.row.length() >= 16 { raise Invalid("CSV width exceeds 16") }
  self.row.push(self.field.to_string())
  self.field = StringBuilder()
  self.units = 0
}

///|
fn CsvReader::finish_row(self : CsvReader) -> Unit raise DesignError {
  self.finish_field()
  if self.rows.length() >= self.budget.limits.max_rows + 1 { raise Budget("CSV row allowance") }
  self.rows.push(self.row)
  self.row = []
}

///|
fn csv_rows(text : String, budget : Meter) -> Array[Array[String]] raise DesignError {
  if text.length() > 1048576 { raise Budget("CSV text allowance") }
  let reader : CsvReader = { field: StringBuilder(), row: [], rows: [], units: 0, budget }
  // States: 0 empty, 1 unquoted, 2 quoted, 3 after closing quote.
  let mut state = 0
  let mut after_cr = false
  let mut touched = false
  for c in text {
    budget.charge(1)
    if after_cr {
      after_cr = false
      if c == '\n' { continue }
    }
    touched = true
    if state == 2 {
      if c == '"' { state = 3 }
      else { reader.append(c) }
      continue
    }
    if state == 3 {
      if c == '"' { reader.append(c); state = 2; continue }
      if c != ',' && c != '\n' && c != '\r' { raise Invalid("characters after CSV closing quote") }
    }
    if c == ',' {
      reader.finish_field()
      state = 0
    } else if c == '\n' || c == '\r' {
      reader.finish_row()
      state = 0
      touched = false
      after_cr = c == '\r'
    } else if c == '"' {
      if state != 0 { raise Invalid("quote inside unquoted CSV field") }
      state = 2
    } else {
      reader.append(c)
      state = 1
    }
  }
  if state == 2 { raise Invalid("unterminated CSV quoted field") }
  if touched || !reader.row.is_empty() { reader.finish_row() }
  reader.rows
}

///|
pub fn parse_table_csv(owner : Schema, text : String, limits? : Limits = default_limits()) -> Table raise DesignError {
  let budget = meter(limits)
  let parsed = csv_rows(text, budget)
  if parsed.is_empty() { raise Invalid("CSV requires an attribute header") }
  let columns = owner.resolve(parsed[0])
  if columns.length() != parsed[0].length() { raise Invalid("duplicate CSV header") }
  if columns.map((i) => owner.labels[i]) != parsed[0] { raise Invalid("CSV header must follow schema order") }
  let rows = []
  for i in 1..<parsed.length() {
    if parsed[i].length() != columns.length() { raise Invalid("CSV row width differs from header") }
    rows.push(parsed[i])
  }
  table(owner, columns, rows, limits~)
}

///|
fn csv_field(value : String) -> String {
  let mut quoted = false
  for c in value {
    if c == ',' || c == '"' || c == '\r' || c == '\n' { quoted = true }
  }
  if !quoted { return value }
  let out = StringBuilder()
  out.write_char('"')
  for c in value {
    if c == '"' { out.write_char('"') }
    out.write_char(c)
  }
  out.write_char('"')
  out.to_string()
}

///|
pub fn Table::to_csv(self : Table) -> String {
  let out = StringBuilder()
  out.write_string(self.column_names().map(csv_field).join(",") + "\n")
  for row in self.data {
    out.write_string(row.map(csv_field).join(",") + "\n")
  }
  out.to_string()
}
