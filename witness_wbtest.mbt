///|
test "lossy tableau materializes an actual FD-satisfying counterexample" {
  let s = schema(["A","B","C"], [{left:[0],right:[1]}])
  let parts = [[0,1],[1,2]]
  let witness = s.lossy_counterexample(parts).unwrap()
  assert_true(s.verify_lossy_counterexample(parts,witness))
  assert_true(witness.instance.audit_dependencies(s).violations.is_empty())
  assert_true(!witness.instance.reconstruct(s,parts).exact)
  assert_true(s.lossy_counterexample([[0,1],[0,2]]) is None)
}
///|
test "trace verification rejects fabricated provenance" {
  let s = schema(["A","B"], [])
  let parts = [[0],[1]]
  let original = s.lossless_chase(parts)
  assert_true(s.verify_chase_trace(parts,original))
  original.final_tableau[0][1] = 1
  assert_true(!s.verify_chase_trace(parts,original))
}
