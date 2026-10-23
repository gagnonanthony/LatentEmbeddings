#!/usr/bin/env Rscript

# Harmonize per-subject functional connectivity matrices with FC-CovBat
# (Chen et al., 2021; https://github.com/andy1764/FCHarmony).
#
# Matrices from notebooks/1-QC.ipynb are Fisher z values: the diagonal is 0
# and the off-diagonal Pearson correlations have been passed through arctanh.
# fcCovBat is therefore called with to.corr = FALSE and fisher = FALSE.
# Pass --correlations when the files are Pearson correlations instead; that
# sets fisher = TRUE.
#
# Site is the only batch. Age stays numeric and sex is a factor. Both are
# protected with model.matrix(~ age + sex). CovBat drops the intercept column
# from that matrix. Site is not included in it. FC-CovBat removes batch
# effects in the mean, variance, and leading covariance components, then adds
# age and sex back. It does not harmonize other sites onto a reference site.
#
# Subject ids are the filename stem up to the first underscore, matching
# subjectkey values stored as sub-NDAR... in abcd_demo.csv.
#
# Install:
#   install.packages(c("RcppCNPy"))
#   devtools::install_github("andy1764/CovBat_Harmonization/R")
#   devtools::install_github("andy1764/FCHarmony")
#
# Usage:
#   Rscript scripts/fc_covbat.R \
#     --mats /path/FunctionalConnectivityNumpy \
#     --demo /path/abcd_demo.csv \
#     --out /path/FunctionalConnectivityNumpy_fccovbat

usage <- function() {
  cat(
"Usage: Rscript scripts/fc_covbat.R --mats DIR --demo CSV --out DIR [options]

Required:
  --mats DIR       Directory of per-subject .npy connectivity matrices
  --demo CSV       Demographic table
  --out DIR        Output directory (must differ from --mats)

Options:
  --id-col NAME      Subject id column (default: subjectkey)
  --batch-col NAME   Site column (default: site_id)
  --age-col NAME     Age column (default: age)
  --sex-col NAME     Sex column (default: sex)
  --correlations     Inputs are Pearson correlations (Fisher-transform them).
                     Omit this when matrices are already Fisher z-transformed.
"
  )
}

parse_args <- function(argv) {
  if (length(argv) == 0 || any(argv %in% c("-h", "--help"))) {
    usage()
    quit(status = if (length(argv) == 0) 1L else 0L)
  }

  spec <- list(
    mats = NULL,
    demo = NULL,
    out = NULL,
    id_col = "subjectkey",
    batch_col = "site_id",
    age_col = "age",
    sex_col = "sex",
    correlations = FALSE
  )
  flags <- c(
    "--mats" = "mats",
    "--demo" = "demo",
    "--out" = "out",
    "--id-col" = "id_col",
    "--batch-col" = "batch_col",
    "--age-col" = "age_col",
    "--sex-col" = "sex_col"
  )

  i <- 1L
  while (i <= length(argv)) {
    key <- argv[[i]]
    if (key == "--correlations") {
      spec$correlations <- TRUE
      i <- i + 1L
      next
    }
    name <- unname(flags[key])
    if (is.na(name) || i == length(argv)) {
      stop("Unknown or incomplete argument: ", key, call. = FALSE)
    }
    spec[[name]] <- argv[[i + 1L]]
    i <- i + 2L
  }

  if (is.null(spec$mats) || is.null(spec$demo) || is.null(spec$out)) {
    stop("--mats, --demo, and --out are required.", call. = FALSE)
  }
  spec
}

require_packages <- function() {
  missing <- c(
    if (!requireNamespace("RcppCNPy", quietly = TRUE)) "RcppCNPy",
    if (!requireNamespace("CovBat", quietly = TRUE)) "CovBat",
    if (!requireNamespace("FCHarmony", quietly = TRUE)) "FCHarmony"
  )
  if (length(missing)) {
    stop(
      "Missing R package(s): ", paste(missing, collapse = ", "), "\n",
      "Install with:\n",
      "  install.packages(c(\"RcppCNPy\"))\n",
      "  devtools::install_github(\"andy1764/CovBat_Harmonization/R\")\n",
      "  devtools::install_github(\"andy1764/FCHarmony\")",
      call. = FALSE
    )
  }
}

subject_id <- function(path) {
  sub("_.*$", "", sub("\\.[^.]*$", "", basename(path)))
}

load_square <- function(path, p = NULL) {
  mat <- RcppCNPy::npyLoad(path, dotranspose = TRUE)
  if (!is.matrix(mat) || nrow(mat) != ncol(mat)) {
    stop(basename(path), " is not a square matrix.", call. = FALSE)
  }
  if (!is.null(p) && nrow(mat) != p) {
    stop(
      basename(path), " has shape ", nrow(mat), " x ", ncol(mat),
      "; expected ", p, " x ", p, ".",
      call. = FALSE
    )
  }
  if (!all(is.finite(mat))) {
    stop(basename(path), " contains non-finite values.", call. = FALSE)
  }
  mat
}

args <- parse_args(commandArgs(trailingOnly = TRUE))
require_packages()

if (!dir.exists(args$mats)) {
  stop("--mats does not exist: ", args$mats, call. = FALSE)
}
if (!file.exists(args$demo)) {
  stop("--demo does not exist: ", args$demo, call. = FALSE)
}

mats_dir <- normalizePath(args$mats, mustWork = TRUE)
if (dir.exists(args$out) && normalizePath(args$out, mustWork = TRUE) == mats_dir) {
  stop("--out must differ from --mats.", call. = FALSE)
}
dir.create(args$out, recursive = TRUE, showWarnings = FALSE)
out_dir <- normalizePath(args$out, mustWork = TRUE)
if (out_dir == mats_dir) {
  stop("--out must differ from --mats.", call. = FALSE)
}

demo <- read.csv(args$demo, stringsAsFactors = FALSE)
needed <- c(args$id_col, args$batch_col, args$age_col, args$sex_col)
missing_cols <- setdiff(needed, names(demo))
if (length(missing_cols)) {
  stop(
    "Demographic file is missing column(s): ",
    paste(missing_cols, collapse = ", "),
    call. = FALSE
  )
}

demo[[args$id_col]] <- as.character(demo[[args$id_col]])
demo[[args$age_col]] <- as.numeric(demo[[args$age_col]])
demo[[args$batch_col]] <- trimws(as.character(demo[[args$batch_col]]))
demo[[args$sex_col]] <- as.character(demo[[args$sex_col]])

if (anyDuplicated(demo[[args$id_col]])) {
  stop("Duplicate subject ids in the demographic file.", call. = FALSE)
}

present <- function(x) !is.na(x) & x != ""
complete <- present(demo[[args$id_col]]) &
  !is.na(demo[[args$age_col]]) &
  present(demo[[args$sex_col]]) &
  present(demo[[args$batch_col]])
n_incomplete <- sum(!complete)
demo <- demo[complete, , drop = FALSE]

paths <- list.files(args$mats, pattern = "[.]npy$", full.names = TRUE)
if (!length(paths)) {
  stop("No .npy files in ", mats_dir, call. = FALSE)
}
ids <- vapply(paths, subject_id, character(1))
if (anyDuplicated(ids)) {
  dups <- unique(ids[duplicated(ids)])
  stop(
    "Duplicate subject ids in --mats: ",
    paste(utils::head(dups, 5), collapse = ", "),
    call. = FALSE
  )
}

keep <- sort(intersect(ids, demo[[args$id_col]]))
if (!length(keep)) {
  stop(
    "No subjects are present in both --mats and --demo with age, sex, and site.",
    call. = FALSE
  )
}

n_mats_dropped <- sum(!ids %in% keep)
n_demo_dropped <- sum(!demo[[args$id_col]] %in% keep)
path_by_id <- stats::setNames(paths, ids)
paths <- unname(path_by_id[keep])
demo <- demo[match(keep, demo[[args$id_col]]), , drop = FALSE]
stopifnot(identical(demo[[args$id_col]], keep))

n <- length(paths)
first <- load_square(paths[[1]])
p <- nrow(first)
cat(sprintf(
  paste0(
    "Stacking %d matrices (%d x %d). ",
    "Dropped %d demographic rows missing age, sex, or site, ",
    "%d matrices with no usable demographic row, ",
    "%d demographic rows with no matrix.\n"
  ),
  n, p, p, n_incomplete, n_mats_dropped, n_demo_dropped
))

x <- array(NA_real_, dim = c(p, p, n))
x[, , 1] <- first
if (n > 1) {
  for (i in seq(2, n)) {
    x[, , i] <- load_square(paths[[i]], p)
    if (i %% 1000 == 0) {
      cat(sprintf("  loaded %d / %d\n", i, n))
    }
  }
}
rm(first)

covars <- data.frame(
  age = demo[[args$age_col]],
  sex = factor(demo[[args$sex_col]])
)
mod <- stats::model.matrix(~ age + sex, data = covars)
bat <- factor(demo[[args$batch_col]])

cat(sprintf(
  "Running fcCovBat on %d subjects and %d sites (fisher = %s).\n",
  n, nlevels(bat), if (args$correlations) "TRUE" else "FALSE"
))
fit <- FCHarmony::fcCovBat(
  x,
  bat = bat,
  mod = mod,
  to.corr = FALSE,
  fisher = args$correlations,
  eb = TRUE,
  percent.var = 0.95
)
rm(x)

cat(sprintf("Writing %d matrices to %s\n", n, out_dir))
for (i in seq_len(n)) {
  RcppCNPy::npySave(file.path(out_dir, basename(paths[[i]])), fit$dat.out[, , i])
}

subjects <- data.frame(
  id = demo[[args$id_col]],
  site = as.character(bat),
  age = covars$age,
  sex = as.character(covars$sex),
  filename = basename(paths),
  stringsAsFactors = FALSE
)
write.csv(subjects, file.path(out_dir, "subjects.csv"), row.names = FALSE)
cat("Wrote ", file.path(out_dir, "subjects.csv"), "\n", sep = "")
