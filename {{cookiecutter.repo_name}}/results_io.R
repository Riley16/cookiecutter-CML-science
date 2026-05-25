# results_io.R
# Scientific results tracking library
# Standardized read/write for statistical results in JSON format.
#
# Usage:
#   source("results_io.R")
#   init_result_file("results/summary/decoder_summary.json",
#                    description = "Decoder accuracy vs chance",
#                    conda_env = "r4.3_rhino2b")
#   write_result(c("subject_classifier", "ttest_vs_chance"),
#                make_ttest_result(statistic = 3.21, df = 42, p_value = 0.002,
#                                  alternative = "two.sided", method = "one_sample",
#                                  effect_size = 0.49, effect_size_type = "cohens_d"),
#                file = "results/summary/decoder_summary.json")

library(jsonlite)

# ============================================================================
# Schema definitions
# ============================================================================

RESULT_SCHEMAS <- list(
  ttest = list(
    required = c("statistic", "df", "p_value", "alternative", "method"),
    optional = c("ci_lower", "ci_upper", "ci_level",
                 "effect_size", "effect_size_type"),
    valid_values = list(
      alternative = c("two.sided", "less", "greater"),
      method = c("one_sample", "paired", "independent")
    )
  ),
  anova = list(
    required = c("statistic", "statistic_type", "df_num", "df_den", "p_value"),
    optional = c("effect_size", "effect_size_type"),
    valid_values = list(
      statistic_type = c("F", "chi_sq")
    )
  ),
  correlation = list(
    required = c("statistic", "p_value", "method"),
    optional = c("df", "ci_lower", "ci_upper", "ci_level"),
    valid_values = list(
      method = c("pearson", "spearman", "kendall")
    )
  ),
  regression_coef = list(
    required = c("estimate", "se", "statistic", "statistic_type", "p_value"),
    optional = c("ci_lower", "ci_upper", "ci_level"),
    valid_values = list(
      statistic_type = c("t", "z")
    )
  ),
  descriptive = list(
    required = c("mean", "sd", "n"),
    optional = c("median", "q1", "q3", "iqr", "ci_lower", "ci_upper", "ci_level"),
    valid_values = list()
  ),
  count_proportion = list(
    required = c("count", "total", "proportion"),
    optional = c("ci_lower", "ci_upper", "ci_level"),
    valid_values = list()
  )
)

# ============================================================================
# Validation
# ============================================================================

validate_result <- function(result) {
  type <- result[["_type"]]
  if (is.null(type)) stop("Result must have a '_type' field")
  schema <- RESULT_SCHEMAS[[type]]
  if (is.null(schema)) {
    stop(sprintf("Unknown result type: '%s'. Valid types: %s",
                 type, paste(names(RESULT_SCHEMAS), collapse = ", ")))
  }
  missing <- setdiff(schema$required, names(result))
  if (length(missing) > 0) {
    stop(sprintf("Missing required fields for '%s': %s",
                 type, paste(missing, collapse = ", ")))
  }
  all_known <- c("_type", schema$required, schema$optional)
  unknown <- setdiff(names(result), all_known)
  if (length(unknown) > 0) {
    stop(sprintf("Unknown fields for '%s': %s",
                 type, paste(unknown, collapse = ", ")))
  }
  for (field in names(schema$valid_values)) {
    val <- result[[field]]
    if (!is.null(val) && !(val %in% schema$valid_values[[field]])) {
      stop(sprintf("Invalid %s: '%s'. Valid: %s",
                   field, val,
                   paste(schema$valid_values[[field]], collapse = ", ")))
    }
  }
  invisible(TRUE)
}

# ============================================================================
# Result constructors (raw values only)
# ============================================================================

make_ttest_result <- function(statistic, df, p_value, alternative, method,
                              ci_lower = NULL, ci_upper = NULL, ci_level = NULL,
                              effect_size = NULL, effect_size_type = NULL) {
  result <- compact_list(
    `_type` = "ttest", statistic = statistic, df = df, p_value = p_value,
    alternative = alternative, method = method,
    ci_lower = ci_lower, ci_upper = ci_upper, ci_level = ci_level,
    effect_size = effect_size, effect_size_type = effect_size_type
  )
  validate_result(result)
  result
}

make_anova_result <- function(statistic, statistic_type, df_num, df_den, p_value,
                              effect_size = NULL, effect_size_type = NULL) {
  result <- compact_list(
    `_type` = "anova", statistic = statistic, statistic_type = statistic_type,
    df_num = df_num, df_den = df_den, p_value = p_value,
    effect_size = effect_size, effect_size_type = effect_size_type
  )
  validate_result(result)
  result
}

make_correlation_result <- function(statistic, p_value, method,
                                    df = NULL, ci_lower = NULL, ci_upper = NULL,
                                    ci_level = NULL) {
  result <- compact_list(
    `_type` = "correlation", statistic = statistic, p_value = p_value,
    method = method, df = df,
    ci_lower = ci_lower, ci_upper = ci_upper, ci_level = ci_level
  )
  validate_result(result)
  result
}

make_regression_coef_result <- function(estimate, se, statistic, statistic_type,
                                        p_value, ci_lower = NULL, ci_upper = NULL,
                                        ci_level = NULL) {
  result <- compact_list(
    `_type` = "regression_coef", estimate = estimate, se = se,
    statistic = statistic, statistic_type = statistic_type, p_value = p_value,
    ci_lower = ci_lower, ci_upper = ci_upper, ci_level = ci_level
  )
  validate_result(result)
  result
}

make_descriptive_result <- function(mean, sd, n,
                                    median = NULL, q1 = NULL, q3 = NULL,
                                    iqr = NULL,
                                    ci_lower = NULL, ci_upper = NULL,
                                    ci_level = NULL) {
  result <- compact_list(
    `_type` = "descriptive", mean = mean, sd = sd, n = n,
    median = median, q1 = q1, q3 = q3, iqr = iqr,
    ci_lower = ci_lower, ci_upper = ci_upper, ci_level = ci_level
  )
  validate_result(result)
  result
}

make_count_proportion_result <- function(count, total, proportion,
                                         ci_lower = NULL, ci_upper = NULL,
                                         ci_level = NULL) {
  result <- compact_list(
    `_type` = "count_proportion", count = count, total = total,
    proportion = proportion,
    ci_lower = ci_lower, ci_upper = ci_upper, ci_level = ci_level
  )
  validate_result(result)
  result
}

# ============================================================================
# File I/O
# ============================================================================

#' Initialize a result file with metadata.
#' Overwrites any existing file at the path.
init_result_file <- function(file, description, conda_env,
                             conda_env_lockfile = NULL) {
  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  git_commit <- tryCatch(
    trimws(system("git rev-parse --short HEAD", intern = TRUE)),
    error = function(e) NA_character_,
    warning = function(w) NA_character_
  )
  meta <- compact_list(
    timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    git_commit = git_commit,
    conda_env = conda_env,
    conda_env_lockfile = conda_env_lockfile,
    description = description
  )
  data <- list(`_metadata` = meta)
  write_json_atomic(data, file)
  invisible(file)
}

#' Write a result at a nested key path.
#' key_path: character vector, e.g. c("subject_classifier", "ttest_vs_chance")
write_result <- function(key_path, result, file) {
  stopifnot(is.character(key_path), length(key_path) >= 1)
  validate_result(result)
  data <- read_json_safe(file)
  data <- set_nested(data, key_path, result)
  write_json_atomic(data, file)
  invisible(result)
}

#' Read a result at a nested key path. Returns NULL if not found.
read_result <- function(key_path, file) {
  data <- read_json_safe(file)
  get_nested(data, key_path)
}

#' Read all results from a file (the full parsed JSON).
read_result_file <- function(file) {
  read_json_safe(file)
}

#' Combine all result files listed in config.yaml into a single JSON.
#' Returns the combined list invisibly.
combine_results <- function(config_path = "config.yaml",
                            output_filename = "all_results.json") {
  config <- yaml::read_yaml(config_path)
  summary_dir <- config$result_summary_dir
  if (is.null(summary_dir)) stop("config must contain 'result_summary_dir'")
  result_files <- config$result_files
  if (is.null(result_files)) stop("config must contain 'result_files'")
  combined <- list()
  for (key in names(result_files)) {
    fpath <- file.path(summary_dir, result_files[[key]])
    if (file.exists(fpath)) {
      combined[[key]] <- read_json_safe(fpath)
    } else {
      warning(sprintf("Result file not found: %s", fpath))
    }
  }
  outpath <- file.path(summary_dir, output_filename)
  write_json_atomic(combined, outpath)
  message(sprintf("Combined %d result files -> %s", length(combined), outpath))
  invisible(combined)
}

# ============================================================================
# Internal helpers
# ============================================================================

#' Drop NULL entries from a named list (used by constructors).
compact_list <- function(...) {
  lst <- list(...)
  lst[!vapply(lst, is.null, logical(1))]
}

#' Navigate into a nested list and return the value, or NULL.
get_nested <- function(lst, key_path) {
  for (k in key_path) {
    lst <- lst[[k]]
    if (is.null(lst)) return(NULL)
  }
  lst
}

#' Set a value at a nested key path, creating intermediate lists as needed.
set_nested <- function(lst, key_path, value) {
  if (length(key_path) == 1) {
    lst[[key_path]] <- value
    return(lst)
  }
  child <- lst[[key_path[1]]]
  if (is.null(child)) child <- list()
  lst[[key_path[1]]] <- set_nested(child, key_path[-1], value)
  lst
}

#' Read JSON, returning an empty list if the file does not exist.
read_json_safe <- function(file) {
  if (!file.exists(file)) return(list())
  fromJSON(file, simplifyVector = FALSE)
}

#' Atomic write: write to temp file then rename (safe on POSIX).
write_json_atomic <- function(data, file) {
  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  tmp <- tempfile(tmpdir = dirname(file), fileext = ".json.tmp")
  on.exit(unlink(tmp), add = TRUE)
  writeLines(toJSON(data, auto_unbox = TRUE, pretty = TRUE, digits = NA), tmp)
  file.rename(tmp, file)
}
