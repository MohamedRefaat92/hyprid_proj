# hyprid-proj

A template for Python + R scientific computing projects. Three tools manage three separate layers, and they never overlap:

| Layer | Tool | Defined in | Locked in | Lives in |
| --- | --- | --- | --- | --- |
| Runtime: R, compilers, C libraries, CLI tools (samtools, bedtools, shellcheck), JupyterLab | Miniforge (`mamba`) | `environment.yml` | `conda-<platform>.lock` | `./env` |
| Python packages | uv | `pyproject.toml` | `uv.lock` | `./.venv` |
| R packages | renv | `_dependencies.R` + code | `renv.lock` | `./renv/library` |

Two rules keep this stable:

- **One owner per layer.** Every R package comes from renv; conda installs only `r-base` and the system libraries R packages compile against. Never `mamba install r-<something>`: renv hides conda's R library, so those packages would be invisible anyway. Python packages come only from uv.
- **Only what the project's code needs goes into the project.** Tools that serve you rather than the code (editors and their extensions, Node/npx for MCP servers, agents) are installed per user, never in `environment.yml`.

## Setup

Requirements: [Miniforge](https://github.com/conda-forge/miniforge) and [uv](https://docs.astral.sh/uv/). macOS or Linux (on Windows, use WSL: bioconda has no Windows builds).

```bash
./bootstrap.sh            # build ./env, .venv, the renv library and the Jupyter kernels
./verify-env.sh --deep    # check that everything matches its declarations and is wired correctly
```

`bootstrap.sh` is safe to re-run. It:

1. creates `./env` from the lockfile for your platform, or from `environment.yml` if no lockfile exists (`--resolve` forces a fresh solve)
2. writes JupyterLab's config: only the project kernels, and the R language server from `./env`
3. runs `uv sync`
4. runs `renv::restore()`, which compiles R packages from source (the first run takes a while)
5. registers the `R (<folder> · renv)` and `Python (<folder> · uv)` kernels inside `./env`

Kernel files and the Jupyter config live in `./env`, which isn't committed. They contain absolute paths, so every machine generates its own.

## Starting a new project from this template

1. On GitHub, **Use this template → Create a new repository**, then clone the new repository.
2. Rename the Python project: `name` and the `[project.scripts]` entry in `pyproject.toml`, and the module folder (`git mv src/hyprid_proj src/<new_name>`; project names use `-`, module names `_`). Update the README title, then run `uv lock`.
3. Decide on the example dependencies: `uv remove …` for Python, `_dependencies.R` for R (then `renv::snapshot()` after bootstrap), and the CLI tools in `environment.yml` (then `./bootstrap.sh --resolve` and relock).
4. `./bootstrap.sh && ./verify-env.sh --deep`, then commit.

Kernel names and the `.Rprofile` messages come from the folder name, so they need no renaming. A project made from the template is a **copy**: later fixes to the template don't reach it automatically, so copy them over by hand.

## Daily use

- **JupyterLab:** `env/bin/jupyter lab`, then pick `R (<folder> · renv)` or `Python (<folder> · uv)`. Both work from notebooks in any subfolder.
- **Positron:** pick **R 4.5.3 (Conda: env)** in the interpreter picker. Every project made from this template is labelled `Conda: env`, so choose by the path shown underneath. The setting `positron.r.interpreters.condaDiscovery` (in `.vscode/settings.json`) makes it appear. The Python interpreter is the suggested `uv` one.
- **VS Code:** start R with **R: Create R Terminal** (or click **R not attached** in the status bar, or press Ctrl+Enter in an `.R` file). It runs `env/bin/R` and connects to the workspace pane and plot viewer through the `sess` package, which the R extension offers to install the first time. Typing `env/bin/R` in a plain terminal works too, but that session doesn't connect to the pane. For notebooks, pick the two kernels from **Select Kernel → Jupyter Kernel…**.
- **Terminals:** integrated terminals (VS Code and Positron) put `env/bin` first on PATH, so `R`, `jupyter` and the CLI tools work by name. Run Python with `uv run python script.py`.
- **R history** is kept across sessions in `.Rhistory` (git-ignored), saved after every command.

VS Code's Jupyter Variables panel supports Python only, so it doesn't show **R notebook** variables. Positron's Variables pane does; in VS Code, use an R terminal or run `ls.str()` in the notebook.

## Checking the environment

```bash
./verify-env.sh           # fast checks (a few seconds)
./verify-env.sh --deep    # also starts each kernel from a subfolder and runs code in it
```

It is **read-only**: it reports, `bootstrap.sh` repairs. Every line is one connection between two components, with its evidence, and every failure comes with a hint:

| Section | Checks |
| --- | --- |
| 0. Prerequisites | mamba, conda and uv on PATH; a usable lockfile for this platform; `./env` exists |
| 1. Runtime | `./env` matches the lockfile; every package in `environment.yml` is locked |
| 2. Runtime rules | no R packages from conda; mamba's cache isn't inside the project |
| 3. R | R version matches `renv.lock`; `./env`'s R runs; renv is active for this project and in sync; the compiler comes from `./env`; no libraries from other R installations; `.Rprofile` exists and ends with a newline |
| 4. Python | `uv.lock` matches `pyproject.toml`; `.venv` matches `uv.lock`; `.venv`'s Python matches `.python-version` |
| 5. Jupyter | each kernel uses its layer (`.venv` for Python, `./env` for R); the allowlist matches the kernels; JupyterLab's R language server is `./env`'s |
| 6. Editors | `settings.json` parses; VS Code's R paths and the terminal PATH point at `./env`; Positron's conda discovery is on; no conflicting extensions |
| 7. `--deep` | each kernel, started from `src/`, really uses the renv library or `.venv` |

The exit code is 0 only if nothing failed, so it can gate other commands: `./verify-env.sh && git push`. When several checks fail at once, start with the **lowest** failing section: it usually explains the ones above it. Run it after any change to the environment, and after any drill (break something on purpose, check that verify catches it, repair, run verify again).

## Adding things

| To add | Do | Then record it |
| --- | --- | --- |
| A Python package | `uv add <pkg>` (`uv add --dev <pkg>` for tooling such as ipykernel) | automatic (`uv.lock`) |
| An R package | `renv::install("<pkg>")`, and use it in code or list it in `_dependencies.R` | `renv::snapshot()` |
| A C library, compiler tool or CLI tool | add it to `environment.yml`, then `mamba env update -p ./env -f environment.yml` | `conda list -p ./env --explicit --md5 > conda-osx-arm64.lock` |

- If an R package fails to compile because a C library is missing, add the library first (third row), then install the R package again.
- Use `conda list`, not `mamba list`, to write the lockfile: mamba omits the `@EXPLICIT` header, and without it the lockfile can't recreate the env.
- Never `uv pip install` into `.venv` or `mamba install` without updating `environment.yml`: it changes the environment behind its declaration, and `verify-env.sh` will report it.
- Run `./verify-env.sh` afterwards.

## Troubleshooting

`./verify-env.sh` is the first step; most problems below show up there with a hint.

- **An R package fails to compile** with `'xyz.h' file not found` or `library not found for -lxyz`: a C library is missing. Add its conda-forge package to `environment.yml`, update the env, relock, and install again.
- **`[<folder>] … is not this project's R; renv not activated`**: an R other than `./env`'s was started in the project (a system R, or another template project's env). `.Rprofile` keeps it out, because it would create a second, incompatible renv library. Use `env/bin/R`, or pick the right interpreter by its path. A stale `RENV_PROJECT` variable causes the same message; `echo $RENV_PROJECT` and unset it.
- **"lockfile was generated with R x.y"** after an R upgrade: reinstall the packages, then `renv::snapshot()`. Don't run `renv::restore()` with a lockfile from a different R version.
- **`.Rprofile` must end with a newline.** R silently skips an unterminated last line, and here that line closes the block that holds everything else.
- **Editor settings seem ignored:** `.vscode/settings.json` (JSONC: comments allowed) probably doesn't parse; editors then silently fall back to defaults. `verify-env.sh` section 6 shows the position of the error.
- **A `python3` kernel appears** after the env is rebuilt or updated: it's the conda Python's own kernel, shipped by `ipykernel`. `./bootstrap.sh` removes it; JupyterLab hides it anyway.
- **A `.micromamba/` folder appears:** something set `MAMBA_ROOT_PREFIX` into the project (the `vscode-micromamba` VS Code extension did). Uninstall the extension, quit VS Code fully (⌘Q), then delete the folder.
- **The project folder was moved or renamed:** kernels and the Jupyter config hold absolute paths. Run `./bootstrap.sh` (rebuild `./env` with `rm -rf env` first if R itself fails to start).

## Files

- `bootstrap.sh`: builds or repairs every layer (see Setup)
- `verify-env.sh`: read-only check of every layer and how they connect (see Checking the environment)
- `scripts/register-r-kernel.R`: writes the R kernelspec (called by `bootstrap.sh`)
- `.Rprofile`: refuses foreign R installations; puts `env/bin` on PATH; sets repos and source-only installs; activates renv; saves R history
- `_dependencies.R`: R packages the project needs that code doesn't load directly (never sourced; renv reads it)
- `.vscode/settings.json`: editor wiring for VS Code (R paths, terminal PATH) and Positron (conda R discovery), using `${workspaceFolder}` paths
- `environment.yml`, `pyproject.toml`: what each layer should contain; `conda-<platform>.lock`, `uv.lock`, `renv.lock`: exactly what it does contain
