"""Example multiome data for the dashboard (scripts/sh/dashboard.sh): simulated, replace with your own.

    uv run python src/python/hyprid_proj/example_multiome.py output/dashboard/example_multiome.h5mu
"""

import sys

import anndata as ad
import mudata as md
import numpy as np
import pandas as pd
from scipy import sparse


def simulate_multiome(n_cells=1000, n_genes=300, n_peaks=2000, n_clusters=4, seed=1):
    """RNA (UMI counts) and ATAC (peak counts) for the same cells, with cluster-specific genes and peaks.

    Returns a MuData: modalities "rna" and "atac" (raw counts in layers["counts"], normalised in X,
    a UMAP each in obsm["X_umap"]); cell annotations and a joint UMAP (obsm["X_wnn_umap"]) at the top level.
    """
    rng = np.random.default_rng(seed)
    cells = [f"cell{i:04d}" for i in range(n_cells)]
    cluster = rng.integers(n_clusters, size=n_cells)
    depth = rng.lognormal(0, 0.4, n_cells)  # sequencing depth per cell

    # RNA: mean UMIs per gene and cluster, most genes low (sparse), 15 markers per cluster 8x up
    mu = np.repeat(rng.gamma(0.6, 2, (n_genes, 1)), n_clusters, axis=1)
    for k in range(n_clusters):
        mu[rng.choice(n_genes, 15, replace=False), k] *= 8
    rna_counts = rng.negative_binomial(2, 2 / (2 + mu[:, cluster].T * depth[:, None]))
    genes = [f"Gene{i:04d}" for i in range(n_genes)]

    # ATAC: open probability per peak and cluster, mostly closed, 100 peaks per cluster opened
    p = np.repeat(rng.beta(0.5, 12, (n_peaks, 1)), n_clusters, axis=1)
    for k in range(n_clusters):
        p[rng.choice(n_peaks, 100, replace=False), k] = rng.uniform(0.4, 0.8, 100)
    atac_counts = rng.binomial(2, np.minimum(p[:, cluster].T * depth[:, None], 1))
    starts = np.sort(rng.choice(np.arange(1_000_000, 100_000_000, 1000), n_peaks, replace=False))
    peaks = [f"chr1:{s}-{s + 500}" for s in starts]

    def modality(counts, features, angle_shift):
        m = ad.AnnData(X=sparse.csr_matrix(counts, dtype=np.float32),
                       obs=pd.DataFrame(index=cells), var=pd.DataFrame(index=features))
        m.layers["counts"] = m.X.copy()
        totals = np.asarray(m.X.sum(axis=1)).ravel()
        m.X = sparse.csr_matrix(m.X.multiply(1e4 / totals[:, None]).log1p(), dtype=np.float32)
        m.obsm["X_umap"] = blobs(angle_shift)
        return m

    def blobs(angle_shift):  # a simulated UMAP: one blob per cluster around a circle
        angle = 2 * np.pi * cluster / n_clusters + angle_shift
        return np.column_stack([6 * np.cos(angle), 6 * np.sin(angle)]) + rng.normal(0, 1, (n_cells, 2))

    mdata = md.MuData({"rna": modality(rna_counts, genes, 0), "atac": modality(atac_counts, peaks, 0.6)})
    mdata.obs["cluster"] = pd.Categorical([f"cluster_{k + 1}" for k in cluster])
    mdata.obs["sample"] = pd.Categorical(rng.choice(["sample_A", "sample_B"], n_cells))
    mdata.obsm["X_wnn_umap"] = blobs(0.3)
    return mdata


if __name__ == "__main__":
    simulate_multiome().write_h5mu(sys.argv[1])
