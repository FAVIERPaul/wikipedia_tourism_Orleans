args <- commandArgs(FALSE)
file_arg <- args[grepl("^--file=", args)]
script_path <- if (length(file_arg) > 0) {
  normalizePath(sub("^--file=", "", file_arg[[1]]), winslash = "/", mustWork = TRUE)
} else {
  normalizePath(file.path("analysis", "compile_clean_report.R"), winslash = "/", mustWork = FALSE)
}

project_root <- normalizePath(file.path(dirname(script_path), ".."), winslash = "/", mustWork = TRUE)
setwd(project_root)

pandoc_candidates <- c(
  "C:/Program Files/RStudio/resources/app/bin/quarto/bin/tools",
  "C:/Program Files/RStudio/bin/pandoc",
  file.path(Sys.getenv("LOCALAPPDATA"), "Python/pythoncore-3.14-64/Lib/site-packages/pypandoc/files")
)
pandoc_dir <- pandoc_candidates[file.exists(file.path(pandoc_candidates, "pandoc.exe"))][1]
if (!is.na(pandoc_dir) && nzchar(pandoc_dir) && !nzchar(Sys.getenv("RSTUDIO_PANDOC"))) {
  Sys.setenv(RSTUDIO_PANDOC = pandoc_dir)
}

if (!requireNamespace("rmarkdown", quietly = TRUE)) {
  stop("Package 'rmarkdown' is required to compile the HTML report.", call. = FALSE)
}

dir.create(file.path(project_root, "outputs", "results"), showWarnings = FALSE, recursive = TRUE)
dir.create(file.path(project_root, "outputs", "figures"), showWarnings = FALSE, recursive = TRUE)
dir.create(file.path(project_root, "outputs", "html"), showWarnings = FALSE, recursive = TRUE)

source(file.path("analysis", "run_loglog_only_analysis.R"))
source(file.path("analysis", "export_loglog_figures.R"))

rmarkdown::render(
  input = file.path("analysis", "loglog_clean_report.Rmd"),
  output_file = "loglog_clean_report.html",
  output_dir = file.path("outputs", "html"),
  knit_root_dir = project_root,
  quiet = FALSE
)

cat("Compiled clean HTML report to outputs/html/loglog_clean_report.html\n")
