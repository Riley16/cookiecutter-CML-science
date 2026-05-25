"""Project path registry (Python).

Single source of truth for project paths is config.yaml. This module reads
it and exposes each path as an uppercase module-level Path under PROJECT_DIR.
An optional gitignored config.local.yaml is merged on top for machine-local
overrides.

Usage:
    from paths import PROJECT_DIR, DATA_DIR, WORKSPACE_DIR, RESULTS_DIR, FIGURE_DIR
"""
from pathlib import Path
import yaml

PROJECT_DIR = Path(__file__).resolve().parent


def _load_config():
    with open(PROJECT_DIR / "config.yaml") as f:
        cfg = yaml.safe_load(f) or {}
    local = PROJECT_DIR / "config.local.yaml"
    if local.exists():
        with open(local) as f:
            cfg.update(yaml.safe_load(f) or {})
    return cfg


config = _load_config()

# Primary directories — add more aliases here as config.yaml grows.
DATA_DIR           = PROJECT_DIR / config["data_dir"]
WORKSPACE_DIR      = PROJECT_DIR / config["workspace_dir"]
RESULTS_DIR        = PROJECT_DIR / config["results_dir"]
FIGURE_DIR         = PROJECT_DIR / config["figure_dir"]
RESULT_SUMMARY_DIR = PROJECT_DIR / config["result_summary_dir"]
TESTS_DIR          = PROJECT_DIR / config["tests_dir"]


# Smokescreen convention: when a script is invoked with --smokescreen,
# isolate its outputs into a .smokescreen/ subfolder of each OUTPUT
# directory so they never clobber full-run output. Wrap each output dir
# at the call site:
#
#     from paths import WORKSPACE_DIR, smokescreen
#     out_dir = smokescreen(WORKSPACE_DIR) if args.smokescreen else WORKSPACE_DIR
#
# Apply only to output dirs (workspace, results, figures, result_summary).
# Never wrap read-only inputs (DATA_DIR) or TESTS_DIR.
SMOKESCREEN_SUBDIR = ".smokescreen"


def smokescreen(output_dir: Path) -> Path:
    """Return the smokescreen-isolated variant of an output directory."""
    return Path(output_dir) / SMOKESCREEN_SUBDIR
