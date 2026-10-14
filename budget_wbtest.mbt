///|
test "checked products cannot wrap and zero factor is free" {
  let m = meter(default_limits())
  try m.charge_product([65536,65536,17]) catch {
    Budget(_) => ()
    _ => fail("unexpected error")
  } noraise { _ => fail("overflow accepted") }
  m.charge_product([65536,65536,0])
  assert_eq(m.remaining, default_limits().max_work)
}
///|
test "reject table JSON column permutations instead of silently moving values" {
  let s = schema(["A","B"], [])
  let malformed = "{\"format\":\"moonnormal-table/v1\",\"attributes\":[\"A\",\"B\"],\"columns\":[1,0],\"rows\":[[\"b\",\"a\"]]}"
  try parse_table_json(s,malformed) catch {
    Invalid(_) => ()
    _ => fail("unexpected error")
  } noraise { _ => fail("permutation accepted") }
}
