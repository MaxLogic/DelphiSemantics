# Read-only consistency facts

The Refactoring Light consistency work is still in progress (T-621 and T-630).
These APIs return semantic facts; they do not edit source or establish that a
project builds. DAK owns DFM loading, command contracts and user-facing reports.

`DelphiSemantics.Consistency.EventSignatures` compares structured procedure
signatures. Results are `match`, `mismatch` or `unknown`, with a reason string.
Parameter names do not determine compatibility. Parameter modes, count,
calling conventions and resolved type declaration identities do. Qualified
types must be visible from the signature's declaring unit.
An omitted calling convention is treated as `register` for comparison. Explicit
convention differences still produce a mismatch; this behavior is compiler-proven
with Delphi 12 Win64 method-pointer assignments.

`DelphiSemantics.Consistency.EventBindings` resolves a published event property
and a published handler through source-defined component and form ancestors.
It returns declaration file, unit, owner, name, line and column evidence.
Ancestor traversal detects cycles and does not fall back to a global simple-name
match. Missing or ambiguous models, unavailable ancestry, unresolved event
types and collapsed same-line handler overloads produce `unknown`.

Current limitations:

- The original `Compare` API has no source models and does not expand aliases.
  `CompareInContext` and event binding resolution expand supported unit-scoped
  aliases only through complete source declarations and their own interface imports.
  Ordinary aliases share target identity; strong aliases retain distinct identity.
  Cycles, ambiguous/missing/partial declarations and stale index positions or files
  remain unknown. Even zero-parameter signatures require complete declaring models.
- Unsupported structured parameter types, such as open arrays, remain unknown.
- An absent handler returns `missing-handler` only after a complete source-backed
  ancestor search. Missing/recovered/rejected models and unavailable ancestors
  remain `unknown`; a retained declaration alone cannot prove a match.
- Binary-only event declarations and unresolved ancestry cannot establish a match.
- These APIs do not replace DAK's existing DFM streaming checks.

The model stores method declaration signatures on members and implementation
signatures on routines. JSON persistence and cache copies retain structured
signatures, including independently owned parameter arrays. The default parser
cache identity is version 27; older default entries require fresh extraction.

`SkipBodyAnalysis` preserves declarations from valid implementation sections.
If full parsing fails and this option is enabled, extraction may recover an
interface projection. Its `ScopeModelStatus` is `ast-interface-only`, not `ast`.
Consumers must not treat that projection as complete project/refactoring proof.

Current tests and evidence live under
`tests/.dak/delphiSemanticsTests/refactoring-light-consistency/` and the separate
SQLite project's corresponding directory. Earlier passing suites do not
certify later source changes or complete slice 7.

Default-parameter expression identifiers retain their source positions, section
and AST routine scope. Declaration/implementation pairs with the same known
routine scope can resolve references when only declaration defaults differ.
Missing scope evidence retains signature-based ambiguity checks. Snapshot and
remove-with fact caches use identity v12 to rebuild older reference targets.
An interface default that uses an imported constant prevents moving that import
to the implementation section; automatic uses moves remain unavailable.

Forward class/interface/dispinterface declarations retain DeclarationRole=forward
from the AST declaration node. They cannot establish a complete ancestor member
inventory. Duplicate or forward-only class evidence stays unknown for handler
lookup; JSON retains the role without a new public field or API signature.

`InspectClassAncestry` returns the validated self-to-base class prefix plus
`Complete` and `Reason`. A partial prefix is not proof of complete ancestry.
Missing, hidden, ambiguous, incomplete, forward-only and non-class bases, class
aliases and cycles remain explicit refusals. An implicit TObject boundary ends
a complete source-class chain; it does not establish DFM resource ancestry.

`ResolveInContext` accepts the unit that originally declares the component
separately from the descendant form unit in the binding. This preserves component
type lookup when the descendant cannot see, or hides, its ancestor's imported
component class. Handler lookup still starts at the descendant form. Missing
component declaration context remains unknown. Existing `Resolve` delegates with
the binding unit as both contexts, preserving its public signature and behavior.
DAK uses these facts for its supported inherited text-DFM merge; the library
does not read or merge DFM resources.

A complete source-backed enum, class, record or interface property returns
`not-event` with `binding.property-not-event`. Consumers may exclude that
assignment from event diagnostics. The property name, including an `On` prefix,
does not establish its type. Forward-only, missing and unsupported type facts
remain `unknown`. Supported aliases to these source types are classified through
their underlying declarations; builtin types are not generally classified.

Enum values retain AST identifier positions and their declaring type name.
Scoped enum values carry their complete enclosing type path and owner name; unscoped enum values retain
the enclosing scope. Enum values are immutable. JSON and persisted unit models
retain these facts. Parser27 changes each unit cache key; snapshot and remove-with
cache contexts already include those keys, so their schema remains version12.
These facts alone do not certify qualified enum reference resolution.
Nested type declarations retain their containing type scope, so equal nested type
names in different classes have distinct identities. Unscoped enum values retain
unit/routine scope even when the enum type is nested. Types beside the type keyword
retain their identifier positions; their methods are not top-level routines.

Event-type aliases preserve the underlying procedure declaration and its unit for
parameter lookup and report evidence. A caller importing a unit cannot make that
unit visible to an alias declared elsewhere. Nested aliases, intrinsic synonym
identity and procedural/structured parameter compatibility remain unsupported.
