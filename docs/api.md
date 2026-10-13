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

Type bodies containing unknown or unavailable conditional activity carry
`MEMBERS_ACTIVITY_UNVERIFIED` at the declaring type's source position. The fact
covers the whole type range, including nested bodies and members omitted by
preprocessing. Known-active and known-inactive regions do not introduce this
fact; legacy extraction without project context publishes no activity authority.
The generic diagnostic array preserves it through model JSON and cache storage.


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
`TDelphiSemanticWithBinding.MemberActivityUnverified` carries the separate
type-member activity barrier. Its public binding has `Status=skipped` and
`SkipReason=MEMBERS_UNVERIFIED`; the planner evaluates ordinary refusals before
applying the activity overlay to an otherwise planned result. Existing reasons
such as `property-selector`, `receiver-type-not-visible` and
`type-source-not-indexed` retain precedence. A newly refused activity result has
`Reason=members-unverified`, `SafetyReason=MEMBERS_UNVERIFIED`, no final edits,
temps or replacement. Member-activity ranges never remain candidate apply
coverage, including when an ordinary final refusal retains its reason.

An uncertain selector-path prefix can give a selector `Status=unsupported`,
`ReasonCode=SELECTOR_MEMBERS_ACTIVITY_UNVERIFIED` and an empty `TypeIdentity`.
Verified receiver identities constrain direct member lookup and its cache keys:
another unit's same-named type cannot supply a direct member. Established
ambiguity, helper and inheritance results keep their existing lookup contract.
Identity-less selectors retain the existing name-based fallback.

The final planner guard refuses a qualification of a `lexical` or `unresolved`
reference when no same-name reference on that line is bound as `member` and
the inventory qualification target is not source-contained in the AST declaration
body of the verified receiver, or a declaration on the binder's verified access
lineage. The inventory location must lie in the verified declaration body or a
standalone include line anchored to that declaration. Owner names, owner IDs alone
and the public type-name span are not containment evidence.
Type declarations carry additive `TypeBodyEndLine`/`TypeBodyEndColumn` metadata;
zero means unverified. Physical line origins and native AST columns establish
these endpoints for both CRLF and LF inputs. `type-body-range` lookup metadata
preserves them in existing snapshot inventory storage without changing the public
name-span identity. Constants retain their existing binder classifications.
Foreign homonyms, unit/global constants and unverified bodies do not authorize a
qualification. The compatibility inventory masks block comments across physical
lines and excludes routine signature parameters, including class operators; real
fields, variant tags/parts, constants, properties and methods retain their facts.
`receiver-member-owner-conflict` is the ordinary-path Reason and SafetyReason;
its DTO has no edits, temps or replacement, and its candidate edit is removed.
Earlier ordinary refusals retain their reasons and ordinary candidate behavior.

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
one cached DTO view per snapshot binding source. Snapshot producer generation 45
and WITH-fact generation 60 rebuild bindings written before receiver-owner
identity and member-activity barriers. Model parser generation 68 rebuilds
type activity diagnostics. `cSemanticRemoveWithBindingFlagMemberActivityUnverified`
uses the existing binding flags field; the snapshot/cache SQLite schemas and
`DS-ACTIVITY-1` wire format are unchanged.

`TDelphiSemanticDeclaration.AstHelperKind` is empty when helper syntax is unverified,
or `none`, `class` or `record` when the active syntax tree proves it. Root-member
lineage evidence keeps `AstHelperKind`, `HelperTargetName`, `IsHelper` and
`HelperCovered` together; a helper name alone cannot prove complete coverage.

`TDelphiSemanticModelObservation` carries `ProjectContextFingerprint`,
`ModelFileName`, `SourceObservations`, `IncludeFileNames` and `CacheHit` to the
request-owned observation validator described above. These fields describe the
actual model inputs and cache path; they are not caller-supplied edit authority.

DS-721 preserves verified parent-file type body endpoints across standalone includes.
Member activity is evaluated against each verified physical origin segment inside the
type output range, including nested includes. Transient activity spans and line origins
carry the copied-source ExpansionId, so repeated inclusions of the same file cannot
share activity authority. Unavailable origin or occurrence evidence retains the
conservative unit-wide activity fallback. Persisted layouts and generations are unchanged.
Context member hits must have a declaration identity in the receiver lineage,
including same-unit hits. A routine-local homonym cannot supply a unit-level member.
Include-line containment authority and its persisted rows were removed after
mutation proof left S1 and origin-activity behavior unchanged.
