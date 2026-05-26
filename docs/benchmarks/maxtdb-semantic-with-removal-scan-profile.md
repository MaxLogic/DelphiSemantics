# maxTdb semantic workflow benchmark baseline

Started: `2026-05-26T19:23:44.1010068+02:00`
Completed: `2026-05-26T19:23:50.2424135+02:00`
DAK: `F:\projects\MaxLogic\DelphiAiKit\bin\DelphiAIKit.exe`
Project: `F:\projects\MaxLogic\DelphiAiKit\tests\fixtures\test-projects\maxTdb\src\maxtdb.dpr`
Machine: `PAWEL3`
DelphiSemantics SHA: `9a32d5da49f793da1beec2e3fd7c8ee779425376`
DAK SHA: `50e75c2b4ff26870c23247fbc16bc1c99fca0436`
Warm target: `10.000` seconds
Cache directory: `F:\projects\MaxLogic\DelphiSemantics\.dak\benchmarks\maxtdb-semantic\with-removal-scan-profile\semantic-cache`

| Feature | Benchmark | Cache mode | Runs | Status | Exit | Median seconds | Target seconds | Target status | Min | Max | Result count | Cache hits | Cache misses | Reference fallbacks |
|---|---|---|---:|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|
| with-removal | remove-with-scan-all | cold | 3 | passed | 0 | 0.710 |  |  | 0.705 | 0.729 | 667 |  |  |  |
| with-removal | remove-with-scan-all | warm | 3 | passed | 0 | 0.702 | 10.000 | met | 0.702 | 0.715 | 667 |  |  |  |

Notes: all commands are report-only or dry-run; the maxTdb fixture is not modified.
