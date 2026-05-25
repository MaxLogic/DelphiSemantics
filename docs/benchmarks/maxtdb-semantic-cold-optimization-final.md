# maxTdb semantic workflow benchmark baseline

Started: `2026-05-25T19:04:43.5544781+02:00`
Completed: `2026-05-25T19:08:30.2916647+02:00`
DAK: `F:\projects\MaxLogic\DelphiAiKit\bin\DelphiAIKit.exe`
Project: `F:\projects\MaxLogic\DelphiAiKit\tests\fixtures\test-projects\maxTdb\src\maxtdb.dpr`
Machine: `PAWEL3`
DelphiSemantics SHA: `70d7ce60855f7dfa3c59557c80f101b387173603`
DAK SHA: `50e75c2b4ff26870c23247fbc16bc1c99fca0436`
Warm target: `10.000` seconds
Cache directory: `F:\projects\MaxLogic\DelphiSemantics\.dak\benchmarks\maxtdb-semantic\cold-optimization-final\semantic-cache`

| Feature | Benchmark | Cache mode | Runs | Status | Exit | Median seconds | Target seconds | Target status | Min | Max | Result count | Cache hits | Cache misses | Reference fallbacks |
|---|---|---|---:|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|
| dead-code-detection | dead-code-legacy-static | cold | 3 | passed | 0 | 22.169 |  |  | 22.066 | 22.832 | 4078 | 0 | 57 | 60963 |
| dead-code-detection | dead-code-legacy-static | warm | 3 | passed | 0 | 6.569 | 10.000 | met | 6.440 | 7.144 | 4078 | 56 | 1 | 0 |
| find-usages | find-usages-allfiles | cold | 3 | passed | 0 | 19.372 |  |  | 18.987 | 19.931 | 4 | 0 | 57 | 60963 |
| find-usages | find-usages-allfiles | warm | 3 | passed | 0 | 3.090 | 10.000 | met | 3.081 | 3.105 | 4 | 56 | 1 | 0 |
| rename | rename-dry-run-allfiles | cold | 3 | passed | 0 | 18.744 |  |  | 18.322 | 19.190 | 4 | 0 | 57 | 60963 |
| rename | rename-dry-run-allfiles | warm | 3 | passed | 0 | 3.096 | 10.000 | met | 3.087 | 3.100 | 4 | 56 | 1 | 0 |

Notes: all commands are report-only or dry-run; the maxTdb fixture is not modified.
