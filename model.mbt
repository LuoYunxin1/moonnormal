///|
pub suberror DesignError { Invalid(String); Budget(String) } derive(Debug)

///|
pub(all) struct FD {
  left : Array[Int]
  right : Array[Int]
} derive(Eq, Debug)

///|
pub struct Schema {
  priv labels : Array[String]
  priv theory : @fca.RuleSystem
} derive(Debug)

///|
pub(all) struct Limits {
  max_work : Int
  max_results : Int
  max_rows : Int
  max_cells : Int
} derive(Eq, Debug)

///|
pub fn default_limits() -> Limits {
  { max_work: 2000000, max_results: 4096, max_rows: 4096, max_cells: 65536 }
}

///|
priv struct Meter {
  mut remaining : Int
  limits : Limits
}

///|
fn meter(limits : Limits) -> Meter raise DesignError {
  if limits.max_work < 1 || limits.max_work > 200000000 ||
     limits.max_results < 1 || limits.max_results > 65536 ||
     limits.max_rows < 1 || limits.max_rows > 65536 ||
     limits.max_cells < 1 || limits.max_cells > 1048576 {
    raise Invalid("limits outside supported bounds")
  }
  { remaining: limits.max_work, limits }
}

///|
fn Meter::charge(self : Meter, work : Int) -> Unit raise DesignError {
  if work < 0 || work > self.remaining {
    raise Budget("operation exhausted work allowance")
  }
  self.remaining -= work
}

///|
fn Meter::result(self : Meter, count : Int) -> Unit raise DesignError {
  if count > self.limits.max_results {
    raise Budget("result count exceeds allowance")
  }
}

///|
fn indices(xs : Array[Int], n : Int) -> Array[Int] raise DesignError {
  let seen = Array::make(n, false)
  for x in xs {
    if x < 0 || x >= n { raise Invalid("attribute index outside schema") }
    seen[x] = true
  }
  let out = []
  for i in 0..<n { if seen[i] { out.push(i) } }
  out
}

///|
fn full(n : Int) -> Array[Int] {
  Array::makei(n, (i) => i)
}

///|
fn subset(a : Array[Int], b : Array[Int]) -> Bool {
  @fca.set_subset(a, b)
}

///|
fn union(a : Array[Int], b : Array[Int]) -> Array[Int] {
  @fca.set_union(a, b)
}

///|
fn difference(a : Array[Int], b : Array[Int]) -> Array[Int] {
  @fca.set_difference(a, b)
}

///|
fn intersection(a : Array[Int], b : Array[Int]) -> Array[Int] {
  @fca.set_intersection(a, b)
}

///|
fn safe_label(s : String) -> Bool {
  if s.length() == 0 || s.length() > 128 { return false }
  for c in s {
    if !((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
         (c >= '0' && c <= '9') || c == '_') { return false }
  }
  true
}

///|
pub fn schema(labels : Array[String], dependencies : Array[FD]) -> Schema raise DesignError {
  if labels.length() < 1 || labels.length() > 16 {
    raise Invalid("schema requires 1..16 attributes")
  }
  if dependencies.length() > 256 { raise Invalid("at most 256 declared dependencies") }
  for i in 0..<labels.length() {
    if !safe_label(labels[i]) { raise Invalid("attribute label must be ASCII identifier, length 1..128") }
    for j in 0..<i {
      if labels[i] == labels[j] { raise Invalid("duplicate attribute label") }
    }
  }
  let rules : Array[@fca.Implication] = []
  for fd in dependencies {
    let rule = try { @fca.implication(indices(fd.left, labels.length()), indices(fd.right, labels.length()), labels.length()) } catch { _ => raise Invalid("invalid upstream implication") }
    rules.push(rule)
  }
  let theory = try { @fca.rule_system(labels.length(), rules) } catch {
    _ => raise Invalid("upstream rejected validated FD theory")
  }
  { labels: labels.copy(), theory }
}

///|
pub fn Schema::attribute_count(self : Schema) -> Int { self.labels.length() }

///|
pub fn Schema::attributes(self : Schema) -> Array[String] { self.labels.copy() }

///|
pub fn Schema::dependencies(self : Schema) -> Array[FD] {
  self.theory.implications().map((r) => { { left: r.premise.copy(), right: r.conclusion.copy() } })
}

///|
pub fn Schema::attribute(self : Schema, label : String) -> Int? {
  for i in 0..<self.labels.length() { if self.labels[i] == label { return Some(i) } }
  None
}

///|
pub fn Schema::resolve(self : Schema, names : Array[String]) -> Array[Int] raise DesignError {
  let out = []
  for name in names {
    match self.attribute(name) {
      Some(i) => out.push(i)
      None => raise Invalid("unknown attribute label: " + name)
    }
  }
  indices(out, self.attribute_count())
}

///|
pub fn Schema::names(self : Schema, attrs : Array[Int]) -> Array[String] raise DesignError {
  indices(attrs, self.attribute_count()).map((i) => { self.labels[i] })
}

///|
fn Schema::close(self : Schema, seed : Array[Int], budget : Meter) -> Array[Int] raise DesignError {
  budget.charge(1 + self.attribute_count() * (self.dependencies().length() + 1))
  try { self.theory.closure(seed) } catch { _ => raise Invalid("upstream closure failed") }
}

///|
pub fn Schema::closure(self : Schema, seed : Array[Int], limits? : Limits = default_limits()) -> Array[Int] raise DesignError {
  self.close(indices(seed, self.attribute_count()), meter(limits))
}

///|
pub fn Schema::entails(self : Schema, fd : FD, limits? : Limits = default_limits()) -> Bool raise DesignError {
  let a = indices(fd.left, self.attribute_count())
  let b = indices(fd.right, self.attribute_count())
  subset(b, self.close(a, meter(limits)))
}

///|
pub extend DesignError with Debug::{to_repr}

///|
pub extend FD with Eq::{equal, not_equal}

///|
pub extend FD with Debug::{to_repr}

///|
pub extend Schema with Debug::{to_repr}

///|
pub extend Limits with Eq::{equal, not_equal}

///|
pub extend Limits with Debug::{to_repr}

///|
fn Meter::charge_product(self : Meter, factors : Array[Int]) -> Unit raise DesignError {
  let mut product = 1
  for factor in factors {
    if factor < 0 { raise Invalid("negative work factor") }
    if factor == 0 { return }
  }
  for factor in factors {
    if product > self.remaining / factor { raise Budget("work product exceeds allowance") }
    product *= factor
  }
  self.charge(product)
}
