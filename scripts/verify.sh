#!/usr/bin/env bash
set -euo pipefail
target="${1:-wasm-gc}"
moon info
moon fmt --check
git diff --exit-code -- '*.mbti'
moon check --target "$target" --deny-warn
moon test --target "$target" --deny-warn
moon build --target "$target" --deny-warn
for workflow in design migration quality; do
  moon run "examples/$workflow" --target "$target" > "$workflow.out"
  grep -qx "$workflow-ok" <(head -n 1 "$workflow.out")
  rm "$workflow.out"
done
python3 scripts/measure.py
