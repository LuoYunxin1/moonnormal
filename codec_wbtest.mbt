///|
test "versioned codecs preserve verified models" {
  let s = parse_schema_text("attributes: A,B,C\nA -> B\nB -> C\n")
  let s2 = parse_schema_json(s.to_json().stringify())
  assert_eq(s2.attributes(), s.attributes())
  assert_true(s.equivalent(s2))
  assert_true(s.equivalent(parse_schema_text(s.to_text())))
  let t = table(s, [0, 1, 2], [["a", "b", "c"], ["d", "e", "f"]])
  assert_true(t.set_equal(parse_table_json(s, t.to_json().stringify())))
  let plan = s.decompose_bcnf()
  assert_eq(parse_plan_json(s, plan.to_json(s).stringify()), plan)
}
