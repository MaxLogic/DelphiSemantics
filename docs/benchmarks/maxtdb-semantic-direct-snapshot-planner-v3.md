# maxTdb semantic workflow benchmark baseline

Started: `2026-06-11T10:00:05.0536391+02:00`
Completed: `2026-06-11T10:01:00.6703525+02:00`
DAK: `F:\projects\MaxLogic\DelphiAiKit\bin\DelphiAIKit.exe`
Project: `F:\projects\MaxLogic\DelphiAiKit\tests\fixtures\test-projects\maxTdb\src\maxtdb.dpr`
Machine: `PAWEL3`
DelphiSemantics SHA: `99b45ac8e25b8922898cea5383da5a43658126de`
DAK SHA: `311a82bb2af1e0741d2dba8c4d296be3fe75ac53`
Warm target: `10.000` seconds
Cache directory: `F:\projects\MaxLogic\DelphiSemantics\.dak\benchmarks\maxtdb-semantic\direct-snapshot-planner-v3\semantic-cache`

| Feature | Benchmark | Cache mode | Runs | Status | Exit | Median seconds | Target seconds | Target status | Min | Max | Result count | Cache hits | Cache misses | Reference fallbacks |
|---|---|---|---:|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|
| with-removal | remove-with-plan-all | cold | 3 | passed | 0 | 10.176 |  |  | 10.050 | 10.188 | 215 |  |  |  |
| with-removal | remove-with-plan-all | warm | 3 | passed | 0 | 6.415 | 10.000 | met | 6.336 | 6.544 | 215 |  |  |  |
| with-removal | remove-with-scan-all | cold | 3 | passed | 0 | 0.576 |  |  | 0.563 | 0.601 | 667 |  |  |  |
| with-removal | remove-with-scan-all | warm | 3 | passed | 0 | 0.547 | 10.000 | met | 0.545 | 0.554 | 667 |  |  |  |

Notes: all commands are report-only or dry-run; the maxTdb fixture is not modified.
