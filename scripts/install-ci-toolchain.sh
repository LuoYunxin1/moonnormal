#!/usr/bin/env bash
set -euo pipefail
# Download the exact official release snapshot, independent of the moving latest alias.
# ETags are object identity pins, not independent cryptographic signatures.
root="${MOON_HOME:?MOON_HOME must be an isolated toolchain directory}"
mkdir -p "$root/lib"
curl --fail --location --retry 2 --header 'If-Match: "0560ebd5ba5528390cd4872766f2234b"' \
  https://cli.moonbitlang.com/binaries/0.10.18%2B6c83a7f62/moonbit-linux-x86_64.tar.gz -o "$root/moonbit.tar.gz"
curl --fail --location --retry 2 --header 'If-Match: "7b87b77b0d942a76fba657b809c31cdf"' \
  https://cli.moonbitlang.com/cores/core-0.10.18%2B6c83a7f62.tar.gz -o "$root/core.tar.gz"
tar -xzf "$root/moonbit.tar.gz" -C "$root"
tar -xzf "$root/core.tar.gz" -C "$root/lib"
chmod +x "$root"/bin/*
export PATH="$root/bin:$PATH"
moon -C "$root/lib/core" bundle --warn-list -a --all
moon version --all
