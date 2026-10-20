///|
test "projection must enforce max_cells on unique output" {
  let s = @moonnormal.schema(["A", "B"], [])
  let t = @moonnormal.table(s, [0, 1], [["a", "x"], ["b", "y"]])
  let small = { ..@moonnormal.default_limits(), max_cells: 1, }
  try t.project([0, 1], limits=small) catch {
    @moonnormal.Budget(_) => ()
    _ => fail("wrong error category")
  } noraise {
    _ => fail("projection exceeded cell limit without Budget")
  }
}

///|
test "upstream cover exhaustion must remain Budget" {
  let attrs = Array::makei(16, i => "A" + i.to_string())
  let fds : Array[@moonnormal.FD] = []
  for mask in 1..<49 {
    let left = []
    for i in 0..<16 {
      if (mask & (1 << i)) != 0 {
        left.push(i)
      }
    }
    fds.push({ left, right: Array::makei(16, i => i), })
  }
  let s = @moonnormal.schema(attrs, fds)
  let large = { ..@moonnormal.default_limits(), max_work: 200000000, }
  try s.minimal_cover(limits=large) catch {
    @moonnormal.Budget(_) => ()
    @moonnormal.Invalid(_) => fail("resource exhaustion was mislabeled Invalid")
  } noraise {
    _ => fail("fixture must exceed upstream reduction allowance")
  }
}

///|
test "projection counts distinct output cells and reconstruction shares guard" {
  let s = @moonnormal.schema(["A", "B"], [])
  let t = @moonnormal.table(s, [0, 1], [["a", "x"], ["a", "y"]])
  let one = { ..@moonnormal.default_limits(), max_cells: 1, max_rows: 1, }
  assert_eq(t.project([0], limits=one).rows(), [["a"]])
  assert_eq(
    t.project([0, 1], limits={ ..one, max_cells: 4, max_rows: 2, }).rows(),
    t.rows(),
  )
  try
    t.reconstruct(s, [[0, 1]], limits={ ..one, max_cells: 3, max_rows: 2, })
  catch {
    @moonnormal.Budget(_) => ()
    _ => fail("wrong error category")
  } noraise {
    _ => fail("reconstruction bypassed projection cell guard")
  }
  try t.project([0], limits={ ..one, max_work: 1, }) catch {
    @moonnormal.Budget(_) => ()
    _ => fail("wrong error category")
  } noraise {
    _ => fail("projection bypassed work allowance")
  }
  assert_eq(t.rows(), [["a", "x"], ["a", "y"]])
}

///|
test "cover clients propagate upstream exhaustion without invalidating schema" {
  let attrs = Array::makei(16, i => "A" + i.to_string())
  let fds : Array[@moonnormal.FD] = []
  for mask in 1..<49 {
    let left = []
    for i in 0..<16 {
      if (mask & (1 << i)) != 0 {
        left.push(i)
      }
    }
    fds.push({ left, right: Array::makei(16, i => i), })
  }
  let s = @moonnormal.schema(attrs, fds)
  let large = { ..@moonnormal.default_limits(), max_work: 200000000, }
  try s.grouped_cover(limits=large) catch {
    @moonnormal.Budget(_) => ()
    _ => fail("grouped cover lost resource category")
  } noraise {
    _ => fail("upstream limit fixture unexpectedly succeeded")
  }
  try s.synthesize_3nf(limits=large) catch {
    @moonnormal.Budget(_) => ()
    _ => fail("3NF synthesis lost resource category")
  } noraise {
    _ => fail("upstream limit fixture unexpectedly succeeded")
  }
  assert_eq(s.closure([0]), Array::makei(16, i => i))
}

///|
test "public models remain isolated across accessors and error paths" {
  let labels = ["A", "B"]
  let left = [0]
  let right = [1]
  let s = @moonnormal.schema(labels, [{ left, right, }])
  labels[0] = "Changed"
  left[0] = 1
  right[0] = 0
  s.attributes()[0] = "Other"
  s.dependencies()[0].right[0] = 0
  assert_eq(s.attributes(), ["A", "B"])
  assert_eq(s.closure([0]), [0, 1])
  try s.closure([-1]) catch {
    @moonnormal.Invalid(_) => ()
    _ => fail("wrong negative-index error")
  } noraise {
    _ => fail("negative index accepted")
  }
  assert_eq(s.closure([0]), [0, 1])
  let trace = s.lossless_chase([[0], [1]])
  assert_true(s.verify_chase_trace([[0], [1]], trace))
  trace.final_tableau[0][1] = 1
  assert_true(!s.verify_chase_trace([[0], [1]], trace))
}

///|
test "schema and index width bounds remain explicit" {
  let s = @moonnormal.schema(Array::makei(16, i => "A" + i.to_string()), [])
  assert_eq(s.closure([15, 15]), [15])
  try s.closure([16]) catch {
    @moonnormal.Invalid(_) => ()
    _ => fail("wrong index-bound error")
  } noraise {
    _ => fail("out-of-bound index accepted")
  }
  for
    labels in [
      [],
      ["A", "A"],
      ["é"],
      Array::makei(17, i => "A" + i.to_string()),
    ] {
    try @moonnormal.schema(labels, []) catch {
      @moonnormal.Invalid(_) => ()
      _ => fail("wrong schema-bound error")
    } noraise {
      _ => fail("invalid labels accepted")
    }
  }
}

///|
test "strict public JSON and CSV entries reject malformed data" {
  let s = @moonnormal.schema(["A", "B"], [])
  for
    text in [
      "{\"format\":\"moonnormal-table/v1\",\"attributes\":[\"A\",\"B\"],\"columns\":[0.5],\"rows\":[]}",
      "{\"format\":\"moonnormal-table/v1\",\"attributes\":[\"A\",\"B\"],\"columns\":[-1],\"rows\":[]}",
      "{\"format\":\"moonnormal-table/v1\",\"attributes\":[\"A\",\"B\"],\"columns\":[1,0],\"rows\":[[\"b\",\"a\"]]}",
      "{\"format\":\"moonnormal-table/v1\",\"attributes\":[\"A\",\"B\"],\"columns\":[0],\"rows\":[[1]]}",
    ] {
    try @moonnormal.parse_table_json(s, text) catch {
      @moonnormal.Invalid(_) => ()
      _ => fail("wrong malformed-JSON error")
    } noraise {
      _ => fail("malformed JSON accepted")
    }
  }
  for text in ["A,B\n\"unclosed", "A,B\na\"b,c", "B,A\nb,a", "A,B\na,b,c"] {
    try @moonnormal.parse_table_csv(s, text) catch {
      @moonnormal.Invalid(_) => ()
      _ => fail("wrong malformed-CSV error")
    } noraise {
      _ => fail("malformed CSV accepted")
    }
  }
  let deep = "[[[[[[[[[[[[[0]]]]]]]]]]]]]"
  try @moonnormal.parse_table_json(s, deep) catch {
    @moonnormal.Budget(_) => ()
    _ => fail("wrong nesting-budget error")
  } noraise {
    _ => fail("excessive nesting accepted")
  }
}

///|
test "invalid limits and capped audit results cannot silently succeed" {
  let s = @moonnormal.schema(["A", "B"], [{ left: [0], right: [1], }])
  for
    limits in [
      { ..@moonnormal.default_limits(), max_work: 0, },
      { ..@moonnormal.default_limits(), max_cells: 1048577, },
      { ..@moonnormal.default_limits(), max_rows: -1, },
      { ..@moonnormal.default_limits(), max_results: 0, },
    ] {
    try @moonnormal.table(s, [0], [], limits~) catch {
      @moonnormal.Invalid(_) => ()
      _ => fail("wrong limits error")
    } noraise {
      _ => fail("invalid limits accepted")
    }
  }
  let t = @moonnormal.table(s, [0, 1], [["a", "x"], ["a", "y"], ["a", "z"]])
  try
    t.audit_dependencies(s, limits={
      ..@moonnormal.default_limits(),
      max_results: 1,
    })
  catch {
    @moonnormal.Budget(_) => ()
    _ => fail("wrong audit result-budget error")
  } noraise {
    _ => fail("audit silently truncated results")
  }
  assert_eq(t.audit_dependencies(s).violations.length(), 3)
}
