#!/usr/bin/env bash
# Open the dashboard of output/dashboard/ in the browser (Ctrl+C to stop).
# The tables are written by the pipeline (scripts/sh/run-pipeline.sh); the app is scripts/R/dashboard-app.R.
#
#   scripts/sh/dashboard.sh [port]      default port 8050
#   On the cluster: run it there, then on your laptop `ssh -L 8050:localhost:8050 <cluster>`
#   and open http://localhost:8050 (no browser opens on the cluster itself).
set -euo pipefail
cd "$(dirname "$0")/../.."   # run from the project root, wherever this was called from

if ! ls output/dashboard/cells.parquet >/dev/null 2>&1; then
  echo "no dashboard tables in output/dashboard/ (run scripts/sh/run-pipeline.sh first)" >&2
  exit 1
fi
port=${1:-8050}
export DASHBOARD_DIR="$PWD/output/dashboard"
echo "dashboard: http://localhost:$port  (Ctrl+C to stop)"
env/bin/Rscript -e 'shiny::runApp("scripts/R/dashboard-app.R", port = as.integer(commandArgs(TRUE)[1]),
                                  launch.browser = interactive() || nzchar(Sys.getenv("DISPLAY")) || Sys.info()[["sysname"]] == "Darwin")' "$port"
