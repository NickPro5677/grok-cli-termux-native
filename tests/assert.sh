# Test helpers. Sourced by the test scripts.

assert_eq() {
  local got="$1" want="$2"
  if [ "$got" != "$want" ]; then
    printf 'expected: [%s]\n     got: [%s]\n' "$want" "$got" >&2
    exit 1
  fi
}

assert_contains() {
  local hay="$1" needle="$2"
  if ! grep -F -q -- "$needle" <<< "$hay"; then
    printf 'output is missing: %s\n' "$needle" >&2
    printf '----- output -----\n%s\n------------------\n' "$hay" >&2
    exit 1
  fi
}

assert_not_contains() {
  local hay="$1" needle="$2"
  if grep -F -q -- "$needle" <<< "$hay"; then
    printf 'output should not contain: %s\n' "$needle" >&2
    printf '----- output -----\n%s\n------------------\n' "$hay" >&2
    exit 1
  fi
}
