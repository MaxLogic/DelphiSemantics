# Changelog

## [Unreleased]

### Added
- Remove-with compatibility fact building now exposes an explicit result record
  with success, diagnostics, facts, and metrics for callers that need
  structured failure handling.
- Remove-with final statement DTOs now expose rewrite recipe metadata for
  selector decisions, temp declarations, text edits, replacement range/text,
  render instruction, and rule provenance.
- Remove-with planning can now run through a DelphiSemantics project-session
  snapshot API path, preserving current plan DTOs without requiring the legacy
  JSON project-facts sidecar on that core path.
- Snapshot primitive API with a case-aware string pool, dense unit snapshot fact
  storage, `UInt64` member-key helper, immutable project snapshot builder, and
  cross-unit file/symbol/member/type/reference indexes for the new typed project
  snapshot architecture.
- Project sessions can now build typed project snapshots from extracted unit
  models and expose snapshot build counts/timing metrics.
- Project snapshot building now has an opt-in worker-local parallel builder with
  deterministic merge metrics for queue, parse/extract, merge, worker count, and
  fact count telemetry.
- Project snapshot SQLite cache metrics now expose probe, SQL read,
  deserialization, index rebuild, parse-avoided estimate, and usefulness
  telemetry through project/session snapshot build metrics.
- Function-result refactor planner API for converting Delphi legacy
  `FunctionName := Value` result-variable idioms to `Result`, with guards for
  calls, qualifiers, comments, strings, nested routines, and `with` bodies.
- Rename planner regressions for project-scoped routine identity, position-based
  routine header rename, same-unit declaration-side type references, and real
  proprietary fixture dogfood blockers.
- Agent guidance for DAK project-scoped semantic refactoring, including
  `find-usages`, dry-run `rename`, and dead-code review safety rules.
- Optional semantic search facade with syntax-only match labeling, resolved
  symbol filtering, and declaration kind/owner/scope/unit filters.
- Dead-code removal edit planner with profile-gated dry-run text edits and
  blockers for audit mode or unsupported deletion shapes.
- Conservative dead-code report API with audit safety profile, blocked-risk
  diagnostics, and tests for dynamic Delphi risk shapes.
- Project rename edit planner API with dry-run edit ranges, API facade support,
  project-source guarding, collision blocking, and cross-unit case-insensitive coverage.
- Project symbol/reference index API with per-snapshot symbol IDs plus conservative
  resolved, ambiguous, and unresolved reference diagnostics.
- Project find-usages API for source-position and symbol-name queries, including
  ambiguous-target blocking and section-aware usage rows.
- Repo-root `run-migration-gate.bat` wrapper for the DelphiSemantics/DAK/proprietary fixture migration gate,
  with documented sequential DAK RemoveWith execution and `DAK_TEST_OUTPUT_ROOT` isolation guidance.
- Migration gate script and documentation for the DelphiSemantics suite, DAK remove-with suite,
  and cloned proprietary fixture apply smoke.
- Stable `DelphiSemantics.Api` facade for project-context loading, query/refactor/search entrypoints,
  and DAK integration, with remove-with and with-binding compatibility APIs split into explicit
  `DelphiSemantics.Api.RemoveWith` and `DelphiSemantics.Api.WithBinding` units.
- DAK obsolete GlobalVars and RemoveWith parser snapshots are backed up under `_obselete` and excluded from normal compilation.
- DAK GlobalVars now consumes the DelphiSemantics global analysis API and rebuilds legacy cache schema entries through the new analyzer.
- Global variable semantic analysis API for reusable declarations, usages, ambiguity reporting, access classification, local shadowing, and semantic filters.
- DAK semantic consumers now use DelphiSemantics adapters for remove-with bindings, SymbolMap extraction, dependency graphs, and global-vars declaration extraction.
- Remove-with inventory now exposes DAK planner-compatible symbol facts and source-owner expansion for DAK migration.
- DAK project/test integration reference to DelphiSemantics with a compile-time wrapper proof.
- LSP boundary helpers for lifecycle state, URI/path normalization, location links, hover payloads, position conversion, hierarchical symbol flattening/filtering, explicit error results, and LSP provenance.
- Dependency graph API with project/external/unresolved nodes, interface/implementation edges, cycle components, hotspot ranking, and exact focus neighborhoods.
- With-binder planning metadata for binding status, skip reasons, lookup-source counts, intrinsic/external call classification, scoped declarations, and unresolved reason codes.
- Remove-with resolver inventory coverage for enum values, typed constants, implementation globals, interface inheritance, overloaded members, and nested-routine `with` selector scopes.
- With-discovery model coverage for selector counts, body ranges, nesting depth, scoped declarations, UTF-8 BOM coordinates, and inactive conditional branches.
- Symbol query API and DAK SymbolMap query coverage for definition lookup, source-position lookup, member/intrinsic/RTL search, token references, and cache/profile status.
- Cache/profile migration coverage for compiler-profile cache keys, equivalent-context reuse, intrinsic resolver rows, stale SQLite profile repair, and cached source-available RTL indexing.
- Optional LSP enrichment boundary with explicit opt-in and provenance for `lsp` and `semantic-model` results.
- Semantic with-binder API for selector type binding and member/lexical/external/ambiguous/unresolved/unsupported reference classification.
- Level 3 semantic resolver support for helpers, inheritance, compiler/RTL intrinsics, and indexed source units.
- Level 2 semantic resolver support for aliases, arrays, pointers, indexed/default properties, nested scopes, and ambiguity.
- Level 1 semantic resolver for lexical symbols, unit declarations, direct members, and explicit unsupported outcomes.
- Optional SQLite-backed semantic unit-model cache with persistent reuse and deterministic rebuild diagnostics.
- In-memory semantic unit-model cache with hit/miss/invalidation metrics and source/context/include/version cache keys.
- DAK SymbolMap unit-model fixture coverage, including member signatures, indexed/default properties, visibility, and identifier metadata.
- Source-context lookup and diagnostic candidate extraction migrated from DAK.
- Source loading and unit-model extraction for Delphi semantic analysis, including deterministic Windows-1252 fallback, declaration/member/routine/local/reference extraction, diagnostics, and `with` ranges.

### Changed
- Remove-with planning now avoids retargeting already-qualified member-chain
  occurrences when recovering reference offsets for pointer-field rewrites.
- Remove-with planning now demotes final replacements that leave receiver-bound
  members unqualified in the rendered body, reporting
  `semantic-rewrite-incomplete` instead of publishing unsafe edits.
- Remove-with planning now demotes final replacement edits that do not cover the
  complete original `with` statement, including tricky `if/then/else` and outer
  `end else` boundary shapes.
- Remove-with planning now exposes a complete stable statement ledger for every
  discovered `with` statement, including skipped reason fields and nested
  statements covered by a parent rewrite.
- proprietary fixture remove-with benchmark proof now emits a report-only `dogfood.json`
  with discovered/planned/skipped counts, skip buckets, completeness status, and
  source mutation status instead of enforcing fixed historical proprietary fixture counts.
- Remove-with skip and safety decisions no longer use proprietary filename or
  exact source-line branches; unresolved or unsafe statements now fail closed
  through generic selector and member diagnostics.
- Remove-with final body rendering no longer uses proprietary fixture-specific replacement
  body tables or filename/line post-render patches; unsupported legacy shapes
  now remain skipped with stable reasons.
- Remove-with proprietary fixture-backed plan tests are now categorized as `<proprietary-fixture-proof-category>`
  and excluded from the ordinary focused DUnitX lane by default; the explicit
  multi-minute proof lane remains the proprietary fixture benchmark wrapper.
- The proprietary fixture semantic benchmark now treats `remove-with-plan-all` warm target
  misses as best-effort performance signals while still recording
  `TargetStatus`, median time, and correctness outputs.
- Remove-with compatibility fact-to-snapshot planning now uses explicitly
  compatibility-named helpers, keeping the primary remove-with API path
  session-backed and snapshot-native.
- Remove-with-only semantic graph skipping now lives on the remove-with request
  options instead of the common API options record.
- Snapshot-backed remove-with planning now caches converted binding DTOs once
  per snapshot binding source instead of rebuilding them on every hot-path
  binding lookup.
- Project and option-set loading now walks MSBuild XML through Delphi's XML DOM,
  covering single-quoted attributes, XML entities, imports, property groups, and
  conditional `DCCReference` entries without regex tokenization of project XML.
- With-binding `BuildUnitIndex` now applies project-derived defines and source
  lookup paths for project-file inputs, and reports project context failures as
  deterministic model diagnostics.
- proprietary fixture semantic benchmark runs now keep generated baseline artifacts under
  `-OutDir` by default; publishing to `docs\benchmarks` requires
  `-PromoteBaseline` and passes dirty/stale provenance gates.
- Snapshot SQLite cache connections now declare a busy timeout plus WAL/normal
  locking policy, and writer transactions retry transient SQLite lock conflicts
  during shared-cache multi-process use.
- Parallel project snapshot worker joins now use bounded handle polling with
  cooperative cancellation and worker/source-file timeout diagnostics instead
  of unbounded `TThread.WaitFor`.
- Remove-with body-analysis scoping now lives on the remove-with-specific
  request/API path instead of the common project/API option records.
- Remove-with apply mode now preserves the semantic report-only statement set
  instead of retrying through a compatibility fallback plan after verification
  failure; the migration gate now emits and compares cloned proprietary fixture report-only
  and apply JSON artifacts.
- The migration gate now uses run-scoped default work roots and writes a Git
  provenance manifest; dirty DelphiSemantics or DAK worktrees require an
  explicit `-AllowDirty` opt-out.
- Explicit migration-gate `-WorkRoot` runs now hold a root-local lock file so
  concurrent runs cannot overwrite each other's clone/report artifacts.
- Dead-code report/removal profile names now use a shared typed profile
  contract with deterministic unknown-profile diagnostics, and DAK CLI
  validation consumes the same parser/allowed-name list.
- `UseLspEnrichment=True` now produces the deterministic
  `lsp.enrichment.unsupported` project-context warning while runtime LSP
  enrichment remains unsupported; the default false path remains
  semantic-model-only.
- With-binding compatibility facts now project compiler and RTL intrinsic
  compatibility symbols from the shared compiler-profile seed instead of a
  local hardcoded routine/type list.
- Default compiler profiles now use the shared versioned intrinsic seed, so
  default, target-backed, and cached-source profile builders expose the same
  intrinsic symbol set.
- RTL source-root compiler profiles now build source models through shared
  unit-model extraction instead of a compiler-profile-local regex parser,
  preserving helper metadata, property metadata, resourcestrings, multiline
  enum values, and forward class declarations.
- Remove-with selector planning now resolves source-backed dotted selector
  chains through semantic symbol/member facts instead of proprietary fixture-specific
  selector-decision patches, while preserving the proprietary fixture `667` scan count and
  `215` planned edit count.
- SQLite semantic caches now read and write cached text through Unicode-safe
  FireDAC accessors, preserving non-ASCII snapshot strings, source paths,
  unit-model JSON, and DAK global-vars projection data across cache reuse.
- Snapshot SQLite cache invalidation now deletes only the exact context-specific
  cache-key row being refreshed, preserving sibling variants for the same source
  file across different project contexts.
- Recursive RTL source fallback now sorts normalized source paths and uses a
  documented first-sorted-path policy for duplicate unit filenames.
- Snapshot SQLite cache persistence now uses prepared dense-fact writes,
  preserves remove-with planning extension facts, validates extension row counts,
  and reports snapshot SQL timing metrics through the remove-with benchmark.
- Dependency graph cycle analysis now uses a shared DelphiSemantics typed SCC
  analyzer for both DelphiSemantics and DAK deps output, replacing duplicated
  reachability sweeps while preserving cycle, hotspot, and SCC JSON fields.
- Unit model extraction now scopes line, source-section, and type-block caches
  to each extraction thread, allowing DAK remove-with semantic fact construction
  to run without a broad global `ProjectSemanticFactsLock`.
- Project-session snapshot builds now reuse SQLite snapshot cache entries per
  unit for multi-unit projects, merge cached and rebuilt units
  deterministically, expose unit hit/miss/stale/build/merge telemetry, and
  conservatively repair cross-unit reference targets after mixed cache hits and
  misses.
- Remove-with snapshot planning now uses snapshot-owned planning facts directly
  instead of rebuilding the legacy project-with-binding facts DTO or
  materializing the full legacy binding array; proprietary fixture proof preserved scan
  count `667` and planned edit count `215` with warm plan median `6.415s`.
- Remove-with no longer reads or writes the obsolete project-facts JSON sidecar;
  planning now keeps the typed snapshot path in memory, reuses the model-backed
  lookup index with only the routine-owner safety subset, and avoids routine
  parent-scope array allocation for top-level lines. The final proprietary fixture proof is
  cold `remove-with-plan-all` `9.224s` median, warm `5.972s`, scan count `667`,
  and planned edit count `215`.
- The earlier compact project-facts sidecar and project-facts reuse path is now
  superseded by typed snapshot planning; `projectFactsCache*` metrics remain
  zero when remove-with plans through DelphiSemantics snapshots.
- Remove-with current-class inventory expansion now deduplicates owner/routine
  projection contexts, and the semantic report contract benchmark now proves
  proprietary fixture cold `remove-with-plan-all` at `9.712s` median with scan count `667`
  and planned edit count `215`.
- Remove-with semantic binding now reports routine scope-conflict facts on
  receiver-member references so DAK can avoid recomputing scope-shadow
  decisions; the proprietary fixture cold `remove-with-plan-all` proof preserved scan count
  `667`, planned edit count `215`, and reduced `fallbackDecisionMs` to `4ms`.
- Remove-with receiver/member binding now uses an operation-local indexed lookup
  and statement-level receiver cache prefixes, reducing proprietary fixture cold
  `remove-with-plan-all` median to `21.841s` and
  `semanticReceiverMemberResolveMs` to `1ms` while preserving scan count `667`
  and planned edit count `215`.
- Remove-with planning now exposes deeper semantic reference-binding and legacy
  resolver-report classification metrics, restoring the proprietary fixture cold
  `remove-with-plan-all` median to `28.138s` while preserving scan count `667`
  and planned edit count `215`.
- Remove-with project fact planning now exposes finer hot-path phase metrics and
  uses indexed final DTO nesting, indexed related-inventory expansion, faster
  scope scanning, and regex-free body reference token enumeration. The current
  proprietary fixture cold `remove-with-plan-all` median improved from `37.458s` to
  `32.961s` while preserving scan count `667` and planned edit count `215`;
  the original T-152 `<= 30.0s` target remains open.
- Project-aware parsing now combines evaluated project defines with target
  compiler/platform built-ins, and DAK project analysis avoids host-process
  DelphiAST compiler defines when analyzing another target platform.
- DAK normal remove-with plan mode now consumes DelphiSemantics final statement
  DTOs as the primary planning source while preserving proprietary fixture scan count 667,
  planned edit count 215, and a 26.870s cold plan benchmark median.
- Remove-with semantic-hub planning now preserves the proprietary fixture 667 scan /
  215 plan baseline while reducing the final cold plan benchmark median to
  29.632s.
- Cold reference reconciliation now builds one token occurrence table per unit
  instead of regex-scanning source once per fallback name, reducing proprietary fixture cold
  `rename-dry-run-allfiles` median runtime from 18.744s to 11.479s.
- Cold semantic unit extraction now reuses per-unit line, type-block, and
  reference-name scan data, reducing proprietary fixture cold `rename-dry-run-allfiles`
  median runtime from 70.012s to 18.744s while preserving warm-cache targets.
- DAK semantic JSON and proprietary fixture benchmark rows now include additive
  `semanticPhaseMetrics` timing and counter data for cold-path optimization.
- Dead-code reporting now uses per-report in-memory lookup caches, bringing
  proprietary fixture warm-cache `dead-code-legacy-static` dogfood below the 10-second target.
- SQLite semantic cache identity now includes compiler/toolchain and extraction
  metadata, while DAK semantic benchmarks report cache hit/miss counts.
- Semantic workflow benchmarks now expose reference reconciliation fallback
  counts, prime warm-cache runs before timing, and fail semantic workflow rows
  that omit the metric.
- Unit model references now carry original-source `Offset` and exclusive
  `EndOffset` ranges with counted regex fallback reconciliation and SQLite
  cache restoration.
- Unit model extraction now records source section boundaries and uses cached
  section lookup for interface/implementation/initialization/finalization
  classification, including SQLite cache restoration.
- Unit model declarations, members, routines, and locals now carry
  original-source `Offset` and exclusive `EndOffset` ranges, including SQLite
  cache restoration.
- Project reference resolution now uses dictionary-backed project-index lookups,
  routine-id local scope matching, and ordered visible-scope queries; proprietary fixture
  warm `rename-dry-run-allfiles` benchmark is down to a 2.849s median.
- Migration gate now reports dominant runtime phases explicitly, uses a sequential DAK RemoveWith gate
  profile to avoid duplicate proprietary fixture/proprietary coverage, and hard-blocks unsafe parallel DAK shards.
- DAK RemoveWith now rewrites safe scoped-declaration `with` bodies while preserving inline locals,
  exception variables, and generic type names; cloned proprietary fixture apply now verifies at 505 removals with
  zero `scoped-declaration-in-with-body` and zero `symbol-not-found` skips.
- DAK RemoveWith tests can isolate process temp/output roots with `DAK_TEST_OUTPUT_ROOT` for explicit
  parallel-filter proof runs while the migration gate remains sequential by default.
- RTL source-root compiler profiles now use a fast DelphiSemantics-owned interface extractor
  that preserves routines, types, members, enum values, constants, variables, and resourcestrings
  without invoking the full unit-model cache/parser path.
- Semantic cache identity now includes source timestamps in addition to content hashes, and
  the public API selects the SQLite cache when `SqliteCacheFileName` is configured.
- Primary remove-with planning now returns a facade-owned stable DTO and keeps
  final statement / rewrite recipe internals behind the compatibility API.
- `UseLspEnrichment=True` now reports an explicit unsupported diagnostic instead
  of the older placeholder diagnostic.

### Fixed
- A with-body call reference now spans the complete balanced call. Nested calls such as `FillChar(Buffer, SizeOf(TMD5Buffer), 0)` used to end at the first inner closing parenthesis. The rest of the argument list was then scanned as separate top-level tokens; those identifiers are now arguments of the outer call. Cached remove-with project facts are rebuilt. Index suffixes keep their current extent.
- Remove-with planning now types a `with` selector that indexes a unit-level typed-constant array, such as `with ResWords[m] do`, and captures the element by address like the element of a variable array. It was skipped as `selector-type-not-resolved`. In a multi-selector `with A, B do`, a field of `A` still takes precedence over a same-named global `B`.
- Routine header references keep their own lexical scope at adjacent and same-line routine boundaries.
- Indented type aliases remain visible to snapshot-backed find-usages and rename.
- Declaration extraction excludes assignments and keeps variables declared after class method declarations in unit scope.
- Record models include packed-record fields and every name in multiline field lists, with source locations preserved. Variant labels and quoted field types retain their existing meaning; obsolete cached models are rebuilt.
- Source-context caching preserves native Windows timestamp precision, so
  same-size edits within a millisecond refresh cached source. Ordinary files
  use one metadata query; file links use their target's timestamp and size.
- Semantic benchmark workflow timings now exclude argument construction and source snapshot setup. Earlier measurements retain their original timing boundary.
- Semantic benchmark mutation checks now retain changed paths and hashes and preserve external dependency edits. Automatic restoration is restricted to project-local files without linked paths.
- Remove-with preserves compiler type casts inside statement bodies, including writable Double and Pointer casts, while retaining user declarations and receiver-member precedence. Older cached planning facts are rebuilt.
- Remove-with keeps nested and conditional body boundaries intact, preserves generated capture wrappers, and retains outer ELSE branches across whitespace and comments.
- Remove-with captures unambiguous global record-array fields at each controlled statement entry, preserving index mutation and skipped guards. Getter and shadowed receivers remain excluded.
- Remove-with keeps reference coordinates correct when a body starts with LF after DO, preventing false unresolved-symbol skips. Cached models from the older parser are rebuilt.
- Semantic benchmarks accept explicit platform, configuration and compiler options; List displays the complete commands for each cache mode without running them.
- Remove-with preserves receiver-member precedence across inline declarations, including initializer expressions and loop bodies, without qualifying declaration identifiers.
- Remove-with now qualifies indexed fields whose name matches the receiver, while preserving explicit qualifiers and anonymous nested receivers under skipped parents.
- Remove-with preserves receiver-field precedence over outer locals in indexed arguments, while retaining lexical indexes and explicit qualifiers, including whitespace after a dot.
- Nested forward and external declarations no longer claim the enclosing routine's later references or remove-with captures. Older cached planning facts are rebuilt without invalidating unit models.
- Legacy remove-with compatibility fact-builder overloads now fail loudly with
  diagnostic codes when fact building fails, instead of returning default facts
  that can look like a valid empty result.
- Primary remove-with planning failures now preserve structured project/session
  diagnostics in the returned plan, so callers can distinguish missing project
  path and missing project file errors without parsing the fallback summary
  string.
- Parallel test-project rebuilds through `build-delphi.bat` now use per-run DCU
  output folders under `.dak`, avoiding shared `tests\bin` unit-output writes
  while keeping executable output unchanged.
- Source-context caches now refresh cached source text, line maps,
  inactive-region state, and line-break provenance when the underlying file's
  timestamp or size changes during a long-lived run.
- Dead-code safety checks now use loaded model or snapshot source text instead
  of rereading files from disk, preserving message/export/initialization/
  finalization blockers for stale or snapshot-backed reports.
- DAK command output writes now share a dedicated helper for stdout/file mechanics,
  keeping command-specific rendering separate while preserving existing bytes and `-`
  semantics.
- SQLite snapshot cache entries now invalidate on include-only file changes by
  using per-unit preprocessing include graph hashes in snapshot identity.
- With-binding indexed expressions such as `LTable[Hash(s)]` no longer treat
  the parenthesized index expression as a routine-call suffix during reference
  binding.
- With-binding class methods now use the owning routine type as receiver-member
  access context, preserving inherited protected member resolution.
- Remove-with selector binding now keeps unsafe indexed/default property
  selectors unsupported while preserving indexed array and pointer selectors.
- Rename planning now keeps legacy `end; {comment}` type blocks from hiding later
  routine declarations, and preserves active units around inline conditional
  directives in `uses` lines so cross-unit alias references are resolved.
- Rename planning now coalesces Delphi routine declarations and implementations,
  targets routine identifiers from header positions, indexes declaration-side
  type references, and de-duplicates identical edit ranges before apply.
- Preprocessing now tolerates legacy compiler directives used by proprietary fixture,
  including multiline conditional close braces, inline conditional pairs,
  compiler switches, resource directives, and region markers.
