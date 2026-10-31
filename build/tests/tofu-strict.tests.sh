#!/usr/bin/env bash
# Tests build/tofu-strict.sh: a warning fails it, a clean run passes, and an error still fails it. Needs tofu on PATH;
# the fixtures use no providers, so nothing is downloaded.
set -euo pipefail

strict="$(cd "$(dirname "$0")/.." && pwd)/tofu-strict.sh"
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
failures=0

check() { # name, expected exit code, fixture folder, tofu subcommand
  local name=$1 expected=$2 dir=$3 command=$4 actual=0
  bash "$strict" -chdir="$dir" init -backend=false >/dev/null 2>&1 || true
  bash "$strict" -chdir="$dir" "$command" >"$root/out" 2>&1 || actual=$?
  if [ "$actual" -eq "$expected" ]; then
    echo "PASS  $name"
  else
    echo "FAIL  $name: exit $actual, expected $expected"
    cat "$root/out"
    failures=$((failures + 1))
  fi
}

# A child module with a backend block: tofu warns that the backend is ignored and exits 0.
mkdir -p "$root/warns/child"
printf 'terraform {\n  backend "local" {}\n}\n' >"$root/warns/child/main.tf"
printf 'module "child" {\n  source = "./child"\n}\n' >"$root/warns/main.tf"
check 'a warning fails validate' 1 "$root/warns" validate

mkdir -p "$root/clean"
printf 'output "answer" {\n  value = 42\n}\n' >"$root/clean/main.tf"
check 'a clean configuration passes validate' 0 "$root/clean" validate

mkdir -p "$root/broken"
printf 'output "answer" {\n  value = var.missing\n}\n' >"$root/broken/main.tf"
check 'an error still fails validate' 1 "$root/broken" validate

if [ "$failures" -ne 0 ]; then
  echo "tofu-strict: $failures test(s) FAILED"
  exit 1
fi
echo 'tofu-strict: all tests passed'
