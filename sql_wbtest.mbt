///|
test "SQL is explicit advisory output with quoted identifiers" {
  let s = schema(["select", "group"], [{ left: [0], right: [1], }])
  let advice = s.sql_advice(s.synthesize_3nf(), "review")
  assert_eq(advice.primary_keys, [[0]])
  assert_true(advice.statements[0].contains("\"select\" TEXT NOT NULL"))
  assert_true(advice.to_text().contains("NOT enforced"))
  try s.sql_advice(s.synthesize_3nf(), "x; DROP TABLE y") catch {
    Invalid(_) => ()
    _ => fail("unexpected error")
  } noraise {
    _ => fail("invalid identifier accepted")
  }
}
