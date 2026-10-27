# Example single-cell data for the dashboard (scripts/sh/dashboard.sh): simulated, replace with your own.

#' Simulate UMI counts for `n_cells` cells in `n_clusters` clusters, with marker genes per cluster.
#' Returns counts (genes x cells), per-cell annotations, and simulated UMAP coordinates.
simulate_single_cell <- function(n_cells = 1000, n_genes = 300, n_clusters = 4, seed = 1) {
  set.seed(seed)
  cell_ids <- sprintf("cell%04d", seq_len(n_cells))
  gene_ids <- sprintf("Gene%04d", seq_len(n_genes))
  cluster <- sample(seq_len(n_clusters), n_cells, replace = TRUE)

  # Mean UMIs per gene and cluster: most genes low (so the matrix is sparse), 15 markers per cluster 8x up
  mu <- matrix(rgamma(n_genes, shape = 0.6, scale = 2), n_genes, n_clusters)
  markers <- split(sample(n_genes, 15 * n_clusters), rep(seq_len(n_clusters), each = 15))
  for (k in seq_len(n_clusters)) mu[markers[[k]], k] <- mu[markers[[k]], k] * 8
  depth <- rlnorm(n_cells, 0, 0.4)                              # sequencing depth per cell
  mu_cells <- sweep(mu[, cluster, drop = FALSE], 2, depth, "*")
  counts <- matrix(rnbinom(length(mu_cells), mu = mu_cells, size = 2), n_genes, n_cells,
                   dimnames = list(gene_ids, cell_ids))

  # Simulated UMAP: one blob per cluster around a circle
  angle <- 2 * pi * cluster / n_clusters
  umap <- data.frame(cell = cell_ids,
                     dim1 = 6 * cos(angle) + rnorm(n_cells, sd = 1),
                     dim2 = 6 * sin(angle) + rnorm(n_cells, sd = 1))

  cells <- data.frame(cell    = cell_ids,
                      cluster = paste0("cluster_", cluster),
                      sample  = sample(c("sample_A", "sample_B"), n_cells, replace = TRUE),
                      n_umi   = colSums(counts),
                      n_genes = colSums(counts > 0))
  list(counts = counts, cells = cells, umap = umap)
}

#' log-normalised counts: log1p(counts per 10,000 UMIs in each cell)
normalize_counts <- function(counts) {
  log1p(t(t(counts) / colSums(counts)) * 1e4)
}

#' PCA on the 100 most variable genes; returns the first two components as dim1, dim2
run_pca <- function(normalized, n_genes = 100) {
  top <- head(order(apply(normalized, 1, var), decreasing = TRUE), n_genes)
  pcs <- prcomp(t(normalized[top, ]), center = TRUE, scale. = TRUE, rank. = 2)$x
  data.frame(cell = colnames(normalized), dim1 = pcs[, 1], dim2 = pcs[, 2])
}
