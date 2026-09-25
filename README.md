# hyprid-proj

A Python + R project for scientific computing. Three tools manage three separate layers, and they never overlap:

| Layer | Tool | Defined in | Locked in | Lives in |
| --- | --- | --- | --- | --- |
| Runtime: R, compilers, C libraries, CLI tools (samtools, bedtools), JupyterLab | Miniforge (`mamba`) | `environment.yml` | `conda-<platform>.lock` | `./env` |
| Python packages | uv | `pyproject.toml` | `uv.lock` | `./.venv` |
| R packages | renv | `_dependencies.R` + code | `renv.lock` | `./renv/library` |

**The rule that keeps this stable: every R package comes from renv.** conda installs only `r-base` and the system libraries that R packages compile against. Never `mamba install r-<something>`: renv hides conda's R library, so those packages would be invisible anyway.

## Setup

Requirements: [Miniforge](https://github.com/conda-forge/miniforge) and [uv](https://docs.astral.sh/uv/). macOS or Linux (on Windows, use WSL: bioconda has no Windows builds).

```bash
./bootstrap.sh
```

This script is safe to re-run. It:

1. creates `./env` from the lockfile for your platform, or from `environment.yml` if no lockfile exists for it
2. restricts JupyterLab to the two project kernels
3. runs `uv sync`
4. runs `renv::restore()`, which compiles R packages from source (the first run takes a while)
5. registers the `R (hyprid · renv)` and `Python (hyprid · uv)` kernels inside `./env`

Kernel files and Jupyter config live in `./env`, which isn't committed. They contain absolute paths, so every machine generates its own through `bootstrap.sh`.

## Daily use

- **JupyterLab:** `env/bin/jupyter lab`, then pick `R (hyprid · renv)` or `Python (hyprid · uv)`. Both work from notebooks in any subfolder.
- **VS Code notebooks:** pick the same two kernels from **Select Kernel → Jupyter Kernel…**.
- **R in VS Code:** use **R: Create R Terminal**, or type `R` in an integrated terminal (`env/bin` is on the terminal PATH). Both attach to the R extension's workspace pane. With several R sessions open, run **R: Attach Active Terminal** to switch the pane to another session.
- **Python scripts:** `uv run python script.py`.

Neither VS Code panel shows the variables of **R notebook** kernels: the Jupyter Variables panel supports Python only. Use an R terminal with `.R`/`.qmd` files when you want the workspace pane, or run `ls.str()` in the notebook.

## Adding things

| To add | Do | Then record it |
| --- | --- | --- |
| A Python package | `uv add <pkg>` | automatic (`uv.lock`) |
| An R package | `renv::install("<pkg>")`, and use it in code or list it in `_dependencies.R` | `renv::snapshot()` |
| A C library, compiler tool or CLI tool | add it to `environment.yml`, then `mamba env update -p ./env -f environment.yml` | `conda list -p ./env --explicit --md5 > conda-osx-arm64.lock` |

Use `conda list`, not `mamba list`, to write the lockfile: mamba omits the `@EXPLICIT` header, and without it the lockfile can't recreate the env.

## Troubleshooting

- **An R package fails to compile** with `'xyz.h' file not found` or `library not found for -lxyz`: a C library is missing. Add its conda-forge package to `environment.yml`, update the env, and install again.
- **`command not found: arm64-apple-darwin20.0.0-clang`**: R was started without the project `.Rprofile`, which puts `env/bin` on PATH. Start R from the project root.
- **"lockfile was generated with R x.y"** after an R upgrade: run `renv::snapshot()` once the packages are reinstalled. Don't run `renv::restore()` with a lockfile from a different R version.
- **A `.micromamba/` folder appears:** the `vscode-micromamba` VS Code extension sets `MAMBA_ROOT_PREFIX` to the project. Disable or uninstall it; the folder is ignored by git.
- **`.Rprofile` must end with a newline.** R silently skips an unterminated last line.

## Files

- `.Rprofile`: puts `env/bin` on PATH, sets repos and source-only installs, activates renv, attaches VS Code R sessions
- `scripts/register-r-kernel.R`: writes the R kernelspec (called by `bootstrap.sh`)
- `.vscode/settings.json`: points VS Code at `./env` R and `.venv` Python, using `${workspaceFolder}` paths
