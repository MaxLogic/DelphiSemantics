# DelphiSemantics API

Use `DelphiSemantics.Api` for common project and semantic-index operations.
It gives DAK and future integrations one stable entry unit. Lower-level units
remain available for focused tests and internal implementation.

## Ordered visible type names

`TDelphiSemanticTypeIdentityIndex.ResolveVisibleName` resolves the declaring
unit first, then used units from last to first. `VisibleUnitNames(Unit, Section)`
returns interface imports followed by implementation imports when applicable.
A later unit with unknown declarations makes an earlier match `unproved`
(`TYPE_VISIBILITY_UNPROVED`, `Found=False`, no candidates). Qualified lookup is
unchanged. Ancestry, alias, binding and consistency consumers use that ordered
scope and retain uncertainty when lookup is unproved.
A shared WITH admission gate refuses unproved or ambiguous receiver and capture
type visibility after every established refusal check. Unsupported body references
alone do not trigger it. Strategy decisions remain provisional until this gate
accepts the statement; refused decisions publish no edits, temps or declarations. Failed pointer-alias and pointee proofs
stay unproved even when a fallback emits a different underlying type; an inventory
name match cannot turn that uncertainty into a plan.
An admission-refused WITH is also a barrier for every nested WITH: the retained
receiver may capture inner selectors and generated names. Descendants refuse with
`enclosing-admission-refusal:receiver-type-not-visible`. Admitted ancestors and
other siblings retain the existing planning rules. When siblings refuse, shared
routine declarations contain only surviving temps; those temps may be renamed
consistently within the routine.

A project session attaches a source-token witness to every binder type index,
including synthetic graphs. Absence is proved only for an unindexed unit with
exactly one SDK pair: a library DCU and its same-named readable Pascal source
under the active Delphi installation's `source` tree. Project and third-party
sources, unpaired SDK sources and DCU-only units remain unknown even when a
readable source does not contain the name.

The candidate union includes the project directory, unit search paths,
DCCReference directories, active Delphi library, browsing and debug DCU paths,
and the SDK source tree. Any second Pascal source, unpaired DCU or incomplete
profile location evidence leaves the name unproved. Compiler search-order
preferences do not establish absence. Installed default unit aliases are read
from `CodeGear.Common.Targets` for the active platform, followed by the project's
`DCC_UnitAlias(es)`. Several distinct targets for one alias key, across defaults and project aliases,
make the result unknown; exact duplicate targets are harmless. The alias key and
its target are scanned as a union. Scope-expanded names reaching the same physical
file form one candidate; different files remain unknown. If the defaults cannot be
read or evaluated, known default alias keys on any platform remain unknown.

SDK includes resolve only within that installation's `source` tree, in the
including file's folder and the root unit's folder. A missing include or two
distinct matching files makes the unit unknown. Project include, reference,
search, library and debug paths cannot supply SDK source includes.

The conservative witness parser accepts both include spellings and comment
forms with space, tab and line-break separators. The tested dcc64 layouts
reject line-break separators with E1030. `INCLUDE+names.inc` and
`INCLUDE-names.inc` include those filenames; only the single-letter `I+` / `I-`
forms are compiler switches, including `I+ x` and `I+x`. Other directive names
are outside include recognition; an unparseable I/INCLUDE argument leaves
content unknown. Tokens in comments, strings and inactive branches can cause
conservative refusals. SDK source, include and default-alias file hashes
participate in warm-cache identity. Affected persisted planning facts rebuild.

Include discovery considers every directive opener independently, even in strings
and comments; unresolved include-looking text cannot establish absence. Paths
passed only on the dcc command line, outside the dproj and IDE profile, are not
visible to DS. Units supplied only through runtime-package `.dcp` files are not
modelled. Installed SDK source is assumed to match the installed DCU.

Unknown activity affects import order only where it can change a uses clause
or its section. Resolved includes with known content activity are expanded in
place before checking clause text and AST imports. Without per-include activity
evidence, conditional or define directives in included content remain unknown;
nested includes follow the same rule. Unresolved includes and imports missing
from the expanded clauses keep import order unproved. Failed models and unavailable activity evidence
remain unproved. WITH capture lookups persist their spelling, status and type
identity. The admission gate removes candidates with unproved or ambiguous
receiver/capture evidence. Existing per-strategy visibility and contradictory
identity checks remain additional refusals. Unknown import
sentinels never reach a root-absence provider as unit names. Verified receiver kinds must agree with the
planner's chosen strategy. All established refusal reasons retain precedence. The gate checks absorbed
children before publication and discards provisional temp-name reservations when
it refuses a statement. A kind refusal retains its candidate with zero edits and temps. Binder lineage
denials remain final across all body qualification passes.

Snapshot cache schema 20 and WITH facts generation 71 rebuild older persisted
planning facts for these additional capture fields and witness identities.

## Named root absence

`DelphiSemantics.RootMemberAbsence` adds `TDelphiSemanticQualifiedRootType`
(`Kind`, `TypeName`, ordered `LookupUnits`) and the optional
`IDelphiSemanticNamedRootMemberAbsence`. Providers remain assigned through
`ImplicitRootMemberAbsence`; DS discovers the optional interface with `Supports`.
`IsNamedRootMemberAbsent(Root, SiteUnits, Name)` returns True only for a name
proved absent from the resolved root, including constructors and class methods.
`LookupUnits` carries the effective declaration scope of the root-most indexed
class, the one declared directly on the unindexed root. Its interface imports
come first; implementation imports follow only for an implementation declaration.
`SiteUnits` separately carries the site's ordered imports. Intermediate class
imports are validated but are not merged into the site scope.

The native witness models these scopes in separate units. A real subclass in
the base probe captures the helper methods active at the root-most declaration.
The site probe also sees its own active helpers. Delphi selects one helper per
type by the last applicable import; helpers for ancestor types can coexist.
Captured helper methods remain visible on descendants. Property visibility also
depends on accessor visibility: the Win64 compiler retained a property with a
public getter but not its private-getter counterpart. The structural probe leaves
that distinction to the compiler. The defining SDK root unit remains a conservative prefix,
which can cause additional refusals. Each scope resolves namespace and alias
spellings to SDK unit identities before retaining the last duplicate position.
Unknown selection, missing scope inputs, local or nested declarations, unresolved includes,
and generic ancestry retain refusal. A False result or provider exception also
preserves refusal.
An empty evidence fingerprint never authorizes a query result.

DS queries only verified indexed class/interface lineages ending in an unresolved
simple or dotted root. Aliases, local types, ambiguous roots, indexed class helpers,
incomplete models and unverified activity refuse conservatively. The original closed
implicit-class provider path remains available. A successful proof is keyed by site
unit, terminal DeclaredId and case-insensitive name; it is never exported or persisted.
Provider-backed requests bypass persistent planning facts. Generic class headings or generic bases anywhere in an
ancestry chain are refused before invoking the named provider; generic ancestry
resolution remains outside this API. Unresolved nested receiver origins cannot
authorize bare names under a retained outer WITH.
Resolved includes are expanded before the named-root declaration and site uses scopes are built. An include filename alone does not refuse a proof. Missing receiver evidence or owner rows, failed site or receiver-lineage models, failed expansion, or unverified or unsupported preprocess activity refuses root absence proof on both named-root and closed implicit-TObject routes; uncertainty cannot bypass the planner guard. The closed implicit-TObject route plans only when positive absence proof exists, including for resolved includes on DS routes. The DAK native route rejects source profiles with conditional or include directives for root-member proof; statements that need that proof retain zero-edit refusals there.

The DAK native provider requires a native project context captured from a project
that imports `CodeGear.Delphi.Targets`. Minimal project files without that context
report `native-root-proof-unavailable` and retain zero-edit refusals.

The final reverse receiver guard checks references left bare and qualifications
to retained outer receivers against each receiver actually removed. An unproved
class/interface receiver refuses with `receiver-member-not-found` and
`OWNER_INHERITED_MEMBERS_UNVERIFIED`; an alias receiver uses
`ALIAS_RECEIVER_MEMBERS_UNVERIFIED`. Retained receivers keep their original binding
scope and do not independently require absence proof. A selector marked
`PARENT_SELECTOR_UNRESOLVED` does not exempt its removed receiver from this check.
Refusals have no replacement, temporary, or final text edit.

A narrow identical-storage exception permits removing an inner WITH while an
enclosing WITH on the same receiver remains. The planner must prove the same
source-backed declaration and lexical scope at both sites, prove the receiver
designator absent from the outer receiver's members, and prove that no intervening
executable statement can change the receiver. Only plain identifier storage is
currently proved; calls, indexing, dereferencing, property getters and unproved
field chains fail closed. Empty compound-statement prefixes are allowed. The
complete compiler-profile TSearchRec member witness can prove a designator name
absent across a strong alias, but does not weaken body-member checks; visible
helpers disable that shortcut. Thus `with SR do with SR do Name := 'x'` may remove
only the repeated inner WITH, while a different variable of the same type and
`with GetSR do with GetSR do ...` remain refused. `with Foo do with Bar do Y := Tag`
still refuses when Bar's lineage has no proof that Tag is absent.

Unindexed-root facts are separate from verified indexed terminal coverage, and
WITH-facts generation 65 rebuilds older planning facts. Snapshot generation 49 is unchanged.

The native request guard rechecks the selected and absent unit candidates across
project, main-source, DCU-output, reference and effective unit-search directories
before reusing evidence or finalizing a plan. New shadowing units invalidate the
request even when all previously captured files are unchanged.

## Alias receiver members

WITH binding follows weak and strong alias targets through their verified DeclaredId
lineage. Fields, methods and class variables retain the declaring owner's name;
constants and variant tags retain the selector type name. Remove-with matches binder
receiver members against decision lineages, innermost first, before its inventory
fallback. Binder receiver members bypass lexical unchanged exemptions. A member
without a usable qualification refuses with `receiver-member-unqualified`.

A strong alias with a possibly applicable indexed or unindexed helper refuses with
`ALIAS_RECEIVER_MEMBERS_UNVERIFIED`, retaining no edits, temporaries, replacement
text or candidate. Unresolved helper targets remain conservative. A chain with
any strong alias also refuses when a reference may be its member and cannot
be qualified, including references inside absorbed nested WITH statements. This
covers unindexed RTL/profile terminals and plain TSearchRec.Name or Size accesses.
WITH-facts generation 65 and snapshot generation 49 invalidate earlier entries.

Alias receivers whose target lineage cannot be verified refuse with
`ALIAS_RECEIVER_MEMBERS_UNVERIFIED` and no candidate edits. This includes
generic instantiations, including receivers without a declaration identity.
Routine-local strong aliases retain `ROUTINE_LOCAL_TYPE_UNSUPPORTED`, including
when a nested routine captures a receiver typed by an enclosing routine alias.
Verified weak aliases from enclosing routines still qualify their members. Escaped target identifiers (`&Ident`) use the
ordinary identifier spelling for lookup. A missing extracted alias declaration
does not authorize lexical fallback: a matching source-token alias candidate
causes conservative refusal. Weak aliases ending at a unique, unshadowed
compiler-profile RTL record (including `TDB_SearchRec = TSearchRec`) retain
their earlier handling only when every alias has a matching projected
`type-member` row. Names outside the complete 18-name Delphi 12 TSearchRec member witness may remain bare.
Names in that witness require verified qualification or a refusal; the four intrinsic
qualification fields are unchanged. The installed-source drift test covers Win32,
Win64, Linux64 and OSX64. Other compiler versions require equivalent member coverage. This compatibility boundary does not apply to strong alias chains.
Every other bare reference under an alias receiver, including ambiguous overloads
used without parentheses, requires indexed proof of member absence; otherwise
the whole WITH refuses with the alias safety reason.
This check includes references carried by absorbed nested WITH statements and
preserves earlier, more specific refusals. Aliases declared on the same line
as TYPE currently lack the required projection and refuse with zero edits.
The inline layout uses `ALIAS_RECEIVER_MEMBERS_UNVERIFIED`; multiple declarations
on one line, a comment after TYPE, and a missing projection on the second alias
link retain the earlier `type-source-not-indexed` reason. Other layouts without
extracted alias projections also refuse safely.

For a strong alias, any helper target resolving to an alias is treated as
possibly applicable, even when the helper's immediate alias identity is outside
the receiver lineage. Such receivers refuse with the same alias safety reason.
Weak-alias helper receivers keep their existing resolution and refusal rules;
this slice does not resolve helpers through strong aliases.

Call references preserve `ALIAS_RECEIVER_MEMBERS_UNVERIFIED` rather than
replacing it with `CALL_SELECTOR_UNSUPPORTED`. Calls through unverified generic
aliases and strong aliases with possibly applicable helpers therefore refuse
with zero edits. Verified plain, weak-alias and strong-alias method calls keep
their ordinary qualified plans. Missing-identity alias scans are memoized for
the lifetime of the project member index; the memo includes negative results.

A routine-local receiver also refuses when its enclosing routine chain cannot
be proved uniquely, including forward-declared nested routines. The established
`ROUTINE_LOCAL_TYPE_UNSUPPORTED` reason takes precedence. Alias receivers refuse
with `ALIAS_RECEIVER_MEMBERS_UNVERIFIED` when a qualified, indexed or call-selector
fallback leaves a reference bare. Existing source qualifications and more specific
refusals remain authoritative. Indexed and qualified binding checks the receiver
root before lexical fallback so it preserves an alias refusal. This guard does
not add member qualification through alias target types.

The syntax-fallback guard preserves the existing weak-alias RTL record
boundary only when the target is the unique compatibility-profile record and
no project declaration shadows it. The check runs once per selector decision,
using declaration lookups already memoized per plan. Strong RTL record aliases
refuse at the binder boundary: a TSearchRec alias with a global Name homonym can
otherwise rewrite to the global variable. This weak-alias exception grants no new
member qualification or member-absence proof.

## Receiver-owned constants and variant tags

Receiver-owned constants and variant-record tags are published in
`TDelphiSemanticUnitModel.TypeValueMembers`, separately from ordinary `Members`.
The JSON key is omitted when the array is empty. Facts carry the declaring type,
scope and source coordinates; unverifiable extraction retains `MEMBERS_INCOMPLETE`.

WITH binding resolves these facts by verified owner DeclaredId, nearest receiver
lineage level first. Bound references use `Classification=member`,
`LookupSource=receiver` and `Kind=const`, `typed-const` or `variant-tag`.
For an inherited value member, `ReceiverTypeName` identifies the selected receiver
type, while the owner DeclaredId identifies the declaring type. Name-set checks
avoid value-member resolution for unrelated names. Ordinary nearer fields retain
precedence. Helper-owned or unverified facts refuse with
`TYPE_VALUE_MEMBERS_UNVERIFIED`; inaccessible constants use
`TYPE_VALUE_MEMBER_ACCESS_UNVERIFIED`. Cross-unit protected and strict visibility
remain conservatively refused.

Remove-with qualifies a value member only through its uniquely verified receiver.
A missing qualification refuses with `receiver-member-unqualified`; unverified or
inaccessible value members retain `SafetyReason=TYPE_VALUE_MEMBERS_UNVERIFIED`.
A statement that qualifies a D2 value member or a D3 evidence-backed tag also
refuses with `RECEIVER_MEMBERS_PARTIALLY_VERIFIED` if another bare unsupported,
unresolved or lexical reference may belong to that receiver's indexed lineage:
an unresolved or unverified receiver, alias or indexed ancestor, incomplete
indexed coverage, or a matching indexed member, tag or constant not qualified
by the plan. The guard combines qualification and bare-reference evidence over
the receiver's complete body, including nested children and siblings at every
depth. Qualifications retain their receiver DeclaredId and qualifier context.
A refusal also rejects nested statements dependent on that body and removes
their candidate edits. The model and persisted-evidence routes share the same DeclaredId
walk. An unindexed implicit or RTL root does not prove member absence. Bare names and
outer-receiver qualifications need indexed absence or recorded native root evidence.
A native lexical binding with `LookupSource=lexical` and no refusal reason
already follows verified member absence on every receiver. It does not trigger
this guard; syntax-only lexical references still require lineage verification.
An anonymous record has no ancestors. Its anchored declaration can prove a bare
name absent only after a complete record scan with known activity, matching
source lines and no unverified include. The scan covers every field, tag and
constant name; extra possible declaration names can only retain a refusal.
Missing anchors, unfinished records, unknown activity and wildcard results
never prove absence. Pointer or other anonymous forms without that complete
record witness keep the existing conservative path. This absence proof only
narrows the partial-receiver guard; it never authorizes a qualification.
Statements without a value-member-path qualification retain their previous behavior.
Parsed anonymous-record identities and complete members supplement only the DS-742 bare-reference absence guard. Guard evidence uses private owner and member keys in the existing persisted value-evidence container; it never enters binding, receiver visibility, qualification, capture, or temporary type emission. General anonymous-record behavior and earlier refusal reasons are unchanged. The nested capture shape still refuses `receiver-type-not-visible` before any temporary is chosen.
Both barriers preserve earlier refusals and remove edits, temporaries, replacement
text and candidate edits. Inventory constants cannot authorize a qualification
that the binder did not establish. Anonymous-record tag homonyms also refuse;
already qualified no-homonym plans retain their prior behavior. Named receivers
retain that path only when relevant value-member coverage is verified through
the binder's DeclaredId lineage, or no unverified name is left bare. A source
declaration with `=` or a selector identity alone does not establish coverage.
For a lexical, unresolved or unsupported name that would stay unqualified, the
planner refuses `TYPE_VALUE_MEMBERS_UNVERIFIED` if the receiver's type/alias
chain declares that value name. Indexed levels are checked by DeclaredId, with
member diagnostics scoped to the declaring receiver or lineage level. Unrelated
types' diagnostics do not invalidate receiver coverage. A forward declaration and
its full class declaration count as one owner. An unindexed class ancestor stays
under the existing root-absence and `OWNER_INHERITED_MEMBERS_UNVERIFIED` handling;
project value names do not describe RTL ancestors. Only an unresolvable receiver
or alias uses the project's `TypeValueMembers` name set as collision evidence.
This evidence never authorizes qualification. Verified member/helper references
and existing qualified edits keep their paths. The shared lookup data retains
this evidence for both facts and compatibility-snapshot planning. A model-free
lookup cannot prove value-member absence. Session SQLite project-facts loads
keep the loaded inventory and its validated value evidence in the original project
identity domain, plus the validated source/activity pair and scope status for
anonymous-record checks. A verified receiver queries coverage by its DeclaredId
and unit/file context. Name-only queries remain uncertain when the name is ambiguous.

Standalone SQLite project-facts entries persist typed relational value evidence
in the same cache-key transaction: source/activity units, per-DeclaredId owner
coverage and terminal/lineage flags, value names, unverified owner keys and type
lookup keys. The binder exports this evidence from its existing native indexes;
both model-backed and evidence-backed planner queries consume the same view.
Header and per-owner counts explicitly witness empty sets. Missing, partial or
obsolete row sets invalidate the project entry before planning. No complete
models or serialized envelope are stored by the snapshot cache. Parser generation
70, WITH-facts 64 and snapshot generation 49 invalidate earlier cache generations.
Rename and find-usages retain their conservative behavior; member-correct
type-value rename is tracked in DS-718.
The anonymous `class var` refusal remains conservative: inventory may anchor
the variable name at a use, and the required following `:` then fails (for
example on `.`). This is not verified class-var declaration provenance. A
`threadvar` inventoried as `unit-global` also remains refused when its anonymous
declaration cannot be anchored; this round does not widen the anchor kinds.

If corrupt or foreign model JSON loses `TypeValueMembers`, the fallback checks only
constants represented in legacy `Declarations`. Variant tags and same-line/peer
constants absent from `Declarations` can lose that protection. Parser generation
guards format drift; cache contents remain trusted inputs, as in DS-720. This
accepted integrity residual also applies to persisted value-evidence rows:
coordinated, well-typed tampering can make a complete row set describe no value
members. Cache files are trusted inputs. This residual does not authorize
qualification of unverified facts.

Anonymous-record scans use validated stored source activity. Known-inactive tags
and includes do not count when a physical declaration anchor and its activity mask
are usable. A missing anonymous anchor refuses only when the receiver type cannot
be resolved to a named type. Missing activity evidence and missing or mismatched
scan source refuse `TYPE_VALUE_MEMBERS_UNVERIFIED` when the body has a lexical,
unresolved or unsupported reference that could name a hidden tag. Active or unknown
includes before or inside the record also refuse. Raw physical text cannot prove
the absence of active tags behind conditional directives. Bodies whose references
all bind to verified fields retain their plans. Expanded anonymous declaration
origins are not trusted. Stored and physical lines use the same splitting rules
for CRLF and LF, including trailing line breaks. Split scan lines are cached per
file for one planning call; each body scans each selected declaration once.
Unrelated types' value-member names do not invalidate an otherwise verified direct
helper member; a candidate on the actual receiver lineage requires proof or refusal.

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

When a planned WITH has code before it on the same line, its edit starts
at that WITH and preserves the prefix. For multi-statement replacements, the
planner lexes each source file once and reuses a cached token table. It walks
backwards over whitespace and comments from the WITH. Any compiler directive
or include passed by that walk requires a begin/end wrapper. Otherwise the
nearest significant token decides: a semicolon, begin, repeat, try, except,
finally, initialization, finalization, or file start is a statement-list boundary;
then, else, a case or statement-label colon, and do require wrapping. A do
belonging to a planned parent WITH is the exception: the parent's replacement
absorbs its direct child. Existing parent decisions establish that exception.
Any other or unavailable context requires wrapping. Directive-like text inside
strings and ordinary comments does not count as a directive. Earlier directives
beyond the nearest significant token do not affect the decision.
This changes rendered edits only. Statuses retain their existing meanings and
no new refusal reason is introduced. WITH facts and snapshot generations do
not change.
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
unsupported binding and its diagnostic. A record-receiver miss refuses lexical and
outer-receiver fallback when a visible, matching record helper has no indexed
declaration. The binder reports `unsupported` with
`RECORD_HELPER_MEMBERS_UNVERIFIED`, including compiler intrinsics, local names and
call names that the helper could shadow. Helper-free and unrelated-helper receivers
retain their established behavior. Missing or unindexed used units are not treated
as possible helper sources; this remains a documented limitation.

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
one cached DTO view per snapshot binding source. Snapshot producer generation 47
and WITH-fact generation 62 rebuild bindings
written before inactive nested WITH safety verification. Model parser generation 69 rebuilds
models with structured unindexed helper facts. `cSemanticRemoveWithBindingFlagMemberActivityUnverified`
uses the existing binding flags field; the snapshot/cache SQLite schemas and
`DS-ACTIVITY-1` wire format are unchanged.

Reference, member and lexical lookup caches distinguish the source model's file
identity as well as its unit and routine. Reference entries also distinguish the
number of same-unit unindexed-helper facts visible at the WITH site, including
overloads with the same lookup name. Reuse within one model is unchanged.
Cached unit-model copies own independent helper-fact arrays. Helper JSON fields
must be JSON strings rather than numbers, booleans or null. The reader accepts
the extractor's helper kinds (empty, record, class), sections (interface,
implementation, initialization, finalization) and scopes (unit, routine).
Empty kind and target metadata round-trip unchanged; the binder applies its
existing unknown-target rule. Malformed entries leave a diagnostic/fact deficit
and fail closed. Line and Column must both be present as nonnegative JSON
integer tokens in the Integer range, including zero for unknown positions;
malformed coordinates drop the whole fact. Cache files are trusted: generation
and value validation protect against format drift, not deliberate tampering,
so a well-typed but wrong coordinate can still move a helper past a WITH site. After expansion, root-file helper positions use verified
physical line origins; helpers in included files retain an unknown root position
and their origin filename.

`TDelphiSemanticDeclaration.AstHelperKind` is empty when helper syntax is unverified,
or `none`, `class` or `record` when the active syntax tree proves it. Root-member
lineage evidence keeps `AstHelperKind`, `HelperTargetName`, `IsHelper` and
`HelperCovered` together; a helper name alone cannot prove complete coverage.

`TDelphiSemanticUnitModel.UnindexedHelpers` contains one
`TDelphiSemanticUnindexedHelperFact` per `AST_HELPER_DECLARATION_UNINDEXED`
diagnostic. Each fact retains the helper name, kind, target, section, lexical scope,
owner scope ID and physical source coordinates. `FileName` is empty for the unit's
own file; include or unverified positions have zero line/column. Model JSON omits
`UnindexedHelpers` when empty. Missing facts in a diagnostic-bearing model fail
closed. Visibility uses the WITH site and helper declaration identity, including
alias lineage; canonical type text does not establish matching identity.

The final planner defers this refusal until established selector and renderer
refusals have finished. It reports `skipped` with ordinary
`receiver-member-not-found` for an assignment target or `symbol-not-found` for
other references, and `SafetyReason=RECORD_HELPER_MEMBERS_UNVERIFIED`. Refused
statements have no edits, temps, replacement text or `remove-with-candidate` edit.
Independent earlier refusals retain their reasons. DS-724 v4 refuses an outer WITH
when any known-inactive span inside its body contains a WITH header token:
`Reason=inactive-nested-with-shadowing`, `SafetyReason=INACTIVE_NESTED_WITH_SHADOW`.
The existing `InactiveSpanSkipReason` fact carries `INACTIVE_NESTED_WITH_SHADOW`
independently of reference ownership; `SkipReason` retains established refusals.
Detection skips comments and quoted strings (including doubled quotes),
uses Unicode identifier boundaries, and excludes escaped `&with` identifiers.
Activity comes only from stored evidence. No subject, type, absence or governed
extent reasoning is performed. Bodies with no rewritten name also refuse.
Real `{$I ...}` / `{$INCLUDE ...}` directives in known-inactive spans also refuse,
since their contents can hide a WITH header. Compiler switches `{$I+}` / `{$I-}`
are excluded. Other inactive spans without a WITH token keep existing behavior; unknown activity keeps
`activity-unverified`. This refusal has
zero edits, temps and replacement text, removes the candidate edit, preserves
earlier refusal precedence and propagates to covering parents. Nested child refusal propagates
to its parent; every contained WITH also receives the barrier, preventing independent
child edits inside the refused range. Snapshot planning preserves the same result.

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

Verified local receivers through aliases remain warm-unreachable on standalone and warm-session SQLite routes (DS-743): the pre-existing guard rejects them with `Snapshot local receiver scope chain is incomplete.` and invalidates the cache entry. The session rebuilds cold; unit-scope aliases support persisted-cache hits.

Alias-lineage and strong-alias helper refusals preserve established selector and
statement refusal reasons. An unfinalizable local alias retains
`ROUTINE_LOCAL_TYPE_UNSUPPORTED`; the alias safety rule applies only after
existing resolution and planning checks permit the receiver.
