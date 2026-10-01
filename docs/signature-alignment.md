# Signature alignment (in progress)

T-619 currently exposes read-only comparison through
`TDelphiSemanticSignatureAlignment.Compare`. There is no DAK signature command
or applicable alignment edit plan yet.

Select a class method declaration by model file name and its exact original-source
identifier offset (the model's 1-based UTF-16 `Offset`). The library uses complete
source models and a source-backed type index to compare that declaration with
implementations in the same unit. It resolves overloads by parameter type identity,
mode, count, return type and calling convention; parameter names are compared only
after pairing. Existing signature/type comparison is reused.

The result contains `Status`, `Reason`, `DeclarationIndex` (the selected model's
Members array) and `ImplementationIndex` (its Routines array). Indices are zero-based;
-1 means no selected entry. Status is `aligned`, `name-drift`, `mismatch` or `unknown`.
Duplicate compatible declarations/implementations remain unknown. An exact source
selector and complete unique source class declaration are required.

These are comparison facts, not edit authorization, complete reference proof or
compiler certification. Broken but parseable source can be compared. In the retained
Win64 fixture, implementation parameter-name drift produces compiler E2037; automatic
apply must still fail its baseline gate. The eventual repair suggestion must be
explicitly non-applicable in that case, with compiler diagnostics retained.

Current type coverage follows the source-backed consistency comparer. Intrinsic
synonym identity, nested alias identity and unsupported structured/procedural parameter
types remain unknown. Implementation-only visibility and remaining context/directive
coverage still need proof. Name-capture checks, bound-reference edits, applicable-plan
integration and DAK contracts remain unfinished. Existing public API signatures are
unchanged; the comparison entry point is additive.

Evidence: `tests/.dak/delphiSemanticsTests/refactoring-light-align/`. The initial
six comparisons have strict RED/GREEN; two ambiguity cases have guard-removal RED
and restored GREEN. This is not completed slice-5 or paired-final acceptance.
The snapshot binding prerequisite now distinguishes qualified members from same-named
parameters. It resolves proven `Self` members, supported unit-qualified declarations
and uniquely identified class variables. The tested unsupported object receiver is
unresolved. Extraction can drop a leading Unicode character; snapshot binding now
rejects partial identifier matches and retains the full receiver text so an ASCII
suffix cannot bind to another declaration. Full Unicode identifier support remains
unproven; the native probe preserves structured signature names but lacks positional
parameter inventory despite an
`ast` status. That status alone cannot certify locatable parameter facts. Fresh-model
and retained-snapshot checks cover the same tested targets; this
still does not authorize alignment edits or prove complete reference coverage.
`InspectParameterChanges` adds a read-only parameter mapping for a uniquely paired
method. `Comparison` retains the comparison result. `Known` means that the
implementation parameter inventory matches its structured signature and source
header; it does not certify body references or authorize edits. Each `Changes`
entry contains a zero-based `ParameterIndex`, copied `Original` parameter facts,
and the selected declaration's `ReplacementName`. Unchanged names are omitted.

The location check requires matching counts, names, types and modes, ordered
non-overlapping header spans, whole identifiers, parameter-name separators and
matching line/column coordinates. Missing or inconsistent evidence returns
`Known=false`, reason `alignment.parameter-positions-unavailable`, and no partial
mapping. Other comparison failures retain their comparison reason. The Unicode
positional-inventory gap is refused even when structured signature comparison
succeeds. Body-reference coverage, capture checks and snapshot-bound edit planning
remain required before this information can become an alignment suggestion.

The provisional `PlanAlignment` implementation reuses the captured-context binder
with operation `signature.align-implementation`, full body/reference analysis and
mandatory fresh-context, same-intent, baseline-build and post-edit-build verification.
It emits implementation parameter and snapshot-bound reference edits for the
initial supported fixture, and refuses tested local, nested-parameter, field and
unresolved-name capture. This implementation is not accepted or exposed by DAK:
complete token/reference inventory checks, stale supplied-fact checks, broader
binding-map proof and compiler/recovery integration remain unfinished. A structural
`Complete` result does not itself authorize mutation. No new extraction or apply
command is provided.

The provisional planner now requires model-fact fingerprints captured with the
snapshot, in addition to matching source text. Divergent references, declaration
signatures, local inventories or enclosing-scope facts are refused with
`alignment.model-evidence-mismatch` and no plan. Missing fingerprints also refuse
planning. Binding identity includes the captured semantic fingerprints. This does
not establish complete reference extraction or authorize mutation. Cache-hit
availability and cost verification remain open under T639.

The provisional planner also checks selected-routine source tokens against retained
reference, parameter and local facts. Unaccounted-for old or replacement-name uses
return `alignment.reference-proof-unavailable`; the assembler-body examples expose
why complete AST status alone is insufficient. T640 now retains the tested fields after same-line visibility keywords, and the
alignment preservation case leaves comments, literals and the qualified field
unchanged. Unknown qualified targets remain refused; full feature acceptance is open.

Field-layout coverage currently includes consecutive ordinary fields, visibility
changes between fields, and a persistent `class var` section on one physical
line. Source coordinates are retained for each tested field. Mixed method,
property and field declarations on one line, and compound variant-record layouts,
are not certified by this coverage. Consumers must not treat a missing member or
`ScopeModelStatus=ast` as proof of absence. Automatic alignment remains unavailable
until the remaining binding and mutation gates pass.
The provisional planner supports multiple parameter-name changes, including a
simultaneous swap. It first requires a complete set of edits bound to the original
snapshot. An existing name is exempt from capture checks only at a declaration or
reference location that this edit set proves will move to a different name.
Unchanged locals and nested parameters still cause refusal. The tests check both
parameter headers and their bound body uses; no edit is applied sequentially to
already changed text. These are repair-plan facts, not evidence of a successful
compiler baseline or authorization to apply.

A mixed `procedure Other; private aOldValue: TValue;` declaration on one physical
line has native Win64 legality/runtime proof. Its missing field reference causes
`alignment.reference-proof-unavailable` and no plan in the current extractor.
This explicit refusal does not certify all mixed member layouts.