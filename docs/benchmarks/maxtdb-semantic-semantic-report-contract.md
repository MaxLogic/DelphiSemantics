# maxTdb semantic workflow benchmark baseline

Started: `2026-06-10T02:09:25.9270563+02:00`
Completed: `2026-06-10T02:10:17.6015990+02:00`
DAK: `F:\projects\MaxLogic\DelphiAiKit\bin\DelphiAIKit.exe`
Project: `F:\projects\MaxLogic\DelphiAiKit\tests\fixtures\test-projects\maxTdb\src\maxtdb.dpr`
Machine: `PAWEL3`
DelphiSemantics SHA: `e0ff77d29eb8b4937616fceaf75c251bbc819549`
DAK SHA: `0b679768b4a892ae66cf04503a266132e18e565c`
Warm target: `10.000` seconds
Cache directory: `F:\projects\MaxLogic\DelphiSemantics\.dak\benchmarks\maxtdb-semantic\semantic-report-contract\semantic-cache`

| Feature | Benchmark | Cache mode | Runs | Status | Exit | Median seconds | Target seconds | Target status | Min | Max | Result count | Cache hits | Cache misses | Reference fallbacks |
|---|---|---|---:|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|
| with-removal | remove-with-plan-all | cold | 3 | passed | 0 | 9.712 |  |  | 9.534 | 9.726 | 215 |  |  |  |
| with-removal | remove-with-scan-all | cold | 3 | passed | 0 | 0.542 |  |  | 0.539 | 0.688 | 667 |  |  |  |

Notes: all commands are report-only or dry-run; the maxTdb fixture is not modified.
