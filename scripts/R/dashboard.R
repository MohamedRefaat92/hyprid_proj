# Tables for the dashboard (scripts/R/dashboard-app.R, started by scripts/sh/dashboard.sh).
# Not analysis: the pipeline calls these to save its results in the layout the dashboard reads.
#
#   output/dashboard/cells.parquet               cell + one column per annotation (cluster, sample, ...)
#   output/dashboard/embedding_<name>.parquet    cell, dim1, dim2               (e.g. umap, pca)
#   output/dashboard/values_<name>.parquet       cell, feature, value           (e.g. raw_umi, normalized)
#
# Parquet with zstd compression; value tables are stored long, non-zero entries only (single-cell
# matrices are mostly zeros). A cell missing for a feature means 0.

#' Save a data frame as output/dashboard/<name>.parquet; returns the path (for format = "file" targets).
write_dashboard_table <- function(df, name, dir = "output/dashboard") {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  path <- file.path(dir, paste0(name, ".parquet"))
  nanoparquet::write_parquet(df, path, compression = "zstd")
  path
}

#' A features x cells matrix as a long table of its non-zero entries: cell, feature, value.
long_values <- function(m) {
  nz <- which(m != 0, arr.ind = TRUE)
  data.frame(cell = colnames(m)[nz[, "col"]], feature = rownames(m)[nz[, "row"]], value = m[nz])
}
