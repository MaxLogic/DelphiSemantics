# maxTdb semantic workflow benchmark baseline

Started: `2026-06-11T05:44:37.2077642+02:00`
Completed: `2026-06-11T05:45:29.5962088+02:00`
DAK: `F:\projects\MaxLogic\DelphiAiKit\bin\DelphiAIKit.exe`
Project: `F:\projects\MaxLogic\DelphiAiKit\tests\fixtures\test-projects\maxTdb\src\maxtdb.dpr`
Machine: `PAWEL3`
DelphiSemantics SHA: `d6ae68c9a97424daf2ecd1c42d85e693ebd4de40`
DAK SHA: `70f3fd4f33a579d4cf3cba608bc4cbd9c8bd71ed`
Warm target: `10.000` seconds
Cache directory: `F:\projects\MaxLogic\DelphiSemantics\.dak\benchmarks\maxtdb-semantic\retire-project-facts-json\semantic-cache`

| Feature | Benchmark | Cache mode | Runs | Status | Exit | Median seconds | Target seconds | Target status | Min | Max | Result count | Cache hits | Cache misses | Reference fallbacks |
|---|---|---|---:|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|
| with-removal | remove-with-plan-all | cold | 3 | passed | 0 | 9.224 |  |  | 9.183 | 9.574 | 215 |  |  |  |
| with-removal | remove-with-plan-all | warm | 3 | passed | 0 | 5.972 | 10.000 | met | 5.910 | 6.020 | 215 |  |  |  |
| with-removal | remove-with-scan-all | cold | 3 | passed | 0 | 0.640 |  |  | 0.637 | 0.704 | 667 |  |  |  |
| with-removal | remove-with-scan-all | warm | 3 | passed | 0 | 0.637 | 10.000 | met | 0.613 | 0.671 | 667 |  |  |  |

Notes: all commands are report-only or dry-run; the maxTdb fixture is not modified.
