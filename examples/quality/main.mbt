///|
fn workflow() -> String raise {
  let schema = @normal.parse_schema_text(
    "attributes: Customer,Email,Region\nCustomer -> Email,Region",
  )
  let data = @normal.parse_table_csv(
    schema, "Customer,Email,Region\n42,one@example.invalid,East\n42,two@example.invalid,West\n7,seven@example.invalid,East\n",
  )
  let audit = data.audit_dependencies(schema)
  assert_eq(audit.violations.length(), 1)
  assert_eq(data.key_collisions([0]).length(), 1)
  let json = data.to_json().stringify()
  assert_true(data.set_equal(@normal.parse_table_json(schema, json)))
  assert_true(data.reconstruct(schema, [[0, 1], [0, 2]]).spurious.length() > 0)
  "quality-ok\n" + data.audit_report(schema)
}

///|
fn main {
  let output = workflow() catch { _ => abort("quality workflow failed") }
  println(output)
}
