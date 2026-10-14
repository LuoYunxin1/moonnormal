///|
test "CSV roundtrip quotes multiline Unicode and empty strings" {
  let s = schema(["A", "B"], [])
  let t = table(s, [0, 1], [
    ["a,b", "line\nnext"],
    ["say \"yes\"", "中文"],
    ["", ""],
  ])
  assert_true(t.set_equal(parse_table_csv(s, t.to_csv())))
  assert_eq(parse_table_csv(s, "A,B\r\nx,y\r\n").rows(), [["x", "y"]])
}

///|
test "CSV rejects syntax and header ambiguity" {
  let s = schema(["A", "B"], [])
  for text in ["B,A\nx,y", "A,A\nx,y", "A,B\n\"x\"z,y", "A,B\n\"x,y", "A,B\nx"] {
    try parse_table_csv(s, text) catch {
      Invalid(_) => ()
      _ => fail("unexpected error class")
    } noraise {
      _ => fail("malformed CSV accepted")
    }
  }
}
