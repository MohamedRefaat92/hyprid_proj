# output/

Everything the project **generates**. Git-ignored (except this README): it can always be rebuilt
from the code and the inputs, so deleting what's in here is safe.

```text
output/
├── _targets/                                  targets store (set in _targets.yaml)
└── reports/
    ├── latest/                                latest render of each report (managed by targets)
    └── archive/<date>/<report>_<date_time>/   frozen snapshots: zip and share a whole folder
```

Never edit files here by hand: change the code or the inputs, then `scripts/sh/run-pipeline.sh`.
