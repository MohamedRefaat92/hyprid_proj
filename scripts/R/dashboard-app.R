# Dashboard: look up features (genes, peaks, ...) in single-cell data, grouped and split by any annotation.
# Started by scripts/sh/dashboard.sh, which first prepares the .h5ad / .h5mu with scripts/py/dashboard.py
# into DASHBOARD_DIR: cells.tsv (annotations), embeddings.tsv, and per modality its matrix feature by feature.
# One tab per modality; the sidebar (embedding, group by, split by) applies to every tab.
library(shiny)
library(ggplot2)

dir <- Sys.getenv("DASHBOARD_DIR")
cells <- read.delim(file.path(dir, "cells.tsv"), colClasses = "character", check.names = FALSE)
coords <- read.delim(file.path(dir, "embeddings.tsv"), check.names = FALSE)
coords <- coords[match(cells$cell, coords$cell), ]

# Annotations as factors; numeric labels (cluster 0, 1, ..., 10) in numeric order
for (g in setdiff(names(cells), "cell")) {
  x <- cells[[g]]
  levels <- unique(x)
  num <- suppressWarnings(as.numeric(levels))
  cells[[g]] <- factor(x, levels = if (anyNA(num)) sort(levels) else levels[order(num)])
}
annotations <- setdiff(names(cells), "cell")
default_group <- c(grep("cluster", annotations, value = TRUE, ignore.case = TRUE), annotations)[1]
embeddings <- unique(sub("_[12]$", "", setdiff(names(coords), "cell")))
embeddings <- embeddings[order(!grepl("umap", embeddings, ignore.case = TRUE))]   # UMAPs first

# Modalities: one folder each. A feature is read from disk when asked for (see scripts/py/dashboard.py)
read_at <- function(path, offset, n, what) {
  con <- file(path, "rb")
  on.exit(close(con))
  seek(con, offset)
  readBin(con, what, n, size = 4)
}
modalities <- readLines(file.path(dir, "modalities.txt"))
modalities <- setNames(lapply(modalities, function(m) {
  path <- file.path(dir, m)
  list(path = path,
       features = readLines(file.path(path, "features.txt")),
       indptr = readBin(file.path(path, "indptr.f64"), "double", file.size(file.path(path, "indptr.f64")) / 8),
       to_cells = match(readLines(file.path(path, "cells.txt")), cells$cell))
}), modalities)

feature_values <- function(mod, feature) {
  j <- match(feature, mod$features)
  x <- rep(NA_real_, nrow(cells))   # NA: cell not measured in this modality
  x[mod$to_cells[!is.na(mod$to_cells)]] <- 0   # to_cells is NA for cells missing from the annotations
  from <- mod$indptr[j]
  n <- mod$indptr[j + 1] - from
  if (n > 0) {
    at <- mod$to_cells[read_at(file.path(mod$path, "indices.i32"), from * 4, n, "integer") + 1]
    values <- read_at(file.path(mod$path, "data.f32"), from * 4, n, "numeric")
    x[at[!is.na(at)]] <- values[!is.na(at)]
  }
  x
}

# Plots
embedding_data <- function(embedding, group, split) {
  data.frame(x = coords[[paste0(embedding, "_1")]], y = coords[[paste0(embedding, "_2")]],
             group = cells[[group]], split = if (split == "none") "" else cells[[split]])
}
panels <- function(split) if (split == "none") 1 else nlevels(cells[[split]])
facet <- function(split) if (split != "none") facet_wrap(~split, ncol = min(panels(split), 4))
theme_dash <- theme_minimal(base_size = 13) + theme(panel.grid = element_blank())
theme_embedding <- theme_dash + theme(aspect.ratio = 1)   # square panels, however many

short_names <- function(group) max(nchar(levels(cells[[group]]))) <= 6
plot_groups <- function(d, embedding, split, group) {
  short <- short_names(group)
  p <- ggplot(d, aes(x, y, colour = group)) + geom_point(size = 0.3, shape = 16) +
    facet(split) + labs(x = paste(embedding, 1), y = paste(embedding, 2), colour = NULL) + theme_embedding +
    # short names (cluster numbers): on the plot, legend in columns; long names: legend below, one per line
    guides(colour = guide_legend(override.aes = list(size = 3), ncol = if (short) ceiling(nlevels(d$group) / 16) else 1)) +
    theme(legend.position = if (short) "right" else "bottom")
  if (short) {
    p <- p + geom_text(data = aggregate(cbind(x, y) ~ group + split, d, median), aes(label = group), colour = "black", size = 3.5)
  }
  p
}
plot_feature <- function(d, embedding, split, feature) {
  d <- d[order(d$value, na.last = FALSE), ]   # expressing cells on top
  ggplot(d, aes(x, y, colour = value)) + geom_point(size = 0.3, shape = 16) +
    scale_colour_viridis_c(name = feature, na.value = "grey85") +
    facet(split) + labs(x = paste(embedding, 1), y = paste(embedding, 2)) + theme_embedding
}
plot_violin <- function(d, group, split, feature) {
  d <- d[!is.na(d$value), ]
  d$fill <- if (split == "none") d$group else d$split
  pct <- aggregate(list(pct = d$value > 0), d[c("group", "fill")], mean)   # % expressing, above each violin
  labelled <- nrow(pct) <= 24                                             # (more would overlap; the table has them)
  ggplot(d, aes(group, value, fill = fill)) +
    geom_violin(scale = "width", position = position_dodge(0.9)) +
    geom_point(position = position_jitterdodge(jitter.width = 0.3, jitter.height = 0, dodge.width = 0.9),
               size = 0.4, alpha = 0.15, shape = 16, show.legend = FALSE) +   # every cell, see-through
    (if (labelled) geom_text(data = pct, aes(y = max(d$value) * 1.08, label = sprintf("%.0f%%", 100 * pct)),
                             position = position_dodge(0.9), size = 3)) +
    labs(x = group, y = feature, fill = if (split != "none") split,
         caption = if (labelled) "% = cells with a value above 0") +
    guides(fill = if (split == "none") "none") + theme_dash +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
}
summary_table <- function(d, group, split) {
  d <- d[!is.na(d$value), ]
  keys <- if (split == "none") d["group"] else d[c("group", "split")]
  out <- aggregate(list(cells = d$value), keys, length)
  out$`% expressing` <- round(100 * aggregate(d$value > 0, keys, mean)$x, 1)
  out$mean <- signif(aggregate(d$value, keys, mean)$x, 3)
  names(out)[1:2] <- c(group, if (split != "none") split else "cells")
  out
}

# A plot with a link to save it at print quality (on screen, plots are drawn at screen resolution)
plot_box <- function(ns, id) tagList(plotOutput(ns(id), height = "auto"), downloadLink(ns(paste0(id, "_png")), "Download PNG (300 dpi)"))
save_plot <- function(plot, name, width, height) {
  downloadHandler(filename = function() paste0(name(), ".png"),
                  content = function(file) ggsave(file, plot(), width = width(), height = height(), dpi = 300, bg = "white"))
}

# UI: sidebar for the shared choices, one tab per modality
modality_tab <- function(name) {
  ns <- NS(name)
  tabPanel(name,
    br(),
    selectizeInput(ns("feature"), "Feature", choices = NULL, width = "400px"),
    uiOutput(ns("embeddings")),   # side by side, or one above the other when split
    fluidRow(column(8, plot_box(ns, "violin")),
             column(4, h4("Per group"), div(style = "overflow-x: auto;", tableOutput(ns("table"))))))
}

ui <- fluidPage(
  titlePanel(paste("Dashboard:", basename(dir)), windowTitle = "Dashboard"),
  sidebarLayout(
    sidebarPanel(width = 2,
      selectInput("embedding", "Embedding", embeddings),
      selectInput("group", "Group by", annotations, selected = default_group),
      selectInput("split", "Split by", c("none", annotations)),
      helpText(sprintf("%d cells", nrow(cells)), br(),
               paste(sprintf("%s: %d features", names(modalities), lengths(lapply(modalities, `[[`, "features"))),
                     collapse = " · "))
    ),
    mainPanel(width = 10, do.call(tabsetPanel, unname(lapply(names(modalities), modality_tab))))
  )
)

# settings(): the sidebar's choices (embedding, group, split) and the cells' coordinates and groups
modality_server <- function(name, settings) {
  moduleServer(name, function(input, output, session) {
    ns <- session$ns
    mod <- modalities[[name]]
    # server = TRUE: the browser only receives the matches, so 100,000s of features stay fast
    updateSelectizeInput(session, "feature", choices = mod$features, selected = mod$features[1], server = TRUE)
    data <- reactive({
      req(input$feature %in% mod$features)
      d <- settings()$cells
      d$value <- feature_values(mod, input$feature)
      d
    })
    plots <- list(
      groups = reactive(with(settings(), plot_groups(cells, embedding, split, group))),
      feature_plot = reactive(with(settings(), plot_feature(data(), embedding, split, input$feature))),
      violin = reactive(with(settings(), plot_violin(data(), group, split, input$feature))))
    # Embedding plots: square panels, so the height follows the plot's width and the number of panel rows
    embedding_height <- function(id) function() {
      n <- panels(settings()$split)
      width <- session$clientData[[paste0("output_", ns(id), "_width")]] %||% 600
      legend <- if (id == "groups" && !short_names(settings()$group)) 24 * nlevels(cells[[settings()$group]]) else 0
      round(80 + (width - 160) / min(n, 4) * ceiling(n / 4) + legend)
    }
    heights <- list(groups = embedding_height("groups"), feature_plot = embedding_height("feature_plot"), violin = function() 380)
    file_name <- function(id) function() paste(name, input$feature, settings()$embedding, settings()$split, id, sep = "_")

    output$embeddings <- renderUI({
      width <- if (settings()$split == "none") 6 else 12
      fluidRow(column(width, plot_box(ns, "groups")), column(width, plot_box(ns, "feature_plot")))
    })
    for (id in names(plots)) local({
      id <- id
      output[[id]] <- renderPlot(plots[[id]](), height = heights[[id]], res = 96)
      output[[paste0(id, "_png")]] <- save_plot(plots[[id]], file_name(id), width = function() 10,
                                                height = function() heights[[id]]() / 80)
    })
    output$table <- renderTable(with(settings(), summary_table(data(), group, split)))
  })
}

server <- function(input, output, session) {
  settings <- reactive(list(embedding = input$embedding, group = input$group, split = input$split,
                            cells = embedding_data(input$embedding, input$group, input$split)))
  for (name in names(modalities)) modality_server(name, settings)
}

shinyApp(ui, server)
