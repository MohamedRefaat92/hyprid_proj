#!/usr/bin/env bash
# Open single-cell data in the dashboard (Ctrl+C to stop): one .h5ad, one .h5mu, or several .h5ad files,
# one per modality of the same cells (my_data_rna.h5ad my_data_atac.h5ad: tabs "rna" and "atac").
# First prepares the data for fast look-ups (scripts/py/dashboard.py, only when a file changed), then
# starts the Shiny app (scripts/R/dashboard-app.R).
#
#   scripts/sh/dashboard.sh [file ...] [--port 8050] [--shared]
#     file       default: the only .h5ad/.h5mu in output/dashboard/
#     --shared   reachable by others on this server's network (default: this machine only)
#   On a remote server, without --shared: `ssh -L 8050:localhost:8050 <server>` on your laptop,
#   then open http://localhost:8050.
set -euo pipefail
cd "$(dirname "$0")/../.."   # run from the project root, wherever this was called from

files=() port=8050 host=127.0.0.1
while [[ $# -gt 0 ]]; do
  case $1 in
    --port)   port=$2; shift 2 ;;
    --shared) host=0.0.0.0; shift ;;
    *)        files+=("$1"); shift ;;
  esac
done
if [[ ${#files[@]} -eq 0 ]]; then
  shopt -s nullglob
  found=(output/dashboard/*.h5ad output/dashboard/*.h5mu)
  if [[ ${#found[@]} -ne 1 ]]; then
    echo "name the file(s) to open: scripts/sh/dashboard.sh <file> [<file> ...]; in output/dashboard/:" >&2
    printf '  %s\n' "${found[@]:-(none)}" >&2
    exit 1
  fi
  files=("${found[0]}")
fi

# the prepared folder (the script's last line of output; its progress goes to the terminal)
DASHBOARD_DIR=$(uv run python scripts/py/dashboard.py "${files[@]}" | tail -n 1)
export DASHBOARD_DIR

if [[ $host == 0.0.0.0 ]]; then
  echo "dashboard: http://$(hostname -f 2>/dev/null || hostname):$port  (for others on this network; Ctrl+C to stop)"
else
  echo "dashboard: http://localhost:$port  (Ctrl+C to stop)"
fi
env/bin/Rscript -e 'a <- commandArgs(TRUE)
  shiny::runApp("scripts/R/dashboard-app.R", host = a[1], port = as.integer(a[2]), launch.browser = a[1] == "127.0.0.1" &&
                (interactive() || nzchar(Sys.getenv("DISPLAY")) || Sys.info()[["sysname"]] == "Darwin"))' "$host" "$port"
