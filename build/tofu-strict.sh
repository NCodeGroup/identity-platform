#!/usr/bin/env bash
# Runs `tofu <args>` and fails when it prints a warning, not only on an error. OpenTofu exits 0 on a warning, so a lock
# file that no longer matches the components' constraints, a deprecated argument or an ignored block would otherwise
# pass validation. Prints tofu's output as it runs, without color so the warnings can be found.
#
#   build/tofu-strict.sh -chdir=live/global validate
set -euo pipefail

log=$(mktemp)
trap 'rm -f "$log"' EXIT

tofu "$@" -no-color 2>&1 | tee "$log"
if grep -qE '^(│ )?Warning: ' "$log"; then
  echo "::error::tofu $* printed a warning; warnings fail validation like errors"
  exit 1
fi
