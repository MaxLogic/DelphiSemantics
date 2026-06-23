# proprietary fixture semantic workflow benchmark baseline

Started: `2026-05-27T07:59:43.3424370+02:00`
Completed: `2026-05-27T07:59:49.7179778+02:00`
DAK: `F:\projects\MaxLogic\DelphiAiKit\bin\DelphiAIKit.exe`
Project: `F:\projects\MaxLogic\DelphiAiKit\tests\fixtures\test-projects\<proprietary-fixture>\src\<fixture>.dpr`
Machine: `PAWEL3`
DelphiSemantics SHA: `0112f2c28c52cac95d38005dea7ae8303b3c5aca`
DAK SHA: `3e3c90b46ee7e3fd3e4a6902d6980d69537d2d28`
Warm target: `10.000` seconds
Cache directory: `F:\projects\MaxLogic\DelphiSemantics\.dak\benchmarks\proprietary-fixture-semantic\with-removal-external-scan-guard\semantic-cache`

| Feature | Benchmark | Cache mode | Runs | Status | Exit | Median seconds | Target seconds | Target status | Min | Max | Result count | Cache hits | Cache misses | Reference fallbacks |
|---|---|---|---:|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|
| with-removal | remove-with-scan-all | cold | 3 | passed | 0 | 0.711 |  |  | 0.703 | 0.727 | 667 |  |  |  |
| with-removal | remove-with-scan-all | warm | 3 | passed | 0 | 0.704 | 10.000 | met | 0.704 | 0.717 | 667 |  |  |  |

Notes: all commands are report-only or dry-run; the proprietary fixture is not modified.
