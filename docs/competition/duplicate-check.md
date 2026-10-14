# Bounded semantic ecosystem review — 2026-10-14

## Method and candidate selection

The installed osc2026-guide Project Research Guide was executed. Review used
expanded English/Chinese concepts and task/function synonyms, `moon search`
with limit 100, exact public package metadata, linked source/interfaces/tests,
account-bound GitHub code search (per_page=100, incomplete_results=false), the
MoonBit awesome list, and the permanent project registry. Raw local research
results are outside this public repository. This is a bounded check, not a
claim that no undiscovered or unpublished equivalent exists.

Scores 1–5: breadth, users, reuse, overlap safety, depth, verification, delivery,
maintenance. Scores never override a mature-direct-substitute rejection.

| Candidate | Scores | Sum | Decision |
|---|---|---:|---|
| Persistent homology / Rips persistence | 4,4,5,1,5,4,3,3 |29|Reject direct mature duplicate|
| Action-based MDP planning |4,4,5,2,5,4,3,3|30|Reject substantial adjacency / prefer existing planner|
| Relational schema decomposition |5,5,5,4,5,5,4,4|37|Select bounded distinct schema extension|

## Scope fingerprint

Users: database designers, migration reviewers and data pipeline maintainers.
Inputs: ordered labels, declared FDs, fragment layouts, finite literal tuples.
Outputs: keys, form violations, 3NF/BCNF plans, preservation/lossless evidence,
concrete counterexample tuples, data witness pairs, advisory SQL and reports.
Core: bounded projection/enumeration, synthesis, decreasing BCNF splits, FD
chase and relational joins. No FCA mining/lattices, SQL parsing/execution/ORM,
MVD/4NF/5NF, automatic migrations or inference from observed absence of violations.

## Source-backed comparison matrix

| Reviewed project/source | Inputs / core behavior | Maintenance evidence | Classification and decision |
|---|---|---|---|
| [wdgodghl/moontopolens](https://mooncakes.io/docs/wdgodghl/moontopolens), 0.20.4, MIT; `rips.mbt`, `persistence_test.mbt`, public interface |point clouds/simplicial filtrations, Rips and persistence|Published version, substantive source and tests|Direct homology substitute; reject candidate|
| [liuzhiyug/MoonRLLab](https://github.com/liuzhiyug/MoonRLLab), `planning.mbt`, public interface|MDP planning/value iteration|Actual planning source present|Highly adjacent to MDP candidate; reject rather than rename|
| [Lyl66655/moon-survival](https://mooncakes.io/docs/Lyl66655/moon-survival), 0.2.4; Markov source/tests|fixed-state transition/survival probabilities|Published tested code inspected|Markov adjacency, not action-control solver|
| [Zh666-lab/moonconcept](https://github.com/Zh666-lab/moonconcept), 0.1.1, MIT; RuleSystem source and interface|FCA contexts/concepts and generic implication closure/reduction|Published package/source/tests|Highly adjacent FD entailment **reused directly**; no duplicated engine|
| MoonSQLGuard registry fingerprint|SQL parsing/AST policy decisions, query text|Permanent full fingerprint reviewed|Same database direction, distinct input/behavior from relational decomposition|
| MoonNormal|declared FDs + fragment layouts + finite tuples|Own exhaustive oracles and runnable workflows|Adds relation-level lossless/preservation/counterexample contracts|

Independence from MoonConcept is justified by the distinct tuple and relational
schema contract; adding SQL advisory/migration policy to a mathematical FCA core
would couple unrelated concerns. The engine is reused as a dependency. MoonSQLGuard
does not substitute a projected-FD chase/3NF/BCNF contract in its reviewed scope.

## Search record and limitations

Expanded searches included normalization, functional dependency, BCNF, 3NF,
lossless, relational, database normalization, candidate key, minimal cover,
dependency preservation, chase, Boyce Codd, relation decomposition and relational
design. Other candidates used homology/topology and markov/mdp/bellman/reinforcement/
policy iteration/value iteration terms. Broad fuzzy searches sometimes hit 100:
these were not treated as exhaustive or zero-result proofs. An initial MDP TLS
failure was retried successfully as a read-only query; no identity switch occurred.
The official awesome list was read, but may omit repositories. GitHub code search
is indexed, language classified and potentially delayed; metadata is not a semantic
proof, which is why adjacent source/tests/interfaces were inspected.

Final reverse check before remote delivery: `"synthesize_3nf" language:MoonBit`
and `"lossless_chase" language:MoonBit` each returned 0; `"BCNF" language:MoonBit`
returned only `OverflowCat/tiago/renderer_svg/embedded_fonts.mbt`, an embedded-font
false positive. All three had incomplete_results=false and a 100-result cap.
The complete live registry was capability-filtered and MoonNormal's reservation
was atomically recorded under its exclusive lock; new nearby records did not
introduce a relational-decomposition substitute. Recorded evidence supports
**no mature direct substitute found in this reviewed scope**, not absolute novelty.
