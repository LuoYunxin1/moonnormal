///|
fn comma_names(text : String) -> Array[String] raise DesignError {
  if text.trim().is_empty() { return [] }
  let out = []
  for token in text.split(",") {
    let name = token.trim().to_owned()
    if !safe_label(name) { raise Invalid("invalid identifier in dependency text") }
    if out.contains(name) { raise Invalid("duplicate identifier in dependency text") }
    out.push(name)
  }
  out
}

///|
pub fn parse_schema_text(text : String) -> Schema raise DesignError {
  if text.length() > 65536 { raise Budget("schema text allowance") }
  let lines = text.split("\n").map((line) => { line.trim().to_owned() }).filter((line) => { !line.is_empty() }).to_array()
  if lines.is_empty() { raise Invalid("missing attributes header") }
  let parts = lines[0].split(":").to_array()
  if parts.length() != 2 || parts[0].trim().to_owned() != "attributes" { raise Invalid("first line must be attributes: A,B,...") }
  let labels = comma_names(parts[1].to_owned())
  let empty = schema(labels, [])
  let dependencies = []
  for i in 1..<lines.length() {
    let halves = lines[i].split("->").to_array()
    if halves.length() != 2 { raise Invalid("dependency line must contain exactly one arrow") }
    let left = empty.resolve(comma_names(halves[0].to_owned()))
    let right = empty.resolve(comma_names(halves[1].to_owned()))
    if right.is_empty() { raise Invalid("text FD conclusion must not be empty") }
    dependencies.push({ left, right })
  }
  schema(labels, dependencies)
}

///|
pub fn Schema::to_text(self : Schema) -> String {
  let out = StringBuilder()
  out.write_string("attributes: " + self.labels.join(",") + "\n")
  for fd in self.dependencies() {
    if fd.right.is_empty() { continue }
    let a = fd.left.map((i) => { self.labels[i] }).join(",")
    let b = fd.right.map((i) => { self.labels[i] }).join(",")
    out.write_string(a + " -> " + b + "\n")
  }
  out.to_string()
}
