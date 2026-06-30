# 00_setup.R ---------------------------------------------------------------
# Project setup: load core libraries, set seed, define paths, register the
# parallel backend. Source this at the top of every other R/ script.
# Keep this file small and side-effect-light.

# Core modelling stack -------------------------------------------------------
library(tidyverse)    # dplyr, ggplot2, readr, purrr, etc.
library(tidymodels)   # recipes, parsnip, workflows, tune, yardstick, rsample
library(here)         # project-root-relative paths (no setwd())

# Resolve tidymodels function-name conflicts in favour of tidymodels.
tidymodels_prefer()

# Reproducibility ------------------------------------------------------------
set.seed(42)

# Paths (all relative to the project root via here::here()) ------------------
path_data_raw <- here::here("data", "raw")
path_models   <- here::here("models")
path_figures  <- here::here("figures")

# Ensure output directories exist (data/raw is owned by the download agent).
for (d in c(path_models, path_figures)) {
  if (!dir.exists(d)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

# Parallel backend -----------------------------------------------------------
# Register doParallel so tune::tune_grid()/fit_resamples() can run folds in
# parallel. Leave one core free for the OS / RStudio.
library(doParallel)
n_cores <- max(1L, parallel::detectCores() - 1L)
cl <- makePSOCKcluster(n_cores)
registerDoParallel(cl)
# NOTE: call stopCluster(cl) at the end of a long modelling run if desired.

message("Setup complete: seed=42, parallel workers=", n_cores)
