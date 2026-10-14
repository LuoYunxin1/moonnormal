///|
pub(all) struct ChaseMerge {
  dependency_index : Int32
  first_row : Int32
  second_row : Int32
  column : Int32
  eliminated : Int32
  representative : Int32
} derive(Eq, Debug)

///|
pub(all) struct ChaseResult {
  lossless : Bool
  witness_row : Int32?
  initial : Array[Array[Int32]]
  final_tableau : Array[Array[Int32]]
  merges : Array[ChaseMerge]
  rounds : Int32
} derive(Eq, Debug)

///|
fn root(parent : Array[Int32], x : Int32) -> Int32 {
  let mut r = x
  while parent[r] != r {
    r = parent[r]
  }
  let mut v = x
  while parent[v] != v {
    let next = parent[v]
    parent[v] = r
    v = next
  }
  r
}

///|
fn tableau_view(
  table : Array[Array[Int32]],
  parent : Array[Int32],
) -> Array[Array[Int32]] {
  table.map(row => row.map(x => root(parent, x)))
}

///|
fn Schema::chase_of(
  self : Schema,
  relations : Array[Array[Int32]],
  budget : Meter,
) -> ChaseResult raise DesignError {
  let n = self.attribute_count()
  let rows = relations.length()
  if rows * n > budget.limits.max_cells {
    raise Budget("chase tableau cell allowance")
  }
  let initial = Array::makei(rows, i => {
    Array::makei(n, j => {
      if relations[i].contains(j) {
        j
      } else {
        n + i * n + j
      }
    })
  })
  let parent = full(n + rows * n)
  let merges : Array[ChaseMerge] = []
  let fds = self.dependencies()
  let mut rounds = 0
  let mut changed = true
  while changed {
    budget.charge(1)
    rounds += 1
    changed = false
    for fi in 0..<fds.length() {
      let fd = fds[fi]
      for i in 0..<rows {
        for j in (i + 1)..<rows {
          budget.charge(1 + fd.left.length() + fd.right.length())
          let agrees = fd.left.all(a => {
            root(parent, initial[i][a]) == root(parent, initial[j][a])
          })
          if !agrees {
            continue
          }
          for column in fd.right {
            let a = root(parent, initial[i][column])
            let b = root(parent, initial[j][column])
            if a == b {
              continue
            }
            let representative = if a < b { a } else { b }
            let eliminated = if a < b { b } else { a }
            budget.result(merges.length() + 1)
            parent[eliminated] = representative
            merges.push({
              dependency_index: fi,
              first_row: i,
              second_row: j,
              column,
              eliminated,
              representative,
            })
            changed = true
          }
        }
      }
    }
  }
  let final_tableau = tableau_view(initial, parent)
  let mut witness_row = None
  for i in 0..<rows {
    if final_tableau[i] == full(n) {
      witness_row = Some(i)
      break
    }
  }
  {
    lossless: witness_row is Some(_),
    witness_row,
    initial,
    final_tableau,
    merges,
    rounds,
  }
}

///|
pub fn Schema::lossless_chase(
  self : Schema,
  relations : Array[Array[Int32]],
  limits~ : Limits = default_limits(),
) -> ChaseResult raise DesignError {
  self.chase_of(self.fragments(relations, true), meter(limits))
}

///|
pub fn Schema::validate_chase_witness(
  self : Schema,
  result : ChaseResult,
  limits~ : Limits = default_limits(),
) -> Bool raise DesignError {
  let budget = meter(limits)
  let n = self.attribute_count()
  let rows = result.final_tableau
  if rows.is_empty() ||
    rows.length() > 64 ||
    rows.length() * n > budget.limits.max_cells {
    return false
  }
  for row in rows {
    if row.length() != n {
      return false
    }
  }
  for fd in self.dependencies() {
    for i in 0..<rows.length() {
      for j in (i + 1)..<rows.length() {
        budget.charge(1 + fd.left.length() + fd.right.length())
        if fd.left.all(a => rows[i][a] == rows[j][a]) &&
          !fd.right.all(a => rows[i][a] == rows[j][a]) {
          return false
        }
      }
    }
  }
  match result.witness_row {
    Some(i) =>
      i >= 0 && i < rows.length() && rows[i] == full(n) && result.lossless
    None => !result.lossless && !rows.any(row => row == full(n))
  }
}

///|
pub extend ChaseMerge with Eq::{equal, not_equal}

///|
pub extend ChaseMerge with Debug::{to_repr}

///|
pub extend ChaseResult with Eq::{equal, not_equal}

///|
pub extend ChaseResult with Debug::{to_repr}
