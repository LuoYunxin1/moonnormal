///|
fn Schema::project_fds(
  self : Schema,
  attrs : Array[Int32],
  budget : Meter,
) -> Array[FD] raise DesignError {
  let fds : Array[FD] = []
  for seed in subsets(attrs, budget) {
    let determined = difference(
      intersection(self.close(seed, budget), attrs),
      seed,
    )
    if !determined.is_empty() {
      budget.result(fds.length() + 1)
      fds.push({ left: seed, right: determined, })
    }
  }
  fds
}

///|
pub fn Schema::project_dependencies(
  self : Schema,
  relation : Array[Int32],
  limits~ : Limits = default_limits(),
) -> Array[FD] raise DesignError {
  let attrs = indices(relation, self.attribute_count())
  self.project_fds(attrs, meter(limits))
}

///|
fn Schema::with_fds(self : Schema, fds : Array[FD]) -> Schema raise DesignError {
  let rules : Array[@fca.Implication] = []
  for fd in fds {
    let rule = @fca.implication(fd.left, fd.right, self.attribute_count()) catch {
      _ => raise Invalid("invalid projected dependency")
    }
    rules.push(rule)
  }
  let theory = @fca.rule_system(self.attribute_count(), rules) catch {
    _ => raise Budget("projected FD system exceeds upstream rule allowance")
  }
  { labels: self.labels.copy(), theory, }
}

///|
fn Schema::fragments(
  self : Schema,
  input : Array[Array[Int32]],
  require_cover : Bool,
) -> Array[Array[Int32]] raise DesignError {
  if input.is_empty() || input.length() > 64 {
    raise Invalid("decomposition requires 1..64 fragments")
  }
  let out : Array[Array[Int32]] = []
  let mut covered = []
  for fragment in input {
    let attrs = indices(fragment, self.attribute_count())
    if attrs.is_empty() {
      raise Invalid("fragment must not be empty")
    }
    if out.any(x => x == attrs) {
      raise Invalid("duplicate fragment")
    }
    covered = union(covered, attrs)
    out.push(attrs)
  }
  if require_cover && covered != full(self.attribute_count()) {
    raise Invalid("decomposition does not cover original relation")
  }
  out
}

///|
pub(all) struct Preservation {
  preserved : Bool
  missing : Array[FD]
  projected_dependency_count : Int32
} derive(Eq, Debug)

///|
fn Schema::preservation_of(
  self : Schema,
  relations : Array[Array[Int32]],
  budget : Meter,
) -> Preservation raise DesignError {
  let fds : Array[FD] = []
  for attrs in relations {
    for fd in self.project_fds(attrs, budget) {
      if !fds.contains(fd) {
        budget.result(fds.length() + 1)
        fds.push(fd)
      }
    }
  }
  let projected = self.with_fds(fds)
  let missing = []
  for fd in self.dependencies() {
    if !subset(fd.right, projected.close(fd.left, budget)) {
      missing.push(fd)
    }
  }
  {
    preserved: missing.is_empty(),
    missing,
    projected_dependency_count: fds.length(),
  }
}

///|
pub fn Schema::dependency_preservation(
  self : Schema,
  relations : Array[Array[Int32]],
  limits~ : Limits = default_limits(),
) -> Preservation raise DesignError {
  self.preservation_of(self.fragments(relations, true), meter(limits))
}

///|
pub fn Schema::binary_lossless(
  self : Schema,
  first : Array[Int32],
  second : Array[Int32],
  limits~ : Limits = default_limits(),
) -> Bool raise DesignError {
  let relations = self.fragments([first, second], true)
  let common = intersection(relations[0], relations[1])
  let closed = self.close(common, meter(limits))
  subset(relations[0], closed) || subset(relations[1], closed)
}

///|
pub extend Preservation with Eq::{equal, not_equal}

///|
pub extend Preservation with Debug::{to_repr}
