#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
fail=0
found=0
for t in tests/test_*.sh; do
  [ -f "$t" ] || continue
  found=1
  if bash "$t"; then
    printf 'PASS %s\n' "$t"
  else
    printf 'FAIL %s\n' "$t" >&2
    fail=1
  fi
done
if [ "$found" -ne 1 ]; then
  printf 'No tests found.\n' >&2
  exit 1
fi
if [ "$fail" -ne 0 ]; then
  printf 'Some tests failed.\n' >&2
  exit 1
fi
printf 'All tests passed.\n'
