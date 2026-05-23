# maxTdb semantic workflow benchmark baseline

Started: `2026-05-23T22:11:37.4742000+02:00`
Completed: `2026-05-23T22:12:20.6284887+02:00`
DAK: `F:\projects\MaxLogic\DelphiAiKit\bin\DelphiAIKit.exe`
Project: `F:\projects\MaxLogic\DelphiAiKit\tests\fixtures\test-projects\maxTdb\src\maxtdb.dpr`
Machine: `PAWEL3`
DelphiSemantics SHA: `4723f156a73ef54a3dbf4b7231a89af4f8df23df`
DAK SHA: `60c82f0b54a76d712f0e9183b1dd06290d98ba11`
Warm target: `10.000` seconds
Cache directory: `F:\projects\MaxLogic\DelphiSemantics\.dak\benchmarks\maxtdb-semantic\dak-dogfood\semantic-cache`

| Feature | Benchmark | Cache mode | Runs | Status | Exit | Median seconds | Target seconds | Target status | Min | Max | Result count | Cache hits | Cache misses | Reference fallbacks |
|---|---|---|---:|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|
| dead-code-detection | dead-code-legacy-static | warm | 3 | passed | 0 | 6.964 | 10.000 | met | 6.957 | 7.214 | 4078 | 56 | 1 | 0 |
| find-usages | find-usages-allfiles | warm | 3 | passed | 0 | 3.182 | 10.000 | met | 3.176 | 3.186 | 4 | 56 | 1 | 0 |
| rename | rename-dry-run-allfiles | warm | 3 | passed | 0 | 3.185 | 10.000 | met | 3.175 | 3.292 | 4 | 56 | 1 | 0 |

Notes: all commands are report-only or dry-run; the maxTdb fixture is not modified.
