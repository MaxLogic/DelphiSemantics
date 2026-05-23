# maxTdb semantic workflow benchmark baseline

Started: `2026-05-23T15:31:55.7309514+02:00`
Completed: `2026-05-23T16:14:34.3566151+02:00`
DAK: `F:\projects\MaxLogic\DelphiAiKit\bin\DelphiAIKit.exe`
Project: `F:\projects\MaxLogic\DelphiAiKit\tests\fixtures\test-projects\maxTdb\src\maxtdb.dpr`
Machine: `PAWEL3`
DelphiSemantics SHA: `40d079421bdeb4974e4bf430b107839bf36a1fc4`
DAK SHA: `b69e2acef83630c31c7310eecfd8ba202053f3d2`
Cache directory: `F:\projects\MaxLogic\DelphiSemantics\.dak\benchmarks\maxtdb-semantic\optimization-harness\semantic-cache`

| Feature | Benchmark | Cache mode | Runs | Status | Exit | Median seconds | Min | Max | Result count |
|---|---|---|---:|---|---:|---:|---:|---:|---:|
| rename | rename-dry-run-allfiles | cold | 3 | passed | 0 | 436.401 | 435.207 | 452.897 | 4 |
| rename | rename-dry-run-allfiles | warm | 3 | passed | 0 | 409.831 | 406.037 | 418.117 | 4 |

Notes: all commands are report-only or dry-run; the maxTdb fixture is not modified.
