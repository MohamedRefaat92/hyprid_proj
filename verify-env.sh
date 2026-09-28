#!/usr/bin/env bash
# verify-env.sh: read-only check that the environment matches its declared setup
# (environment.yml, lockfiles, kernels, VS Code settings) and that the layers are
# wired together correctly. It changes nothing; ./bootstrap.sh is what repairs.
#
#   ./verify-env.sh          fast checks
#   ./verify-env.sh --deep   also start each kernel and run code
set -uo pipefail                       # no -e: one failed check must not end the report
cd "$(dirname "$0")" || exit 1
root=$PWD

n_pass=0 n_warn=0 n_fail=0
section() { printf '\n== %s\n' "$1"; }
info()    { printf '  · %s\n' "$1"; }
pass()    { printf '  ✔ %s\n' "$1"; n_pass=$((n_pass + 1)); }
warn()    { printf '  ! %s\n    → %s\n' "$1" "$2"; n_warn=$((n_warn + 1)); }
fail()    { printf '  ✖ %s\n    → %s\n' "$1" "$2"; n_fail=$((n_fail + 1)); }

section "0. Prerequisites"

for tool in mamba conda uv; do
  if command -v "$tool" >/dev/null; then
    pass "$tool found: $(command -v "$tool")"
  else
    fail "$tool not on PATH" "install Miniforge (mamba, conda) / uv, or fix PATH"
  fi
done

case "$(uname -s)-$(uname -m)" in
  Darwin-arm64)  platform=osx-arm64 ;;
  Darwin-x86_64) platform=osx-64 ;;
  Linux-x86_64)  platform=linux-64 ;;
  Linux-aarch64) platform=linux-aarch64 ;;
  *) platform="" ;;
esac
if [[ -z $platform ]]; then
  fail "unsupported platform: $(uname -s)-$(uname -m)" \
       "supported: osx-arm64, osx-64, linux-64, linux-aarch64 (on Windows use WSL)"
else
  lock="conda-${platform}.lock"
  if [[ ! -f $lock ]]; then
    warn "no lockfile for $platform" "bootstrap will solve from environment.yml"
  elif grep -q '^@EXPLICIT' "$lock"; then
    pass "lockfile: $lock"
  else
    fail "$lock has no @EXPLICIT header, so it can't recreate the env" \
         "regenerate: conda list -p ./env --explicit --md5 > $lock"
  fi
fi

have_env=false
if [[ -d env/conda-meta ]]; then
  have_env=true
  pass "./env exists"
else
  fail "no ./env (conda env)" "run ./bootstrap.sh"
fi

printf '\n%d passed, %d warnings, %d failed\n' "$n_pass" "$n_warn" "$n_fail"
[[ $n_fail -eq 0 ]]                    # exit code 1 if anything failed

