# Put the conda env's tools (compilers, pkg-config, pandoc) on PATH even when
# R is started directly as env/bin/R, without `mamba activate`.
local({
  prefix <- normalizePath(file.path(R.home(), "..", ".."), mustWork = FALSE)
  bins <- if (.Platform$OS.type == "windows") {
    file.path(prefix, c("Library/mingw-w64/bin", "Library/usr/bin", "Library/bin", "Scripts"))
  } else {
    file.path(prefix, "bin")
  }
  Sys.setenv(PATH = paste(c(bins, Sys.getenv("PATH")), collapse = .Platform$path.sep))
})

# conda R cannot use CRAN macOS binaries, so always build from source
options(
  pkgType = "source",
  repos = c(
    CRAN        = "https://cloud.r-project.org",
    vscdebugger = "https://manuelhentschel.r-universe.dev"
  )
)

# RENV_PROJECT lets kernels started in subfolders find the project
local({
  root <- Sys.getenv("RENV_PROJECT", unset = getwd())
  source(file.path(root, "renv", "activate.R"))
})

# Attach self-started R sessions in VS Code terminals to the R extension's
# workspace pane. Terminals made with "R: Create R Terminal" already attach.
if (interactive() && Sys.getenv("TERM_PROGRAM") == "vscode" &&
    !nzchar(Sys.getenv("VSCODE_INIT_R"))) {
  init <- file.path(Sys.getenv(if (.Platform$OS.type == "windows") "USERPROFILE" else "HOME"),
                    ".vscode-R", "init.R")
  if (file.exists(init)) source(init)
  rm(init)
}
