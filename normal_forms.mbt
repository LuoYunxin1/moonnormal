///|
pub(all) enum NormalForm { Second; Third; BoyceCodd } derive(Eq, Debug)

///|
pub(all) struct Violation {
  relation : Array[Int]
  dependency : FD
  form : NormalForm
} derive(Eq, Debug)

///|
fn Schema::violations_of(self : Schema, attrs : Array[Int], form : NormalForm, budget : Meter) -> Array[Violation] raise DesignError {
  let keys = if form == BoyceCodd { [] } else { self.keys_of(attrs, budget) }
  let mut prime = []
  for key in keys { prime = union(prime, key) }
  let out = []
  for seed in subsets(attrs, budget) {
    let closed = intersection(self.close(seed, budget), attrs)
    if subset(attrs, closed) { continue }
    let mut bad = difference(closed, seed)
    if form != BoyceCodd { bad = difference(bad, prime) }
    if form == Second && !keys.any(fn(k) { seed.length() < k.length() && subset(seed, k) }) { continue }
    if !bad.is_empty() {
      budget.result(out.length() + 1)
      out.push({ relation: attrs.copy(), dependency: { left: seed, right: bad }, form })
    }
  }
  out
}

///|
pub fn Schema::normal_form_violations(self : Schema, relation : Array[Int], form : NormalForm, limits? : Limits = default_limits()) -> Array[Violation] raise DesignError {
  let attrs = indices(relation, self.attribute_count())
  if attrs.is_empty() { raise Invalid("normal form requires nonempty relation") }
  self.violations_of(attrs, form, meter(limits))
}

///|
pub fn Schema::in_normal_form(self : Schema, relation : Array[Int], form : NormalForm, limits? : Limits = default_limits()) -> Bool raise DesignError {
  self.normal_form_violations(relation, form, limits~).is_empty()
}

///|
pub(all) struct RelationProfile {
  attributes : Array[Int]
  keys : Array[Array[Int]]
  prime : Array[Int]
  second : Bool
  third : Bool
  boyce_codd : Bool
} derive(Eq, Debug)

///|
pub fn Schema::relation_profile(self : Schema, relation : Array[Int], limits? : Limits = default_limits()) -> RelationProfile raise DesignError {
  let attrs = indices(relation, self.attribute_count())
  if attrs.is_empty() { raise Invalid("profile requires nonempty relation") }
  let budget = meter(limits)
  let keys = self.keys_of(attrs, budget)
  let mut prime = []
  for key in keys { prime = union(prime, key) }
  let second = self.violations_of(attrs, Second, budget).is_empty()
  let third = self.violations_of(attrs, Third, budget).is_empty()
  let boyce_codd = self.violations_of(attrs, BoyceCodd, budget).is_empty()
  { attributes: attrs, keys, prime, second, third, boyce_codd }
}

///|
pub extend NormalForm with Eq::{equal, not_equal}

///|
pub extend NormalForm with Debug::{to_repr}

///|
pub extend Violation with Eq::{equal, not_equal}

///|
pub extend Violation with Debug::{to_repr}

///|
pub extend RelationProfile with Eq::{equal, not_equal}

///|
pub extend RelationProfile with Debug::{to_repr}
