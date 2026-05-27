# maxTdb semantic workflow benchmark baseline

Started: `2026-05-27T18:57:12.0572346+02:00`
Completed: `2026-05-27T18:57:18.5982126+02:00`
DAK: `F:\projects\MaxLogic\DelphiAiKit\bin\DelphiAIKit.exe`
Project: `F:\projects\MaxLogic\DelphiAiKit\tests\fixtures\test-projects\maxTdb\src\maxtdb.dpr`
Machine: `PAWEL3`
DelphiSemantics SHA: `36e05a927c21846fcec519d101ae869a24849580`
DAK SHA: `3e3c90b46ee7e3fd3e4a6902d6980d69537d2d28`
Warm target: `10.000` seconds
Cache directory: `F:\projects\MaxLogic\DelphiSemantics\.dak\benchmarks\maxtdb-semantic\semantic-hub-scan-guard\semantic-cache`

| Feature | Benchmark | Cache mode | Runs | Status | Exit | Median seconds | Target seconds | Target status | Min | Max | Result count | Cache hits | Cache misses | Reference fallbacks |
|---|---|---|---:|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|
| with-removal | remove-with-scan-all | cold | 3 | passed | 0 | 0.709 |  |  | 0.705 | 0.725 | 667 |  |  |  |
| with-removal | remove-with-scan-all | warm | 3 | passed | 0 | 0.713 | 10.000 | met | 0.708 | 0.716 | 667 |  |  |  |

Notes: all commands are report-only or dry-run; the maxTdb fixture is not modified.
