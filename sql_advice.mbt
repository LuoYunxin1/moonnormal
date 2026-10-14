///|
pub(all) struct SqlAdvice {
  statements : Array[String]
  warnings : Array[String]
  primary_keys : Array[Array[Int32]]
} derive(Eq, Debug)

///|
fn quote_sql_identifier(name : String) -> String raise DesignError {
  if !safe_label(name) {
    raise Invalid("SQL identifiers must use validated ASCII labels")
  }
  "\"" + name + "\""
}

///|
fn sql_columns(
  owner : Schema,
  attrs : Array[Int32],
) -> String raise DesignError {
  let names = []
  for a in attrs {
    names.push(quote_sql_identifier(owner.labels[a]))
  }
  names.join(", ")
}

///|
pub fn Schema::sql_advice(
  self : Schema,
  plan : Plan,
  prefix : String,
  limits~ : Limits = default_limits(),
) -> SqlAdvice raise DesignError {
  if !safe_label(prefix) || prefix.length() > 100 {
    raise Invalid("SQL prefix must be a short ASCII identifier")
  }
  let parts = self.fragments(plan.relations, true)
  let budget = meter(limits)
  let statements = []
  let primary_keys = []
  let warnings = [
    "Advisory SQL only: no execution, type inference, migration ordering or dialect validation.",
    "All columns use TEXT NOT NULL. Literal strings do not model SQL NULL.", "General functional dependencies are NOT enforced by these primary keys.",
    "No foreign keys are inferred: repeated attributes alone do not imply referential integrity.",
  ]
  for i in 0..<parts.length() {
    let attrs = parts[i]
    let keys = self.keys_of(attrs, budget)
    let key = keys[0]
    primary_keys.push(key.copy())
    let clauses = []
    for a in attrs {
      clauses.push(
        "  " + quote_sql_identifier(self.labels[a]) + " TEXT NOT NULL",
      )
    }
    if key.is_empty() {
      warnings.push(
        "Relation " +
        i.to_string() +
        " has an empty key; SQL does not enforce its at-most-one-tuple semantics.",
      )
    } else {
      clauses.push("  PRIMARY KEY (" + sql_columns(self, key) + ")")
    }
    let name = quote_sql_identifier(prefix + "_" + i.to_string())
    statements.push(
      "CREATE TABLE " + name + " (\n" + clauses.join(",\n") + "\n);",
    )
  }
  let preservation = self.preservation_of(parts, budget)
  if !preservation.preserved {
    warnings.push(
      "Decomposition loses " +
      preservation.missing.length().to_string() +
      " declared dependencies; cross-relation checks are required.",
    )
  }
  SqlAdvice::{ statements, warnings, primary_keys, }
}

///|
pub fn SqlAdvice::to_text(self : SqlAdvice) -> String {
  let out = StringBuilder()
  for warning in self.warnings {
    out.write_string("-- " + warning + "\n")
  }
  out.write_string(self.statements.join("\n\n"))
  out.write_string("\n")
  out.to_string()
}

///|
pub extend SqlAdvice with Eq::{equal, not_equal}

///|
pub extend SqlAdvice with Debug::{to_repr}
