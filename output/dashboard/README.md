# output/dashboard/

Single-cell results to look up in the dashboard: `.h5ad` (AnnData) files, one per modality for
multimodal data (`<dataset>_<modality>.h5ad`), or `.h5mu` (MuData) files. Open them with
`scripts/sh/dashboard.sh <file> [<file> ...]` (see the Dashboard section of the main README).

The first time, the dashboard writes `<dataset>/` next to them (again when a file changes): the same
data laid out for fast look-ups. Safe to delete. Git-ignored, except this README.
