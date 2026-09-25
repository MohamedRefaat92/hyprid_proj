#!/usr/bin/env bash
# Build (or repair) all project environments. Safe to re-run.
#
#   ./bootstrap.sh            exact rebuild from conda-<platform>.lock when one exists
#   ./bootstrap.sh --resolve  re-solve the conda env from environment.yml instead
#
# Needs: Miniforge (mamba + conda) and uv on PATH. macOS/Linux; on Windows use WSL.
set -euo pipefail
cd "$(dirname "$0")"

# Keep mamba's package cache in ~/miniforge3, not in the project
unset MAMBA_ROOT_PREFIX MAMBA_EXE

resolve=false
[[ "${1:-}" == "--resolve" ]] && resolve=true

case "$(uname -s)-$(uname -m)" in
  Darwin-arm64)  platform=osx-arm64 ;;
  Darwin-x86_64) platform=osx-64 ;;
  Linux-x86_64)  platform=linux-64 ;;
  Linux-aarch64) platform=linux-aarch64 ;;
  *) echo "Unsupported platform: $(uname -s)-$(uname -m)" >&2; exit 1 ;;
esac
lock="conda-${platform}.lock"

echo "==> [1/5] conda env (./env): runtime, C libraries, CLI tools, JupyterLab"
if [[ -d env/conda-meta ]]; then
  echo "    ./env exists, skipping (delete it to rebuild)"
elif [[ -f "$lock" && "$resolve" == false ]]; then
  mamba create -y -p ./env --file "$lock"
else
  mamba env create -y -p ./env -f environment.yml
  echo "    Solved fresh. Record it with: conda list -p ./env --explicit --md5 > $lock"
fi

echo "==> [2/5] JupyterLab shows only the project kernels"
mkdir -p env/etc/jupyter
echo '{"KernelSpecManager": {"allowed_kernelspecs": ["hyprid-r", "hyprid-py"]}}' \
  > env/etc/jupyter/jupyter_server_config.json

echo "==> [3/5] Python packages (uv)"
uv sync --locked

echo "==> [4/5] R packages (renv)"
env/bin/Rscript -e 'renv::restore(prompt = FALSE)'

echo "==> [5/5] Jupyter kernels"
env/bin/Rscript scripts/register-r-kernel.R
# ipykernel warns that ./env "may not be found": that's the .venv's view; env/bin/jupyter finds it
uv run --locked python -m ipykernel install --prefix ./env \
  --name hyprid-py --display-name "Python (hyprid · uv)"

echo "Done. Start JupyterLab with: env/bin/jupyter lab"
