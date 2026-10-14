///|
test "observed FD audit is not universal inference" {
  let s = schema(["A","B","C"], [{left:[0],right:[1]}, {left:[1],right:[2]}])
  let t = table(s,[0,1,2],[["x","one","z"],["x","two","z"]])
  let audit = t.audit_dependencies(s)
  assert_eq(audit.violations.length(), 1)
  assert_eq(audit.violations[0].differing_attributes, [1])
  assert_eq(t.key_collisions([0]).length(), 1)
  assert_eq(t.column_profiles()[0].distinct_values, 1)
  let partial = t.project([0,1]).audit_dependencies(s)
  assert_eq(partial.checked_dependencies, [0])
  assert_eq(partial.skipped_dependencies, [1])
}
