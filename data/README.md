# data/

Input files for this project, as **symlinks** to where the data really lives (cluster, shared drive, downloads).
The links are git-ignored, because their targets are specific to each machine.

```bash
scripts/sh/link-input.sh /absolute/path/to/file-or-folder [name]   # link an input (a folder brings all its files)
scripts/sh/catalogue-data.sh                                       # catalogue them: see metadata/README.md
```

What the project's data is, and where each file came from, is recorded in `metadata/catalogue_data.tsv`.
Never write into `data/`: derived data belongs to the pipeline, under `output/`.
