#!/usr/bin/env bash
# verify-env.sh: read-only check that the environment matches its declared setup
# (environment.yml, lockfiles, kernels, VS Code settings) and that the layers are
# wired together correctly. It changes nothing; ./bootstrap.sh is what repairs.
#
#   ./verify-env.sh          fast checks
#   ./verify-env.sh --deep   also start each kernel and run code
set -uo pipefail                       # no -e: one failed check must not end the report
cd "$(dirname "$0")"
root=$PWD

n_pass=0 n_warn=0 n_fail=0
section() { printf '\n== %s\n' "$1"; }
info()    { printf '  · %s\n' "$1"; }
pass()    { printf '  ✔ %s\n' "$1"; n_pass=$((n_pass + 1)); }
warn()    { printf '  ! %s\n    → %s\n' "$1" "$2"; n_warn=$((n_warn + 1)); }
fail()    { printf '  ✖ %s\n    → %s\n' "$1" "$2"; n_fail=$((n_fail + 1)); }

# checks go here, one section per step

printf '\n%d passed, %d warnings, %d failed\n' "$n_pass" "$n_warn" "$n_fail"
[[ $n_fail -eq 0 ]]                    # exit code 1 if anything failed

