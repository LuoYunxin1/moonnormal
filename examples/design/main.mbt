///|
fn workflow() -> String raise {
  let schema = @normal.parse_schema_text(
    "attributes: Student,Course,Tutor\nStudent,Course -> Tutor\nTutor -> Course",
  )
  let third = schema.synthesize_3nf()
  let bcnf = schema.decompose_bcnf()
  let third_audit = schema.audit_plan(third)
  let bcnf_audit = schema.audit_plan(bcnf)
  assert_true(third_audit.lossless && third_audit.dependency_preserving)
  assert_true(bcnf_audit.lossless && bcnf_audit.target_satisfied)
  assert_true(!bcnf_audit.dependency_preserving)
  let saved = @normal.parse_plan_json(schema, bcnf.to_json(schema).stringify())
  assert_true(schema.verify_split_trace(saved))
  "design-ok\n" +
  schema.plan_report(bcnf) +
  schema.sql_advice(bcnf, "advisory").to_text()
}

///|
fn main {
  let output = workflow() catch { _ => abort("design workflow failed") }
  println(output)
}
