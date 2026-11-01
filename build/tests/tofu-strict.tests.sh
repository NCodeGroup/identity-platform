#!/usr/bin/env bash
# Tests build/tofu-strict.sh: a warning from init, validate or test fails it and is reported, a clean run passes, and an
# error still fails it without a warning being reported. Needs tofu on PATH; the fixtures use no providers, so nothing
# is downloaded.
set -euo pipefail

strict="$(cd "$(dirname "$0")/.." && pwd)/tofu-strict.sh"
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
failures=0

check() { # name, expected exit code, warning reported (yes|no), fixture folder, tofu subcommand and its arguments
  local name=$1 expected=$2 warned=$3 dir=$4 actual=0 problem=''
  shift 4
  # Setup runs plain tofu, because the warns fixture warns on init too.
  if [ "$1" != init ] && ! tofu -chdir="$dir" init -backend=false >"$root/out" 2>&1; then
    problem='tofu init failed before the command under test'
  else
    bash "$strict" -chdir="$dir" "$@" >"$root/out" 2>&1 || actual=$?
    if [ "$actual" -ne "$expected" ]; then
      problem="exit $actual, expected $expected"
    elif [ "$warned" = yes ] && ! grep -q 'printed a warning' "$root/out"; then
      problem='the gate did not report a warning'
    elif [ "$warned" = no ] && grep -q 'printed a warning' "$root/out"; then
      problem='the gate reported a warning'
    fi
  fi
  if [ -z "$problem" ]; then
    echo "PASS  $name"
  else
    echo "FAIL  $name: $problem"
    cat "$root/out"
    failures=$((failures + 1))
  fi
}

# A child module with a backend block: tofu warns that the backend is ignored, on init, validate and test, and exits 0.
mkdir -p "$root/warns/child" "$root/warns/tests"
printf 'terraform {\n  backend "local" {}\n}\n' >"$root/warns/child/main.tf"
printf 'module "child" {\n  source = "./child"\n}\n' >"$root/warns/main.tf"
printf 'run "plan" {\n  command = plan\n}\n' >"$root/warns/tests/a.tftest.hcl"
check 'a warning fails init' 1 yes "$root/warns" init -backend=false
check 'a warning fails validate' 1 yes "$root/warns" validate
check 'a warning fails test' 1 yes "$root/warns" test

mkdir -p "$root/clean"
printf 'output "answer" {\n  value = 42\n}\n' >"$root/clean/main.tf"
check 'a clean configuration passes validate' 0 no "$root/clean" validate

mkdir -p "$root/broken"
printf 'output "answer" {\n  value = var.missing\n}\n' >"$root/broken/main.tf"
check 'an error still fails validate' 1 no "$root/broken" validate

if [ "$failures" -ne 0 ]; then
  echo "tofu-strict: $failures test(s) FAILED"
  exit 1
fi
echo 'tofu-strict: all tests passed'
