# Writes the project's R kernelspec into env/share/jupyter/kernels/hyprid-r.
# Run from the project root with the env's R: env/bin/Rscript scripts/register-r-kernel.R
root   <- normalizePath(".", winslash = "/")
prefix <- normalizePath(file.path(R.home(), "..", ".."), winslash = "/")  # conda env root
r_bin  <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "R.exe" else "R")

kdir <- file.path(prefix, "share", "jupyter", "kernels", "hyprid-r")
dir.create(kdir, recursive = TRUE, showWarnings = FALSE)

spec <- list(
  argv = c(r_bin, "--slave", "-e", "IRkernel::main()", "--args", "{connection_file}"),
  display_name = "R (hyprid · renv)",
  language = "R",
  env = list(
    RENV_PROJECT   = root,
    R_PROFILE_USER = file.path(root, ".Rprofile")
  )
)
jsonlite::write_json(spec, file.path(kdir, "kernel.json"), auto_unbox = TRUE, pretty = TRUE)
invisible(file.copy(list.files(system.file("kernelspec", package = "IRkernel"), pattern = "^logo", full.names = TRUE), kdir, overwrite = TRUE))
message("Wrote ", file.path(kdir, "kernel.json"))

