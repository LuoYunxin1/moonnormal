# Three downstream workflows

Each executable imports only the public library interface and checks its outcome.

| Package | User and input | Result |
|---|---|---|
| design | Designer supplies Student/Course/Tutor FDs | 3NF/BCNF tradeoff, serialized split trace and advisory SQL |
| migration | Reviewer compares two A/B/C layouts | Lossless regression and a concrete FD-satisfying counterexample |
| quality | Pipeline maintainer supplies Customer CSV | FD witness pairs, key collisions and spurious reconstructed tuples |

Run `moon run examples/design`, `moon run examples/migration`, and
`moon run examples/quality`. Successful output starts with the matching `*-ok`
marker. An assertion failure terminates instead of printing a success marker.
No database is modified. No live network request or account data is used.
