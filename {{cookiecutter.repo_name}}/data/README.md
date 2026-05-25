# Data

Raw input data for the project. **Read-only** from analysis scripts —
nothing in this directory should be created or modified by the pipeline.

Anything regenerable (cached fits, intermediate tables, per-subject RDS
files) belongs in `../workspace/`. Final deliverables (figures, result
JSONs) belong in `../results/`.

By default this folder is not version-controlled; add it to `.gitignore`
explicitly if your raw data is large or sensitive.
