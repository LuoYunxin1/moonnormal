///|
test "reports expose caveats rather than pretending to enforce FDs" {
  let s = parse_schema_text("attributes: A,B,C\nA,B -> C\nC -> B")
  let p = s.decompose_bcnf()
  assert_true(s.plan_report(p).contains("Not preserved: {A, B} -> {C}"))
  let t = table(s,[0,1,2],[["a","b","c"],["a","b","d"]])
  assert_true(t.audit_report(s).contains("Rows 0 and 1 violate"))
  assert_true(s.review_migration(p,p).summary(s).contains("does not authorize"))
}
