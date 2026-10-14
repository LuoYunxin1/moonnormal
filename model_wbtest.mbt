///|
test "schema isolates caller arrays and delegates closure" {
  let labels = ["A", "B", "C"]
  let left = [0]
  let s = schema(labels, [{ left, right: [1], }, { left: [1], right: [2], }])
  labels[0] = "changed"
  left.clear()
  assert_eq(s.attributes(), ["A", "B", "C"])
  assert_eq(s.closure([0]), [0, 1, 2])
  assert_true(s.entails({ left: [0], right: [2], }))
  assert_true(!s.entails({ left: [2], right: [0], }))
  assert_eq(s.resolve(["C", "A", "A"]), [0, 2])
}

///|
test "invalid labels and indices are errors" {
  let rejected = try {
    let _ = schema(["A", "A"], [])
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  let s = schema(["A"], [])
  assert_true(
    try {
      let _ = s.closure([1])
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      let _ = schema(["bad name"], [])
      false
    } catch {
      _ => true
    },
  )
}
