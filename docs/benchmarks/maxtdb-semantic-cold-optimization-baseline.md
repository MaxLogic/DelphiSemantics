# maxTdb semantic workflow benchmark baseline

Started: `2026-05-25T17:30:00.3021306+02:00`
Completed: `2026-05-25T17:41:41.2589363+02:00`
DAK: `F:\projects\MaxLogic\DelphiAiKit\bin\DelphiAIKit.exe`
Project: `F:\projects\MaxLogic\DelphiAiKit\tests\fixtures\test-projects\maxTdb\src\maxtdb.dpr`
Machine: `PAWEL3`
DelphiSemantics SHA: `22f4da87aec80524d76cd1b11488999a499d27b2`
DAK SHA: `60c82f0b54a76d712f0e9183b1dd06290d98ba11`
Warm target: `10.000` seconds
Cache directory: `F:\projects\MaxLogic\DelphiSemantics\.dak\benchmarks\maxtdb-semantic\cold-optimization-baseline\semantic-cache`

| Feature | Benchmark | Cache mode | Runs | Status | Exit | Median seconds | Target seconds | Target status | Min | Max | Result count | Cache hits | Cache misses | Reference fallbacks |
|---|---|---|---:|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|
| dead-code-detection | dead-code-legacy-static | cold | 3 | passed | 0 | 76.300 |  |  | 74.254 | 77.259 | 4078 | 0 | 57 | 60963 |
| dead-code-detection | dead-code-legacy-static | warm | 3 | passed | 0 | 6.440 | 10.000 | met | 6.108 | 6.518 | 4078 | 56 | 1 | 0 |
| find-usages | find-usages-allfiles | cold | 3 | passed | 0 | 74.744 |  |  | 71.523 | 75.234 | 4 | 0 | 57 | 60963 |
| find-usages | find-usages-allfiles | warm | 3 | passed | 0 | 3.415 | 10.000 | met | 3.207 | 3.569 | 4 | 56 | 1 | 0 |
| rename | rename-dry-run-allfiles | cold | 3 | passed | 0 | 70.012 |  |  | 66.708 | 71.593 | 4 | 0 | 57 | 60963 |
| rename | rename-dry-run-allfiles | warm | 3 | passed | 0 | 3.082 | 10.000 | met | 3.071 | 3.184 | 4 | 56 | 1 | 0 |

Notes: all commands are report-only or dry-run; the maxTdb fixture is not modified.
