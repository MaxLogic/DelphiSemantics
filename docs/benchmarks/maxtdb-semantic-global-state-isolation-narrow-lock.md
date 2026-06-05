# maxTdb semantic workflow benchmark baseline

Started: `2026-06-05T13:02:03.1725045+02:00`
Completed: `2026-06-05T13:02:48.6220922+02:00`
DAK: `F:\projects\MaxLogic\DelphiAiKit\bin\DelphiAIKit.exe`
Project: `F:\projects\MaxLogic\DelphiAiKit\tests\fixtures\test-projects\maxTdb\src\maxtdb.dpr`
Machine: `PAWEL3`
DelphiSemantics SHA: `9e28ad076a2fd8bfb430cf33e3f6f39e41e5bc07`
DAK SHA: `80839b3a0f0562ac6f80a88943e23cdb264e881b`
Warm target: `10.000` seconds
Cache directory: `F:\projects\MaxLogic\DelphiSemantics\.dak\benchmarks\maxtdb-semantic\global-state-isolation-narrow-lock\semantic-cache`

| Feature | Benchmark | Cache mode | Runs | Status | Exit | Median seconds | Target seconds | Target status | Min | Max | Result count | Cache hits | Cache misses | Reference fallbacks |
|---|---|---|---:|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|
| with-removal | remove-with-plan-all | cold | 1 | passed | 0 | 36.765 |  |  | 36.765 | 36.765 | 215 |  |  |  |
| with-removal | remove-with-scan-all | cold | 1 | passed | 0 | 0.571 |  |  | 0.571 | 0.571 | 667 |  |  |  |

Notes: all commands are report-only or dry-run; the maxTdb fixture is not modified.
