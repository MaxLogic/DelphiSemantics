# DelphiSemantics API

Use `DelphiSemantics.Api` for common project and semantic-index operations.
It gives DAK and future integrations one stable entry unit. Lower-level units
remain available for focused tests and internal implementation.

## Stable Facade

- `TDelphiSemanticApiOptions` configures project loading, source loading,
  project context, cache behavior, and later opt-in LSP enrichment.
- `TDelphiSemanticApi.LoadProjectContext` loads `.dproj` or `.dpr` metadata
  through the project-context implementation.
- `TDelphiSemanticApi.BuildUnitIndex` builds or loads one cache-backed unit
  model and returns with-binding and remove-with inventory DTOs.
- `TDelphiSemanticApi.FindUsagesByName` and
  `TDelphiSemanticApi.FindUsagesAtPosition` return project-scoped usage DTOs
  from a caller-supplied symbol query context.
- `TDelphiSemanticApi.PlanRename` returns dry-run text edits for a
  project-scoped rename; callers own file transactions, backups, rollback,
  and user-facing apply policy.
- `TDelphiSemanticUnitIndex` returns DTO records only: model, bindings,
  inventory, cache metrics, and cache diagnostics.

## Cache Policy

The default cache is in-memory. Set
`TDelphiSemanticApiOptions.Cache.SqliteCacheFileName` to a non-empty path when a
caller needs a persistent SQLite cache.

## LSP Enrichment

This DelphiSemantics build does not support LSP enrichment. Setting
`UseLspEnrichment` returns the warning diagnostic `lsp.enrichment.unsupported`; leaving it false keeps the
semantic-model-only behavior and emits no LSP diagnostic. The reusable LSP unit
still owns settings JSON construction and result normalization helpers for a
later adapter, but no production path performs enrichment today.

## Remove-With Planning

Use `TDelphiSemanticRemoveWithApi.PlanRemoveWith` as the stable planning
entry point. It reports every discovered `with` statement in a Delphi project
as either planned or skipped. The facade-owned DTO includes operation status,
diagnostics, required verification, a complete statement ledger, candidate
edits, and skipped statements. `Statements` has one row for every discovered `with` statement with
`planned` or `skipped` status, stable reason fields, source range, semantic ID,
and `CoveredByStatementId` when a nested statement is rewritten as part of a
parent replacement. `SkippedStatements` mirrors the skipped ledger rows for
report consumers that only need unresolved statements. It does not expose final
statement DTOs, rewrite recipes, parity helpers, or planner internals.

Use project fixtures to check the planner on real code. Do not make production
behavior depend on fixture profiles, filenames, line numbers, or fixed counts.

`TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFactsResult`
is the failure-aware fact-build entry point. It returns `Success`, structured
diagnostics, facts, and metrics so production callers can decide how to handle
project/session failures.

`TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith` returns the full
internal planner record for DAK parity and migration workflows that still need
final statement DTOs or rewrite recipe data.

The legacy `BuildProjectWithBindingFacts` overloads are compatibility-only.
They raise an exception containing the diagnostic codes when fact building
fails, instead of returning default facts that could be mistaken for a valid
empty result. New callers should use `BuildProjectWithBindingFactsResult`.

## Boundary

Types containing `class const` declarations carry a `MEMBERS_INCOMPLETE`
diagnostic at the declaring type's source position. The parser may omit an
ordinary constant or misclassify a keyword-like name as a field, so partial
member facts do not establish a complete member list. With-removal refuses
receivers whose declaring type carries this diagnostic; unrelated types remain
available. The diagnostic survives model serialization and cache storage.

An ordinary field after a normally named `class const` declaration remains a
DelphiAST parsing limitation: the model reports `SCOPE_MODEL_FAILED` with
`ast-failed` scope status and `MEMBERS_UNVERIFIED`. This source shape cannot be
used to prove safe member edits. Keyword-like constant names can take a different
parser path and parse successfully; their owning type is still incomplete.

DelphiSemantics owns project metadata, source loading, preprocessing, cache
identity, semantic unit models, symbol queries, usage resolution, rename edit
planning, resolver behavior, and with-binding classification. DAK keeps CLI
orchestration, source rewrite, apply, rollback, verification, and user-facing
telemetry.

## Optional root-member absence evidence

`ImplicitRootMemberAbsence` on API and project options accepts
`IDelphiSemanticImplicitRootMemberAbsence` from `DelphiSemantics.RootMemberAbsence`.
`EvidenceFingerprint` identifies immutable evidence and its compiler inputs;
`IsNameAbsent(aName)` answers only the exact requested name on the implicit
class root. It does not certify an SDK inventory or indexed ancestors. Every
indexed declaration must independently prove the name absent. Missing evidence,
an empty fingerprint, a negative answer, or a provider exception retains the
unsupported binding and its diagnostic. Record-helper coverage remains a known
gap: an unindexed visible record helper can allow a lexical homonym to bind.
The follow-up DS-720 owns that limitation and its four retained regression cases.

Provider-backed requests bypass persistent project WITH-fact reads and writes,
even when an entry has the exact provider context. Ordinary requests retain
their cache behavior. Providers should retain immutable inputs for the full
request; a configuration or platform label alone cannot establish equivalence.

A provider may also implement `IDelphiSemanticProjectProfileValidator` from
`DelphiSemantics.ProjectContext`. Before constructing the session,
`ValidateProjectProfile(aProject, aReason)` receives the actual loaded project
profile. The implementation must compare the compiler inputs it verified,
including defines, ordered paths, aliases and compiler properties, as applicable.
False or an exception prevents session creation with
`PROJECT_PROFILE_VALIDATION_FAILED`. Implementing only the absence interface
does not perform this comparison automatically.

For request-owned source validation, a provider may additionally implement
`IDelphiSemanticModelObservationOwner` from `DelphiSemantics.Cache`.
`ValidateModelSources(aObservation, aReason)` validates the observed model source
inputs on extraction and cache-hit paths, and before publication of binding or
planning results. A refusal or exception prevents publication with
`MODEL_SOURCE_VALIDATION_FAILED`; model observations do not replace compiler
profile validation. Observation owners also bypass persistent project snapshots
whose source inputs were not observed by that request.


## Conditional source and WITH binding fields

`TDelphiSemanticUnitModel.VerifiedActiveSourceText` preserves source coordinates
and records known-active, known-inactive and unknown spans. An empty value supplies
no activity proof. `ReferenceScanSourceText` is a scan-only witness for degraded
extraction; it never authorizes edits. `TUnitSnapshot.VerifiedActiveSourceTextId`
interns the same evidence; `SetVerifiedActiveSourceTextId` requires a mutable snapshot.

`TDelphiSemanticPreprocessResult.ActivitySpans` contains inclusive source offsets
and `TDelphiSemanticSourceActivity` values (`saActive`, `saInactive`, `saUnknown`).
`HasUnknownActivity` reports uncertainty, and `ActivityEvidenceAvailable` states
whether complete evidence was captured. `TDelphiSemanticActivitySpan.FileName`,
`SourceText`, `StartOffset`, `EndOffset` and `Activity` identify each source span.

`TDelphiSemanticWithBinding.ActivityUnverified` is an independent edit barrier.
`References` and their counts describe the general active reference partition.
`InactiveSpanReferences` preserves the already-resolved inactive partition for
remove-with verification; it must not become rename or usage occurrences.
`InactiveSpanSkipReason` retains the full base-equivalent verification reason.
When that partition refuses a binding, public `Status` is `skipped` and `SkipReason`
retains the base refusal (for example `UNRESOLVED_REFERENCE`), even when the active
partition alone has no failure. Existing selector/member safety checks still apply.
`WithBindingForPlanning` merges the two partitions in source order without resolving
names again; general reference consumers use `References` alone.

`TSemanticRemoveWithBindingFact.InactiveSpanSkipReasonId` interns the same reason;
its `InactiveSpanReferences` stores the inactive facts. The binding flag
`cSemanticRemoveWithBindingFlagActivityUnverified` retains activity uncertainty.
Snapshot copying and persistence preserve both partitions, and the planner builds
one cached DTO view per snapshot binding source. Snapshot producer generation 42
and WITH-fact generation 57 rebuild cached bindings written before the public
inactive-only refusal reason was restored.

`TDelphiSemanticDeclaration.AstHelperKind` is empty when helper syntax is unverified,
or `none`, `class` or `record` when the active syntax tree proves it. Root-member
lineage evidence keeps `AstHelperKind`, `HelperTargetName`, `IsHelper` and
`HelperCovered` together; a helper name alone cannot prove complete coverage.

`TDelphiSemanticModelObservation` carries `ProjectContextFingerprint`,
`ModelFileName`, `SourceObservations`, `IncludeFileNames` and `CacheHit` to the
request-owned observation validator described above. These fields describe the
actual model inputs and cache path; they are not caller-supplied edit authority.
