# Dashboard of the tables in output/dashboard/ (written by the pipeline: see scripts/R/dashboard.R).
# Start it with scripts/sh/dashboard.sh. It reads whatever tables are there:
#   cells.parquet               cell + annotation columns   -> "Colour by" and the groups
#   embedding_<name>.parquet    cell, dim1, dim2            -> one choice per embedding
#   values_<name>.parquet       cell, feature, value        -> one choice per value table (long, non-zero only)
library(shiny)
library(ggplot2)

# runApp() switches to this file's folder, so find the tables from the project root (renv records it)
dir <- Sys.getenv("DASHBOARD_DIR", file.path(Sys.getenv("RENV_PROJECT", "."), "output", "dashboard"))
read_tables <- function(prefix) {
  files <- list.files(dir, paste0("^", prefix, "_.+\\.parquet$"), full.names = TRUE)
  names(files) <- sub(paste0("^", prefix, "_(.+)\\.parquet$"), "\\1", basename(files))
  lapply(files, function(f) as.data.frame(nanoparquet::read_parquet(f)))
}
embeddings <- read_tables("embedding")
values <- read_tables("values")
cells <- as.data.frame(nanoparquet::read_parquet(file.path(dir, "cells.parquet")))
annotations <- names(cells)[vapply(cells, function(x) is.character(x) || is.factor(x), logical(1))]
annotations <- setdiff(annotations, "cell")

# One lookup per value table: feature -> its non-zero cells and values (cells not listed are 0)
by_feature <- lapply(values, function(v) split(v[c("cell", "value")], v$feature))
features <- sort(unique(unlist(lapply(by_feature, names))))
feature_values <- function(table, feature) {
  x <- setNames(numeric(nrow(cells)), cells$cell)
  hit <- by_feature[[table]][[feature]]
  if (!is.null(hit)) x[hit$cell] <- hit$value
  x
}

# Top features per group: highest mean value (zeros included) within each group
top_features <- function(table, annotation, n = 5) {
  v <- values[[table]]
  group <- cells[[annotation]][match(v$cell, cells$cell)]
  sums <- tapply(v$value, list(v$feature, group), sum, default = 0)
  means <- sweep(sums, 2, table(cells[[annotation]])[colnames(sums)], "/")
  as.data.frame(lapply(setNames(colnames(means), colnames(means)), function(g) {
    top <- head(order(means[, g], decreasing = TRUE), n)
    sprintf("%s (%.2f)", rownames(means)[top], means[top, g])
  }), check.names = FALSE)
}

ui <- fluidPage(
  titlePanel(paste("Dashboard:", basename(normalizePath(file.path(dir, "../..")))), windowTitle = "Dashboard"),
  sidebarLayout(
    sidebarPanel(width = 3,
      selectInput("embedding", "Embedding", names(embeddings),
                  selected = if ("umap" %in% names(embeddings)) "umap" else names(embeddings)[1]),
      radioButtons("colour_by", "Colour cells by", c("annotation", "feature"), inline = TRUE),
      selectInput("annotation", "Annotation (groups)", annotations),
      selectInput("table", "Values", names(values)),
      selectizeInput("feature", "Feature", choices = NULL),
      helpText(sprintf("%d cells · %d features · %d embedding(s) · %d value table(s)",
                       nrow(cells), length(features), length(embeddings), length(values)))
    ),
    mainPanel(width = 9,
      plotOutput("embedding_plot", height = 480),
      plotOutput("feature_plot", height = 260),
      h4("Top features per group"),
      tableOutput("top")
    )
  )
)

server <- function(input, output, session) {
  # server = TRUE: the browser only receives the matches, so thousands of genes stay fast
  updateSelectizeInput(session, "feature", choices = features, selected = features[1], server = TRUE)

  output$embedding_plot <- renderPlot({
    d <- merge(embeddings[[input$embedding]], cells, by = "cell")
    if (input$colour_by == "feature" && nzchar(input$feature)) {
      d$colour <- feature_values(input$table, input$feature)[d$cell]
      d <- d[order(d$colour), ]                                   # high values drawn on top
      scale <- scale_colour_viridis_c(name = input$feature)
    } else {
      d$colour <- d[[input$annotation]]
      scale <- scale_colour_discrete(name = input$annotation)
    }
    ggplot(d, aes(dim1, dim2, colour = colour)) + geom_point(size = 0.8) + scale +
      labs(title = input$embedding, x = "dimension 1", y = "dimension 2") + theme_minimal(base_size = 13)
  })

  output$feature_plot <- renderPlot({
    req(nzchar(input$feature))
    d <- data.frame(group = cells[[input$annotation]],
                    value = feature_values(input$table, input$feature)[cells$cell])
    ggplot(d, aes(group, value, fill = group)) + geom_violin(scale = "width", show.legend = FALSE) +
      labs(title = sprintf("%s (%s) by %s", input$feature, input$table, input$annotation), x = NULL, y = NULL) +
      theme_minimal(base_size = 13)
  })

  output$top <- renderTable(top_features(input$table, input$annotation))
}

shinyApp(ui, server)
