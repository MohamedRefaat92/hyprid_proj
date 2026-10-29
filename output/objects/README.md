# output/objects/

Analysis objects to keep and reuse: `.h5ad` (AnnData), `.h5mu` (MuData), `.rds` (Seurat, ...). For
multimodal data in the dashboard, one `.h5ad` per modality: `<dataset>_<modality>.h5ad`. Open them with
`scripts/sh/dashboard.sh <file> [<file> ...]` (see the Dashboard section of the main README).

Git-ignored, except this README.
