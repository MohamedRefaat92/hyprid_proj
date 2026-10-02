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
short() { head -5 | sed 's#.*/##; s#\.conda.*##; s#\.tar\.bz2.*##' | paste -sd, - | sed 's/,/, /g'; }

section "0. Prerequisites"

for tool in mamba conda uv; do
  if command -v "$tool" >/dev/null; then
    pass "$tool found: $(command -v "$tool")"
  else
    fail "$tool not on PATH" "install Miniforge (mamba, conda) / uv, or fix PATH"
  fi
done

have_lock=false
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
    have_lock=true
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

section "1. Runtime (./env)"
if ! $have_env || ! $have_lock; then
  info "skipped: needs ./env and a usable lockfile"
else
  locked=$(grep '^https' "$lock" | sort)
  installed=$(conda list -p ./env --explicit --md5 | grep '^https' | sort)
  missing=$(comm -23 <(echo "$locked") <(echo "$installed"))
  extra=$(comm -13 <(echo "$locked") <(echo "$installed"))
  if [[ -z $missing ]] && [[ -z $extra ]]; then
    pass  "./env matches $lock ($(grep -c '^https' "$lock") packages)"
  else
    msg=""
    [[ -n $missing ]] && msg+="missing: $(short <<<"$missing")  "
    [[ -n $extra ]]   && msg+="extra: $(short <<<"$extra")"
    fail "./env differs from $lock: $msg" \
         "if you changed the env on purpose, relock; else rm -rf env && ./bootstrap.sh"
  fi

  names=$(sed -n '/^dependencies:/,$p' environment.yml |
    grep -E '^[[:space:]]*-[[:space:]]' |
    sed -E 's/^[[:space:]]*-[[:space:]]*//; s/[[:space:]]*#.*//; s/[=<>!~ ].*//')
  unlocked=""
  for pkg in $names; do
    if ! grep -qE "/${pkg}-[0-9]" "$lock"; then
      unlocked="${unlocked}${unlocked:+, }$pkg"
    fi
  done

  if [[ -z $unlocked ]]; then
    pass "all $(wc -w <<<"$names" | tr -d ' ') packages in environment.yml are locked"
  else
    fail "in environment.yml but not in $lock: $unlocked" \
    "mamba env update -p ./env -f environment.yml, then: conda list -p ./env --explicit --md5 > $lock"
  fi
fi

section "2. Runtime rules"

if $have_env; then
  meta=$(ls env/conda-meta)
  conda_r=$(grep '^r-' <<<"$meta" | grep -v '^r-base-[0-9]')
  if [[ -z $conda_r ]]; then
    rbase_ver=$(sed -nE 's/^r-base-([0-9][^-]*)-.*/\1/p' <<<"$meta")
    pass "only r-base $rbase_ver from conda; R packages come from renv"
  else
    names=$(sed -E 's/-[0-9].*$//' <<<"$conda_r" | paste -sd' ' -)
    fail "R packages installed by conda: $names" \
         "mamba remove -p ./env $names; drop them from environment.yml; renv::install() them instead"
  fi
else
  info "skipped: needs ./env"
fi

if [[ -z ${MAMBA_ROOT_PREFIX:-} ]]; then
  pass "MAMBA_ROOT_PREFIX unset: mamba uses its default cache (~/miniforge3/pkgs)"
elif [[ $MAMBA_ROOT_PREFIX == "$root"* ]]; then
  fail "MAMBA_ROOT_PREFIX points into the project: $MAMBA_ROOT_PREFIX" \
       "quit VS Code fully (⌘Q), reopen, check: echo \$MAMBA_ROOT_PREFIX"
else
  info "MAMBA_ROOT_PREFIX set outside the project: $MAMBA_ROOT_PREFIX"
fi

if [[ -d .micromamba ]]; then
  warn ".micromamba/ exists in the project ($(du -sh .micromamba | cut -f1))" \
       "rm -rf .micromamba once MAMBA_ROOT_PREFIX no longer points here"
fi

section "3. R (./env)"

have_r=false
r_version="" r_home="" r_lib="" r_renv_project="" r_cc="" r_synced="" renv_active=false
if $have_env; then
  # shellcheck disable=SC2016  # single-quoted R code; $ is R's list operator
  r_facts=$(PATH=/usr/bin:/bin env/bin/Rscript -e '
    cat("version=", format(getRversion()), "\n", sep = "")
    cat("home=", R.home(), "\n", sep = "")
    cat("lib=", .libPaths()[1], "\n", sep = "")
    cat("renv_project=", Sys.getenv("RENV_PROJECT"), "\n", sep = "")
    cc_name <- system2(file.path(R.home("bin"), "R"), c("CMD", "config", "CC"), stdout = TRUE)
    cat("cc=", Sys.which(strsplit(cc_name, " ")[[1]][1]), "\n", sep = "")
    s <- tryCatch({ invisible(capture.output(x <- renv::status())); x }, error = function(e) NULL)
    cat("synced=", if (is.null(s)) "unknown" else s$synchronized, "\n", sep = "")
  ' 2>/dev/null)

  if [[ -z $r_facts ]]; then
    fail "env/bin/Rscript produced no output" "run it by hand to see the error: env/bin/Rscript -e 1"
  else
    while IFS='=' read -r key value; do
      [[ $key =~ ^[a-z_]+$ ]] || continue   # ignore stray output (e.g. renv startup warnings)
      printf -v "r_$key" '%s' "$value"     # creates r_version, r_home, ... for step 5
      info "$key: $value"
    done <<<"$r_facts"
    have_r=true
  fi
else
  info "skipped: needs ./env"
fi

if $have_r; then
  lock_r=$(env/bin/python -c 'import json; print(json.load(open("renv.lock"))["R"]["Version"])')
  if [[ $r_version == "$lock_r" ]];then
    pass "R $r_version matches renv.lock"
  else
    fail "R is $r_version but renv.lock was made with R $lock_r" \
         "if R was upgraded on purpose: reinstall packages, then renv::snapshot(); else rebuild ./env from the lockfile"
  fi
    if [[ $r_home == "$root/env/"* ]]; then
    pass "running R is ./env's R"
  else
    fail "the R that ran is not ./env's R: $r_home" \
         "env/bin/Rscript should launch ./env's R; rebuild the env (rm -rf env && ./bootstrap.sh)"
  fi
  if [[ $r_lib == "$root/renv/library/"* ]];then
    renv_active=true
    pass "renv library active: ${r_lib#"$root/"}"
  else
    fail "R uses $r_lib, not the project's renv library" \
         "check .Rprofile: missing, guarded out, or activation failed."
  fi
  if [[ $r_renv_project == "$root" ]]; then
    pass "renv activated this project"
  elif [[ -z $r_renv_project ]]; then
    fail "renv not activated (RENV_PROJECT is empty)" \
         "check .Rprofile: missing, guarded out, or activation failed"
  else
    fail "renv activated a different project: $r_renv_project" \
         "a stale RENV_PROJECT? check this shell (echo \$RENV_PROJECT) or the kernel's env, and unset it"
  fi
  if [[ $r_synced == TRUE ]]; then
    pass "renv is synchronized"
  elif [[ $r_synced == unknown ]]; then
    info "renv sync: skipped, renv could not be loaded"
  else
    fail "renv library is out of sync with renv.lock" \
         "run env/bin/Rscript -e 'renv::status()' for details: renv::restore() if packages are missing, renv::snapshot() if the lockfile is out of date"
  fi
  if [[ $r_cc == "$root/env/"* ]];then
    pass "C compiler: ${r_cc#"$root/"}"
  elif [[ -z $r_cc ]];then
    fail "C compiler not found on R's PATH" "check the PATH block in .Rprofile; rerun ./bootstrap.sh"
  else
    warn "C compiler outside ./env: $r_cc" "packages would build with a compiler conda didn't provide; check PATH order"
  fi
  if $renv_active; then
    libs=$(find renv/library -mindepth 2 -maxdepth 5 -name renv | sed 's#/renv$##')
    active=${r_lib#"$root/"}
    foreign=$(grep -vxF -- "$active" <<<"$libs")
    if [[ -z $foreign ]]; then
      pass "one renv library: $active"
    else
      fail "renv libraries from another R: $(paste -sd' ' - <<<"$foreign")" \
           "delete them (rm -rf <folder>) and find out which R opened this project"
    fi
  else
    info "foreign-library check: skipped, renv library not active"
  fi
fi
if [[ ! -f .Rprofile ]]; then
  fail ".Rprofile missing, so R starts without the guard, PATH setup or renv" \
       "restore it: git checkout .Rprofile"
elif [[ -z $(tail -c1 .Rprofile) ]]; then
  pass ".Rprofile ends with a newline"
else
  fail ".Rprofile does not end with a newline, so R silently skips its last line" "echo >> .Rprofile"
fi

info "R on this shell's PATH: $(command -v R || echo none)"

printf '\n%d passed, %d warnings, %d failed\n' "$n_pass" "$n_warn" "$n_fail"
[[ $n_fail -eq 0 ]]                    # exit code 1 if anything failed

