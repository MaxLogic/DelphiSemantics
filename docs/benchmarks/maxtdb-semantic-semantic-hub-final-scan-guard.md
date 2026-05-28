# maxTdb semantic workflow benchmark baseline

Started: `2026-05-28T23:35:05.1301877+02:00`
Completed: `2026-05-28T23:35:11.7292331+02:00`
DAK: `F:\projects\MaxLogic\DelphiAiKit\bin\DelphiAIKit.exe`
Project: `F:\projects\MaxLogic\DelphiAiKit\tests\fixtures\test-projects\maxTdb\src\maxtdb.dpr`
Machine: `PAWEL3`
DelphiSemantics SHA: `4235a6a2c4c96c6d9e3738639436d18f48afdf50`
DAK SHA: `e0b9c58effaeae7a3f6be771c2ae9294800dd85f`
Warm target: `10.000` seconds
Cache directory: `F:\projects\MaxLogic\DelphiSemantics\.dak\benchmarks\maxtdb-semantic\semantic-hub-final-scan-guard\semantic-cache`

| Feature | Benchmark | Cache mode | Runs | Status | Exit | Median seconds | Target seconds | Target status | Min | Max | Result count | Cache hits | Cache misses | Reference fallbacks |
|---|---|---|---:|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|
| with-removal | remove-with-scan-all | cold | 3 | passed | 0 | 0.703 |  |  | 0.699 | 0.717 | 667 |  |  |  |
| with-removal | remove-with-scan-all | warm | 3 | passed | 0 | 0.703 | 10.000 | met | 0.695 | 0.709 | 667 |  |  |  |

Notes: all commands are report-only or dry-run; the maxTdb fixture is not modified.
