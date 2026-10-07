# Run bookkeeping for the pipeline and reports. Not analysis: nothing here touches the data's content.

git <- function(...) {
  out <- tryCatch(system2("git", c(...), stdout = TRUE, stderr = FALSE),
                  error = function(e) character(), warning = function(w) character())
  if (length(out) == 0) NA_character_ else out[1]
}

#' The commit the code is at, named after the nearest tag (e.g. v0.1, or v0.1-3-g8f2c1ab three commits later).
git_version <- function() {
  v <- git("describe", "--tags", "--always")
  if (is.na(v)) "not a git repository" else v
}

#' TRUE if the project (or just `path`) differs from the commit: modified files, or new files not yet added.
#' One rule for code and data, so "uncommitted changes" means the same thing everywhere in a report.
has_uncommitted <- function(path = ".") {
  !is.na(git("status", "--porcelain", "--", path))
}

#' Web link to the current commit on GitHub (NA if there is no GitHub remote).
#' Only works once the commit is pushed; with uncommitted changes it shows the code without them.
git_commit_url <- function() {
  sha <- git("rev-parse", "HEAD")
  remote <- git("remote", "get-url", "origin")
  if (is.na(sha) || is.na(remote) || !grepl("github\\.com", remote)) return(NA_character_)
  repo <- sub("\\.git$", "", sub("^git@github\\.com:", "https://github.com/", remote))
  paste0(repo, "/commit/", sha)
}

#' Which data the report is based on: markdown summary of the reviewed data catalogue (metadata/catalogue_data.tsv): link at this commit, files per kind and format.
catalogue_summary <- function(file = "metadata/catalogue_data.tsv") {
  if (!file.exists(file)) return("_no reviewed data catalogue: run `scripts/sh/catalogue-data.sh`, review, copy to metadata/catalogue_data.tsv_\n\n")
  cat_tab <- read.delim(file, colClasses = "character", na.strings = character())
  url <- git_commit_url()
  link <- if (is.na(url)) paste0("`", file, "`") else
    paste0("[`", file, "`](", sub("/commit/", "/blob/", url), "/", file, ")")
  dirty <- has_uncommitted(file)
  present <- cat_tab[cat_tab$status == "present", , drop = FALSE]
  kind <- ifelse(present$kind == "", "(not described)", present$kind)
  counts <- as.data.frame(table(kind = kind, format = present$format), responseName = "files")
  counts <- counts[counts$files > 0, , drop = FALSE]
  paste0(
    link, if (dirty) " (uncommitted changes)" else "", ": ",
    nrow(present), " file(s) in use",
    if (any(cat_tab$status == "missing")) paste0(", ", sum(cat_tab$status == "missing"), " missing") else "",
    "\n\n", paste(knitr::kable(counts, row.names = FALSE), collapse = "\n"), "\n\n"
  )
}

#' Which code made the report: commit (linked to GitHub when possible), when and where it was rendered.
#' (R and package versions are in the session info at the end of each report.)
code_summary <- function() {
  v <- git_version()
  url <- git_commit_url()
  commit <- if (is.na(url)) paste0("`", v, "`") else paste0("[`", v, "`](", url, ")")
  if (has_uncommitted()) commit <- paste0(commit, " (uncommitted changes)")
  paste0("**Commit** ", commit,
         " &middot; **Rendered** ", format(Sys.time(), "%Y-%m-%d %H:%M"),
         " on `", Sys.info()[["nodename"]], "`\n\n")
}

#' Path of the report being rendered, relative to the project root.
report_input <- function() {
  input <- normalizePath(knitr::current_input(dir = TRUE))
  input <- sub("\\.rmarkdown$", ".qmd", input)   # knitr sees Quarto's intermediate copy, not the .qmd
  sub(paste0("^", normalizePath(getwd()), "/"), "", input)
}

#' Folder for the figures and tables a report saves: artifacts/ next to its HTML in output/reports/latest/.
#' notebooks/<report>/<report>.qmd -> output/reports/latest/notebooks/<report>/artifacts/
#' Emptied at the start of each render, so it only ever holds what the latest render produced.
#' Call it once per report (in the setup chunk).
report_dir <- function() {
  dir <- file.path("output", "reports", "latest", dirname(report_input()), "artifacts")
  unlink(dir, recursive = TRUE)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  dir
}

#' Name of the pipeline target that renders this report (the tar_quarto() whose command names this file).
# targets reads _targets.R in a separate R process (it can't run inside knitr while this report renders);
# keep that process's console output (e.g. renv startup notes) out of the report.
quiet_callr <- list(show = FALSE)

report_target <- function() {
  m <- targets::tar_manifest(fields = c("name", "command"), callr_arguments = quiet_callr)
  hit <- m$name[grepl(report_input(), m$command, fixed = TRUE)]
  if (length(hit) == 0) NA_character_ else hit[1]
}

#' Static Mermaid diagram of this report and everything upstream of it, as a Quarto mermaid block.
#' Print it from a chunk with `output: asis`.
pipeline_mermaid <- function() {
  target <- report_target()
  lines <- if (is.na(target)) {
    targets::tar_mermaid(targets_only = TRUE, outdated = FALSE, legend = FALSE,
                         callr_arguments = quiet_callr)
  } else {
    targets::tar_mermaid(names = tidyselect::any_of(!!target), targets_only = TRUE,
                         outdated = FALSE, legend = FALSE, callr_arguments = quiet_callr)
  }
  paste(c("```{mermaid}", lines, "```"), collapse = "\n")
}

#' Interactive graph of this report and everything upstream of it (other targets are left out).
pipeline_graph <- function(height = "380px") {
  target <- report_target()
  g <- if (is.na(target)) {
    targets::tar_visnetwork(targets_only = TRUE, outdated = FALSE, callr_arguments = quiet_callr)
  } else {
    # !! injects the name now: the selection is evaluated in the separate process, where `target` doesn't exist
    targets::tar_visnetwork(names = tidyselect::any_of(!!target), targets_only = TRUE,
                            outdated = FALSE, callr_arguments = quiet_callr)
  }
  g$height <- height
  g
}
