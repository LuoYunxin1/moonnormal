# Changelog

## 0.1.2 — 2026-11-01

- Pin CI compiler and matching core downloads to official MoonBit 0.10.18
  (6c83a7f62), meeting the acceptance requirement of moonc >= 0.10.16.
- Document the compiler minimum, verified toolchain and exact package installation.

## 0.1.1 — 2026-10-20

- Enforce cell budgets on distinct projection results, including reconstruction,
  and charge projection work before materializing intermediate rows.
- Preserve the Budget error category when MoonConcept cover reduction exhausts
  its rule allowance, including grouped-cover and 3NF-synthesis callers.
- Add public-API budget, malformed-input and defensive-copy regression tests.

- Pin CI installer downloads to the exact official compiler/core version URLs,
  retaining the original snapshot ETags instead of depending on moving latest aliases.

## 0.1.0 — 2026-10-14

- Validated declared-FD schemas, closure adapter, minimal covers and key profiles.
- FD projection, 2NF/3NF/BCNF diagnostics, 3NF synthesis and BCNF decomposition.
- FD tableau chase, replay checks and finite lossy counterexample materialization.
- Tuple projection, joins, reconstruction, dependency and key collision audits.
- Versioned JSON, dependency text, quoted CSV and human-readable review reports.
- Migration preservation/layout diagnostics and explicitly advisory SQL.
- Independent exhaustive three-attribute oracle and three executable workflows.
