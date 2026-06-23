# proprietary fixture semantic workflow benchmark baseline

Started: `2026-05-25T23:06:15.3430456+02:00`
Completed: `2026-05-25T23:08:50.3746833+02:00`
DAK: `F:\projects\MaxLogic\DelphiAiKit\bin\DelphiAIKit.exe`
Project: `F:\projects\MaxLogic\DelphiAiKit\tests\fixtures\test-projects\<proprietary-fixture>\src\<fixture>.dpr`
Machine: `PAWEL3`
DelphiSemantics SHA: `bd7b30bfe1a32cc423d2373b66f93b37a7504094`
DAK SHA: `50e75c2b4ff26870c23247fbc16bc1c99fca0436`
Warm target: `10.000` seconds
Cache directory: `F:\projects\MaxLogic\DelphiSemantics\.dak\benchmarks\proprietary-fixture-semantic\cold-optimization-next\semantic-cache`

| Feature | Benchmark | Cache mode | Runs | Status | Exit | Median seconds | Target seconds | Target status | Min | Max | Result count | Cache hits | Cache misses | Reference fallbacks |
|---|---|---|---:|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|
| dead-code-detection | dead-code-legacy-static | cold | 3 | passed | 0 | 14.063 |  |  | 13.856 | 14.196 | 4078 | 0 | 57 | 60963 |
| dead-code-detection | dead-code-legacy-static | warm | 3 | passed | 0 | 6.754 | 10.000 | met | 6.749 | 6.767 | 4078 | 56 | 1 | 0 |
| find-usages | find-usages-allfiles | cold | 3 | passed | 0 | 10.830 |  |  | 10.724 | 11.141 | 4 | 0 | 57 | 60963 |
| find-usages | find-usages-allfiles | warm | 3 | passed | 0 | 3.200 | 10.000 | met | 3.185 | 3.569 | 4 | 56 | 1 | 0 |
| rename | rename-dry-run-allfiles | cold | 3 | passed | 0 | 11.479 |  |  | 10.824 | 11.701 | 4 | 0 | 57 | 60963 |
| rename | rename-dry-run-allfiles | warm | 3 | passed | 0 | 3.191 | 10.000 | met | 3.185 | 3.191 | 4 | 56 | 1 | 0 |

Notes: all commands are report-only or dry-run; the proprietary fixture is not modified.
