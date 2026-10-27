# output/dashboard/

Tables for the dashboard, written by the pipeline (`dashboard_tables` in `_targets.R`, using
`write_dashboard_table()` from `scripts/R/dashboard.R`). Open the dashboard with `scripts/sh/dashboard.sh`.

| File | Columns | In the dashboard |
| --- | --- | --- |
| `cells.parquet` | `cell` + annotation columns (`cluster`, `sample`, ...) | colours and groups |
| `embedding_<name>.parquet` | `cell`, `dim1`, `dim2` (e.g. `umap`, `pca`) | one choice per embedding |
| `values_<name>.parquet` | `cell`, `feature`, `value`: non-zero entries only | one choice per value table (e.g. `raw_umi`, `normalized`) |

Parquet with zstd compression (about 10x smaller than CSV). Git-ignored, except this README.
