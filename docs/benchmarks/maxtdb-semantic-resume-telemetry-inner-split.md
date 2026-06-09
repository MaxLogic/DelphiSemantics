# maxTdb semantic workflow benchmark baseline

Started: `2026-06-09T12:02:47.5638885+02:00`
Completed: `2026-06-09T12:04:35.7183323+02:00`
DAK: `F:\projects\MaxLogic\DelphiAiKit\bin\DelphiAIKit.exe`
Project: `F:\projects\MaxLogic\DelphiAiKit\tests\fixtures\test-projects\maxTdb\src\maxtdb.dpr`
Machine: `PAWEL3`
DelphiSemantics SHA: `c199566fd111fb5add3dc3b1ee10d57381aeaca1`
DAK SHA: `0406acd849c36be999afb335160e55ed35cccbff`
Warm target: `10.000` seconds
Cache directory: `F:\projects\MaxLogic\DelphiSemantics\.dak\benchmarks\maxtdb-semantic\resume-telemetry-inner-split\semantic-cache`

| Feature | Benchmark | Cache mode | Runs | Status | Exit | Median seconds | Target seconds | Target status | Min | Max | Result count | Cache hits | Cache misses | Reference fallbacks |
|---|---|---|---:|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|
| with-removal | remove-with-plan-all | cold | 3 | passed | 0 | 28.138 |  |  | 27.277 | 29.232 | 215 |  |  |  |
| with-removal | remove-with-scan-all | cold | 3 | passed | 0 | 0.513 |  |  | 0.509 | 0.548 | 667 |  |  |  |

Notes: all commands are report-only or dry-run; the maxTdb fixture is not modified.
