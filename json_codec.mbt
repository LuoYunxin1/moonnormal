///|
fn parse_json_value(text : String) -> Json raise DesignError {
  if text.length() > 1048576 {
    raise Budget("JSON text exceeds one million code units")
  }
  let mut depth = 0
  let mut in_string = false
  let mut escaped = false
  for c in text {
    if in_string {
      if escaped {
        escaped = false
      } else if c == '\\' {
        escaped = true
      } else if c == '"' {
        in_string = false
      }
    } else if c == '"' {
      in_string = true
    } else if c == '[' || c == '{' {
      depth += 1
      if depth > 12 {
        raise Budget("JSON nesting exceeds 12")
      }
    } else if c == ']' || c == '}' {
      depth -= 1
    }
  }
  @json.parse(text[:]) catch {
    _ => raise Invalid("invalid JSON")
  }
}

///|
fn fields_of(
  value : Json,
  names : Array[String],
) -> Map[String, Json] raise DesignError {
  match value {
    Object(fields) => {
      if fields.length() != names.length() ||
        !names.all(s => fields.contains(s)) {
        raise Invalid("JSON fields differ from versioned schema")
      }
      fields
    }
    _ => raise Invalid("expected JSON object")
  }
}

///|
fn required(
  fields : Map[String, Json],
  name : String,
) -> Json raise DesignError {
  match fields.get(name) {
    Some(v) => v
    None => raise Invalid("missing JSON field")
  }
}

///|
fn array_of(value : Json, limit : Int32) -> Array[Json] raise DesignError {
  match value {
    Array(values) => {
      if values.length() > limit {
        raise Budget("JSON array allowance")
      }
      values
    }
    _ => raise Invalid("expected JSON array")
  }
}

///|
fn string_of(value : Json) -> String raise DesignError {
  match value {
    String(s) => s
    _ => raise Invalid("expected JSON string")
  }
}

///|
fn attribute_array(value : Json, n : Int32) -> Array[Int32] raise DesignError {
  let out = []
  for v in array_of(value, 16) {
    match v {
      Number(x, ..) => {
        if x.is_nan() ||
          x.is_inf() ||
          x < 0.0 ||
          x >= n.to_double() ||
          x.to_int().to_double() != x {
          raise Invalid("JSON attribute must be an in-range integer")
        }
        out.push(x.to_int())
      }
      _ => raise Invalid("expected JSON attribute number")
    }
  }
  indices(out, n)
}

///|
fn ordered_attributes(
  value : Json,
  n : Int32,
) -> Array[Int32] raise DesignError {
  let attrs = attribute_array(value, n)
  let original = array_of(value, 16)
  if original.length() != attrs.length() {
    raise Invalid("duplicate table columns")
  }
  for i in 0..<attrs.length() {
    match original[i] {
      Number(x, ..) =>
        if x != attrs[i].to_double() {
          raise Invalid("table columns must be ordered")
        }
      _ => raise Invalid("table column must be numeric")
    }
  }
  attrs
}

///|
fn attrs_json(attrs : Array[Int32]) -> Json {
  Json::array(attrs.map(i => Json::number(i.to_double())))
}

///|
fn fd_json(fd : FD) -> Json {
  Json::object({ "left": attrs_json(fd.left), "right": attrs_json(fd.right) })
}

///|
pub fn Schema::to_json(self : Schema) -> Json {
  Json::object({
    "format": Json::string("moonnormal-schema/v1"),
    "attributes": Json::array(self.labels.map(s => Json::string(s))),
    "dependencies": Json::array(self.dependencies().map(fd => fd_json(fd))),
  })
}

///|
pub fn parse_schema_json(text : String) -> Schema raise DesignError {
  let fields = fields_of(parse_json_value(text), [
    "format", "attributes", "dependencies",
  ])
  if string_of(required(fields, "format")) != "moonnormal-schema/v1" {
    raise Invalid("unsupported schema format")
  }
  let labels = array_of(required(fields, "attributes"), 16).map(v => {
    string_of(v)
  })
  let dependencies = array_of(required(fields, "dependencies"), 256).map(v => {
    let f = fields_of(v, ["left", "right"])
    {
      left: attribute_array(required(f, "left"), labels.length()),
      right: attribute_array(required(f, "right"), labels.length()),
    }
  })
  schema(labels, dependencies)
}

///|
pub fn Table::to_json(self : Table) -> Json {
  Json::object({
    "format": Json::string("moonnormal-table/v1"),
    "attributes": Json::array(self.labels.map(s => Json::string(s))),
    "columns": attrs_json(self.columns),
    "rows": Json::array(
      self.data.map(row => Json::array(row.map(s => Json::string(s)))),
    ),
  })
}

///|
pub fn parse_table_json(
  owner : Schema,
  text : String,
  limits~ : Limits = default_limits(),
) -> Table raise DesignError {
  let fields = fields_of(parse_json_value(text), [
    "format", "attributes", "columns", "rows",
  ])
  if string_of(required(fields, "format")) != "moonnormal-table/v1" {
    raise Invalid("unsupported table format")
  }
  let labels = array_of(required(fields, "attributes"), 16).map(v => {
    string_of(v)
  })
  if labels != owner.attributes() {
    raise Invalid("JSON table schema mismatch")
  }
  let columns = ordered_attributes(required(fields, "columns"), labels.length())
  let rows = array_of(required(fields, "rows"), limits.max_rows).map(row => {
    array_of(row, 16).map(cell => string_of(cell))
  })
  table(owner, columns, rows, limits~)
}

///|
pub fn Plan::to_json(self : Plan, owner : Schema) -> Json raise DesignError {
  let relations = owner.fragments(self.relations, true)
  let target = match self.target {
    Second => "2NF"
    Third => "3NF"
    BoyceCodd => "BCNF"
  }
  Json::object({
    "format": Json::string("moonnormal-plan/v1"),
    "target": Json::string(target),
    "relations": Json::array(relations.map(r => attrs_json(r))),
    "added_key_relation": Json::boolean(self.added_key_relation),
    "splits": Json::array(
      self.splits.map(step => {
        Json::object({
          "input": attrs_json(step.input),
          "dependency": fd_json(step.dependency),
          "first": attrs_json(step.first),
          "second": attrs_json(step.second),
        })
      }),
    ),
  })
}

///|
pub fn parse_plan_json(owner : Schema, text : String) -> Plan raise DesignError {
  let fields = fields_of(parse_json_value(text), [
    "format", "target", "relations", "added_key_relation", "splits",
  ])
  if string_of(required(fields, "format")) != "moonnormal-plan/v1" {
    raise Invalid("unsupported plan format")
  }
  let target = match string_of(required(fields, "target")) {
    "2NF" => Second
    "3NF" => Third
    "BCNF" => BoyceCodd
    _ => raise Invalid("unknown normal form")
  }
  let n = owner.attribute_count()
  let relations = owner.fragments(
    array_of(required(fields, "relations"), 64).map(v => attribute_array(v, n)),
    true,
  )
  let added_key_relation = match required(fields, "added_key_relation") {
    True => true
    False => false
    _ => raise Invalid("key relation flag must be boolean")
  }
  let splits = array_of(required(fields, "splits"), 64).map(v => {
    let f = fields_of(v, ["input", "dependency", "first", "second"])
    let d = fields_of(required(f, "dependency"), ["left", "right"])
    {
      input: attribute_array(required(f, "input"), n),
      dependency: {
        left: attribute_array(required(d, "left"), n),
        right: attribute_array(required(d, "right"), n),
      },
      first: attribute_array(required(f, "first"), n),
      second: attribute_array(required(f, "second"), n),
    }
  })
  { target, relations, splits, added_key_relation, }
}
