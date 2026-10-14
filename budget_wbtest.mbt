///|
test "checked products cannot wrap and zero factor is free" {
  let m = meter(default_limits())
  let outcome = try? m.charge_product([65536,65536,17])
  assert_true(outcome is Err(Budget(_)))
  m.charge_product([65536,65536,0])
  assert_eq(m.remaining, default_limits().max_work)
}
///|
test "reject table JSON column permutations instead of silently moving values" {
  let s = schema(["A","B"], [])
  let malformed = "{\"format\":\"moonnormal-table/v1\",\"attributes\":[\"A\",\"B\"],\"columns\":[1,0],\"rows\":[[\"b\",\"a\"]]}"
  let outcome = try? parse_table_json(s,malformed)
  assert_true(outcome is Err(Invalid(_)))
}
