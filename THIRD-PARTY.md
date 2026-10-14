# Dependency and reference boundaries

- **MoonConcept**, `Zh666-lab/moonconcept@0.1.1`, MIT,
  https://github.com/Zh666-lab/moonconcept . Used through its public RuleSystem,
  Implication and reduction API. It is a registry dependency, not vendored code.
  Its own copyright and MIT license remain with upstream.
- **MoonBit core**, official standard library, used through its normal runtime
  and JSON API. No standard-library files are redistributed in this repository.
- FD closure, minimal keys, 3NF synthesis, BCNF decomposition and tableau chase
  are standard relational database theory (Armstrong inference / lossless-join
  tests). Algorithms were independently implemented from mathematical contracts;
  textbook source, examples and figures were not copied. Small fixtures are
  synthetic and the independent oracle was authored for this project.

This is an original MIT schema extension, not a port of an existing SQL engine,
normalization application, MoonConcept's FCA lattice, or MoonSQLGuard's SQL parser.
