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
DATA_DIR           <- file.path(PROJECT_DIR, config$data_dir)
WORKSPACE_DIR      <- file.path(PROJECT_DIR, config$workspace_dir)
RESULTS_DIR        <- file.path(PROJECT_DIR, config$results_dir)
FIGURE_DIR         <- file.path(PROJECT_DIR, config$figure_dir)
RESULT_SUMMARY_DIR <- file.path(PROJECT_DIR, config$result_summary_dir)
TESTS_DIR          <- file.path(PROJECT_DIR, config$tests_dir)


# Smokescreen convention: when a script is invoked with --smokescreen,
# isolate its outputs into a .smokescreen/ subfolder of each OUTPUT
# directory so they never clobber full-run output. Wrap each output dir
# at the call site:
#
#     source("paths.R")
#     out_dir <- if (smokescreen_mode) smokescreen(WORKSPACE_DIR) else WORKSPACE_DIR
#
# Apply only to output dirs (workspace, results, figures, result_summary).
# Never wrap read-only inputs (DATA_DIR) or TESTS_DIR.
SMOKESCREEN_SUBDIR <- ".smokescreen"

smokescreen <- function(output_dir) {
    file.path(output_dir, SMOKESCREEN_SUBDIR)
}
