# Project path registry (R) — mirror of paths.py.
#
# Source from R scripts run from the project root:
#   source("paths.R")
#   readRDS(file.path(DATA_DIR, "analysis.rds"))
#
# Single source of truth is config.yaml. An optional gitignored
# config.local.yaml is merged on top for machine-local overrides.

suppressPackageStartupMessages(library(yaml))

.load_config <- function() {
    cfg <- yaml::read_yaml("config.yaml")
    if (file.exists("config.local.yaml")) {
        cfg <- modifyList(cfg, yaml::read_yaml("config.local.yaml"))
    }
    cfg
}

config      <- .load_config()
PROJECT_DIR <- normalizePath(".")

# Primary directories — add more aliases here as config.yaml grows.
DATA_DIR      <- file.path(PROJECT_DIR, config$data_dir)
WORKSPACE_DIR <- file.path(PROJECT_DIR, config$workspace_dir)
RESULTS_DIR   <- file.path(PROJECT_DIR, config$results_dir)
FIGURE_DIR    <- file.path(PROJECT_DIR, config$figure_dir)
TESTS_DIR     <- file.path(PROJECT_DIR, config$tests_dir)
