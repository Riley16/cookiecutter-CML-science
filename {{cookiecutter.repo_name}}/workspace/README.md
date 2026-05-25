# Workspace

Intermediate analysis output: cached model fits, per-subject RDS files,
intermediate tables, and anything else regenerable by the pipeline.

Safe to delete in full — the pipeline rebuilds it from `../data/`.

This folder is gitignored by default (see `../.gitignore`). Final
deliverables (figures, standardized result JSONs) belong in
`../results/`, not here.
