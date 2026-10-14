///|
test "3NF tradeoff against BCNF" {
  let s = schema(["A", "B", "C"], [
    { left: [0, 1], right: [2], },
    { left: [2], right: [1], },
  ])
  assert_eq(s.candidate_keys(), [[0, 1], [0, 2]])
  assert_true(s.normal_form_violations([0, 1, 2], Third).is_empty())
  assert_true(!s.normal_form_violations([0, 1, 2], BoyceCodd).is_empty())
  let third = s.synthesize_3nf()
  let a = s.audit_plan(third)
  assert_true(a.lossless && a.dependency_preserving && a.target_satisfied)
  let bcnf = s.decompose_bcnf()
  assert_true(s.verify_split_trace(bcnf))
  let b = s.audit_plan(bcnf)
  assert_true(b.lossless && b.target_satisfied && !b.dependency_preserving)
}

///|
test "empty determinant and no dependencies" {
  let constant = schema(["A", "B"], [{ left: [], right: [0, 1], }])
  assert_eq(constant.candidate_keys(), [[]])
  assert_true(constant.audit_plan(constant.synthesize_3nf()).lossless)
  let empty = schema(["A", "B"], [])
  assert_eq(empty.synthesize_3nf().relations, [[0, 1]])
  assert_eq(empty.decompose_bcnf().relations, [[0, 1]])
}
