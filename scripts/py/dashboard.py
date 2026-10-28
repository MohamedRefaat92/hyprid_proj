"""Prepare single-cell data for the dashboard (scripts/R/dashboard-app.R).

Input: one .h5ad (AnnData), one .h5mu (MuData, e.g. multiome), or several .h5ad files, one per modality
of the same cells (e.g. my_data_rna.h5ad my_data_atac.h5ad: modalities "rna" and "atac", dataset "my_data";
the first file with embeddings gives the annotations and embeddings, and its tab comes first).

Started by scripts/sh/dashboard.sh. Writes a folder next to the (first) file, redone only when an input
is newer or the set of files changed, and prints its path:

  cells.tsv                  cell + the categorical obs columns: what cells can be grouped and split by
  embeddings.tsv             cell + the first two dimensions of every embedding: <key>_1, <key>_2
  modalities.txt             the modalities, in order (one tab each)
  <modality>/features.txt    feature names (genes, peaks, ...), one per line
  <modality>/cells.txt       the modality's cells, in matrix order
  <modality>/data.f32        X stored feature by feature (CSC): non-zero values      (float32)
  <modality>/indices.i32                                       their cell positions  (int32, 0-based)
  <modality>/indptr.f64                                        where each feature starts (float64)

One feature is one small read (base R readBin), whatever the number of cells or features.

    uv run python scripts/py/dashboard.py <file> [<file> ...]
"""

import os
import sys
from pathlib import Path

import anndata as ad
import mudata as md
import numpy as np
import pandas as pd
from scipy import sparse


def groups(obs):
    """Categorical and text columns with at most 200 groups: what the cells can be grouped and split by."""
    t = pd.api.types
    keep = [c for c in obs.columns
            if (isinstance(obs[c].dtype, pd.CategoricalDtype) or t.is_string_dtype(obs[c]) or t.is_bool_dtype(obs[c]))
            and obs[c].nunique() <= 200]
    return obs[keep].astype(str)


def embeddings(obsm, prefix=""):
    """The first two dimensions of every 2-D obsm entry, as columns <prefix><key>_1, <prefix><key>_2."""
    cols = {}
    for key in obsm.keys():
        x = np.asarray(obsm[key])
        if x.ndim == 2 and x.shape[1] >= 2:
            cols[f"{prefix}{key}_1"], cols[f"{prefix}{key}_2"] = x[:, 0], x[:, 1]
    return cols


def write_matrix(m, out):
    out.mkdir(parents=True, exist_ok=True)
    x = sparse.csc_matrix(m.X, dtype=np.float32)
    x.sort_indices()
    x.data.tofile(out / "data.f32")
    x.indices.astype(np.int32).tofile(out / "indices.i32")
    x.indptr.astype(np.float64).tofile(out / "indptr.f64")
    (out / "features.txt").write_text("\n".join(map(str, m.var_names)) + "\n")
    (out / "cells.txt").write_text("\n".join(map(str, m.obs_names)) + "\n")


def names(paths):
    """(dataset, modalities): my_data_rna.h5ad, my_data_atac.h5ad -> my_data, [rna, atac]."""
    if len(paths) == 1:
        return paths[0].stem, None
    stems = [p.stem for p in paths]
    prefix = os.path.commonprefix(stems)
    if any(s == prefix for s in stems):  # one name is the prefix of another: keep whole names
        prefix = ""
    return prefix.rstrip("_-.") or "combined", [s[len(prefix):] for s in stems]


def prepare(paths, out, modality_names):
    if modality_names:  # several .h5ad files: annotations and embeddings from the first one with embeddings
        modalities = {n: ad.read_h5ad(p) for n, p in zip(modality_names, paths)}
        top = next((m for m in modalities.values() if embeddings(m.obsm)), next(iter(modalities.values())))
        modalities = dict(sorted(modalities.items(), key=lambda item: item[1] is not top))  # its tab first
    elif paths[0].suffix == ".h5mu":
        top = md.read_h5mu(paths[0])
        modalities = dict(top.mod)
    else:
        top = ad.read_h5ad(paths[0])
        modalities = {"expression": top}

    coords = pd.DataFrame(embeddings(top.obsm), index=top.obs_names)
    for name, m in modalities.items():
        if m is not top:  # a modality's own embeddings, named <modality>:<key>
            coords = coords.join(pd.DataFrame(embeddings(m.obsm, f"{name}:"), index=m.obs_names))
        print(f"  {name}: {m.n_vars} features x {m.n_obs} cells", file=sys.stderr)
        write_matrix(m, out / name)
    (out / "modalities.txt").write_text("\n".join(modalities) + "\n")
    groups(top.obs).rename_axis("cell").to_csv(out / "cells.tsv", sep="\t")
    coords.rename_axis("cell").to_csv(out / "embeddings.tsv", sep="\t")


def main():
    paths = [Path(p) for p in sys.argv[1:]]
    if len(paths) > 1 and any(p.suffix != ".h5ad" for p in paths):
        sys.exit("several files: give .h5ad files, one per modality")
    dataset, modality_names = names(paths)
    out = paths[0].parent / dataset
    done = out / "embeddings.tsv"  # written last
    fresh = (done.exists() and all(done.stat().st_mtime > p.stat().st_mtime for p in paths)
             and (not modality_names or sorted((out / "modalities.txt").read_text().split()) == sorted(modality_names)))
    if not fresh:
        print(f"preparing {' '.join(map(str, paths))} -> {out}/ (once; again when a file changes)", file=sys.stderr)
        prepare(paths, out, modality_names)
    print(out.resolve())


if __name__ == "__main__":
    main()
