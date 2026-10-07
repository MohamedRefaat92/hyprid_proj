# The pipeline: run with scripts/sh/run-pipeline.sh (or targets::tar_make() in R).
# The store lives in output/_targets (set in _targets.yaml).
# The example needs inputs in data/: create mock ones with scripts/sh/mock-data.sh.
library(targets)
library(tarchetypes)

tar_source(c("src/R", "scripts/R/provenance.R"))   # analysis functions + report bookkeeping (not all of scripts/R: some helpers run when sourced)

list(
  # Inputs as file targets: targets re-runs everything downstream when a file's content changes.
  # Which data the project uses, and what it is: metadata/catalogue_data.tsv (scripts/sh/catalogue-data.sh).
  tar_target(counts_file, "data/counts.tsv", format = "file"),
  tar_target(samples_file, "metadata/samples.csv", format = "file"),   # the sample sheet (metadata you write)

  # Example analysis
  tar_target(counts, read_counts(counts_file)),
  tar_target(samples, read_samples(samples_file)),
  tar_target(logcpm, log_cpm(counts)),
  tar_target(gene_summary, summarise_genes(logcpm, samples)),
  tar_target(gene_plot, plot_genes(gene_summary)),

  # Not used by any report: it stays out of the report's pipeline graph
  tar_target(orphan_example, "not used by any report"),

  # Reports: one folder per report under notebooks/, rendered to output/reports/latest/
  # extra_files: also re-render when the report style, the provenance helper, the reviewed data catalogue or renv.lock changes
  tar_quarto(example_report, "notebooks/example-report/example-report.qmd",
             extra_files = c("_quarto.yml", "scripts/R/provenance.R", "metadata/catalogue_data.tsv", "renv.lock"))
)
