///|
fn oracle_close(seed : Int32, fds : Array[FD]) -> Int32 {
  let mut current = seed
  let mut changed = true
  while changed {
    let before = current
    for fd in fds {
      let mut left = 0
      let mut right = 0
      for a in fd.left {
        left = left | (1 << a)
      }
      for a in fd.right {
        right = right | (1 << a)
      }
      if (current & left) == left {
        current = current | right
      }
    }
    changed = before != current
  }
  current
}

///|
fn oracle_theory(bits : Int32) -> Array[FD] {
  let out = []
  let mut index = 0
  for rhs in 0..<3 {
    for lhs in 0..<8 {
      if (lhs & (1 << rhs)) != 0 {
        continue
      }
      if (bits & (1 << index)) != 0 {
        out.push({ left: mask_set(lhs, [0, 1, 2]), right: [rhs], })
      }
      index += 1
    }
  }
  out
}

///|
test "all 4096 three-attribute singleton FD theories match independent keys and cover" {
  let mut checked = 0
  for bits in 0..<4096 {
    let fds = oracle_theory(bits)
    let s = schema(["A", "B", "C"], fds)
    let keys = s.candidate_keys()
    let reduced = s.minimal_cover()
    for seed in 0..<8 {
      let closed = oracle_close(seed, fds)
      assert_eq(
        s.closure(mask_set(seed, [0, 1, 2])),
        mask_set(closed, [0, 1, 2]),
      )
      assert_eq(oracle_close(seed, reduced), closed)
      let mut minimal = closed == 7
      for a in 0..<3 {
        if (seed & (1 << a)) != 0 && oracle_close(seed - (1 << a), fds) == 7 {
          minimal = false
        }
      }
      assert_eq(keys.contains(mask_set(seed, [0, 1, 2])), minimal)
      checked += 1
    }
  }
  assert_eq(checked, 32768)
}

///|
test "all 4096 theories satisfy decomposition guarantees and binary chase equivalence" {
  let mut plans = 0
  let mut binary_pairs = 0
  for bits in 0..<4096 {
    let s = schema(["A", "B", "C"], oracle_theory(bits))
    let third = s.audit_plan(s.synthesize_3nf())
    assert_true(
      third.lossless && third.dependency_preserving && third.target_satisfied,
    )
    let bcnf_plan = s.decompose_bcnf()
    let bcnf = s.audit_plan(bcnf_plan)
    assert_true(bcnf.lossless && bcnf.target_satisfied)
    assert_true(s.verify_split_trace(bcnf_plan))
    plans += 2
    for left in 1..<8 {
      for right in (left + 1)..<8 {
        if (left | right) != 7 {
          continue
        }
        let first = mask_set(left, [0, 1, 2])
        let second = mask_set(right, [0, 1, 2])
        let expected = s.binary_lossless(first, second)
        let chased = s.lossless_chase([first, second])
        assert_eq(chased.lossless, expected)
        if !expected {
          assert_true(
            s.verify_lossy_counterexample(
              [first, second],
              s.lossy_counterexample([first, second]).unwrap(),
            ),
          )
        }
        binary_pairs += 1
      }
    }
  }
  assert_eq(plans, 8192)
  assert_eq(binary_pairs, 49152)
}

///|
test "2NF detects partial keys and 3NF detects nonprime transitivity" {
  let partial = schema(["A", "B", "C"], [{ left: [0], right: [2], }])
  assert_true(!partial.in_normal_form([0, 1, 2], Second))
  let transitive = schema(["A", "B", "C"], [
    { left: [0], right: [1], },
    { left: [1], right: [2], },
  ])
  assert_true(transitive.in_normal_form([0, 1, 2], Second))
  assert_true(!transitive.in_normal_form([0, 1, 2], Third))
}
