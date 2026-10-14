///|
fn mask_set(mask : Int32, attrs : Array[Int32]) -> Array[Int32] {
  let out = []
  for i in 0..<attrs.length() {
    if (mask & (1 << i)) != 0 {
      out.push(attrs[i])
    }
  }
  out
}

///|
fn subsets(
  attrs : Array[Int32],
  budget : Meter,
) -> Array[Array[Int32]] raise DesignError {
  let count = 1 << attrs.length()
  budget.charge_product([count, attrs.length() + 1, attrs.length() + 1])
  let out = []
  // Cardinality order makes minimal-key filtering deterministic.
  for size in 0..<=attrs.length() {
    for mask in 0..<count {
      let xs = mask_set(mask, attrs)
      if xs.length() == size {
        out.push(xs)
      }
    }
  }
  out
}

///|
fn Schema::keys_of(
  self : Schema,
  attrs : Array[Int32],
  budget : Meter,
) -> Array[Array[Int32]] raise DesignError {
  let keys : Array[Array[Int32]] = []
  for seed in subsets(attrs, budget) {
    budget.charge(keys.length() + 1)
    if keys.any(k => subset(k, seed)) {
      continue
    }
    if subset(attrs, self.close(seed, budget)) {
      budget.result(keys.length() + 1)
      keys.push(seed)
    }
  }
  keys
}

///|
pub fn Schema::candidate_keys(
  self : Schema,
  relation~ : Array[Int32] = [],
  limits~ : Limits = default_limits(),
) -> Array[Array[Int32]] raise DesignError {
  let attrs = if relation.is_empty() {
    full(self.attribute_count())
  } else {
    indices(relation, self.attribute_count())
  }
  self.keys_of(attrs, meter(limits))
}

///|
pub fn Schema::is_superkey(
  self : Schema,
  seed : Array[Int32],
  relation : Array[Int32],
  limits~ : Limits = default_limits(),
) -> Bool raise DesignError {
  let attrs = indices(relation, self.attribute_count())
  let key = indices(seed, self.attribute_count())
  if !subset(key, attrs) {
    raise Invalid("key must be within relation")
  }
  subset(attrs, self.close(key, meter(limits)))
}

///|
pub fn Schema::is_candidate_key(
  self : Schema,
  seed : Array[Int32],
  relation : Array[Int32],
  limits~ : Limits = default_limits(),
) -> Bool raise DesignError {
  let attrs = indices(relation, self.attribute_count())
  let key = indices(seed, self.attribute_count())
  if !subset(key, attrs) {
    raise Invalid("key must be within relation")
  }
  let budget = meter(limits)
  if !subset(attrs, self.close(key, budget)) {
    return false
  }
  for a in key {
    if subset(attrs, self.close(difference(key, [a]), budget)) {
      return false
    }
  }
  true
}

///|
pub fn Schema::prime_attributes(
  self : Schema,
  relation : Array[Int32],
  limits~ : Limits = default_limits(),
) -> Array[Int32] raise DesignError {
  let attrs = indices(relation, self.attribute_count())
  let mut prime = []
  for key in self.keys_of(attrs, meter(limits)) {
    prime = union(prime, key)
  }
  prime
}

///|
pub fn Schema::essential_attributes(self : Schema) -> Array[Int32] {
  let mut rhs = []
  for fd in self.dependencies() {
    rhs = union(rhs, difference(fd.right, fd.left))
  }
  difference(full(self.attribute_count()), rhs)
}

///|
pub(all) struct KeyProfile {
  keys : Array[Array[Int32]]
  prime : Array[Int32]
  essential : Array[Int32]
  minimum_width : Int32
  maximum_width : Int32
} derive(Eq, Debug)

///|
pub fn Schema::key_profile(
  self : Schema,
  limits~ : Limits = default_limits(),
) -> KeyProfile raise DesignError {
  let keys = self.keys_of(full(self.attribute_count()), meter(limits))
  let mut prime = []
  let mut minimum_width = self.attribute_count()
  let mut maximum_width = 0
  for key in keys {
    prime = union(prime, key)
    if key.length() < minimum_width {
      minimum_width = key.length()
    }
    if key.length() > maximum_width {
      maximum_width = key.length()
    }
  }
  {
    keys,
    prime,
    essential: self.essential_attributes(),
    minimum_width,
    maximum_width,
  }
}

///|
pub extend KeyProfile with Eq::{equal, not_equal}

///|
pub extend KeyProfile with Debug::{to_repr}
