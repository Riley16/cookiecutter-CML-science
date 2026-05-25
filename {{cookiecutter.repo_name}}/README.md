# {{cookiecutter.project_name}}

{{cookiecutter.description}}

## Quick start

1. Fill in [config.yaml](config.yaml) with the paths for this project.
2. Install the Python package: `pip install -e .`
3. See [CLAUDE.md](CLAUDE.md) for full development conventions.

## Key conventions

- **Paths** — [config.yaml](config.yaml) is the single source of truth;
  [paths.py](paths.py) and [paths.R](paths.R) are the loaders. Override
  per-machine via a gitignored `config.local.yaml`.
- **Output separation** — three sibling directories: `data/` (raw input,
  read-only), `workspace/` (intermediate, regenerable), `results/` (final
  deliverables — figures in `results/figures/`, standardized JSONs in
  `results/summary/`). Smokescreen runs go to `.smokescreen/` (gitignored).
- **Results tracking** — standardized JSON summaries via
  [results_io.R](results_io.R); one JSON per analysis in `results/summary/`.
- **Final-figure manifest** — [results.yaml](results.yaml) lists paper
  figures; [download_main_figures.py](download_main_figures.py) copies or
  fetches them.
- **Workflow reproducibility** — [snakefile](snakefile) captures the full
  pipeline once individual scripts stabilize.
- **Tests** — in [tests/](tests/). R: `testthat::test_dir("tests")`.
  Python: `pytest tests/`.
