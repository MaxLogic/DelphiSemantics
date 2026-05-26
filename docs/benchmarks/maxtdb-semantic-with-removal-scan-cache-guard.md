# maxTdb semantic workflow benchmark baseline

Started: `2026-05-26T21:51:54.7208382+02:00`
Completed: `2026-05-26T21:52:01.3060390+02:00`
DAK: `F:\projects\MaxLogic\DelphiAiKit\bin\DelphiAIKit.exe`
Project: `F:\projects\MaxLogic\DelphiAiKit\tests\fixtures\test-projects\maxTdb\src\maxtdb.dpr`
Machine: `PAWEL3`
DelphiSemantics SHA: `65532b4905ca0c94d89ce179b98b5022d81d87bc`
DAK SHA: `d41c95867f6ba7bce5e5418bd1a169af257de47c`
Warm target: `10.000` seconds
Cache directory: `F:\projects\MaxLogic\DelphiSemantics\.dak\benchmarks\maxtdb-semantic\with-removal-scan-cache-guard\semantic-cache`

| Feature | Benchmark | Cache mode | Runs | Status | Exit | Median seconds | Target seconds | Target status | Min | Max | Result count | Cache hits | Cache misses | Reference fallbacks |
|---|---|---|---:|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|
| with-removal | remove-with-scan-all | cold | 3 | passed | 0 | 0.717 |  |  | 0.712 | 0.741 | 667 |  |  |  |
| with-removal | remove-with-scan-all | warm | 3 | passed | 0 | 0.705 | 10.000 | met | 0.704 | 0.708 | 667 |  |  |  |

Notes: all commands are report-only or dry-run; the maxTdb fixture is not modified.
