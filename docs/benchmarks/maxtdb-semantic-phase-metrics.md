# maxTdb semantic workflow benchmark baseline

Started: `2026-05-25T18:35:53.9253498+02:00`
Completed: `2026-05-25T18:37:05.1026098+02:00`
DAK: `F:\projects\MaxLogic\DelphiAiKit\bin\DelphiAIKit.exe`
Project: `F:\projects\MaxLogic\DelphiAiKit\tests\fixtures\test-projects\maxTdb\src\maxtdb.dpr`
Machine: `PAWEL3`
DelphiSemantics SHA: `3419a16c327096e2580ae6df8f4adaa7a2acc6bc`
DAK SHA: `60c82f0b54a76d712f0e9183b1dd06290d98ba11`
Warm target: `10.000` seconds
Cache directory: `F:\projects\MaxLogic\DelphiSemantics\.dak\benchmarks\maxtdb-semantic\phase-metrics\semantic-cache`

| Feature | Benchmark | Cache mode | Runs | Status | Exit | Median seconds | Target seconds | Target status | Min | Max | Result count | Cache hits | Cache misses | Reference fallbacks |
|---|---|---|---:|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|
| rename | rename-dry-run-allfiles | cold | 1 | passed | 0 | 67.968 |  |  | 67.968 | 67.968 | 4 | 0 | 57 | 60963 |
| rename | rename-dry-run-allfiles | warm | 1 | passed | 0 | 3.079 | 10.000 | met | 3.079 | 3.079 | 4 | 56 | 1 | 0 |

Notes: all commands are report-only or dry-run; the maxTdb fixture is not modified.
