///|
test "lossy reconstruction witnesses and set semantics" {
  let s = schema(["A", "B", "C"], [])
  let t = table(s, [0, 1, 2], [
    ["a", "b", "c"],
    ["x", "b", "y"],
    ["a", "b", "c"],
  ])
  assert_eq(t.row_count(), 2)
  let r = t.reconstruct(s, [[0, 1], [1, 2]])
  assert_true(!r.exact)
  assert_eq(r.spurious.length(), 2)
  assert_eq(r.missing.length(), 0)
  assert_true(t.project([0, 1]).natural_join(t.project([0, 2])).set_equal(t))
}

///|
test "tuple inputs and getters are isolated" {
  let s = schema(["A"], [])
  let rows = [["before"]]
  let t = table(s, [0], rows)
  rows[0][0] = "after"
  let copy = t.rows()
  copy[0][0] = "changed"
  assert_eq(t.rows(), [["before"]])
}
