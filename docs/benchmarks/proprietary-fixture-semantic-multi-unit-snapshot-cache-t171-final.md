# proprietary fixture semantic workflow benchmark baseline

Started: `2026-06-11T10:40:45.2694745+02:00`
Completed: `2026-06-11T10:41:22.3273555+02:00`
DAK: `F:\projects\MaxLogic\DelphiAiKit\bin\DelphiAIKit.exe`
Project: `F:\projects\MaxLogic\DelphiAiKit\tests\fixtures\test-projects\<proprietary-fixture>\src\<fixture>.dpr`
Machine: `PAWEL3`
DelphiSemantics SHA: `3fd612d5b6336ca296ad2092c4602b0fa386b6a9`
DAK SHA: `311a82bb2af1e0741d2dba8c4d296be3fe75ac53`
Warm target: `10.000` seconds
Cache directory: `F:\projects\MaxLogic\DelphiSemantics\.dak\benchmarks\proprietary-fixture-semantic\multi-unit-snapshot-cache-t171-final\semantic-cache`

| Feature | Benchmark | Cache mode | Runs | Status | Exit | Median seconds | Target seconds | Target status | Min | Max | Result count | Cache hits | Cache misses | Reference fallbacks |
|---|---|---|---:|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|
| with-removal | remove-with-plan-all | cold | 2 | passed | 0 | 10.223 |  |  | 10.191 | 10.255 | 215 |  |  |  |
| with-removal | remove-with-plan-all | warm | 2 | passed | 0 | 6.371 | 10.000 | met | 6.333 | 6.409 | 215 |  |  |  |
| with-removal | remove-with-scan-all | cold | 2 | passed | 0 | 0.584 |  |  | 0.577 | 0.592 | 667 |  |  |  |
| with-removal | remove-with-scan-all | warm | 2 | passed | 0 | 0.575 | 10.000 | met | 0.552 | 0.598 | 667 |  |  |  |

Notes: all commands are report-only or dry-run; the proprietary fixture is not modified.

## Direct Snapshot Cache Metrics

Command: `.\.dak\t171-snapshot-metrics\bin\T171SnapshotMetrics.exe F:\projects\MaxLogic\DelphiAiKit\tests\fixtures\test-projects\<proprietary-fixture>\src\<fixture>.dpr .dak\benchmarks\proprietary-fixture-semantic\multi-unit-snapshot-cache-t171-final\snapshot-metrics\snapshot-cache.sqlite3`

| Run | Probes | Hits | Misses | Stale | Unit hits | Unit misses | Unit stale | Deserialize ms | Build ms | Merge ms | Unit build ms | Unit merge ms | Units | Symbols | References | Withs |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| cold | 59 | 0 | 59 | 0 | 0 | 59 | 0 | 0 | 75 | 75 | 170291 | 75 | 59 | 14274 | 67069 | 664 |
| warm | 59 | 59 | 0 | 0 | 59 | 0 | 0 | 661 | 179 | 179 | 0 | 179 | 59 | 14274 | 67069 | 664 |
