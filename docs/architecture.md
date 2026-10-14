# Architecture and correctness contracts

## Immutable models

A Schema binds ordered labels to MoonConcept RuleSystem. The declared FDs are
assertions supplied by a caller, not mined facts. Tables copy caller rows and
store literal string set semantics. Private fields and defensive getters prevent
mutation of the model through ordinary public calls. Public result records are
not immutable attestations.

## Reused theory engine

`model.mbt` uses `@fca.implication` and `@fca.rule_system` plus RuleSystem closure.
`cover.mbt` delegates split-conclusion, premise reduction and irredundancy.
The standalone schema extension avoids imposing SQL policy on an FCA package.
No upstream implementation was copied. Projected theories remain bounded by the
upstream 4,096-rule limit; exceeding it raises Budget.

## Relational algorithms

Candidate keys enumerate subsets by increasing cardinality, prune known keys,
and test closure. Projection enumerates each determinant within a fragment and
retains the nontrivial in-fragment closure. Preservation takes the union of these
projections and checks each original FD. Checking only explicitly declared FDs
inside each fragment would be incorrect; implied dependencies matter.

2NF examines proper subsets of candidate keys determining nonprime attributes.
3NF permits a determinant that is a superkey or a prime RHS attribute. BCNF
requires every nontrivial determinant to be a superkey.

3NF synthesis groups a reduced cover by determinant, removes contained relations
and includes a candidate-key relation when needed. BCNF chooses a deterministic
violating FD, splits into X union Y and R minus (Y minus X), and strictly decreases
both child widths. It preserves losslessness but may lose FD preservation.

The FD chase initializes shared distinguished symbols for fragment columns and
unique symbols elsewhere. Union-find prefers the smaller symbol; each column's
distinguished symbol is smaller than its nondistinguished symbols. Matching FD
premises merge conclusion symbols until a fixed point. A completely distinguished
row proves lossless decomposition under the declared FDs. A lossy fixed point
itself supplies an FD-satisfying tuple counterexample, without inventing data.

## Verification and resource use

The independent test oracle uses integer bit masks and a standalone FD fixpoint,
not MoonConcept or the production subset helper for closure. All 4,096 theories
formed from 12 three-attribute nontrivial singleton-conclusion implications are
covered. Binary chase is compared to the intersection-closure theorem. Generated
plans are audited for their required properties; preservation is not assumed for
BCNF. These are finite regression checks, not mechanized proofs for all inputs.

Meter charges conceptual conservative operations and guards multiplication before
Int32 overflow. It is not a hard CPU/memory timer. Composite report/review APIs
apply a separate supplied limit to each documented component; their combined
work can exceed one component's max_work. Input lengths, rows, cells, results and
upstream rule bounds provide independent limits. Larger settings are opt-in.

Table projection removes duplicate rows; natural joins compare common literal
values. Reconstruction reports both missing and spurious rows. Dependency audits
skip FDs whose referenced columns are absent instead of falsely declaring success.
