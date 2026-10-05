# Changelog

## [Unreleased]

### Fixed
- Remove-with member-safety checks now follow the proven declaration of imported and nested `with` receivers. Unrelated incomplete-member diagnostics no longer mask complete receiver types; diagnostics on the actual type still refuse edits.
- Snapshot SQLite caches now open absolute database paths beyond 300 characters, allowing DAK position queries to reuse the persisted snapshot at a deep semantic-unit-cache.sqlite3 path.
- Semantic-unit SQLite caches now persist at deep project cache paths beyond 300 characters and remain reusable by a fresh cache instance.
- Remove-with preserves syntax-proven local labels and `goto` targets, including numeric labels and labels sharing a receiver field's name. Missing, duplicate, out-of-scope or unverified labels are refused. Protected occurrences retain their positions through member qualification and cached planning. Bodies containing escaped identifiers are conservatively refused to avoid malformed qualification.
- Pointer and array `with` selectors now follow aliases through the declaring unit, so member binding and rename planning include provable cross-unit references. Unimported, private, ambiguous and cyclic types remain unresolved; snapshot and remove-with caches refresh for the corrected binding.
- Remove-with refuses edits in units with unverified scope facts, skips selectors whose declaring type has unverified or incomplete members, and names the reason. Include-expanded `with` statements are refused when their original source range cannot be verified; other verified units can still be planned. Unit-model and remove-with cache identities are refreshed.
- Facts whose text comes from an `{$I}` or `{$INCLUDE}` file (references, declarations, routines, members, locals and parameters, in routine bodies or between declarations, including nested includes) now carry that file and its own line and column (`FileName` on the model fact, `FileId` on the snapshot fact). Previously they were mapped onto the including unit at an unrelated position: a reference could land in an inactive `{$IFDEF}` branch or in another routine, and a routine declared in an include was placed on the `{$I}` directive, so rename planned edits there. Include references stay unresolved and are listed at their own file; rename lists include usages (reason `include-file`) and is `incomplete`; find-usages reports include positions and a position in an include file resolves. Dead-code blocks an unused symbol declared in an include (`declared-in-include`), also one an include expanded inside a line puts on the directive, and dead-code removal only removes a declaration whose exact name stands at its recorded position. Facts after an include now get their exact source line. An include expanded in the middle of a line has no exact position: its facts sit on the directive and are listed with reason `include-position-unknown`, never dropped. If the preprocessed lines cannot be traced to their files, the unit becomes `include-line-map-failed`. Parser version `.36`, snapshot cache schema `12`.
- Rename refuses a plan (`blocked`) when the source text at a planned edit position is not the old name.
- Dead-code counts a call to a routine's interface or `forward` declaration for its implementation too (overloads pair by their parameter lists read by meaning, so grouped names, omitted default values, spacing and case do not matter; a short-form body pairs with its only interface declaration; nested routines of the same name are separate; an implementation body that pairs with no declaration while a same-named interface declaration is used is blocked as `unpaired-implementation`), and `initialization`/`finalization` blocks see the implementation `uses` clause. A call that stays unresolved anywhere in the project (an overload set without argument types) blocks every unit-level routine of that name that has an interface declaration. A function used only by a program main block or another unit's `initialization` or `finalization` block was reported `definitely-unused`, and removing it broke the build.
- A routine body now ends at its own `end;`, as the syntax tree delimits it (nested routines, anonymous methods, `asm` bodies and local types included). A var or const section after a routine, the program main block and the `initialization`/`finalization` statements no longer become that routine's references or locals, and an interface, `forward` or `external` header owns no body. Previously a global used next to a same-named local of another routine could bind to a phantom local, and declarations after a routine were reported as references at their own position. Statements after an `asm` routine (for example an `initialization` section) were missing and are now extracted; `asm` bodies themselves yield no references, so their occurrences are listed as unclassified. Body reference positions are exact without reconciliation. Units whose syntax tree fails keep the line scan and stay `ast-failed`. Parser version `.34`.
- Names used by declarations are references wherever the declaration sits: const and var initializers (`PLimit: PInteger = @GLimit`, `CDouble = CLimit * 2`), `absolute` targets, array bounds, default values and the types of routine headings, including class-method headings. Dead-code no longer reports such a declaration `definitely-unused`; before, removing `GLimit` still compiled and silently let a same-named global from another unit take its place. Dead-code also blocks (`unclassified-occurrence`) any symbol whose name occurs at a source position no reference covers, for example in inactive conditional code or an `asm` block. A routine or main block whose syntax range does not end with `end` makes the unit `ast-failed`, and one reference is kept per name and position.
- A source position on a local declaration resolves to that local rather than to the enclosing routine, whatever order the line index holds them in, and the level-1 resolver reports a local name declared in two overloads of a routine as ambiguous instead of picking the first.
- Rename plans and usages include member references in other units: `a.Member` through a variable, parameter, field or property of a project class, record or interface type; `Self.Member` and unqualified uses of members inherited from a project ancestor; class members through the type (`TA.Member`); and `with a do Member`, where a with body binds a name to the innermost selector's member before any other scope. A name in a with body, or an unqualified name in a method, is no longer bound to a same-named global or local unless the type chain is proven not to declare it: an ancestor outside the project, a helper, an inherited TObject name, a name the type declares without a recorded member (a class constant or nested type), or a type whose declaration includes a file (`{$I}`, `{$INCLUDE}`) leaves it unresolved. Previously a renamed field kept its old name in consumer units and the rename did not build.
- A same-name occurrence that cannot be proven to be or not to be the symbol is listed in the usage result's `Unresolved` (role `unresolved`, with a `Reason`: `unresolved-reference`, `unverified-unit`, `unclassified-occurrence` or `conflicting-facts`), and the rename plan becomes `incomplete` with `UnresolvedReferences`, no apply fingerprint and a diagnostic, instead of `planned` with edits silently missing. This covers calls into an overload set without argument types, any occurrence in a unit whose scope status is not `ast`, code in inactive conditional branches, and a reference placed on another symbol's declaration (a program routine's extracted body can run past its `end`). References in a unit whose scope status is not `ast` no longer count as proven usages.
- A planned rename now names the owning-project build (`project-build`) in its required verification.
- Find-usages and rename at a source position return `unknown` or `blocked` unless the position is one of the resolved symbol's own declarations or proven references, for example whitespace in a routine body. Previously a position on a local declared in a program routine could resolve to the enclosing routine, and rename renamed the routine.
- Renaming a method lists same-named methods of other types as `possible-override` unless both declarations are provably static, because overrides are not linked to their base method.
- Class, record and interface members are checked against the syntax tree. Every member on a shared line is kept (`procedure A; procedure B;`, `private FX: Integer; published procedure Handler;`) with the visibility the syntax tree gives it, so a second published handler on a line no longer reports `missing-handler`. Members of nested types belong to the qualified owner (`TForm.TInner`), and nested visibility no longer leaks into the outer class. Parameters on a method's continuation line are no longer reported as fields, escaped identifiers (`&Label`) are kept, and method and property positions point at the name. A type whose members cannot be fully reconciled gets a `MEMBERS_INCOMPLETE` diagnostic naming the missed members, so consistency refuses it instead of trusting a partial member list.
- A unit whose syntax tree cannot be built keeps its class and record members again. They come from a bounded line scan and carry a `MEMBERS_UNVERIFIED` diagnostic; the unit stays `ast-failed` with every declaration rejected, and class variables are left out so global-vars does not list them. When the interface-only retry runs, the original parser message is kept (`AST_BODY_PARSE_FAILED` on success, `SCOPE_MODEL_FAILED` on failure). Find-usages and rename return `unknown` or `blocked` for a symbol declared in a unit whose scope status is not `ast`, instead of resolving it through unverified members, and dead-code reports such a symbol as `blocked` with reason `unverified-scope-facts`. Cached unit facts are rebuilt.
- Remove-with planning qualifies every record or class constant declared on a shared line (`const CLo = 1; CHi = 5;`) and class properties. Previously a constant after the first, or a class property, stayed bare when an outer declaration had the same name, so the rewritten code compiled but used the outer value. Cached remove-with facts are rebuilt.
- Unit-level untyped constants retain syntax-backed declarations when section keywords and multiple declarations share a line. Ordinary constants are marked immutable, and affected cache identities are advanced so previous incomplete facts are rebuilt.

### Added
- Initial source-backed class declaration/implementation comparison distinguishes parameter-name drift, shape mismatches and ambiguous pairs. Read-only parameter mappings validate source positions and refuse incomplete inventories; body-edit planning and CLI integration remain in progress.
- Source-backed consistency comparison follows supported unit-scoped type aliases in their declaring import context, preserves strong type identity and original event declaration evidence, and refuses incomplete or stale facts.
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
- Nested indexed default-property and pointer selectors inside an enclosing `with` now bind through the parent receiver using the member type's declaring unit. Unknown or ambiguous declaring-unit provenance refuses the binding.
- Snapshot reference binding no longer sends a call to the wrong overload when overloads differ only by an open-array element type or generic arguments; such calls stay unresolved. Range bounds such as `cMin..cMax` in subranges, case labels, set and array bounds bind their upper bound again, and signature alignment detects a parameter rename that would capture such a bound. Remove-with planning now qualifies a with-member used after `..` instead of leaving it to bind to an outer declaration. The parser cache version is advanced so earlier facts are rebuilt.
- Snapshot reference binding distinguishes tested Self members and explicit class variables from same-named parameters. Partial Unicode identifier matches are refused and old snapshot cache entries are rebuilt; full Unicode parsing remains unproven.
- Treat omitted and explicit register calling conventions as equivalent in
  source-backed event signature comparisons.
- Preserve nested type and enum ownership, including unscoped enum visibility,
  and correct declaration positions for types written beside the type keyword.
- Project context now tracks runtime-package controls and raw compiler switches
  in its identity, diagnoses unresolved inputs, and preserves MSBuild's empty
  defaults for optional link settings. Regenerate saved plans whose semantic
  IDs were derived from the previous context identity.
- Captured locals retain their qualified parent method owner. Variables declared after nested routines resolve within that owner, sibling routine variables cannot escape through unit lookup, and conflicting declaration identities stop resolution as ambiguous. Remove-with planning preserves method and constructor captures after the owner correction; older planning facts are rebuilt.
- Snapshot-backed find-usages and rename pair routine declarations across line breaks and tabs, while preserving overload and default-value distinctions. Persisted snapshots with older pairing rules are rebuilt.
- Remove-with reference occurrence matching ignores identifier case while preserving the source spelling in replacements. Mixed-case index members no longer cause a `reference-offset-not-resolved` skip.
- A with-body index reference now spans its complete balanced index, such as `Values[Lookup[Index]]`, and the identifiers inside an index are bound as references of their own, as call arguments are. Parentheses inside an index no longer count as call arguments. Cached remove-with project facts are rebuilt.
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
