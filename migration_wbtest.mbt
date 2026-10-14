///|
test "migration catches preservation regression and reports locality" {
  let s = schema(["A","B","C"], [{left:[0,1],right:[2]},{left:[2],right:[1]}])
  let before : Plan = {target:BoyceCodd,relations:[[0,1,2]],splits:[],added_key_relation:false}
  let after = s.decompose_bcnf()
  let review = s.review_migration(before,after)
  assert_true(!review.lossless_regression)
  assert_eq(review.lost_dependencies.length(),1)
  assert_eq(review.locality[0].containing_relations,[])
  assert_true(!review.locality[0].jointly_preserved)
  assert_eq(review.layout.duplicated_attributes_after,[2])
}
