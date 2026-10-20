#!/usr/bin/env bash
set -euo pipefail
# Download the exact official release snapshot, independent of the moving latest alias.
# ETags are object identity pins, not independent cryptographic signatures.
root="${MOON_HOME:?MOON_HOME must be an isolated toolchain directory}"
mkdir -p "$root/lib"
curl --fail --location --retry 2 --header 'If-Match: "6ae7c52851085cc3d4d65fd04410ef7b-12"' \
  https://cli.moonbitlang.com/binaries/0.10.15%2B943464bfa/moonbit-linux-x86_64.tar.gz -o "$root/moonbit.tar.gz"
curl --fail --location --retry 2 --header 'If-Match: "65ef1811c0e64c48bf01312100f7e998"' \
  https://cli.moonbitlang.com/cores/core-0.10.15%2B943464bfa.tar.gz -o "$root/core.tar.gz"
tar -xzf "$root/moonbit.tar.gz" -C "$root"
tar -xzf "$root/core.tar.gz" -C "$root/lib"
chmod +x "$root"/bin/*
export PATH="$root/bin:$PATH"
moon -C "$root/lib/core" bundle --warn-list -a --all
moon version --all
