# proprietary fixture semantic workflow benchmark baseline

Started: `2026-06-11T01:30:13.3227827+02:00`
Completed: `2026-06-11T01:32:10.7060224+02:00`
DAK: `F:\projects\MaxLogic\DelphiAiKit\bin\DelphiAIKit.exe`
Project: `F:\projects\MaxLogic\DelphiAiKit\tests\fixtures\test-projects\<proprietary-fixture>\src\<fixture>.dpr`
Machine: `PAWEL3`
DelphiSemantics SHA: `5839bed8ef3bcd4519592d73a3f79da180196c93`
DAK SHA: `1defedc927ebbba3177b9607a5617c33fad98b3c`
Warm target: `10.000` seconds
Cache directory: `F:\projects\MaxLogic\DelphiSemantics\.dak\benchmarks\proprietary-fixture-semantic\dak-snapshot-planner\semantic-cache`

| Feature | Benchmark | Cache mode | Runs | Status | Exit | Median seconds | Target seconds | Target status | Min | Max | Result count | Cache hits | Cache misses | Reference fallbacks |
|---|---|---|---:|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|
| with-removal | remove-with-plan-all | cold | 3 | passed | 0 | 13.675 |  |  | 13.574 | 13.928 | 215 |  |  |  |
| with-removal | remove-with-plan-all | warm | 3 | passed | 0 | 4.638 | 10.000 | met | 3.712 | 4.874 | 215 |  |  |  |
| with-removal | remove-with-scan-all | cold | 3 | passed | 0 | 0.788 |  |  | 0.741 | 0.795 | 667 |  |  |  |
| with-removal | remove-with-scan-all | warm | 3 | passed | 0 | 0.995 | 10.000 | met | 0.970 | 1.126 | 667 |  |  |  |

Notes: all commands are report-only or dry-run; the proprietary fixture is not modified.
