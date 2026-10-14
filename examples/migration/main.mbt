///|
fn workflow() -> String raise {
  let schema = @normal.parse_schema_text("attributes: A,B,C\nA -> B")
  let before : @normal.Plan = {
    target: @normal.BoyceCodd,
    relations: [[0, 1], [0, 2]],
    splits: [],
    added_key_relation: false,
  }
  let after : @normal.Plan = {
    target: @normal.BoyceCodd,
    relations: [[0, 1], [1, 2]],
    splits: [],
    added_key_relation: false,
  }
  let review = schema.review_migration(before, after)
  assert_true(review.lossless_regression)
  let witness = schema.lossy_counterexample(after.relations).unwrap()
  assert_true(schema.verify_lossy_counterexample(after.relations, witness))
  assert_true(!witness.instance.reconstruct(schema, after.relations).exact)
  "migration-ok\n" + review.summary(schema) + witness.instance.to_csv()
}

///|
fn main {
  let output = workflow() catch { _ => abort("migration workflow failed") }
  println(output)
}
