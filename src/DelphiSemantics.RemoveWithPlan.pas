unit DelphiSemantics.RemoveWithPlan;

interface

uses
  DelphiSemantics.CompilerProfile, DelphiSemantics.ProjectContext, DelphiSemantics.Snapshot, DelphiSemantics.Snapshot.RemoveWith,
  DelphiSemantics.WithBinding;

type
  TDelphiSemanticRemoveWithSourceRange = record
    StartLine: Integer;
    StartColumn: Integer;
    EndLine: Integer;
    EndColumn: Integer;
  end;

  TDelphiSemanticRemoveWithVerification = record
    Kind: string;
    Description: string;
  end;

  TDelphiSemanticRemoveWithEdit = record
    Kind: string;
    FileName: string;
    StatementId: string;
    ExpectedFileHash: string;
    ExpectedSourceText: string;
    Range: TDelphiSemanticRemoveWithSourceRange;
    ReplacementText: string;
    ApplyMode: string;
    SemanticReason: string;
    SemanticId: string;
    ReferenceIds: TArray<string>;
  end;

  TDelphiSemanticRemoveWithSkippedStatement = record
    FileName: string;
    StatementId: string;
    Range: TDelphiSemanticRemoveWithSourceRange;
    Reason: string;
    SafetyReason: string;
    SemanticId: string;
  end;

  TDelphiSemanticRemoveWithStatement = record
    FileName: string;
    StatementId: string;
    Range: TDelphiSemanticRemoveWithSourceRange;
    Status: string;
    Reason: string;
    SafetyReason: string;
    SemanticId: string;
    CoveredByStatementId: string;
  end;

  TDelphiSemanticRemoveWithSourceVerification = record
    ExpectedFileHash: string;
    ExpectedSourceText: string;
    Range: TDelphiSemanticRemoveWithSourceRange;
  end;

  TDelphiSemanticRemoveWithFinalTempDecision = record
    SelectorText: string;
    QualifierText: string;
    Strategy: string;
    ReceiverType: string;
    TempName: string;
    DeclarationText: string;
    InitializationText: string;
    Reason: string;
    SemanticId: string;
  end;

  TDelphiSemanticRemoveWithFinalTextEdit = record
    Kind: string;
    FileName: string;
    StatementId: string;
    Range: TDelphiSemanticRemoveWithSourceRange;
    ReplacementText: string;
    SemanticId: string;
    Verification: TDelphiSemanticRemoveWithSourceVerification;
  end;

  TDelphiSemanticRemoveWithRewriteSelectorDecision = record
    SelectorText: string;
    QualifierText: string;
    Strategy: string;
    ReceiverType: string;
    TempName: string;
    DeclarationText: string;
    InitializationText: string;
    Reason: string;
    SemanticId: string;
  end;

  TDelphiSemanticRemoveWithRewriteRecipe = record
    Status: string;
    Reason: string;
    SafetyReason: string;
    RuleId: string;
    Provenance: string;
    RenderInstruction: string;
    ReplacementRange: TDelphiSemanticRemoveWithSourceRange;
    ReplacementText: string;
    SelectorDecisions: TArray<TDelphiSemanticRemoveWithRewriteSelectorDecision>;
    TempDeclarations: TArray<TDelphiSemanticRemoveWithFinalTempDecision>;
    TextEdits: TArray<TDelphiSemanticRemoveWithFinalTextEdit>;
  end;

  TDelphiSemanticRemoveWithFinalStatement = record
    FileName: string;
    StatementId: string;
    SemanticId: string;
    RoutineName: string;
    Status: string;
    Reason: string;
    SafetyReason: string;
    UnsupportedIdentifierRole: string;
    Range: TDelphiSemanticRemoveWithSourceRange;
    ReplacementText: string;
    Verification: TDelphiSemanticRemoveWithSourceVerification;
    Edits: TArray<TDelphiSemanticRemoveWithFinalTextEdit>;
    Temps: TArray<TDelphiSemanticRemoveWithFinalTempDecision>;
    RewriteRecipe: TDelphiSemanticRemoveWithRewriteRecipe;
    ReferenceIds: TArray<string>;
  end;

  TDelphiSemanticRemoveWithPlanParityEdit = record
    Kind: string;
    FileName: string;
    StatementId: string;
    Range: TDelphiSemanticRemoveWithSourceRange;
    ReplacementText: string;
  end;

  TDelphiSemanticRemoveWithPlanParityStatement = record
    StatementId: string;
    FileName: string;
    Status: string;
    Reason: string;
    UnsupportedIdentifierRole: string;
    ReplacementText: string;
    Edits: TArray<TDelphiSemanticRemoveWithPlanParityEdit>;
  end;

  TDelphiSemanticRemoveWithPlanParityMismatch = record
    Kind: string;
    StatementId: string;
    FileName: string;
    ExpectedStatus: string;
    ActualStatus: string;
    Reason: string;
    EditKind: string;
    EditRange: string;
    ReplacementTextDigest: string;
    ReplacementTextExcerpt: string;
    Message: string;
  end;

  TDelphiSemanticRemoveWithPlanParityReport = record
    MismatchCount: Integer;
    Mismatches: TArray<TDelphiSemanticRemoveWithPlanParityMismatch>;
    SummaryText: string;
  end;

  TDelphiSemanticRemoveWithPlan = record
    Operation: string;
    Status: string;
    ContextFingerprint: string;
    BaselineSemanticModelVersion: string;
    Diagnostic: string;
    Diagnostics: TArray<TDelphiSemanticDiagnostic>;
    RequiredVerification: TArray<TDelphiSemanticRemoveWithVerification>;
    Statements: TArray<TDelphiSemanticRemoveWithStatement>;
    Edits: TArray<TDelphiSemanticRemoveWithEdit>;
    SkippedStatements: TArray<TDelphiSemanticRemoveWithSkippedStatement>;
    FinalStatements: TArray<TDelphiSemanticRemoveWithFinalStatement>;
  end;

  TDelphiSemanticRemoveWithPlannerMetrics = record
    SnapshotBuildMilliseconds: Int64;
    SnapshotBindingMaterializationMilliseconds: Int64;
    CorePlanMilliseconds: Int64;
    SemanticPlanUnattributedMilliseconds: Int64;
    CandidateEditMilliseconds: Int64;
    BindingTreeMilliseconds: Int64;
    DecisionMilliseconds: Int64;
    RoutineDeclarationMilliseconds: Int64;
    StatementRefreshMilliseconds: Int64;
    CorePlanUnattributedMilliseconds: Int64;
    LookupRequestCount: Int64;
    LookupResultMaterializationCount: Int64;
    LookupResultReuseCount: Int64;
    LookupMaterializedSymbolCount: Int64;
  end;

  TDelphiSemanticRemoveWithPlanner = record
  public
    class function Plan(const aFacts: TDelphiSemanticProjectWithBindingFacts):
      TDelphiSemanticRemoveWithPlan; overload; static;
    class function Plan(const aSnapshot: TDelphiProjectSnapshot):
      TDelphiSemanticRemoveWithPlan; overload; static;
    class function Plan(const aSnapshot: TDelphiProjectSnapshot;
      out aMetrics: TDelphiSemanticRemoveWithPlannerMetrics):
      TDelphiSemanticRemoveWithPlan; overload; static;
  end;

  TDelphiSemanticRemoveWithPlanParity = record
  public
    class function Compare(const aSemanticPlan: TDelphiSemanticRemoveWithPlan;
      const aExpectedStatements: TArray<TDelphiSemanticRemoveWithPlanParityStatement>):
      TDelphiSemanticRemoveWithPlanParityReport; static;
  end;

implementation

uses
  System.Classes, System.Diagnostics, System.Generics.Collections, System.Generics.Defaults,
  System.Hash, System.IOUtils, System.StrUtils, System.SysUtils,
  SimpleParser.Lexer, SimpleParser.Lexer.Types,
  DelphiSemantics.Model, DelphiSemantics.Model.Text, DelphiSemantics.RemoveWith.Visibility, DelphiSemantics.RemoveWithPlan.FinalBodyRenderer,
  DelphiSemantics.RemoveWithPlan.FinalRewrite,
  DelphiSemantics.Resolve.TypeResolver,
  DelphiSemantics.SourceConditionals, DelphiSemantics.SourceContext,
  MaxLogic.StrUtils;

type
  TPlannerRoutineLookupResult = record
    Found: Boolean;
    Symbol: TDelphiSemanticInventorySymbol;
  end;

  TPlannerLookupMemo = class
  private
    fDeclarationsByName: TDictionary<string,
      TArray<TDelphiSemanticInventorySymbol>>;
    fIndex: TDelphiSemanticRemoveWithLookupIndex;
    fMaterializedSymbolCount: Int64;
    fMembersByOwnerName: TDictionary<string,
      TArray<TDelphiSemanticInventorySymbol>>;
    fOwnerMemberResults: TDictionary<string, Boolean>;
    fRootLineages: TDictionary<string, Boolean>;
    fPointerTargetsByType: TDictionary<string, string>;
    fRequestCount: Int64;
    fResultMaterializationCount: Int64;
    fResultReuseCount: Int64;
    fRoutineScopedSymbols: TDictionary<string, TPlannerRoutineLookupResult>;
    fRoutineSymbolsByName: TDictionary<string, TPlannerRoutineLookupResult>;
    fSymbolsByName: TDictionary<string,
      TArray<TDelphiSemanticInventorySymbol>>;
    fSymbolsByOwnerType: TDictionary<string,
      TArray<TDelphiSemanticInventorySymbol>>;
    fUnitsAndGlobalsByName: TDictionary<string,
      TArray<TDelphiSemanticInventorySymbol>>;
    class function BindingNameKey(const aBinding: TDelphiSemanticWithBinding;
      const aName: string): string; static;
    class function OwnerNameKey(const aOwnerName, aName: string): string; static;
    procedure StoreOwnerMemberResult(const aOwnerName, aName: string;
      const aResult: Boolean);
    procedure StoreRoutineScopedSymbol(
      const aBinding: TDelphiSemanticWithBinding; const aName: string;
      const aFound: Boolean; const aSymbol: TDelphiSemanticInventorySymbol);
    procedure StoreSymbols(const aCache: TDictionary<string,
      TArray<TDelphiSemanticInventorySymbol>>; const aKey: string;
      const aSymbols: TArray<TDelphiSemanticInventorySymbol>);
    function TryReuseSymbols(const aCache: TDictionary<string,
      TArray<TDelphiSemanticInventorySymbol>>; const aKey: string;
      out aSymbols: TArray<TDelphiSemanticInventorySymbol>): Boolean;
    function TryReuseRoutineScopedSymbol(
      const aBinding: TDelphiSemanticWithBinding; const aName: string;
      out aFound: Boolean; out aSymbol: TDelphiSemanticInventorySymbol):
      Boolean;
    function TryReuseOwnerMemberResult(const aOwnerName, aName: string;
      out aResult: Boolean): Boolean;
  public
    destructor Destroy; override;
    function FindMembersByOwnerAndName(const aOwnerName, aName: string):
      TArray<TDelphiSemanticInventorySymbol>;
    function FindRoutineSymbol(const aRoutineName, aName: string;
      out aSymbol: TDelphiSemanticInventorySymbol): Boolean;
    function PointerTargetType(const aTypeName: string): string;
    function FindDeclarationOrTypeAliasByName(const aName: string):
      TArray<TDelphiSemanticInventorySymbol>;
    function FindUnitOrGlobalByName(const aName: string):
      TArray<TDelphiSemanticInventorySymbol>;
    function FindSymbolsByName(const aName: string):
      TArray<TDelphiSemanticInventorySymbol>;
    function FindSymbolsByOwnerType(const aOwnerType: string):
      TArray<TDelphiSemanticInventorySymbol>;
    procedure Initialize(const aIndex: TDelphiSemanticRemoveWithLookupIndex);
    function UnverifiedValueMemberMayApply(const aOwnerType, aName: string;
      const aOwnerIdentity: TDelphiSemanticTypeIdentity): Boolean;
    function ReceiverLineageDeclaresMember(const aOwnerIdentity: TDelphiSemanticTypeIdentity;
      const aOwnerName, aName: string): Boolean;
    function UnverifiedReceiverMemberMayApply(const aOwnerType, aName: string;
      const aOwnerIdentity: TDelphiSemanticTypeIdentity): Boolean;
    function ReceiverLineageHasUnindexedRoot(const aOwnerIdentity: TDelphiSemanticTypeIdentity): Boolean;
    function ReceiverMemberAbsenceProved(const aSiteUnitName, aOwnerType, aName: string;
      const aOwnerIdentity: TDelphiSemanticTypeIdentity): Boolean;
    function IsProfileRecord(const aIdentity: TDelphiSemanticTypeIdentity;
      const aAllowStrongAlias: Boolean): Boolean;
    function IsWeakProfileRecord(const aIdentity: TDelphiSemanticTypeIdentity): Boolean;
    function MaterializedSymbolCount: Int64;
    function RequestCount: Int64;
    function ResultMaterializationCount: Int64;
    function ResultReuseCount: Int64;
  end;

  TFinalReferenceQualification = (NoMatch, RetainedMember, QualifiedMember);

  TFinalSelectorDecision = record
    SelectorText: string;
    QualifierText: string;
    Strategy: string;
    ReceiverType: string;
    ReceiverIdentity: TDelphiSemanticTypeIdentity;
    RetainedIdenticalStorageProved: Boolean;
    StrategyKindContradiction: Boolean;
    CaptureDenied: Boolean;
    TempName: string;
    DeclarationText: string;
    InitializationText: string;
    Reason: string;
  end;

  TFinalReferenceRefusal = record
    Offset: Integer;
    Length: Integer;
    Reason: string;
  end;

  TFinalBodyEdit = record
    Offset: Integer;
    Length: Integer;
    ExpectedText: string;
    ReplacementText: string;
    QualifierText: string;
  end;

  TFinalQualifiedFallback = record
    Reference: TDelphiSemanticBoundReference;
    QualifierText: string;
  end;

  TFinalReceiverBodyFacts = record
    LineageDenialReason: string;
    StrategyKindContradiction: Boolean;
    CaptureDenied: Boolean;
    AdmissionDenied: Boolean;
    ValueQualifications: TArray<TFinalSelectorDecision>;
    BareReferences: TArray<TDelphiSemanticBoundReference>;
    QualifiedFallbacks: TArray<TFinalQualifiedFallback>;
  end;

  TFinalNestedReplacement = record
    ReceiverBodyFacts: TFinalReceiverBodyFacts;
    Range: TDelphiSemanticRemoveWithSourceRange;
    ReplacementText: string;
  end;

  TControlContextToken = record
    Kind: TptTokenKind;
    Line: Integer;
    Column: Integer;
    IsDirective: Boolean;
  end;

  TRemoveWithPlanFacts = record
    ContextFingerprint: string;
    ScanSources: TDictionary<string, string>;
    ScanLines: TDictionary<string, TArray<string>>;
    ScanActivityKnown: TDictionary<string, Boolean>;
    ControlSources: TDictionary<string, string>;
    ControlTokens: TDictionary<string, TArray<TControlContextToken>>;
    LookupIndex: TPlannerLookupMemo;
    Symbols: TArray<TDelphiSemanticInventorySymbol>;
    UseArchitectureStableRoutineEndTrim: Boolean;
    UnitVisibility: TRemoveWithUnitVisibility;
  end;

  TRemoveWithPlanBindingSource = class abstract
  public
    function BindingByIndex(const aIndex: Integer): TDelphiSemanticWithBinding; virtual; abstract;
    function BindingCount: Integer; virtual; abstract;
    function BindingContainsBindingByIndex(const aOuterIndex,
      aInnerIndex: Integer): Boolean; virtual;
    function BindingHasStableSourceRange(const aIndex: Integer): Boolean; virtual;
  end;

  TArrayRemoveWithPlanBindingSource = class(TRemoveWithPlanBindingSource)
  private
    fBindings: TArray<TDelphiSemanticWithBinding>;
  public
    constructor Create(const aBindings: TArray<TDelphiSemanticWithBinding>);
    function BindingByIndex(const aIndex: Integer): TDelphiSemanticWithBinding; override;
    function BindingCount: Integer; override;
  end;

  TSnapshotRemoveWithPlanBindingSource = class(TRemoveWithPlanBindingSource)
  private
    fBindings: TArray<TDelphiSemanticWithBinding>;
    fSnapshot: TDelphiProjectSnapshot;
  public
    constructor Create(const aSnapshot: TDelphiProjectSnapshot);
    function BindingByIndex(const aIndex: Integer): TDelphiSemanticWithBinding; override;
    function BindingCount: Integer; override;
    function BindingContainsBindingByIndex(const aOuterIndex,
      aInnerIndex: Integer): Boolean; override;
    function BindingHasStableSourceRange(const aIndex: Integer): Boolean; override;
  end;

  TFinalBindingIndexArray = TArray<Integer>;

  TFinalBindingChildIndexArray = TArray<TFinalBindingIndexArray>;

  TFinalBindingTree = record
    ParentIndexes: TFinalBindingIndexArray;
    RootIndexes: TFinalBindingIndexArray;
    ChildIndexes: TFinalBindingChildIndexArray;
  end;

  TFinalBindingInfo = record
    Index: Integer;
    FileName: string;
    SemanticId: string;
    Range: TDelphiSemanticRemoveWithSourceRange;
  end;

  TFinalBindingInfoArray = TArray<TFinalBindingInfo>;

class function TPlannerLookupMemo.BindingNameKey(
  const aBinding: TDelphiSemanticWithBinding; const aName: string): string;
begin
  if aBinding.SemanticId <> '' then
    Result := 'id' + #31 + aBinding.SemanticId + #31 + aName
  else
    Result := 'source' + #31 + aBinding.FileName + #31 +
      IntToStr(aBinding.Line) + #31 + IntToStr(aBinding.Column) + #31 +
      aBinding.RoutineName + #31 + aName;
end;

class function TPlannerLookupMemo.OwnerNameKey(const aOwnerName,
  aName: string): string;
begin
  Result := aOwnerName + #31 + aName;
end;

procedure TPlannerLookupMemo.Initialize(
  const aIndex: TDelphiSemanticRemoveWithLookupIndex);
begin
  fIndex := aIndex;
  fRootLineages := TDictionary<string, Boolean>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  fDeclarationsByName := TDictionary<string,
    TArray<TDelphiSemanticInventorySymbol>>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  fMembersByOwnerName := TDictionary<string,
    TArray<TDelphiSemanticInventorySymbol>>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  fOwnerMemberResults := TDictionary<string, Boolean>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  fPointerTargetsByType := TDictionary<string, string>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  fRoutineScopedSymbols := TDictionary<string,
    TPlannerRoutineLookupResult>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  fRoutineSymbolsByName := TDictionary<string,
    TPlannerRoutineLookupResult>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  fSymbolsByName := TDictionary<string,
    TArray<TDelphiSemanticInventorySymbol>>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  fSymbolsByOwnerType := TDictionary<string,
    TArray<TDelphiSemanticInventorySymbol>>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  fUnitsAndGlobalsByName := TDictionary<string,
    TArray<TDelphiSemanticInventorySymbol>>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
end;

destructor TPlannerLookupMemo.Destroy;
begin
  fRootLineages.Free;
  fUnitsAndGlobalsByName.Free;
  fSymbolsByOwnerType.Free;
  fSymbolsByName.Free;
  fRoutineSymbolsByName.Free;
  fRoutineScopedSymbols.Free;
  fPointerTargetsByType.Free;
  fOwnerMemberResults.Free;
  fMembersByOwnerName.Free;
  fDeclarationsByName.Free;
  inherited;
end;

procedure TPlannerLookupMemo.StoreOwnerMemberResult(const aOwnerName,
  aName: string; const aResult: Boolean);
begin
  fOwnerMemberResults.Add(OwnerNameKey(aOwnerName, aName), aResult);
end;

procedure TPlannerLookupMemo.StoreRoutineScopedSymbol(
  const aBinding: TDelphiSemanticWithBinding; const aName: string;
  const aFound: Boolean; const aSymbol: TDelphiSemanticInventorySymbol);
var
  lLookup: TPlannerRoutineLookupResult;
begin
  lLookup.Found := aFound;
  lLookup.Symbol := aSymbol;
  fRoutineScopedSymbols.Add(BindingNameKey(aBinding, aName), lLookup);
end;

procedure TPlannerLookupMemo.StoreSymbols(const aCache: TDictionary<string,
  TArray<TDelphiSemanticInventorySymbol>>; const aKey: string;
  const aSymbols: TArray<TDelphiSemanticInventorySymbol>);
begin
  aCache.Add(aKey, aSymbols);
  if Length(aSymbols) = 0 then
    Exit;
  Inc(fResultMaterializationCount);
  Inc(fMaterializedSymbolCount, Length(aSymbols));
end;

function TPlannerLookupMemo.TryReuseSymbols(const aCache: TDictionary<string,
  TArray<TDelphiSemanticInventorySymbol>>; const aKey: string;
  out aSymbols: TArray<TDelphiSemanticInventorySymbol>): Boolean;
begin
  Inc(fRequestCount);
  Result := aCache.TryGetValue(aKey, aSymbols);
  if Result then
    Inc(fResultReuseCount);
end;

function TPlannerLookupMemo.TryReuseRoutineScopedSymbol(
  const aBinding: TDelphiSemanticWithBinding; const aName: string;
  out aFound: Boolean; out aSymbol: TDelphiSemanticInventorySymbol): Boolean;
var
  lLookup: TPlannerRoutineLookupResult;
begin
  aFound := False;
  aSymbol := Default(TDelphiSemanticInventorySymbol);
  Result := fRoutineScopedSymbols.TryGetValue(BindingNameKey(aBinding, aName),
    lLookup);
  if not Result then
    Exit;
  aFound := lLookup.Found;
  aSymbol := lLookup.Symbol;
end;

function TPlannerLookupMemo.TryReuseOwnerMemberResult(const aOwnerName,
  aName: string; out aResult: Boolean): Boolean;
begin
  Result := fOwnerMemberResults.TryGetValue(OwnerNameKey(aOwnerName, aName),
    aResult);
end;

function TPlannerLookupMemo.FindMembersByOwnerAndName(const aOwnerName,
  aName: string): TArray<TDelphiSemanticInventorySymbol>;
var
  lKey: string;
begin
  lKey := OwnerNameKey(aOwnerName, aName);
  if TryReuseSymbols(fMembersByOwnerName, lKey, Result) then
    Exit;
  Result := fIndex.FindMembersByOwnerAndName(aOwnerName, aName);
  StoreSymbols(fMembersByOwnerName, lKey, Result);
end;

function TPlannerLookupMemo.FindRoutineSymbol(const aRoutineName,
  aName: string; out aSymbol: TDelphiSemanticInventorySymbol): Boolean;
var
  lKey: string;
  lLookup: TPlannerRoutineLookupResult;
begin
  Inc(fRequestCount);
  lKey := OwnerNameKey(aRoutineName, aName);
  if fRoutineSymbolsByName.TryGetValue(lKey, lLookup) then
  begin
    Inc(fResultReuseCount);
    aSymbol := lLookup.Symbol;
    Exit(lLookup.Found);
  end;
  lLookup.Found := fIndex.FindRoutineSymbol(aRoutineName, aName,
    lLookup.Symbol);
  fRoutineSymbolsByName.Add(lKey, lLookup);
  aSymbol := lLookup.Symbol;
  Result := lLookup.Found;
end;

function TPlannerLookupMemo.PointerTargetType(const aTypeName: string): string;
begin
  Inc(fRequestCount);
  if fPointerTargetsByType.TryGetValue(aTypeName, Result) then
  begin
    Inc(fResultReuseCount);
    Exit;
  end;
  Result := fIndex.PointerTargetType(aTypeName);
  fPointerTargetsByType.Add(aTypeName, Result);
end;

function TPlannerLookupMemo.FindDeclarationOrTypeAliasByName(
  const aName: string): TArray<TDelphiSemanticInventorySymbol>;
begin
  if TryReuseSymbols(fDeclarationsByName, aName, Result) then
    Exit;
  Result := fIndex.FindDeclarationOrTypeAliasByName(aName);
  StoreSymbols(fDeclarationsByName, aName, Result);
end;

function TPlannerLookupMemo.FindUnitOrGlobalByName(
  const aName: string): TArray<TDelphiSemanticInventorySymbol>;
begin
  if TryReuseSymbols(fUnitsAndGlobalsByName, aName, Result) then
    Exit;
  Result := fIndex.FindUnitOrGlobalByName(aName);
  StoreSymbols(fUnitsAndGlobalsByName, aName, Result);
end;

function TPlannerLookupMemo.FindSymbolsByName(
  const aName: string): TArray<TDelphiSemanticInventorySymbol>;
begin
  if TryReuseSymbols(fSymbolsByName, aName, Result) then
    Exit;
  Result := fIndex.FindSymbolsByName(aName);
  StoreSymbols(fSymbolsByName, aName, Result);
end;

function TPlannerLookupMemo.FindSymbolsByOwnerType(
  const aOwnerType: string): TArray<TDelphiSemanticInventorySymbol>;
begin
  if TryReuseSymbols(fSymbolsByOwnerType, aOwnerType, Result) then
    Exit;
  Result := fIndex.FindSymbolsByOwnerType(aOwnerType);
  StoreSymbols(fSymbolsByOwnerType, aOwnerType, Result);
end;

function TPlannerLookupMemo.MaterializedSymbolCount: Int64;
begin
  Result := fMaterializedSymbolCount;
end;

function TPlannerLookupMemo.RequestCount: Int64;
begin
  Result := fRequestCount;
end;

function TPlannerLookupMemo.ResultMaterializationCount: Int64;
begin
  Result := fResultMaterializationCount;
end;

function TPlannerLookupMemo.ResultReuseCount: Int64;
begin
  Result := fResultReuseCount;
end;

constructor TArrayRemoveWithPlanBindingSource.Create(
  const aBindings: TArray<TDelphiSemanticWithBinding>);
begin
  inherited Create;
  fBindings := aBindings;
end;

function TArrayRemoveWithPlanBindingSource.BindingByIndex(
  const aIndex: Integer): TDelphiSemanticWithBinding;
begin
  Result := WithBindingForPlanning(fBindings[aIndex]);
end;

function TArrayRemoveWithPlanBindingSource.BindingCount: Integer;
begin
  Result := Length(fBindings);
end;

function BindingRange(const aBinding: TDelphiSemanticWithBinding):
  TDelphiSemanticRemoveWithSourceRange;
begin
  Result.StartLine := aBinding.Line;
  Result.StartColumn := aBinding.Column;
  Result.EndLine := aBinding.EndLine;
  Result.EndColumn := aBinding.EndColumn;
end;

function SourceFileHash(const aFileName: string; const aHashCache:
  TDictionary<string, string>): string;
begin
  if Assigned(aHashCache) and aHashCache.TryGetValue(aFileName, Result) then
    Exit;

  if not TFile.Exists(aFileName) then
    Result := ''
  else
    Result := THashSHA2.GetHashStringFromFile(aFileName);

  if Assigned(aHashCache) then
    aHashCache.AddOrSetValue(aFileName, Result);
end;

function SourceLineBreakForFile(const aFileName: string;
  const aLineCache: TDelphiSemanticSourceContextCache): string;
var
  lCache: TDelphiSemanticSourceContextCache;
begin
  if Assigned(aLineCache) then
    Exit(aLineCache.LineBreakForFile(aFileName));

  lCache := TDelphiSemanticSourceContextCache.Create;
  try
    Result := lCache.LineBreakForFile(aFileName);
  finally
    lCache.Free;
  end;
end;

function SourceTextForRange(const aFileName: string;
  const aRange: TDelphiSemanticRemoveWithSourceRange;
  const aLineCache: TDelphiSemanticSourceContextCache): string;
var
  lCache: TDelphiSemanticSourceContextCache;
begin
  Result := '';
  if Assigned(aLineCache) then
  begin
    aLineCache.TryExtractRange(aFileName, aRange.StartLine, aRange.StartColumn,
      aRange.EndLine, aRange.EndColumn, Result);
    Exit;
  end;

  lCache := TDelphiSemanticSourceContextCache.Create;
  try
    lCache.TryExtractRange(aFileName, aRange.StartLine, aRange.StartColumn,
      aRange.EndLine, aRange.EndColumn, Result);
  finally
    lCache.Free;
  end;
end;

function ReferenceIdsForBinding(const aBinding: TDelphiSemanticWithBinding): TArray<string>;
var
  lIds: TList<string>;
  lReference: TDelphiSemanticBoundReference;
begin
  lIds := TList<string>.Create;
  try
    for lReference in aBinding.References do
      if lReference.SemanticId <> '' then
        lIds.Add(lReference.SemanticId);
    Result := lIds.ToArray;
  finally
    lIds.Free;
  end;
end;

function IndentText(const aColumn: Integer): string;
begin
  if aColumn <= 1 then
    Result := ''
  else
    Result := StringOfChar(' ', aColumn - 1);
end;

function RemoveLeadingTypePrefix(const aTypeName: string): string;
begin
  Result := Trim(aTypeName);
  if (Length(Result) > 1) and SameText(Copy(Result, 1, 1), 'T') then
    Result := Copy(Result, 2, MaxInt);
end;

function IsSimpleIdentifier(const aText: string): Boolean;
var
  lText: string;
  i: Integer;
begin
  lText := Trim(aText);
  if lText = '' then
    Exit(False);
  if not CharInSet(lText[1], ['A'..'Z', 'a'..'z', '_']) then
    Exit(False);
  for i := 2 to Length(lText) do
  begin
    if not CharInSet(lText[i], ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
      Exit(False);
  end;
  Result := True;
end;

function IsSimplePointerDereferenceSelector(const aText: string): Boolean;
var
  lBaseText: string;
begin
  Result := False;
  lBaseText := Trim(aText);
  if not EndsText('^', lBaseText) then
    Exit;
  Delete(lBaseText, Length(lBaseText), 1);
  Result := IsSimpleIdentifier(lBaseText);
end;

function IsPureUnitLevelSelector(const aText: string): Boolean;
var
  lBracketDepth: Integer;
  lPreviousWasDot: Boolean;
  lSawCode: Boolean;
  lText: string;
  i: Integer;
begin
  lText := Trim(aText);
  if lText = '' then
    Exit(False);

  lBracketDepth := 0;
  lPreviousWasDot := False;
  lSawCode := False;
  for i := 1 to Length(lText) do
  begin
    if CharInSet(lText[i], [#9, ' ']) then
      Continue;

    if lBracketDepth > 0 then
    begin
      if lText[i] = ']' then
      begin
        Dec(lBracketDepth);
        lPreviousWasDot := False;
        Continue;
      end;
      if not CharInSet(lText[i], ['0'..'9', ',']) then
        Exit(False);
      Continue;
    end;

    if lText[i] = '[' then
    begin
      if not lSawCode then
        Exit(False);
      Inc(lBracketDepth);
      lPreviousWasDot := False;
      Continue;
    end;

    if lText[i] = '.' then
    begin
      if (not lSawCode) or lPreviousWasDot then
        Exit(False);
      lPreviousWasDot := True;
      Continue;
    end;

    if not CharInSet(lText[i], ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
      Exit(False);
    lSawCode := True;
    lPreviousWasDot := False;
  end;

  Result := lSawCode and (lBracketDepth = 0) and (not lPreviousWasDot);
end;

function TypeArgumentText(const aTypeName: string): string;
var
  lEndPos: Integer;
  lStartPos: Integer;
begin
  Result := '';
  lStartPos := Pos('<', aTypeName);
  lEndPos := LastDelimiter('>', aTypeName);
  if (lStartPos > 0) and (lEndPos > lStartPos) then
    Result := Trim(Copy(aTypeName, lStartPos + 1, lEndPos - lStartPos - 1));
end;

function ArrayElementTypeText(const aTypeName: string): string;
var
  lMarkerPos: Integer;
begin
  Result := '';
  lMarkerPos := Pos(' of ', LowerCase(aTypeName));
  if lMarkerPos > 0 then
    Result := Trim(Copy(aTypeName, lMarkerPos + Length(' of '), MaxInt));
end;

function IndexedElementType(const aFacts: TRemoveWithPlanFacts;
  const aTypeName: string): string;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := TypeArgumentText(aTypeName);
  if Result <> '' then
    Exit;
  Result := ArrayElementTypeText(aTypeName);
  if Result <> '' then
    Exit;
  for lSymbol in aFacts.LookupIndex.FindDeclarationOrTypeAliasByName(aTypeName) do
  begin
    Result := TypeArgumentText(lSymbol.RelatedTypeName);
    if Result <> '' then
      Exit;
    Result := ArrayElementTypeText(lSymbol.RelatedTypeName);
    if Result <> '' then
      Exit;
    Result := TypeArgumentText(lSymbol.TypeName);
    if Result <> '' then
      Exit;
    Result := ArrayElementTypeText(lSymbol.TypeName);
    if Result <> '' then
      Exit;
  end;
  for lSymbol in aFacts.LookupIndex.FindSymbolsByOwnerType(aTypeName) do
    if lSymbol.IsDefault and lSymbol.IsIndexed and (Trim(lSymbol.TypeName) <> '') then
      Exit(lSymbol.TypeName);
end;

function ConventionalPointerTargetType(const aFacts: TRemoveWithPlanFacts;
  const aTypeName: string): string;
var
  lCandidateTypeName: string;
  lTypeName: string;
begin
  Result := '';
  lTypeName := Trim(aTypeName);
  if EndsText('Ptr', lTypeName) and (Length(lTypeName) > Length('Ptr')) then
  begin
    lCandidateTypeName := Copy(lTypeName, 1, Length(lTypeName) - Length('Ptr'));
    if Length(aFacts.LookupIndex.FindDeclarationOrTypeAliasByName(lCandidateTypeName)) > 0 then
      Exit(lCandidateTypeName);
  end;
  if StartsText('P', lTypeName) and (Length(lTypeName) > 1) then
  begin
    lCandidateTypeName := Copy(lTypeName, 2, MaxInt);
    if Length(aFacts.LookupIndex.FindDeclarationOrTypeAliasByName(lCandidateTypeName)) > 0 then
      Exit(lCandidateTypeName);
  end;
end;

function SelectorShapeType(const aFacts: TRemoveWithPlanFacts;
  const aBaseTypeName, aSelectorText: string): string;
var
  lElementType: string;
  lIndexPos: Integer;
  lPointerPos: Integer;
  lPointerTargetType: string;
begin
  Result := aBaseTypeName;
  lIndexPos := Pos('[', aSelectorText);
  lPointerPos := Pos('^', aSelectorText);
  if (lPointerPos > 0) and ((lIndexPos = 0) or (lPointerPos < lIndexPos)) then
  begin
    lPointerTargetType := aFacts.LookupIndex.PointerTargetType(Result);
    if lPointerTargetType = '' then
      lPointerTargetType := ConventionalPointerTargetType(aFacts, Result);
    if (lPointerTargetType = '') and (lIndexPos > 0) then
      Exit('')
    else if lPointerTargetType <> '' then
      Result := lPointerTargetType;
  end;
  if lIndexPos > 0 then
  begin
    lElementType := IndexedElementType(aFacts, Result);
    if lElementType = '' then
      Exit('')
    else
      Result := lElementType;
  end;
  if (lPointerPos > 0) and (lIndexPos > 0) and (lIndexPos < lPointerPos) then
  begin
    lPointerTargetType := aFacts.LookupIndex.PointerTargetType(Result);
    if lPointerTargetType = '' then
      lPointerTargetType := ConventionalPointerTargetType(aFacts, Result);
    if lPointerTargetType = '' then
      Exit('')
    else
      Result := lPointerTargetType;
  end;
end;

function SelectorChainPartShapeType(const aFacts: TRemoveWithPlanFacts;
  const aBaseTypeName, aSelectorText: string): string;
var
  lElementType: string;
  lIndexPos: Integer;
  lPointerPos: Integer;
  lPointerTargetType: string;
begin
  Result := aBaseTypeName;
  lIndexPos := Pos('[', aSelectorText);
  lPointerPos := Pos('^', aSelectorText);
  if (lPointerPos > 0) and ((lIndexPos = 0) or (lPointerPos < lIndexPos)) then
  begin
    lPointerTargetType := aFacts.LookupIndex.PointerTargetType(Result);
    if lPointerTargetType = '' then
      lPointerTargetType := ConventionalPointerTargetType(aFacts, Result);
    if (lPointerTargetType = '') and (lIndexPos > 0) then
      Exit('')
    else if lPointerTargetType <> '' then
      Result := lPointerTargetType;
  end;
  if lIndexPos > 0 then
  begin
    lElementType := IndexedElementType(aFacts, Result);
    if lElementType = '' then
      Exit('')
    else
      Result := lElementType;
  end;
  if (lPointerPos > 0) and (lIndexPos > 0) and (lIndexPos < lPointerPos) then
  begin
    lPointerTargetType := aFacts.LookupIndex.PointerTargetType(Result);
    if lPointerTargetType = '' then
      lPointerTargetType := ConventionalPointerTargetType(aFacts, Result);
    if lPointerTargetType = '' then
      Exit('')
    else
      Result := lPointerTargetType;
  end;
end;

function FinalStatementId(const aIndex: Integer): string;
begin
  Result := 'with-' + IntToStr(aIndex);
end;

function TryFindDecisionForSelector(const aDecisions: TArray<TFinalSelectorDecision>;
  const aSelectorText: string; out aDecision: TFinalSelectorDecision): Boolean;
var
  lDecision: TFinalSelectorDecision;
begin
  Result := False;
  aDecision := Default(TFinalSelectorDecision);
  for lDecision in aDecisions do
  begin
    if SameText(lDecision.SelectorText, aSelectorText) then
    begin
      aDecision := lDecision;
      Exit(True);
    end;
  end;
end;

function HasDecisionForSelector(const aDecisions: TArray<TFinalSelectorDecision>;
  const aSelectorText: string): Boolean;
var
  lDecision: TFinalSelectorDecision;
begin
  Result := TryFindDecisionForSelector(aDecisions, aSelectorText, lDecision);
end;

function SelectorHasEarlierSelector(const aBinding: TDelphiSemanticWithBinding;
  const aSelectorText: string): Boolean;
var
  lSelector: TDelphiSemanticWithSelectorBinding;
begin
  Result := False;
  for lSelector in aBinding.Selectors do
  begin
    if SameText(lSelector.SelectorText, aSelectorText) then
      Exit;
    Result := True;
  end;
end;

function SelectorBaseIdentifier(const aSelectorText: string): string;
var
  lStopPos: Integer;
begin
  Result := Trim(aSelectorText);
  lStopPos := Pos('[', Result);
  if lStopPos <= 0 then
    lStopPos := Pos('^', Result);
  if lStopPos > 0 then
    Result := Trim(Copy(Result, 1, lStopPos - 1));
end;

function TryFindRoutineScopedSymbolForBinding(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aName: string;
  out aSymbol: TDelphiSemanticInventorySymbol): Boolean; forward;

function SelectorBaseDeclaredShapeType(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aSelectorText: string): string;
var
  lBaseName: string;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := '';
  lBaseName := SelectorBaseIdentifier(aSelectorText);
  if lBaseName = '' then
    Exit;
  if TryFindRoutineScopedSymbolForBinding(aFacts, aBinding, lBaseName,
    lSymbol) then
  begin
    Result := SelectorShapeType(aFacts, lSymbol.TypeName, aSelectorText);
    if Result <> '' then
      Exit;
  end;
  for lSymbol in aFacts.LookupIndex.FindUnitOrGlobalByName(lBaseName) do
  begin
    Result := SelectorShapeType(aFacts, lSymbol.TypeName, aSelectorText);
    if Result <> '' then
      Exit;
  end;
end;

function IndexedPointerSelectorBaseRequiresTypeResolutionSkip(
  const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aSelectorText: string): Boolean;
var
  lBaseName: string;
  lCloseBracket: Integer;
  lIndexName: string;
  lIndexSymbol: TDelphiSemanticInventorySymbol;
  lOpenBracket: Integer;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  if (Pos('[', aSelectorText) <= 0) or (Pos('^', aSelectorText) <= 0) then
    Exit;
  lBaseName := SelectorBaseIdentifier(aSelectorText);
  if lBaseName = '' then
    Exit;
  if aFacts.LookupIndex.FindRoutineSymbol(aBinding.RoutineName, lBaseName,
    lSymbol) then
  begin
    if (not SameText(lSymbol.SymbolClass, 'parameter')) or
      (not MatchText(lSymbol.Modifier, ['const', 'var', 'out'])) then
      Exit;
    lOpenBracket := Pos('[', aSelectorText);
    lCloseBracket := Pos(']', aSelectorText);
    if lCloseBracket <= lOpenBracket then
      Exit;
    lIndexName := Trim(Copy(aSelectorText, lOpenBracket + 1,
      lCloseBracket - lOpenBracket - 1));
    if not IsSimpleIdentifier(lIndexName) then
      Exit;
    if not aFacts.LookupIndex.FindRoutineSymbol(aBinding.RoutineName,
      lIndexName, lIndexSymbol) then
      Exit;
    Result := SameText(lIndexSymbol.SymbolClass, 'local');
  end;
end;

function UnqualifiedTypeName(const aTypeName: string): string;
var
  lSeparator: Integer;
begin
  Result := Trim(aTypeName);
  lSeparator := LastDelimiter('.', Result);
  if (lSeparator > 0) and (lSeparator < Length(Result)) then
    Result := Copy(Result, lSeparator + 1, MaxInt);
end;

function TypeNameMatches(const aLeft, aRight: string): Boolean;
begin
  Result := SameText(aLeft, aRight) or
    ((Trim(aLeft) <> '') and (Trim(aRight) <> '') and
    SameText(UnqualifiedTypeName(aLeft), UnqualifiedTypeName(aRight)));
end;

function SymbolIsMemberOfOwner(const aSymbol: TDelphiSemanticInventorySymbol;
  const aOwnerType: string): Boolean;
begin
  Result := MatchText(aSymbol.SymbolClass, ['field', 'property', 'member']) and
    (TypeNameMatches(aSymbol.OwnerType, aOwnerType) or
    TypeNameMatches(aSymbol.OwnerName, aOwnerType) or
    TypeNameMatches(aSymbol.SourceOwnerType, aOwnerType));
end;

function OwnerHasMemberNamed(const aFacts: TRemoveWithPlanFacts;
  const aOwnerType, aName: string): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  if aFacts.LookupIndex.TryReuseOwnerMemberResult(aOwnerType, aName,
    Result) then
    Exit;
  Result := Length(aFacts.LookupIndex.FindMembersByOwnerAndName(aOwnerType,
    aName)) > 0;
  if not Result then
  begin
    for lSymbol in aFacts.LookupIndex.FindSymbolsByName(aName) do
    begin
      if SymbolIsMemberOfOwner(lSymbol, aOwnerType) then
      begin
        Result := True;
        Break;
      end;
    end;
  end;
  aFacts.LookupIndex.StoreOwnerMemberResult(aOwnerType, aName, Result);
end;

function ReferenceLookupName(const aReferenceName: string): string; forward;

function SymbolIsRoutineMemberKind(const aSymbol:
  TDelphiSemanticInventorySymbol): Boolean;
begin
  Result := MatchText(aSymbol.SymbolClass, ['method', 'routine']) or
    MatchText(aSymbol.Kind, ['method', 'routine']);
end;

function SymbolIsRoutineMemberOfOwner(const aSymbol:
  TDelphiSemanticInventorySymbol; const aOwnerType: string): Boolean;
begin
  Result := SymbolIsRoutineMemberKind(aSymbol) and
    (TypeNameMatches(aSymbol.OwnerType, aOwnerType) or
    TypeNameMatches(aSymbol.OwnerName, aOwnerType));
end;

function SymbolIsOwnRoutineMemberOfOwner(const aSymbol:
  TDelphiSemanticInventorySymbol; const aOwnerType: string): Boolean;
begin
  Result := SymbolIsRoutineMemberOfOwner(aSymbol, aOwnerType) and
    (not aSymbol.IsHelper) and
    ((Trim(aSymbol.SourceOwnerType) = '') or
    TypeNameMatches(aSymbol.SourceOwnerType, aOwnerType));
end;

function ReceiverRoutineMemberCandidateCount(const aFacts: TRemoveWithPlanFacts;
  const aOwnerType, aName: string): Integer;
var
  lCandidateKey: string;
  lCandidateKeys: TDictionary<string, Byte>;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := 0;
  lCandidateKeys := TDictionary<string, Byte>.Create;
  try
    for lSymbol in aFacts.LookupIndex.FindSymbolsByName(aName) do
    begin
      if not SymbolIsRoutineMemberOfOwner(lSymbol, aOwnerType) then
        Continue;
      if SymbolIsOwnRoutineMemberOfOwner(lSymbol, aOwnerType) then
        Exit(1);
      lCandidateKey := LowerCase(lSymbol.SourceOwnerType + #31 +
        lSymbol.OwnerType + #31 + lSymbol.Name);
      if lCandidateKeys.ContainsKey(lCandidateKey) then
        Continue;
      lCandidateKeys.Add(lCandidateKey, 1);
      Inc(Result);
    end;
  finally
    lCandidateKeys.Free;
  end;
end;

function ReferenceHasAmbiguousReceiverRoutineMember(
  const aFacts: TRemoveWithPlanFacts;
  const aDecisions: TArray<TFinalSelectorDecision>;
  const aReference: TDelphiSemanticBoundReference): Boolean;
var
  lDecision: TFinalSelectorDecision;
  lReferenceName: string;
begin
  Result := False;
  if not MatchText(aReference.Kind, ['method', 'routine']) then
    Exit;
  lReferenceName := ReferenceLookupName(aReference.Name);
  if lReferenceName = '' then
    Exit;

  for lDecision in aDecisions do
  begin
    if Trim(lDecision.ReceiverType) = '' then
      Continue;
    if ReceiverRoutineMemberCandidateCount(aFacts, lDecision.ReceiverType,
      lReferenceName) > 1 then
      Exit(True);
  end;
end;

function BindingDependentSelectorQualifier(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aDecisions: TArray<TFinalSelectorDecision>; const aSelectorText,
  aSelectorName: string; out aQualifierText: string): Boolean;
var
  lDecision: TFinalSelectorDecision;
  lPreviousSelector: TDelphiSemanticWithSelectorBinding;
  lPreviousTypeName: string;
begin
  Result := False;
  for lPreviousSelector in aBinding.Selectors do
  begin
    if SameText(lPreviousSelector.SelectorText, aSelectorText) then
      Exit;
    if not TryFindDecisionForSelector(aDecisions, lPreviousSelector.SelectorText,
      lDecision) then
      Continue;
    if SameText(lDecision.Reason, 'skipped-parent-context') or
      (Trim(lDecision.QualifierText) = '') then
      Continue;
    lPreviousTypeName := SelectorShapeType(aFacts, lPreviousSelector.TypeName,
      lPreviousSelector.SelectorText);
    if lPreviousTypeName = '' then
      lPreviousTypeName := SelectorBaseDeclaredShapeType(aFacts, aBinding,
        lPreviousSelector.SelectorText);
    if lPreviousTypeName = '' then
      lPreviousTypeName := lDecision.ReceiverType;
    if (lPreviousTypeName <> '') and
      OwnerHasMemberNamed(aFacts, lPreviousTypeName, aSelectorName) then
    begin
      aQualifierText := lDecision.QualifierText + '.' + aSelectorText;
      Exit(True);
    end;
  end;
end;

function DependentSelectorQualifier(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aDecisions: TArray<TFinalSelectorDecision>; const aSelectorText: string;
  out aQualifierText: string): Boolean;
var
  lDecision: TFinalSelectorDecision;
  lSelectorName: string;
begin
  Result := False;
  aQualifierText := '';
  lSelectorName := SelectorBaseIdentifier(aSelectorText);
  if lSelectorName = '' then
    Exit;

  for lDecision in aDecisions do
  begin
    if SameText(lDecision.Reason, 'skipped-parent-context') then
      Continue;
    if (lDecision.ReceiverType <> '') and
      OwnerHasMemberNamed(aFacts, lDecision.ReceiverType, lSelectorName) then
    begin
      aQualifierText := lDecision.QualifierText + '.' + aSelectorText;
      Exit(True);
    end;
  end;
  Result := BindingDependentSelectorQualifier(aFacts, aBinding, aDecisions,
    aSelectorText, lSelectorName, aQualifierText);
end;

function SkippedParentContextHasMember(const aFacts:
  TRemoveWithPlanFacts; const aDecisions:
  TArray<TFinalSelectorDecision>; const aSelectorText: string): Boolean;
var
  lDecision: TFinalSelectorDecision;
  lSelectorName: string;
begin
  Result := False;
  lSelectorName := Trim(aSelectorText);
  if lSelectorName = '' then
    Exit;
  for lDecision in aDecisions do
  begin
    if SameText(lDecision.Reason, 'skipped-parent-context') and
      OwnerHasMemberNamed(aFacts, lDecision.ReceiverType, lSelectorName) then
      Exit(True);
  end;
end;

function IndexedPointerSelectorBaseHasSkippedParentMember(const aFacts:
  TRemoveWithPlanFacts; const aDecisions:
  TArray<TFinalSelectorDecision>; const aSelectorText: string): Boolean;
var
  lBaseName: string;
begin
  lBaseName := SelectorBaseIdentifier(aSelectorText);
  Result := (lBaseName <> '') and
    SkippedParentContextHasMember(aFacts, aDecisions, lBaseName);
end;

function SkippedParentContextHasIndexedSelector(const aDecisions:
  TArray<TFinalSelectorDecision>): Boolean;
var
  lDecision: TFinalSelectorDecision;
begin
  // An unproven receiver can hide the pointer name. An unknown body reference
  // on a proven receiver does not invalidate independent nested selectors.
  Result := False;
  for lDecision in aDecisions do
  begin
    if SameText(lDecision.Reason, 'skipped-parent-context') and
      (Pos('[', lDecision.SelectorText) > 0) and
      (Trim(lDecision.ReceiverType) = '') then
      Exit(True);
  end;
end;

function SelectorTextOccurrenceCount(const aBindingSelectorText,
  aSelectorText: string): Integer;
var
  lPart: string;
  lParts: TArray<string>;
begin
  Result := 0;
  if not TrySplitTopLevelCommaList(aBindingSelectorText, lParts) then
    Exit;
  for lPart in lParts do
    if SameText(lPart, Trim(aSelectorText)) then
      Inc(Result);
end;

function SelectorTextDeclaredInBinding(const aBindingSelectorText,
  aSelectorText: string): Boolean;
begin
  Result := SelectorTextOccurrenceCount(aBindingSelectorText, aSelectorText) > 0;
end;

function SelectorHasDependentSelector(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aSelectorText,
  aReceiverType: string): Boolean;
var
  lAfterSelector: Boolean;
  lSelector: TDelphiSemanticWithSelectorBinding;
  lSelectorName: string;
  lStopPos: Integer;
begin
  Result := False;
  lAfterSelector := False;
  for lSelector in aBinding.Selectors do
  begin
    if not SelectorTextDeclaredInBinding(aBinding.SelectorText, lSelector.SelectorText) then
      Continue;
    if not lAfterSelector then
    begin
      if SameText(lSelector.SelectorText, aSelectorText) then
        lAfterSelector := True;
      Continue;
    end;

    lSelectorName := Trim(lSelector.SelectorText);
    lStopPos := Pos('[', lSelectorName);
    if lStopPos <= 0 then
      lStopPos := Pos('^', lSelectorName);
    if lStopPos > 0 then
      lSelectorName := Trim(Copy(lSelectorName, 1, lStopPos - 1));
    if (lSelectorName <> '') and OwnerHasMemberNamed(aFacts, aReceiverType,
      lSelectorName) then
      Exit(True);
  end;
end;

function TryDependentSelectorTypeName(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aSelectorText,
  aReceiverType: string; out aTypeName: string): Boolean;
var
  lAfterSelector: Boolean;
  lSelector: TDelphiSemanticWithSelectorBinding;
  lSelectorName: string;
  lStopPos: Integer;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  aTypeName := '';
  lAfterSelector := False;
  for lSelector in aBinding.Selectors do
  begin
    if not SelectorTextDeclaredInBinding(aBinding.SelectorText,
      lSelector.SelectorText) then
      Continue;
    if not lAfterSelector then
    begin
      if SameText(lSelector.SelectorText, aSelectorText) then
        lAfterSelector := True;
      Continue;
    end;

    lSelectorName := Trim(lSelector.SelectorText);
    lStopPos := Pos('[', lSelectorName);
    if lStopPos <= 0 then
      lStopPos := Pos('^', lSelectorName);
    if lStopPos <= 0 then
      lStopPos := Pos('.', lSelectorName);
    if lStopPos > 0 then
      lSelectorName := Trim(Copy(lSelectorName, 1, lStopPos - 1));
    if lSelectorName = '' then
      Continue;

    for lSymbol in aFacts.LookupIndex.FindMembersByOwnerAndName(aReceiverType,
      lSelectorName) do
    begin
      aTypeName := lSymbol.TypeName;
      Exit(True);
    end;
    for lSymbol in aFacts.LookupIndex.FindSymbolsByName(lSelectorName) do
    begin
      if not SymbolIsMemberOfOwner(lSymbol, aReceiverType) then
        Continue;
      aTypeName := lSymbol.TypeName;
      Exit(True);
    end;
  end;
end;

function TypeIsRecordLike(const aFacts: TRemoveWithPlanFacts;
  const aTypeName: string): Boolean; forward;

function SelectorHasAnonymousRecordDependentSelector(
  const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aSelectorText,
  aReceiverType: string): Boolean;
var
  lTypeName: string;
begin
  Result := TryDependentSelectorTypeName(aFacts, aBinding, aSelectorText,
    aReceiverType, lTypeName) and ContainsText(lTypeName, '.') and
    TypeIsRecordLike(aFacts, lTypeName);
end;

function BindingBodyRange(const aBinding: TDelphiSemanticWithBinding):
  TDelphiSemanticRemoveWithSourceRange;
begin
  Result.StartLine := aBinding.BodyLine;
  Result.StartColumn := aBinding.BodyColumn;
  Result.EndLine := aBinding.BodyEndLine;
  Result.EndColumn := aBinding.BodyEndColumn;
end;

function FirstNonWhitespaceColumn(const aText: string): Integer;
var
  i: Integer;
begin
  for i := 1 to Length(aText) do
    if not CharInSet(aText[i], [#9, ' ']) then
      Exit(i);
  Result := Length(aText) + 1;
end;

function LineStartsOuterElse(const aLine: string;
  const aBindingColumn: Integer): Boolean;
var
  lColumn: Integer;
  lText: string;
begin
  lColumn := FirstNonWhitespaceColumn(aLine);
  lText := LowerCase(Trim(aLine));
  Result := (StartsText('else', lText) or StartsText('end else', lText)) and
    (lColumn < aBindingColumn);
end;

function LineIsOuterElseTrivia(const aLine: string): Boolean;
var
  lText: string;
begin
  lText := Trim(aLine);
  Result := (lText = '') or StartsText('//', lText) or
    (StartsText('{', lText) and EndsText('}', lText)) or
    (StartsText('(*', lText) and EndsText('*)', lText));
end;

function TrimRangeBeforeOuterElse(const aBinding: TDelphiSemanticWithBinding;
  const aLineCache: TDelphiSemanticSourceContextCache;
  var aRange: TDelphiSemanticRemoveWithSourceRange): Boolean;
var
  lLineIndex: Integer;
  lLines: TArray<string>;
  lTriviaStartLine: Integer;
begin
  Result := False;
  if not aLineCache.TryGetValue(aBinding.FileName, lLines) then
    Exit;

  lTriviaStartLine := 0;
  for lLineIndex := aRange.StartLine to aRange.EndLine do
  begin
    if (lLineIndex < 1) or (lLineIndex > Length(lLines)) then
      Continue;
    if LineIsOuterElseTrivia(lLines[lLineIndex - 1]) then
    begin
      if lTriviaStartLine = 0 then
        lTriviaStartLine := lLineIndex;
      Continue;
    end;
    if not LineStartsOuterElse(lLines[lLineIndex - 1], aBinding.Column) then
    begin
      lTriviaStartLine := 0;
      Continue;
    end;
    if lLineIndex <= aRange.StartLine then
      Exit;
    if lTriviaStartLine > aRange.StartLine then
      aRange.EndLine := lTriviaStartLine - 1
    else
      aRange.EndLine := lLineIndex - 1;
    aRange.EndColumn := Length(lLines[aRange.EndLine - 1]);
    if aRange.EndColumn < 1 then
      aRange.EndColumn := 1;
    Exit(True);
  end;

  if (aRange.EndLine >= aRange.StartLine) and
    LineIsOuterElseTrivia(lLines[aRange.EndLine - 1]) then
  begin
    lLineIndex := aRange.EndLine + 1;
    while (lLineIndex <= Length(lLines)) and
      LineIsOuterElseTrivia(lLines[lLineIndex - 1]) do
      Inc(lLineIndex);
    if (lLineIndex <= Length(lLines)) and
      LineStartsOuterElse(lLines[lLineIndex - 1], aBinding.Column) then
    begin
      while (aRange.EndLine >= aRange.StartLine) and
        LineIsOuterElseTrivia(lLines[aRange.EndLine - 1]) do
        Dec(aRange.EndLine);
      if aRange.EndLine < aRange.StartLine then
        Exit;
      aRange.EndColumn := Length(lLines[aRange.EndLine - 1]);
      if aRange.EndColumn < 1 then
        aRange.EndColumn := 1;
      Exit(True);
    end;
  end;
end;

function RangeIsFollowedByOuterElse(const aBinding: TDelphiSemanticWithBinding;
  const aLineCache: TDelphiSemanticSourceContextCache;
  const aRange: TDelphiSemanticRemoveWithSourceRange): Boolean;
var
  lColumn: Integer;
  lCommentEnd: string;
  lEndColumn: Integer;
  lLineIndex: Integer;
  lLineText: string;
  lLines: TArray<string>;
  lSuffix: string;
begin
  Result := False;
  if not aLineCache.TryGetValue(aBinding.FileName, lLines) then
    Exit;
  if (aRange.EndLine < 1) or (aRange.EndLine > Length(lLines)) then
    Exit;

  lCommentEnd := '';
  lColumn := aRange.EndColumn + 1;
  for lLineIndex := aRange.EndLine to Length(lLines) do
  begin
    lLineText := lLines[lLineIndex - 1];
    while lColumn <= Length(lLineText) do
    begin
      if lCommentEnd <> '' then
      begin
        lEndColumn := PosEx(lCommentEnd, lLineText, lColumn);
        if lEndColumn = 0 then
          Break;
        lColumn := lEndColumn + Length(lCommentEnd);
        lCommentEnd := '';
      end else if CharInSet(lLineText[lColumn], [#9, ' ']) then
        Inc(lColumn)
      else if lLineText[lColumn] = '{' then
      begin
        lCommentEnd := '}';
        Inc(lColumn);
      end else if Copy(lLineText, lColumn, 2) = '(*' then
      begin
        lCommentEnd := '*)';
        Inc(lColumn, 2);
      end else if Copy(lLineText, lColumn, 2) = '//' then
        Break
      else begin
        lSuffix := Copy(lLineText, lColumn, MaxInt);
        if StartsText('else', lSuffix) and
          ((Length(lSuffix) = 4) or
          (not CharInSet(lSuffix[5], ['A'..'Z', 'a'..'z', '0'..'9', '_']))) then
          Exit(True);
        Exit((lLineIndex > aRange.EndLine) and
          LineStartsOuterElse(lLineText, aBinding.Column));
      end;
    end;
    lColumn := 1;
  end;
end;

function ReferenceInsideRange(const aReference: TDelphiSemanticBoundReference;
  const aRange: TDelphiSemanticRemoveWithSourceRange): Boolean;
var
  lReference: TDelphiSemanticBoundReference;

  function ReferenceInsideRangeExact(const aCandidate:
    TDelphiSemanticBoundReference): Boolean;
  begin
    Result := ((aCandidate.Line > aRange.StartLine) or
      ((aCandidate.Line = aRange.StartLine) and (aCandidate.Column >= aRange.StartColumn))) and
      ((aCandidate.Line < aRange.EndLine) or
      ((aCandidate.Line = aRange.EndLine) and (aCandidate.Column <= aRange.EndColumn)));
  end;
begin
  Result := ReferenceInsideRangeExact(aReference);
  if Result or (aReference.Line <= aRange.StartLine) then
    Exit;

  lReference := aReference;
  Dec(lReference.Line);
  Result := ReferenceInsideRangeExact(lReference);
end;

function TypeIsClassLike(const aFacts: TRemoveWithPlanFacts;
  const aTypeName: string): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
  lSymbols: TArray<TDelphiSemanticInventorySymbol>;
begin
  Result := False;
  lSymbols := aFacts.LookupIndex.FindDeclarationOrTypeAliasByName(aTypeName);
  for lSymbol in lSymbols do
  begin
    if SameText(lSymbol.TypeName, 'class') or SameText(lSymbol.TypeName, 'interface') or
      SameText(lSymbol.Kind, 'class') or SameText(lSymbol.Kind, 'interface') or
      SameText(lSymbol.TypeCategory, 'class') or SameText(lSymbol.TypeCategory, 'interface') then
      Exit(True);
  end;
  Result := EndsText('Object', aTypeName) or EndsText('Class', aTypeName);
end;

function TypeIsRecordLike(const aFacts: TRemoveWithPlanFacts;
  const aTypeName: string): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
  lSymbols: TArray<TDelphiSemanticInventorySymbol>;
begin
  Result := False;
  lSymbols := aFacts.LookupIndex.FindDeclarationOrTypeAliasByName(aTypeName);
  for lSymbol in lSymbols do
  begin
    if SameText(lSymbol.TypeName, 'record') or SameText(lSymbol.Kind, 'record') or
      SameText(lSymbol.TypeCategory, 'record') then
      Exit(True);
  end;
end;

function TypeHasRoutineMembers(const aFacts: TRemoveWithPlanFacts;
  const aTypeName: string): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  for lSymbol in aFacts.LookupIndex.FindSymbolsByOwnerType(aTypeName) do
  begin
    if SameText(lSymbol.Kind, 'routine') then
      Exit(True);
  end;
end;

function TypeHasOperatorSyntax(const aFacts: TRemoveWithPlanFacts;
  const aTypeName: string; const aLineCache: TDelphiSemanticSourceContextCache): Boolean;
var
  lDeclaration: TDelphiSemanticInventorySymbol;
  lDeclarations: TArray<TDelphiSemanticInventorySymbol>;
  lLine: string;
  lLines: TArray<string>;
  i: Integer;
begin
  Result := False;
  lDeclarations := aFacts.LookupIndex.FindDeclarationOrTypeAliasByName(aTypeName);
  for lDeclaration in lDeclarations do
  begin
    if (lDeclaration.FileName = '') or (lDeclaration.Line <= 0) then
      Continue;
    if not aLineCache.TryGetValue(lDeclaration.FileName, lLines) then
      Continue;
    for i := lDeclaration.Line to Length(lLines) do
    begin
      lLine := LowerCase(Trim(lLines[i - 1]));
      if ContainsText(lLine, 'operator ') then
        Exit(True);
      if SameText(lLine, 'end;') or SameText(lLine, 'end') then
        Break;
    end;
  end;
end;

function ResolvedPointerCastSelector(const aBinding: TDelphiSemanticWithBinding;
  const aSelectorText: string): Boolean;
var
  i: Integer;
  lSelector: TDelphiSemanticWithSelectorBinding;
begin
  // The binder proves the whole cast and its declaration. Argument postfixes
  // must not be applied again to the resolved record receiver type.
  Result := False;
  if (Pos('(', aSelectorText) = 0) or (not EndsText(')^', Trim(aSelectorText))) then
    Exit;
  for i := High(aBinding.Selectors) downto 0 do
  begin
    lSelector := aBinding.Selectors[i];
    if SameText(lSelector.SelectorText, aSelectorText) then
      Exit(SameText(lSelector.Status, 'resolved') and
        (lSelector.ReasonCode = '') and (lSelector.TypeName <> ''));
  end;
end;

function SelectorTypeName(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aSelectorText: string): string;
var
  i: Integer;
  lBracketPos: Integer;
  lMember: TDelphiSemanticInventorySymbol;
  lHasEarlierSelector: Boolean;
  lPreviousSelector: TDelphiSemanticWithSelectorBinding;
  lPreviousTypeName: string;
  lSelector: TDelphiSemanticWithSelectorBinding;
  lSelectorName: string;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := '';
  if ResolvedPointerCastSelector(aBinding, aSelectorText) then
    for i := High(aBinding.Selectors) downto 0 do
      if SameText(aBinding.Selectors[i].SelectorText, aSelectorText) then
        Exit(aBinding.Selectors[i].TypeName);
  lHasEarlierSelector := False;
  lSelectorName := Trim(aSelectorText);
  if EndsText('^', lSelectorName) then
    lSelectorName := Copy(lSelectorName, 1, Length(lSelectorName) - 1);
  lBracketPos := Pos('[', lSelectorName);
  if lBracketPos > 0 then
    lSelectorName := Trim(Copy(lSelectorName, 1, lBracketPos - 1));
  if EndsText('^', lSelectorName) then
    lSelectorName := Copy(lSelectorName, 1, Length(lSelectorName) - 1);
  if TryFindRoutineScopedSymbolForBinding(aFacts, aBinding, lSelectorName,
    lSymbol) then
  begin
    Result := SelectorShapeType(aFacts, lSymbol.TypeName, aSelectorText);
    if Result <> '' then
      Exit;
  end;
  for lSelector in aBinding.Selectors do
  begin
    if SameText(lSelector.SelectorText, aSelectorText) and
      (Trim(lSelector.TypeName) <> '') then
    begin
      Result := SelectorShapeType(aFacts, lSelector.TypeName, aSelectorText);
      if Result <> '' then
        Exit;
    end;
  end;
  for lSymbol in aFacts.LookupIndex.FindUnitOrGlobalByName(lSelectorName) do
  begin
    Result := SelectorShapeType(aFacts, lSymbol.TypeName, aSelectorText);
    if Result <> '' then
      Exit;
  end;
  for lPreviousSelector in aBinding.Selectors do
  begin
    if SameText(lPreviousSelector.SelectorText, aSelectorText) then
      Break;
    lHasEarlierSelector := True;
    lPreviousTypeName := SelectorTypeName(aFacts, aBinding,
      lPreviousSelector.SelectorText);
    if lPreviousTypeName = '' then
      Continue;
    for lMember in aFacts.LookupIndex.FindMembersByOwnerAndName(lPreviousTypeName,
      lSelectorName) do
    begin
      Result := SelectorShapeType(aFacts, lMember.TypeName, aSelectorText);
      if Result <> '' then
      Exit;
    end;
  end;
  if lHasEarlierSelector then
    Exit;
  // Unit-level typed constants are not in the unit/global index, but an element of a typed-constant
  // array is an addressable selector like the element of a variable array (T-290: TDB02 ResWords[m]).
  // Only a first selector may resolve here: in "with A, B do" a member of A hides a global B.
  for lSymbol in aFacts.LookupIndex.FindSymbolsByName(lSelectorName) do
    if SameText(lSymbol.SymbolClass, 'constant') and (Trim(lSymbol.RoutineName) = '') and
      (Trim(lSymbol.TypeName) <> '') then
    begin
      Result := SelectorShapeType(aFacts, lSymbol.TypeName, aSelectorText);
      if Result <> '' then
        Exit;
    end;
end;

function ReferenceIsRoutineSymbol(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aReferenceName: string): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := aFacts.LookupIndex.FindRoutineSymbol(aBinding.RoutineName, aReferenceName,
    lSymbol);
end;

function RoutineLeafName(const aRoutineName: string): string;
var
  lSeparator: Integer;
begin
  Result := Trim(aRoutineName);
  lSeparator := LastDelimiter('.', Result);
  if (lSeparator > 0) and (lSeparator < Length(Result)) then
    Result := Copy(Result, lSeparator + 1, MaxInt);
end;

function RoutineNameMatchesOrEncloses(const aCandidateRoutine,
  aBindingRoutine: string): Boolean;
var
  lBindingRoutine: string;
  lCandidateRoutine: string;
begin
  lCandidateRoutine := Trim(aCandidateRoutine);
  lBindingRoutine := Trim(aBindingRoutine);
  Result := (lCandidateRoutine <> '') and
    (SameText(lCandidateRoutine, lBindingRoutine) or
    StartsText(lCandidateRoutine + '.', lBindingRoutine) or
    SameText(RoutineLeafName(lCandidateRoutine), RoutineLeafName(lBindingRoutine)));
end;

function ReferenceIsKnownNonMemberSymbol(const aFacts:
  TRemoveWithPlanFacts; const aBinding:
  TDelphiSemanticWithBinding; const aReference:
  TDelphiSemanticBoundReference): Boolean;
var
  lReferenceName: string;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  lReferenceName := ReferenceLookupName(aReference.Name);
  for lSymbol in aFacts.LookupIndex.FindSymbolsByName(lReferenceName) do
  begin
    if MatchText(lSymbol.SymbolClass, ['local', 'parameter']) then
    begin
      if SameText(lSymbol.FileName, aBinding.FileName) and
        RoutineNameMatchesOrEncloses(lSymbol.RoutineName, aBinding.RoutineName) and
        (lSymbol.Line > 0) and (lSymbol.Line <= aReference.Line) then
        Exit(True);
      Continue;
    end;
    if MatchText(lSymbol.SymbolClass, ['unit', 'unit-global', 'declaration']) or
      MatchText(lSymbol.Kind, ['const',
      'constant', 'var', 'type', 'type-alias']) then
      Exit(True);
  end;
end;

function ReferenceIsRoutineScopeValue(const aFacts:
  TRemoveWithPlanFacts; const aBinding:
  TDelphiSemanticWithBinding; const aReference:
  TDelphiSemanticBoundReference): Boolean;
var
  lReferenceName: string;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  lReferenceName := ReferenceLookupName(aReference.Name);
  for lSymbol in aFacts.LookupIndex.FindSymbolsByName(lReferenceName) do
  begin
    if not MatchText(lSymbol.SymbolClass, ['local', 'parameter']) then
      Continue;
    if SameText(lSymbol.FileName, aBinding.FileName) and
      RoutineNameMatchesOrEncloses(lSymbol.RoutineName, aBinding.RoutineName) and
      (lSymbol.Line > 0) and (lSymbol.Line <= aReference.Line) then
      Exit(True);
  end;
end;

function ReferenceQualifiedPrefixIsRoutineScopeValue(const aFacts:
  TRemoveWithPlanFacts; const aBinding:
  TDelphiSemanticWithBinding; const aReference:
  TDelphiSemanticBoundReference): Boolean;
var
  lPrefix: string;
  lReference: TDelphiSemanticBoundReference;
  lSeparator: Integer;
begin
  Result := False;
  lSeparator := Pos('.', aReference.Name);
  if lSeparator <= 1 then
    Exit;
  lPrefix := Copy(aReference.Name, 1, lSeparator - 1);
  lReference := aReference;
  lReference.Name := lPrefix;
  Result := ReferenceIsRoutineScopeValue(aFacts, aBinding, lReference);
end;

function ReferenceCanRemainUnchanged(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aReference: TDelphiSemanticBoundReference): Boolean; forward;

function ReferenceQualifiedPrefixCanRemainUnchanged(const aFacts:
  TRemoveWithPlanFacts; const aBinding:
  TDelphiSemanticWithBinding; const aReference:
  TDelphiSemanticBoundReference): Boolean;
var
  lPrefix: string;
  lReference: TDelphiSemanticBoundReference;
  lSeparator: Integer;
begin
  Result := False;
  lSeparator := Pos('.', aReference.Name);
  if lSeparator <= 1 then
    Exit;
  lPrefix := Copy(aReference.Name, 1, lSeparator - 1);
  lReference := aReference;
  lReference.Name := lPrefix;
  Result := ReferenceCanRemainUnchanged(aFacts, aBinding, lReference);
end;

function ReferenceCanRemainUnchanged(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aReference: TDelphiSemanticBoundReference): Boolean;
begin
  Result := ReferenceIsRoutineSymbol(aFacts, aBinding, aReference.Name) or
    (Length(aFacts.LookupIndex.FindUnitOrGlobalByName(aReference.Name)) > 0) or
    (Length(aFacts.LookupIndex.FindDeclarationOrTypeAliasByName(aReference.Name)) > 0) or
    ReferenceIsKnownNonMemberSymbol(aFacts, aBinding, aReference);
end;

function ReferenceHasKnownRoutineSymbol(const aFacts:
  TRemoveWithPlanFacts;
  const aReference: TDelphiSemanticBoundReference): Boolean; forward;

function ReferenceShouldRemainUnchanged(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aReference: TDelphiSemanticBoundReference): Boolean;
begin
  Result := SameText(aReference.Name, aBinding.RoutineName) or
    (SameText(aReference.Kind, 'routine') and
    (not SameText(aReference.Classification, 'member'))) or
    ReferenceCanRemainUnchanged(aFacts, aBinding, aReference);
end;

function KnownRoutineSymbolInArray(
  const aSymbols: TArray<TDelphiSemanticInventorySymbol>): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  for lSymbol in aSymbols do
  begin
    if (not SameText(lSymbol.SymbolClass, 'routine')) and
      (not SameText(lSymbol.Kind, 'routine')) then
      Continue;
    if MatchText(lSymbol.SourceOwnerType, ['compiler-intrinsic', 'rtl-source']) or
      (Trim(lSymbol.TypeName) <> '') then
      Exit(True);
  end;
end;

function ReferenceHasKnownRoutineSymbol(const aFacts: TRemoveWithPlanFacts;
  const aReference: TDelphiSemanticBoundReference): Boolean;
var
  lName: string;
  lSeparator: Integer;
begin
  Result := KnownRoutineSymbolInArray(aFacts.LookupIndex.FindSymbolsByName(
    aReference.Name));
  if Result then
    Exit;
  lName := Trim(aReference.Name);
  lSeparator := LastDelimiter('.', lName);
  if (lSeparator > 0) and (lSeparator < Length(lName)) then
    Result := KnownRoutineSymbolInArray(aFacts.LookupIndex.FindSymbolsByName(
      Copy(lName, lSeparator + 1, MaxInt)));
end;

function ReferenceIsKnownTypeName(const aFacts: TRemoveWithPlanFacts;
  const aReference: TDelphiSemanticBoundReference): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := Length(aFacts.LookupIndex.FindDeclarationOrTypeAliasByName(
    aReference.Name)) > 0;
  if Result then
    Exit;
  for lSymbol in aFacts.LookupIndex.FindSymbolsByName(aReference.Name) do
  begin
    if MatchText(lSymbol.SymbolClass, ['type-member', 'declaration', 'type']) or
      MatchText(lSymbol.Kind, ['type-member', 'declaration', 'type']) then
      Exit(True);
  end;
end;

function ReferenceLooksLikeLocalLabel(const aBinding: TDelphiSemanticWithBinding;
  const aReference: TDelphiSemanticBoundReference;
  const aLineCache: TDelphiSemanticSourceContextCache): Boolean;
var
  lLine: string;
  lLines: TArray<string>;
  lReferenceName: string;
begin
  Result := False;
  lReferenceName := Trim(aReference.Name);
  if (lReferenceName = '') or (Pos('.', lReferenceName) > 0) or
    (Pos('(', lReferenceName) > 0) then
    Exit;
  if (aReference.Line <= 0) or (not aLineCache.TryGetValue(aBinding.FileName,
    lLines)) or (aReference.Line > Length(lLines)) then
    Exit;

  lLine := Trim(lLines[aReference.Line - 1]);
  Result := (SameText(lReferenceName, 'goto') and
    StartsText('goto ', LowerCase(lLine))) or
    SameText(lLine, lReferenceName + ':') or
    SameText(lLine, 'goto ' + lReferenceName + ';');
end;

function LineOpensEndClosedBlock(const aLine, aLowerLine: string): Boolean;
begin
  Result := SameText(aLine, 'begin') or EndsText(' begin', aLowerLine) or
    SameText(aLowerLine, 'try') or
    (StartsText('case ', aLowerLine) and EndsText(' of', aLowerLine));
end;

function ReferenceIsInlineLocalDeclaredInBinding(
  const aBinding: TDelphiSemanticWithBinding;
  const aReference: TDelphiSemanticBoundReference;
  const aLineCache: TDelphiSemanticSourceContextCache): Boolean;
var
  lBlockDepth: Integer;
  lDeclarationName: string;
  lDeclarationDepths: TList<Integer>;
  lLine: string;
  lLineIndex: Integer;
  lLines: TArray<string>;
  lLowerLine: string;
  lReferenceName: string;
  lStopPos: Integer;
begin
  Result := False;
  lReferenceName := ReferenceLookupName(aReference.Name);
  if (lReferenceName = '') or (aReference.Line < aBinding.BodyLine) or
    (aReference.Line > aBinding.BodyEndLine) or
    (not aLineCache.TryGetValue(aBinding.FileName, lLines)) then
    Exit;

  lBlockDepth := 0;
  lDeclarationDepths := TList<Integer>.Create;
  try
    for lLineIndex := aBinding.BodyLine to aReference.Line do
    begin
      if (lLineIndex <= 0) or (lLineIndex > Length(lLines)) then
        Continue;
      lLine := Trim(lLines[lLineIndex - 1]);
      lLowerLine := LowerCase(lLine);
      if StartsText('end', lLowerLine) and (lBlockDepth > 0) then
      begin
        Dec(lBlockDepth);
        while (lDeclarationDepths.Count > 0) and
          (lDeclarationDepths[lDeclarationDepths.Count - 1] > lBlockDepth) do
          lDeclarationDepths.Delete(lDeclarationDepths.Count - 1);
      end;
      lDeclarationName := '';
      if StartsText('var ', lLowerLine) then
        lDeclarationName := Trim(Copy(lLine, Length('var ') + 1, MaxInt))
      else if StartsText('for var ', lLowerLine) then
        lDeclarationName := Trim(Copy(lLine, Length('for var ') + 1, MaxInt))
      else if StartsText('on ', lLowerLine) then
        lDeclarationName := Trim(Copy(lLine, Length('on ') + 1, MaxInt));
      if lDeclarationName = '' then
      begin
        if LineOpensEndClosedBlock(lLine, lLowerLine) then
          Inc(lBlockDepth);
        Continue;
      end;
      lStopPos := Pos(':=', lDeclarationName);
      if lStopPos <= 0 then
        lStopPos := Pos(':', lDeclarationName);
      if lStopPos <= 0 then
        lStopPos := Pos(' in ', LowerCase(lDeclarationName));
      if lStopPos <= 0 then
        lStopPos := Pos(' ', lDeclarationName);
      if lStopPos > 0 then
        lDeclarationName := Trim(Copy(lDeclarationName, 1, lStopPos - 1));
      if SameText(lDeclarationName, lReferenceName) then
        lDeclarationDepths.Add(lBlockDepth);
      if LineOpensEndClosedBlock(lLine, lLowerLine) then
        Inc(lBlockDepth);
    end;
    Result := lDeclarationDepths.Count > 0;
  finally
    lDeclarationDepths.Free;
  end;
end;

function InlineDeclarationPositions(const aText: string): TArray<Boolean>;
var
  i: Integer;
  lDepth: Integer;
  lHandler: Boolean;
  lLexer: TmwBasePasLex;
  lPrevious: TptTokenKind;
  lStart: Integer;
begin
  Result := nil;
  if (not ContainsText(aText, 'var')) and (not ContainsText(aText, 'on')) then
    Exit;
  lLexer := TmwBasePasLex.Create;
  try
    lLexer.UseDefines := False;
    lLexer.Origin := aText;
    lPrevious := ptNull;
    while lLexer.TokenID <> ptNull do
    begin
      lStart := lLexer.TokenPos + 1;
      lHandler := (lLexer.GenID = ptOn) and SameText(lLexer.Token, 'on') and
        (lPrevious in [ptExcept, ptSemiColon, ptEnd]);
      if lHandler then
      begin
        lLexer.NextNoJunk;
        lHandler := lLexer.TokenID = ptIdentifier;
        if lHandler then
        begin
          lLexer.NextNoJunk;
          lHandler := lLexer.TokenID in [ptColon, ptDo];
        end;
      end;
      if (lLexer.TokenID = ptVar) or lHandler then
      begin
        lDepth := 0;
        if lLexer.TokenID <> ptDo then
          lLexer.NextNoJunk;
        while lLexer.TokenID <> ptNull do
        begin
          if (lDepth = 0) and
            ((lHandler and (lLexer.TokenID = ptDo)) or
            ((not lHandler) and (lLexer.TokenID in [ptAssign, ptSemiColon, ptIn]))) then
            Break;
          if lLexer.TokenID in [ptRoundOpen, ptSquareOpen] then
            Inc(lDepth)
          else if (lDepth > 0) and
            (lLexer.TokenID in [ptRoundClose, ptSquareClose]) then
            Dec(lDepth);
          lLexer.NextNoJunk;
        end;
        if Length(Result) = 0 then
          SetLength(Result, Length(aText) + 1);
        for i := lStart to lLexer.TokenPos do
          Result[i] := True;
      end;
      lPrevious := lLexer.TokenID;
      if lLexer.TokenID <> ptNull then
        lLexer.NextNoJunk;
    end;
  finally
    lLexer.Free;
  end;
end;

function BodyNonReferencePositions(const aText: string;
  const aRequireSyntaxMask: Boolean): TArray<Boolean>;
var
  i: Integer;
  lLexer: TmwBasePasLex;
  lStart: Integer;
begin
  Result := InlineDeclarationPositions(aText);
  if (not aRequireSyntaxMask) and (Pos('&', aText) = 0) then
    Exit;
  // DS-671: the lexer distinguishes &End from the END control token.
  // Compound reference names omit the leading escape, so their inner
  // syntax always needs this mask. Ordinary unescaped bodies keep our
  // existing declaration scan and its cost.
  lLexer := TmwBasePasLex.Create;
  try
    lLexer.UseDefines := False;
    lLexer.Origin := aText;
    while lLexer.TokenID <> ptNull do
    begin
      if lLexer.TokenID <> ptIdentifier then
      begin
        if Length(Result) = 0 then
          SetLength(Result, Length(aText) + 1);
        lStart := lLexer.TokenPos + 1;
        for i := lStart to lStart + Length(lLexer.Token) - 1 do
          Result[i] := True;
      end;
      lLexer.NextNoJunk;
    end;
  finally
    lLexer.Free;
  end;
end;

function BodyOffsetIsDeclaration(const aDeclarations: TArray<Boolean>;
  const aOffset: Integer): Boolean;
begin
  Result := (aOffset > 0) and (aOffset < Length(aDeclarations)) and
    aDeclarations[aOffset];
end;

function ReferenceIsCompilerIntrinsicTypeName(
  const aReference: TDelphiSemanticBoundReference): Boolean;
var
  lName: string;
  lSeparator: Integer;
begin
  lName := Trim(aReference.Name);
  lSeparator := LastDelimiter('.', lName);
  if (lSeparator > 0) and (lSeparator < Length(lName)) then
    lName := Copy(lName, lSeparator + 1, MaxInt);
  Result := MatchText(lName, ['AnsiChar', 'Exit', 'Integer', 'Int32', 'PByte']);
end;

function ReferenceAppearsQualified(const aReference: TDelphiSemanticBoundReference;
  const aBinding: TDelphiSemanticWithBinding;
  const aLineCache: TDelphiSemanticSourceContextCache): Boolean;
var
  lColumn: Integer;
  lLine: string;
  lLines: TArray<string>;
  lSelectorColumn: Integer;
begin
  Result := False;
  if (aReference.Line <= 0) or (aReference.Column <= 1) or
    (not aLineCache.TryGetValue(aBinding.FileName, lLines)) or
    (aReference.Line > Length(lLines)) then
    Exit;
  lLine := lLines[aReference.Line - 1];
  lColumn := aReference.Column - 1;
  if lColumn > Length(lLine) then
    Exit;
  lSelectorColumn := PosEx(aBinding.SelectorText, lLine);
  while (lSelectorColumn > 0) and (not IsSimpleIdentifier(aBinding.SelectorText)) do
  begin
    if (aReference.Column >= lSelectorColumn) and
      (aReference.Column < lSelectorColumn + Length(aBinding.SelectorText)) then
      Exit(True);
    lSelectorColumn := PosEx(aBinding.SelectorText, lLine,
      lSelectorColumn + Length(aBinding.SelectorText));
  end;
  if (lColumn > 0) and (lLine[lColumn] = '&') then
    Dec(lColumn);
  while (lColumn > 0) and CharInSet(lLine[lColumn], [#9, ' ']) do
    Dec(lColumn);
  Result := IsMemberAccessDot(lLine, lColumn);
end;

function ReferenceLineHasConditionalDirective(const aBinding: TDelphiSemanticWithBinding;
  const aReference: TDelphiSemanticBoundReference;
  const aLineCache: TDelphiSemanticSourceContextCache): Boolean;
var
  lLines: TArray<string>;
begin
  if not aLineCache.TryGetValue(aBinding.FileName, lLines) then
    Exit(False);
  Result := TDelphiSemanticSourceConditionals.LineHasConditionalDirective(lLines,
    aReference.Line);
end;

function ReferenceInsideInactiveNeverConditionalRegion(
  const aBinding: TDelphiSemanticWithBinding;
  const aReference: TDelphiSemanticBoundReference;
  const aLineCache: TDelphiSemanticSourceContextCache): Boolean;
var
  lLines: TArray<string>;
begin
  if not aLineCache.TryGetValue(aBinding.FileName, lLines) then
    Exit(False);
  Result := TDelphiSemanticSourceConditionals.InsideInactiveNeverConditionalRegion(lLines,
    aBinding.BodyLine, aReference.Line);
end;

function LineIsTopLevel(const aLine: string): Boolean;
begin
  Result := (aLine <> '') and (not CharInSet(aLine[1], [#9, ' ']));
end;

function RoutineDeclarationHasOverload(const aBinding: TDelphiSemanticWithBinding;
  const aLineCache: TDelphiSemanticSourceContextCache;
  const aDeclarationLine: Integer): Boolean;
var
  lLines: TArray<string>;
begin
  Result := False;
  if not aLineCache.TryGetValue(aBinding.FileName, lLines) then
    Exit;
  if (aDeclarationLine <= 0) or (aDeclarationLine > Length(lLines)) then
    Exit;
  if not LineIsTopLevel(lLines[aDeclarationLine - 1]) then
    Exit;
  Result := ContainsText(lLines[aDeclarationLine - 1], 'overload') or
    ((aDeclarationLine < Length(lLines)) and
    ContainsText(lLines[aDeclarationLine], 'overload'));
end;

function RoutineDeclarationIsNestedInBindingScope(const aFacts:
  TRemoveWithPlanFacts; const aBinding:
  TDelphiSemanticWithBinding; const aRoutine: TDelphiSemanticInventorySymbol;
  const aLineCache: TDelphiSemanticSourceContextCache): Boolean;
var
  lLines: TArray<string>;
  lOwner: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  if not aLineCache.TryGetValue(aBinding.FileName, lLines) then
    Exit;
  if (aRoutine.Line <= 0) or (aRoutine.Line > Length(lLines)) then
    Exit;
  if LineIsTopLevel(lLines[aRoutine.Line - 1]) then
    Exit;
  if (aRoutine.EndLine <= 0) or (aRoutine.EndLine >= aBinding.Line) then
    Exit;
  for lOwner in aFacts.Symbols do
  begin
    if (not SameText(lOwner.SymbolClass, 'routine')) and
      (not SameText(lOwner.Kind, 'routine')) then
      Continue;
    if SameText(lOwner.FileName, aBinding.FileName) and
      (lOwner.Line < aRoutine.Line) and (lOwner.EndLine >= aBinding.EndLine) then
      Exit(True);
  end;
end;

function ReferenceHasPriorRoutineDeclaration(const aFacts:
  TRemoveWithPlanFacts; const aBinding:
  TDelphiSemanticWithBinding; const aReference: TDelphiSemanticBoundReference;
  const aLineCache: TDelphiSemanticSourceContextCache): Boolean;
var
  lName: string;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  lName := Trim(aReference.Name);
  if (lName = '') or (Pos('.', lName) > 0) or (Pos('[', lName) > 0) then
    Exit;
  for lSymbol in aFacts.LookupIndex.FindSymbolsByName(lName) do
  begin
    if (not SameText(lSymbol.SymbolClass, 'routine')) and
      (not SameText(lSymbol.Kind, 'routine')) then
      Continue;
    if SameText(lSymbol.FileName, aBinding.FileName) and
      (lSymbol.Line > 0) and (lSymbol.Line < aReference.Line) and
      (RoutineDeclarationHasOverload(aBinding, aLineCache, lSymbol.Line) or
      RoutineDeclarationIsNestedInBindingScope(aFacts, aBinding, lSymbol,
      aLineCache)) then
      Exit(True);
  end;
end;

function ReferenceAppearsAsAssignmentTarget(const aReference:
  TDelphiSemanticBoundReference; const aBinding: TDelphiSemanticWithBinding;
  const aLineCache: TDelphiSemanticSourceContextCache): Boolean;
var
  lColumn: Integer;
  lLine: string;
  lLines: TArray<string>;
begin
  Result := False;
  if (aReference.Line <= 0) or (aReference.Column <= 0) or
    (not aLineCache.TryGetValue(aBinding.FileName, lLines)) or
    (aReference.Line > Length(lLines)) then
    Exit;
  lLine := lLines[aReference.Line - 1];
  lColumn := aReference.Column + Length(aReference.Name);
  while (lColumn <= Length(lLine)) and CharInSet(lLine[lColumn], [#9, ' ']) do
    Inc(lColumn);
  Result := Copy(lLine, lColumn, 2) = ':=';
end;

function ReceiverMemberMissReason(const aReference:
  TDelphiSemanticBoundReference; const aBinding: TDelphiSemanticWithBinding;
  const aLineCache: TDelphiSemanticSourceContextCache): string;
begin
  if ReferenceAppearsAsAssignmentTarget(aReference, aBinding, aLineCache) then
    Result := 'receiver-member-not-found'
  else
    Result := 'symbol-not-found';
end;

function BindingHasUnverifiedLocalAlias(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding): Boolean;
var
  lCandidates: TArray<TDelphiSemanticInventorySymbol>;
  lParentScope: string;
  lRoutineCount, lRemaining: Integer;
  lScopeId: string;
  lSelector: TDelphiSemanticWithSelectorBinding;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  for lSelector in aBinding.Selectors do
    if SameText(lSelector.ReasonCode, 'ROUTINE_LOCAL_TYPE_UNSUPPORTED') then
    begin
      lCandidates := aFacts.LookupIndex.FindDeclarationOrTypeAliasByName(lSelector.TypeName);
      lScopeId := aBinding.RoutineScopeId;
      lRemaining := Length(aFacts.Symbols) + 1;
      // Captured receivers may use an alias declared by any enclosing routine.
      // Follow exact scope IDs, bounded even when supplied inventory is malformed.
      while (lScopeId <> '') and (lRemaining > 0) do
      begin
        Dec(lRemaining);
        for lSymbol in lCandidates do
          if (SameText(lSymbol.Kind, 'type-alias') or
            (SameText(lSymbol.Kind, 'unsupported-local-type') and
            StartsText('type ', Trim(lSymbol.TypeName)))) and
            SameText(lSymbol.FileName, aBinding.FileName) and
            SameText(lSymbol.RoutineScopeId, lScopeId) then
            Exit(True);
        lRoutineCount := 0;
        lParentScope := '';
        for lSymbol in aFacts.Symbols do
          if SameText(lSymbol.SymbolClass, 'routine') and
            SameText(lSymbol.FileName, aBinding.FileName) and
            SameText(lSymbol.RoutineScopeId, lScopeId) then
          begin
            Inc(lRoutineCount);
            lParentScope := lSymbol.ParentScopeId;
          end;
        // DS-741: a forward or ambiguous routine inventory cannot prove
        // that an enclosing alias is absent. Never turn that gap into a plan.
        if lRoutineCount <> 1 then
          Exit(True);
        lScopeId := lParentScope;
      end;
      if lScopeId <> '' then
        Exit(True);
    end;
end;

function BindingHelperUnverifiedReason(const aBinding: TDelphiSemanticWithBinding;
  const aLineCache: TDelphiSemanticSourceContextCache; out aReason: string): Boolean;
var
  lReference: TDelphiSemanticBoundReference;
begin
  aReason := '';
  for lReference in aBinding.References do
    if SameText(lReference.Classification, 'unsupported') and
      SameText(lReference.ReasonCode, 'RECORD_HELPER_MEMBERS_UNVERIFIED') then
    begin
      aReason := ReceiverMemberMissReason(lReference, aBinding, aLineCache);
      Exit(True);
    end;
  Result := False;
end;

function ExistingSymbolName(const aFacts: TRemoveWithPlanFacts;
  const aRoutineName, aName: string): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := aFacts.LookupIndex.FindRoutineSymbol(aRoutineName, aName, lSymbol) or
    (Length(aFacts.LookupIndex.FindUnitOrGlobalByName(aName)) > 0);
end;

function SelectorIsByReferenceParameter(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aSelectorText: string): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  if not IsSimpleIdentifier(aSelectorText) then
    Exit;
  if not TryFindRoutineScopedSymbolForBinding(aFacts, aBinding,
    Trim(aSelectorText), lSymbol) then
    Exit;
  Result := SameText(lSymbol.SymbolClass, 'parameter') and
    MatchText(lSymbol.Modifier, ['var', 'out']);
end;

function SelectorIsByValueParameter(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aSelectorText: string): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  if not IsSimpleIdentifier(aSelectorText) then
    Exit;
  if not TryFindRoutineScopedSymbolForBinding(aFacts, aBinding,
    Trim(aSelectorText), lSymbol) then
    Exit;
  Result := SameText(lSymbol.SymbolClass, 'parameter') and (Trim(lSymbol.Modifier) = '');
end;

function ReferenceIsByValueRoutineParameter(
  const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aReference: TDelphiSemanticBoundReference): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  if not SameText(aReference.Classification, 'lexical') then
    Exit;
  if not aFacts.LookupIndex.FindRoutineSymbol(aBinding.RoutineName, aReference.Name,
    lSymbol) then
    Exit;
  Result := SameText(lSymbol.SymbolClass, 'parameter') and (Trim(lSymbol.Modifier) = '');
end;

function ByValueParameterReferencesHaveUnitFallback(
  const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding): Boolean;
var
  lBodyRange: TDelphiSemanticRemoveWithSourceRange;
  lHasParameterReference: Boolean;
  lReference: TDelphiSemanticBoundReference;
begin
  Result := False;
  lHasParameterReference := False;
  lBodyRange := BindingBodyRange(aBinding);
  for lReference in aBinding.References do
  begin
    if (not ReferenceInsideRange(lReference, lBodyRange)) or
      (not ReferenceIsByValueRoutineParameter(aFacts, aBinding, lReference)) then
      Continue;
    lHasParameterReference := True;
    if Length(aFacts.LookupIndex.FindUnitOrGlobalByName(lReference.Name)) = 0 then
      Exit;
  end;
  Result := lHasParameterReference;
end;

function BindingFollowsControlStatement(const aBinding: TDelphiSemanticWithBinding;
  const aLineCache: TDelphiSemanticSourceContextCache): Boolean;
var
  lLineIndex: Integer;
  lLines: TArray<string>;
  lText: string;
begin
  Result := False;
  if not aLineCache.TryGetValue(aBinding.FileName, lLines) then
    Exit;
  for lLineIndex := aBinding.Line - 1 downto 1 do
  begin
    lText := Trim(lLines[lLineIndex - 1]);
    if (lText = '') or StartsText('//', lText) then
      Continue;
    Result := EndsText(' then', LowerCase(lText)) or SameText(lText, 'then') or
      EndsText(' do', LowerCase(lText)) or SameText(lText, 'do') or
      EndsText(' else', LowerCase(lText)) or SameText(lText, 'else') or
      SameText(lText, 'try') or EndsText(':', lText);
    Exit;
  end;
end;

function ReservedTempName(const aFacts: TRemoveWithPlanFacts;
  const aReservedNames: TDictionary<string, Integer>; const aRoutineName,
  aBaseName: string): string;
var
  lIndex: Integer;
  lKey: string;
begin
  lIndex := 0;
  repeat
    if lIndex = 0 then
      Result := aBaseName
    else
      Result := aBaseName + IntToStr(lIndex);
    Inc(lIndex);
    lKey := aRoutineName + #31 + Result;
  until (not aReservedNames.ContainsKey(lKey)) and
    (not ExistingSymbolName(aFacts, aRoutineName, Result));
  aReservedNames.Add(lKey, 1);
end;

procedure RollbackReservedTempName(
  const aReservedNames: TDictionary<string, Integer>; const aRoutineName,
  aTempName: string);
begin
  if Trim(aTempName) = '' then
    Exit;
  aReservedNames.Remove(aRoutineName + #31 + aTempName);
end;

procedure RollbackReservedTempNamesForDecisions(
  const aReservedNames: TDictionary<string, Integer>; const aRoutineName: string;
  const aDecisions: TArray<TFinalSelectorDecision>);
var
  lDecision: TFinalSelectorDecision;
begin
  for lDecision in aDecisions do
    RollbackReservedTempName(aReservedNames, aRoutineName, lDecision.TempName);
end;

procedure RollbackReservedTempNamesForFinalTemps(
  const aReservedNames: TDictionary<string, Integer>; const aRoutineName: string;
  const aTemps: TArray<TDelphiSemanticRemoveWithFinalTempDecision>);
var
  lTemp: TDelphiSemanticRemoveWithFinalTempDecision;
begin
  for lTemp in aTemps do
    RollbackReservedTempName(aReservedNames, aRoutineName, lTemp.TempName);
end;

function RoutineDeclarationIsProcedure(const aBinding: TDelphiSemanticWithBinding;
  const aLineCache: TDelphiSemanticSourceContextCache): Boolean; forward;

function RoutineDeclarationIsMethod(const aBinding: TDelphiSemanticWithBinding;
  const aLineCache: TDelphiSemanticSourceContextCache): Boolean; forward;

procedure AddSelectorChainPart(var aParts: TArray<string>; const aPart: string);
var
  lPartCount: Integer;
begin
  lPartCount := Length(aParts);
  SetLength(aParts, lPartCount + 1);
  aParts[lPartCount] := Trim(aPart);
end;

function TrySplitSelectorChainParts(const aSelectorText: string;
  out aParts: TArray<string>): Boolean;
var
  i: Integer;
  lBracketDepth: Integer;
  lPart: string;
begin
  Result := False;
  aParts := nil;
  lBracketDepth := 0;
  lPart := '';
  for i := 1 to Length(aSelectorText) do
  begin
    if aSelectorText[i] = '[' then
      Inc(lBracketDepth)
    else if aSelectorText[i] = ']' then
    begin
      if lBracketDepth <= 0 then
      begin
        aParts := nil;
        Exit;
      end;
      Dec(lBracketDepth);
    end;

    if (aSelectorText[i] = '.') and (lBracketDepth = 0) then
    begin
      if Trim(lPart) = '' then
      begin
        aParts := nil;
        Exit;
      end;
      AddSelectorChainPart(aParts, lPart);
      lPart := '';
    end else
      lPart := lPart + aSelectorText[i];
  end;

  if (lBracketDepth <> 0) or (Trim(lPart) = '') then
  begin
    aParts := nil;
    Exit;
  end;
  AddSelectorChainPart(aParts, lPart);
  Result := Length(aParts) > 1;
end;

function InventorySymbolIsSourceBacked(const aSymbol:
  TDelphiSemanticInventorySymbol): Boolean;
begin
  Result := (Trim(aSymbol.FileName) <> '') and
    (not MatchText(aSymbol.SourceOwnerType, ['compiler-intrinsic',
    'rtl-source']));
end;

function RoutineScopedSymbolMatchesBinding(const aSymbol:
  TDelphiSemanticInventorySymbol;
  const aBinding: TDelphiSemanticWithBinding): Boolean;
begin
  Result := InventorySymbolIsSourceBacked(aSymbol) and
    MatchText(aSymbol.SymbolClass, ['local', 'parameter']) and
    SameText(aSymbol.FileName, aBinding.FileName) and
    (aSymbol.Line > 0) and (aSymbol.Line <= aBinding.Line) and
    ((Trim(aBinding.RoutineName) = '') or (Trim(aSymbol.RoutineName) = '') or
    SameText(aSymbol.RoutineName, aBinding.RoutineName) or
    RoutineNameMatchesOrEncloses(aSymbol.RoutineName, aBinding.RoutineName) or
    RoutineNameMatchesOrEncloses(aBinding.RoutineName, aSymbol.RoutineName));
end;

function RoutineSymbolEnclosesBinding(const aFacts: TRemoveWithPlanFacts;
  const aRoutineName: string; const aBinding: TDelphiSemanticWithBinding):
  Boolean;
var
  lRoutineLeaf: string;
  lRoutineSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  lRoutineLeaf := RoutineLeafName(aRoutineName);
  if (lRoutineLeaf = '') or (aBinding.Line <= 0) then
    Exit;

  for lRoutineSymbol in aFacts.LookupIndex.FindSymbolsByName(lRoutineLeaf) do
  begin
    if (not SameText(lRoutineSymbol.FileName, aBinding.FileName)) or
      (not SymbolIsRoutineMemberKind(lRoutineSymbol)) or
      (not SameText(lRoutineSymbol.Name, lRoutineLeaf)) or
      (lRoutineSymbol.Line <= 0) or (lRoutineSymbol.Line > aBinding.Line) or
      (lRoutineSymbol.EndLine < aBinding.Line) then
      Continue;
    Exit(True);
  end;
end;

function RoutineScopedSymbolBindingScore(const aFacts: TRemoveWithPlanFacts;
  const aSymbol: TDelphiSemanticInventorySymbol;
  const aBinding: TDelphiSemanticWithBinding): Integer;
var
  lBindingRoutine: string;
  lSymbolRoutine: string;
begin
  Result := -1;
  if (not InventorySymbolIsSourceBacked(aSymbol)) or
    (not MatchText(aSymbol.SymbolClass, ['local', 'parameter'])) or
    (not SameText(aSymbol.FileName, aBinding.FileName)) or
    (aSymbol.Line <= 0) or (aSymbol.Line > aBinding.Line) then
    Exit;

  lBindingRoutine := Trim(aBinding.RoutineName);
  lSymbolRoutine := Trim(aSymbol.RoutineName);
  if SameText(lSymbolRoutine, lBindingRoutine) then
    Exit(200000 + Length(lSymbolRoutine));
  if RoutineNameMatchesOrEncloses(lSymbolRoutine, lBindingRoutine) then
    Exit(100000 + Length(lSymbolRoutine));
  if RoutineNameMatchesOrEncloses(lBindingRoutine, lSymbolRoutine) then
    Exit(90000 + Length(lSymbolRoutine));
  if RoutineSymbolEnclosesBinding(aFacts, lSymbolRoutine, aBinding) then
    Exit(80000 + Length(lSymbolRoutine));
  if (lSymbolRoutine = '') and (lBindingRoutine = '') then
    Exit(0);
end;

function TryFindRoutineScopedSymbolForBinding(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aName: string;
  out aSymbol: TDelphiSemanticInventorySymbol): Boolean;
var
  lBestScore: Integer;
  lFound: Boolean;
  lScore: Integer;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  if aFacts.LookupIndex.TryReuseRoutineScopedSymbol(aBinding, aName, lFound,
    aSymbol) then
  begin
    Result := lFound;
    Exit;
  end;
  lBestScore := -1;
  for lSymbol in aFacts.LookupIndex.FindSymbolsByName(aName) do
  begin
    lScore := RoutineScopedSymbolBindingScore(aFacts, lSymbol, aBinding);
    if lScore <= lBestScore then
      Continue;
    lBestScore := lScore;
    aSymbol := lSymbol;
    Result := True;
  end;
  aFacts.LookupIndex.StoreRoutineScopedSymbol(aBinding, aName, Result,
    aSymbol);
end;

function TryFindSourceBackedSelectorSymbol(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aName: string;
  out aSymbol: TDelphiSemanticInventorySymbol): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  aSymbol := Default(TDelphiSemanticInventorySymbol);
  if TryFindRoutineScopedSymbolForBinding(aFacts, aBinding, aName, lSymbol) and
    (Trim(lSymbol.TypeName) <> '') then
  begin
    aSymbol := lSymbol;
    Exit(True);
  end;

  for lSymbol in aFacts.LookupIndex.FindSymbolsByName(aName) do
  begin
    if RoutineScopedSymbolMatchesBinding(lSymbol, aBinding) then
    begin
      aSymbol := lSymbol;
      Exit(True);
    end;
  end;
end;

function TryResolveSelectorBasePartType(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aSelectorPart: string;
  out aTypeName, aSymbolClass: string): Boolean;
var
  lBaseName: string;
  lShapeType: string;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  aTypeName := '';
  aSymbolClass := '';
  lBaseName := SelectorBaseIdentifier(aSelectorPart);
  if lBaseName = '' then
    Exit;

  if TryFindSourceBackedSelectorSymbol(aFacts, aBinding, lBaseName,
    lSymbol) then
  begin
    lShapeType := SelectorChainPartShapeType(aFacts, lSymbol.TypeName, aSelectorPart);
    if lShapeType <> '' then
    begin
      aTypeName := lShapeType;
      aSymbolClass := lSymbol.SymbolClass;
      Exit(True);
    end;
  end;

  for lSymbol in aFacts.LookupIndex.FindUnitOrGlobalByName(lBaseName) do
  begin
    if not InventorySymbolIsSourceBacked(lSymbol) then
      Continue;
    lShapeType := SelectorChainPartShapeType(aFacts, lSymbol.TypeName, aSelectorPart);
    if lShapeType <> '' then
    begin
      aTypeName := lShapeType;
      aSymbolClass := lSymbol.SymbolClass;
      Exit(True);
    end;
  end;
end;

function TypeIdentityHasVerifiedOrigin(const aIdentity: TDelphiSemanticTypeIdentity):
  Boolean;
begin
  Result := (aIdentity.UnitName <> '') and (aIdentity.Name <> '') and
    (aIdentity.DeclaredId.Value <> '') and (aIdentity.CanonicalId.Value <> '') and
    (aIdentity.SectionKind <> '') and (aIdentity.SourceRange.FileName <> '') and
    (aIdentity.SourceRange.Line > 0) and
    (aIdentity.SourceRange.Column > 0) and
    (not SameText(aIdentity.ScopeKind, 'routine') or
      ((aIdentity.OwnerScopeId <> '') and
        (aIdentity.SemanticSymbolId <> '')));
end;

function TypeIdentitiesAreSameDeclaration(const aLeft,
  aRight: TDelphiSemanticTypeIdentity): Boolean;
begin
  Result := TypeIdentityHasVerifiedOrigin(aLeft) and
    TypeIdentityHasVerifiedOrigin(aRight) and
    SameText(aLeft.DeclaredId.Value, aRight.DeclaredId.Value) and
    SameText(aLeft.CanonicalId.Value, aRight.CanonicalId.Value) and
    SameText(aLeft.UnitName, aRight.UnitName) and
    SameText(aLeft.Name, aRight.Name) and
    SameText(aLeft.ScopeKind, aRight.ScopeKind) and
    SameText(aLeft.OwnerScopeId, aRight.OwnerScopeId) and
    SameText(aLeft.SemanticSymbolId, aRight.SemanticSymbolId) and
    SameText(aLeft.SourceRange.FileName, aRight.SourceRange.FileName) and
    SameText(aLeft.SectionKind, aRight.SectionKind) and
    (aLeft.SourceRange.Line = aRight.SourceRange.Line) and
    (aLeft.SourceRange.Column = aRight.SourceRange.Column) and
    (aLeft.SourceRange.EndLine = aRight.SourceRange.EndLine) and
    (aLeft.SourceRange.EndColumn = aRight.SourceRange.EndColumn);
end;

function TryResolveSelectorChainMemberType(const aFacts: TRemoveWithPlanFacts;
  const aOwnerType, aSelectorPart: string;
  const aOwnerIdentity: TDelphiSemanticTypeIdentity;
  out aTypeName: string): Boolean;
var
  lMember: TDelphiSemanticInventorySymbol;
  lMemberName: string;
  lShapeType: string;

  function TryUseMember(const aMember: TDelphiSemanticInventorySymbol): Boolean;
  begin
    Result := False;
    if not InventorySymbolIsSourceBacked(aMember) then
      Exit;
    if SameText(aMember.Kind, 'property') or
      SameText(aMember.SymbolClass, 'property') then
      Exit;
    if not SymbolIsMemberOfOwner(aMember, aOwnerType) then
      Exit;
    if aOwnerIdentity.DeclaredId.Value <> '' then
    begin
      if (not TypeIdentityHasVerifiedOrigin(aMember.OwnerIdentity)) or
        ((not TypeIdentitiesAreSameDeclaration(aMember.OwnerIdentity,
          aOwnerIdentity)) and
        ((not TypeIdentitiesAreSameDeclaration(aMember.AccessOwnerIdentity,
          aOwnerIdentity)) or
          (not SameText(aMember.AccessOwnerIdentity.Name,
            aMember.OwnerName)))) then
        Exit;
    end;
    lShapeType := SelectorChainPartShapeType(aFacts, aMember.TypeName, aSelectorPart);
    if lShapeType = '' then
      Exit;
    aTypeName := lShapeType;
    Result := True;
  end;

begin
  Result := False;
  aTypeName := '';
  lMemberName := SelectorBaseIdentifier(aSelectorPart);
  if (aOwnerType = '') or (lMemberName = '') then
    Exit;

  for lMember in aFacts.LookupIndex.FindMembersByOwnerAndName(aOwnerType,
    lMemberName) do
  begin
    if TryUseMember(lMember) then
      Exit(True);
  end;

  for lMember in aFacts.LookupIndex.FindSymbolsByName(lMemberName) do
  begin
    if TryUseMember(lMember) then
      Exit(True);
  end;
end;

function TryResolveSourceBackedSelectorChainType(
  const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aSelectorText: string;
  out aReceiverType, aRootSymbolClass: string): Boolean;
var
  lCurrentType: string;
  lNextType: string;
  lPartIndex: Integer;
  lParts: TArray<string>;
begin
  Result := False;
  aReceiverType := '';
  aRootSymbolClass := '';
  if not TrySplitSelectorChainParts(aSelectorText, lParts) then
    Exit;
  if not TryResolveSelectorBasePartType(aFacts, aBinding, lParts[0],
    lCurrentType, aRootSymbolClass) then
    Exit;
  for lPartIndex := 1 to High(lParts) do
  begin
    if not TryResolveSelectorChainMemberType(aFacts, lCurrentType,
      lParts[lPartIndex], Default(TDelphiSemanticTypeIdentity), lNextType) then
      Exit;
    lCurrentType := lNextType;
  end;
  aReceiverType := lCurrentType;
  Result := aReceiverType <> '';
end;

function BindingReferencesAreResolved(const aBinding:
  TDelphiSemanticWithBinding): Boolean;
begin
  Result := (aBinding.UnresolvedReferenceCount = 0) and
    (aBinding.UnsupportedReferenceCount = 0);
end;

function SourceBackedSelectorChainRootIsSafe(const aRootSymbolClass: string;
  const aBinding: TDelphiSemanticWithBinding): Boolean;
begin
  Result := not SameText(aRootSymbolClass, 'local') or
    BindingReferencesAreResolved(aBinding);
end;

function BindingBodyContainsNestedWith(const aBinding: TDelphiSemanticWithBinding;
  const aLineCache: TDelphiSemanticSourceContextCache): Boolean;
var
  lLineIndex: Integer;
  lLines: TArray<string>;
begin
  Result := False;
  if (aBinding.BodyLine <= 0) or (aBinding.BodyEndLine <= 0) or
    (not aLineCache.TryGetValue(aBinding.FileName, lLines)) then
    Exit;
  for lLineIndex := aBinding.BodyLine to aBinding.BodyEndLine do
  begin
    if lLineIndex = aBinding.Line then
      Continue;
    if (lLineIndex < 1) or (lLineIndex > Length(lLines)) then
      Continue;
    if ContainsText(lLines[lLineIndex - 1], 'with ') then
      Exit(True);
  end;
end;

function TryResolveDependentSelectorType(const aFacts: TRemoveWithPlanFacts;
  const aDecisions: TArray<TFinalSelectorDecision>; const aSelectorText: string;
  const aSelector: TDelphiSemanticWithSelectorBinding;
  out aHasDependentReceiver: Boolean; out aReceiverType: string): Boolean;
var
  i: Integer;
  lNextType: string;
  lParts: TArray<string>;
begin
  Result := False;
  aHasDependentReceiver := False;
  aReceiverType := '';
  for i := High(aDecisions) downto 0 do
  begin
    if not TypeIdentityHasVerifiedOrigin(aDecisions[i].ReceiverIdentity) then
    begin
      aHasDependentReceiver := True;
      Exit;
    end;
    if (not TrySplitSelectorChainParts(aSelectorText, lParts)) and
      (Length(lParts) <> 1) then
      Exit;
    if not OwnerHasMemberNamed(aFacts, aDecisions[i].ReceiverType,
      SelectorBaseIdentifier(lParts[0])) then
      Continue;
    aHasDependentReceiver := True;
    if not TryResolveSelectorChainMemberType(aFacts, aDecisions[i].ReceiverType,
      lParts[0], aDecisions[i].ReceiverIdentity, lNextType) then
      Exit;
    if Length(lParts) = 1 then
      aReceiverType := lNextType
    else
    begin
      // The binder resolved the complete chain from this receiver; do not reuse
      // the parent's declaration identity for a later member's different owner.
      if (not SameText(aSelector.SelectorText, aSelectorText)) or
        (not SameText(aSelector.Status, 'resolved')) or
        (aSelector.TypeName = '') or
        (not TypeIdentityHasVerifiedOrigin(aSelector.TypeIdentity)) then
        Exit;
      aReceiverType := aSelector.TypeName;
    end;
    Exit(True);
  end;
end;

function FindRoutineDeclarationRange(const aFileName: string;
  const aBeforeLine: Integer; const aRoutineName: string;
  const aLineCache: TDelphiSemanticSourceContextCache;
  out aRange: TDelphiSemanticRemoveWithSourceRange; out aHasVarSection: Boolean):
  Boolean; forward;

function CaptureDeclarationIsVisible(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aDeclaration: TDelphiSemanticInventorySymbol;
  const aLineCache: TDelphiSemanticSourceContextCache): Boolean;
var
  lHasVarSection: Boolean;
  lInsertion: TDelphiSemanticRemoveWithSourceRange;
  lRoutine: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  if SameText(aDeclaration.FileName, aBinding.FileName) then
  begin
    if (aDeclaration.Line <= 0) or (aDeclaration.Line > aBinding.Line) then
      Exit;
    if (not FindRoutineDeclarationRange(aBinding.FileName, aBinding.Line,
      aBinding.RoutineName, aLineCache, lInsertion, lHasVarSection)) or
      (aDeclaration.Line >= lInsertion.StartLine) then
      Exit;
    // A local type must belong to a routine that also encloses the capture.
    for lRoutine in aFacts.Symbols do
    begin
      if (not SameText(lRoutine.Kind, 'routine')) or
        (not SameText(lRoutine.FileName, aBinding.FileName)) or
        (lRoutine.Line >= aDeclaration.Line) or
        (lRoutine.EndLine < aDeclaration.Line) then
        Continue;
      if (aBinding.Line <= lRoutine.Line) or
        (aBinding.EndLine > lRoutine.EndLine) then
        Exit;
    end;
    Exit(True);
  end;
  if not SameText(aDeclaration.SectionKind, 'interface') then
    Exit;
  if SameText(aDeclaration.UnitName, 'System') then
    Exit(True);
  Result := (aFacts.UnitVisibility <> nil) and
    aFacts.UnitVisibility.IsUnitVisible(aBinding.FileName, aDeclaration.UnitName);
end;

function DeclarationIsRoutineLocal(const aFacts: TRemoveWithPlanFacts;
  const aDeclaration: TDelphiSemanticInventorySymbol): Boolean;
var
  lRoutine: TDelphiSemanticInventorySymbol;
begin
  // Unit-scope declarations carry the unit scope id; a local one carries the scope
  // of a routine, or at least lies inside a routine body of its file.
  for lRoutine in aFacts.Symbols do
    if ((aDeclaration.RoutineScopeId <> '') and
      SameText(lRoutine.SymbolClass, 'routine') and
      SameText(lRoutine.RoutineScopeId, aDeclaration.RoutineScopeId)) or
      (SameText(lRoutine.Kind, 'routine') and
      SameText(lRoutine.FileName, aDeclaration.FileName) and
      (lRoutine.Line < aDeclaration.Line) and
      (lRoutine.EndLine >= aDeclaration.Line)) then
      Exit(True);
  Result := False;
end;

function CaptureLookupDenies(const aSelector: TDelphiSemanticWithSelectorBinding;
  const aTypeName: string; const aReceiverIdentity: TDelphiSemanticTypeIdentity): Boolean;
begin
  Result := SameText(aSelector.ReasonCode, 'TYPE_VISIBILITY_UNPROVED');
  if Result or (aSelector.CaptureTypeName = '') then
    Exit;
  // DS-719: an unknown alias cannot authorize a temp of its underlying type.
  Result := (aSelector.CaptureTypeStatus = '') or
    SameText(aSelector.CaptureTypeStatus, 'unproved') or
    SameText(aSelector.CaptureTypeStatus, 'ambiguous') or
    (SameText(aSelector.CaptureTypeName, aTypeName) and
      SameText(aSelector.CaptureTypeStatus, 'resolved') and
      ((aSelector.CaptureTypeIdentity.CanonicalId.Value = '') or
       (aSelector.CaptureTypeIdentity.CanonicalId.Value <> aReceiverIdentity.CanonicalId.Value)));
end;

function BindingReceiverVisibilityDenies(const aBinding: TDelphiSemanticWithBinding): Boolean;
var
  lSelector: TDelphiSemanticWithSelectorBinding;
  lReference: TDelphiSemanticBoundReference;
begin
  // A6: unsupported body references do not disprove receiver-type visibility.
  Result := False;
  for lSelector in aBinding.Selectors do
    if CaptureLookupDenies(lSelector, '', lSelector.CaptureTypeIdentity) or
      MatchText(lSelector.Status, ['unproved', 'ambiguous']) or
      MatchText(lSelector.CaptureTypeStatus, ['unproved', 'ambiguous']) or
      SameText(lSelector.ReasonCode, 'TYPE_VISIBILITY_UNPROVED') then
      Exit(True);
  for lReference in aBinding.References do
    if SameText(lReference.ReasonCode, 'TYPE_VISIBILITY_UNPROVED') then
      Exit(True);
end;

function UniqueUnitTypeDeclarationIsVisible(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aSelector: TDelphiSemanticWithSelectorBinding; const aTypeName: string;
  const aLineCache: TDelphiSemanticSourceContextCache;
  out aCaptureDenied: Boolean): Boolean;
var
  lDeclaration: TDelphiSemanticInventorySymbol;
  lSelected: TDelphiSemanticInventorySymbol;
begin
  // Without a binder identity only a project-unique name proves which declaration
  // the unqualified temp type denotes; any other declaration of it refuses.
  aCaptureDenied := False;
  Result := False;
  lSelected := Default(TDelphiSemanticInventorySymbol);
  for lDeclaration in aFacts.LookupIndex.FindDeclarationOrTypeAliasByName(aTypeName) do
  begin
    if (not SameText(aTypeName, lDeclaration.Name)) and
      (not SameText(aTypeName, lDeclaration.UnitName + '.' + lDeclaration.Name)) then
      Continue;
    // Only cast binding has already checked the target's declaration identity.
    if ResolvedPointerCastSelector(aBinding, aBinding.SelectorText) and
      (not CaptureDeclarationIsVisible(aFacts, aBinding, lDeclaration, aLineCache)) then
      Continue;
    if Result and ((not SameText(lSelected.FileName, lDeclaration.FileName)) or
      (lSelected.Line <> lDeclaration.Line) or
      (lSelected.Column <> lDeclaration.Column)) then
      Exit(False);
    if (not Result) or SameText(lDeclaration.SymbolClass, 'declaration') then
      lSelected := lDeclaration;
    Result := True;
  end;
  // A routine-local type is visible only through its scoped binder identity.
  Result := Result and (not DeclarationIsRoutineLocal(aFacts, lSelected)) and
    CaptureDeclarationIsVisible(aFacts, aBinding, lSelected, aLineCache);
  if Result then
  begin
    // No receiver identity exists here; the shared predicate still rejects an
    // unknown capture before the declaration-name comparison below.
    aCaptureDenied := CaptureLookupDenies(aSelector, '', aSelector.CaptureTypeIdentity);
    if (not aCaptureDenied) and SameText(aSelector.CaptureTypeName, aTypeName) and
      SameText(aSelector.CaptureTypeStatus, 'resolved') then
      aCaptureDenied := (not SameText(aSelector.CaptureTypeIdentity.UnitName, lSelected.UnitName)) or
        (not SameText(aSelector.CaptureTypeIdentity.Name, lSelected.Name));
    Result := not aCaptureDenied;
  end;
end;

function HeadCaptureTypeIsVisible(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aSelector: TDelphiSemanticWithSelectorBinding; const aTypeName: string;
  const aIdentity: TDelphiSemanticTypeIdentity;
  const aLineCache: TDelphiSemanticSourceContextCache): Boolean;
var
  lDeclaration: TDelphiSemanticInventorySymbol;
  lFoundSelected: Boolean;
  lMatchingCount: Integer;
  lRoutine: TDelphiSemanticInventorySymbol;
  lRoutineCount: Integer;
  lScopeId: string;
  lSeenScopes: TDictionary<string, Byte>;
  lSelected: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  if not TypeIdentityHasVerifiedOrigin(aIdentity) then
    Exit;
  if SameText(aIdentity.ScopeKind, 'routine') then
  begin
    if (aBinding.RoutineScopeId = '') or (aIdentity.OwnerScopeId = '') or
      (aIdentity.SemanticSymbolId = '') or
      (not SameText(aBinding.UnitName, aIdentity.UnitName)) or
      (not SameText(aBinding.FileName, aIdentity.SourceRange.FileName)) or
      (not SameText(aTypeName, aIdentity.Name)) then
      Exit;
    lSeenScopes := TDictionary<string, Byte>.Create(
      TFastCaseAwareComparer.OrdinalIgnoreCase);
    try
      lScopeId := aBinding.RoutineScopeId;
      while lScopeId <> '' do
      begin
        if lSeenScopes.ContainsKey(lScopeId) then
          Exit(False);
        lSeenScopes.Add(lScopeId, 0);
        lRoutineCount := 0;
        lRoutine := Default(TDelphiSemanticInventorySymbol);
        for lSelected in aFacts.Symbols do
          if SameText(lSelected.SymbolClass, 'routine') and
            SameText(lSelected.FileName, aBinding.FileName) and
            SameText(lSelected.RoutineScopeId, lScopeId) then
          begin
            Inc(lRoutineCount);
            lRoutine := lSelected;
          end;
        if lRoutineCount <> 1 then
          Exit(False);
        lMatchingCount := 0;
        for lDeclaration in aFacts.LookupIndex.FindDeclarationOrTypeAliasByName(
          aTypeName) do
          if SameText(lDeclaration.FileName, aBinding.FileName) and
            SameText(lDeclaration.RoutineScopeId, lScopeId) and
            SameText(lDeclaration.Name, aTypeName) then
          begin
            Inc(lMatchingCount);
            if (not SameText(lDeclaration.OwnerSymbolId,
              aIdentity.SemanticSymbolId)) or
              (not SameText(lDeclaration.OwnerScopeId,
                aIdentity.OwnerScopeId)) or
              (lDeclaration.Line <> aIdentity.SourceRange.Line) or
              (lDeclaration.Column <> aIdentity.SourceRange.Column) or
              (not CaptureDeclarationIsVisible(aFacts, aBinding,
                lDeclaration, aLineCache)) then
              Exit(False);
          end;
        if lMatchingCount > 0 then
          Exit(lMatchingCount = 1);
        lScopeId := lRoutine.ParentScopeId;
      end;
    finally
      lSeenScopes.Free;
    end;
    Exit(False);
  end;
  lFoundSelected := False;
  lSelected := Default(TDelphiSemanticInventorySymbol);
  for lDeclaration in aFacts.LookupIndex.FindDeclarationOrTypeAliasByName(aTypeName) do
  begin
    if (not SameText(aTypeName, lDeclaration.Name)) and
      (not SameText(aTypeName, lDeclaration.UnitName + '.' + lDeclaration.Name)) then
      Continue;
    if not CaptureDeclarationIsVisible(aFacts, aBinding, lDeclaration, aLineCache) then
      Continue;
    if Result and ((not SameText(lSelected.FileName, lDeclaration.FileName)) or
      (lSelected.Line <> lDeclaration.Line) or
      (lSelected.Column <> lDeclaration.Column)) then
      Exit(False);
    if not Result then
      lSelected := lDeclaration;
    if SameText(lDeclaration.UnitName, aIdentity.UnitName) and
      SameText(lDeclaration.Name, aIdentity.Name) and
      SameText(lDeclaration.FileName, aIdentity.SourceRange.FileName) and
      SameText(lDeclaration.SectionKind, aIdentity.SectionKind) and
      (lDeclaration.Line = aIdentity.SourceRange.Line) and
      (lDeclaration.Column = aIdentity.SourceRange.Column) and
      (lDeclaration.Line = aIdentity.SourceRange.EndLine) and
      (lDeclaration.Column + Length(lDeclaration.Name) =
        aIdentity.SourceRange.EndColumn) then
      lFoundSelected := True;
    Result := True;
  end;
  Result := Result and lFoundSelected;
end;

function CaptureTypeIsVisible(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aSelector: TDelphiSemanticWithSelectorBinding; const aTypeName: string;
  const aIdentity: TDelphiSemanticTypeIdentity;
  const aLineCache: TDelphiSemanticSourceContextCache;
  out aCaptureDenied: Boolean): Boolean;
begin
  aCaptureDenied := False;
  if aIdentity.DeclaredId.Value = '' then
    Exit((not SameText(aIdentity.ScopeKind, 'routine')) and
      UniqueUnitTypeDeclarationIsVisible(aFacts, aBinding, aSelector, aTypeName,
        aLineCache, aCaptureDenied));
  // A2: D4 is additional. HEAD's refusal and its candidate coverage stand.
  Result := HeadCaptureTypeIsVisible(aFacts, aBinding, aSelector, aTypeName,
    aIdentity, aLineCache);
  if Result then
  begin
    aCaptureDenied := CaptureLookupDenies(aSelector, aTypeName, aIdentity);
    Result := not aCaptureDenied;
  end;
end;

function BuildSelectorDecision(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aSelectorText: string;
  const aSelector: TDelphiSemanticWithSelectorBinding;
  const aReservedNames: TDictionary<string, Integer>;
  const aPriorDecisions: TArray<TFinalSelectorDecision>;
  const aLineCache: TDelphiSemanticSourceContextCache;
  out aDecision: TFinalSelectorDecision; out aReason: string): Boolean;
var
  lBaseName: string;
  lChainReceiverType: string;
  lChainRootSymbolClass: string;
  lHasDependentReceiver: Boolean;
  lHasNestedWith: Boolean;
  lOpenParen: Integer;
  lPrefixText: string;
  lPointerCast: Boolean;
begin
  Result := False;
  aReason := '';
  lPointerCast := ResolvedPointerCastSelector(aBinding, aSelectorText);
  aDecision := Default(TFinalSelectorDecision);
  aDecision.SelectorText := aSelectorText;
  aDecision.ReceiverType := SelectorTypeName(aFacts, aBinding, aSelectorText);
  if SameText(aSelector.Status, 'resolved') and
    (aSelector.TypeIdentity.DeclaredId.Value <> '') then
  begin
    aDecision.ReceiverType := aSelector.TypeName;
    aDecision.ReceiverIdentity := aSelector.TypeIdentity;
  end;
  if TryResolveDependentSelectorType(aFacts, aPriorDecisions, aSelectorText, aSelector,
    lHasDependentReceiver, lChainReceiverType) then
  begin
    if (aDecision.ReceiverIdentity.DeclaredId.Value = '') or
      (not SameText(aDecision.ReceiverType, lChainReceiverType)) then
    begin
      aReason := 'dependent-selector-type-not-resolved';
      Exit;
    end;
    aDecision.ReceiverType := lChainReceiverType;
  end
  else if lHasDependentReceiver then
  begin
    aReason := 'dependent-selector-type-not-resolved';
    Exit;
  end;
  lOpenParen := Pos('(', aSelectorText);
  if (lOpenParen > 0) and (not lPointerCast) then
  begin
    lPrefixText := Trim(Copy(aSelectorText, 1, lOpenParen - 1));
    if Length(aFacts.LookupIndex.FindDeclarationOrTypeAliasByName(lPrefixText)) > 0 then
    begin
      aReason := 'cast-selector';
      Exit;
    end;
    aReason := 'call-selector';
    Exit;
  end;
  if ContainsText(aSelectorText, '.') and (not lHasDependentReceiver) and
    (not lPointerCast) then
  begin
    lHasNestedWith := BindingBodyContainsNestedWith(aBinding, aLineCache);
    if ((not lHasNestedWith) or (Length(aBinding.Selectors) > 1)) and
      TryResolveSourceBackedSelectorChainType(aFacts, aBinding, aSelectorText,
      lChainReceiverType, lChainRootSymbolClass) and
      SourceBackedSelectorChainRootIsSafe(lChainRootSymbolClass, aBinding) then
      aDecision.ReceiverType := lChainReceiverType
    else
    begin
      aReason := 'property-selector';
      Exit;
    end;
  end;
  if (not lPointerCast) and IndexedPointerSelectorBaseRequiresTypeResolutionSkip(aFacts, aBinding,
    aSelectorText) and (not IndexedPointerSelectorBaseHasSkippedParentMember(aFacts,
    aPriorDecisions, aSelectorText)) then
  begin
    aReason := 'selector-type-not-resolved';
    Exit;
  end;
  if aDecision.ReceiverType = '' then
  begin
    aReason := 'selector-type-not-resolved';
    Exit;
  end;

  lBaseName := 'lWith' + RemoveLeadingTypePrefix(aDecision.ReceiverType);
  if TypeIsClassLike(aFacts, aDecision.ReceiverType) then
  begin
    aDecision.StrategyKindContradiction :=
      TypeIdentityHasVerifiedOrigin(aDecision.ReceiverIdentity) and
      MatchText(aDecision.ReceiverIdentity.UnderlyingName, ['record', 'packed record']);
    if not CaptureTypeIsVisible(aFacts, aBinding, aSelector, aDecision.ReceiverType,
      aDecision.ReceiverIdentity,
      aLineCache, aDecision.CaptureDenied) then
    begin
      aReason := 'receiver-type-not-visible';
      Exit;
    end;
    aDecision.Strategy := 'reference-temp';
    aDecision.TempName := ReservedTempName(aFacts, aReservedNames, aBinding.RoutineName, lBaseName);
    aDecision.QualifierText := aDecision.TempName;
    aDecision.DeclarationText := aDecision.TempName + ': ' + aDecision.ReceiverType + ';';
    aDecision.InitializationText := aDecision.TempName + ' := ' + aSelectorText + ';';
    aDecision.Reason := 'reference-temp-preserves-evaluation';
  end else if TypeIsRecordLike(aFacts, aDecision.ReceiverType) then
  begin
    aDecision.StrategyKindContradiction :=
      TypeIdentityHasVerifiedOrigin(aDecision.ReceiverIdentity) and
      SameText(aDecision.ReceiverIdentity.UnderlyingName, 'class');
    if IsSimpleIdentifier(aSelectorText) and
      EndsText('.' + aSelectorText, aDecision.ReceiverType) then
    begin
      aDecision.Strategy := 'direct-qualification';
      aDecision.QualifierText := aSelectorText;
      aDecision.Reason := 'local-record-direct-qualification';
      Exit(True);
    end else if SelectorIsByReferenceParameter(aFacts, aBinding, aSelectorText) and
      SelectorHasDependentSelector(aFacts, aBinding, aSelectorText,
      aDecision.ReceiverType) and (Pos('.', aBinding.RoutineName) > 0) and
      (not RoutineDeclarationIsMethod(aBinding, aLineCache)) then
    begin
      aReason := 'selector-type-not-resolved';
      Exit;
    end;
    if ((aBinding.RoutineName = '') and IsPureUnitLevelSelector(aSelectorText)) or
      (SelectorIsByReferenceParameter(aFacts, aBinding, aSelectorText) and
      RoutineDeclarationIsProcedure(aBinding, aLineCache) and
      SelectorHasDependentSelector(aFacts, aBinding, aSelectorText,
      aDecision.ReceiverType) and
      (not (SelectorHasAnonymousRecordDependentSelector(aFacts, aBinding,
      aSelectorText, aDecision.ReceiverType) and
      RoutineDeclarationIsMethod(aBinding, aLineCache)))) or
      (SelectorIsByReferenceParameter(aFacts, aBinding, aSelectorText) and
      (TypeHasRoutineMembers(aFacts, aDecision.ReceiverType) or
      TypeHasOperatorSyntax(aFacts, aDecision.ReceiverType, aLineCache))) or
      (SelectorIsByValueParameter(aFacts, aBinding, aSelectorText) and
      BindingFollowsControlStatement(aBinding, aLineCache) and
      ByValueParameterReferencesHaveUnitFallback(aFacts, aBinding) and
      (TypeHasRoutineMembers(aFacts, aDecision.ReceiverType) or
      TypeHasOperatorSyntax(aFacts, aDecision.ReceiverType, aLineCache))) then
    begin
      aDecision.Strategy := 'direct-qualification';
      aDecision.QualifierText := aSelectorText;
      if aBinding.RoutineName = '' then
        aDecision.Reason := 'unit-level-pure-selector'
      else
        aDecision.Reason := 'record-routine-member-direct-qualification';
    end else
    begin
      if not CaptureTypeIsVisible(aFacts, aBinding, aSelector, aDecision.ReceiverType,
        aDecision.ReceiverIdentity,
        aLineCache, aDecision.CaptureDenied) then
      begin
        aReason := 'receiver-type-not-visible';
        Exit;
      end;
      lBaseName := lBaseName + 'Ptr';
      aDecision.Strategy := 'record-pointer-temp';
      aDecision.TempName := ReservedTempName(aFacts, aReservedNames, aBinding.RoutineName, lBaseName);
      aDecision.QualifierText := aDecision.TempName + '^';
      aDecision.DeclarationText := aDecision.TempName + ': ^' + aDecision.ReceiverType + ';';
      aDecision.InitializationText := aDecision.TempName + ' := @' + aSelectorText + ';';
      aDecision.Reason := 'record-pointer-preserves-alias';
    end;
  end else if IsSimpleIdentifier(aSelectorText) then
  begin
    if SelectorHasEarlierSelector(aBinding, aSelectorText) then
    begin
      aReason := 'selector-type-not-resolved';
      Exit;
    end;
    aDecision.Strategy := 'direct-qualification';
    aDecision.QualifierText := aSelectorText;
    aDecision.Reason := 'simple-selector';
  end else
  begin
    aReason := 'type-category-not-resolved';
    Exit;
  end;
  Result := True;
end;

function QualificationIsDenied(const aRefusals: TArray<TFinalReferenceRefusal>;
  const aOffset, aLength: Integer; out aReason: string): Boolean;
var
  lRefusal: TFinalReferenceRefusal;
begin
  aReason := '';
  for lRefusal in aRefusals do
    if (aOffset < lRefusal.Offset + lRefusal.Length) and
      (lRefusal.Offset < aOffset + aLength) then
    begin
      aReason := lRefusal.Reason;
      Exit(True);
    end;
  Result := False;
end;

procedure AddFinalBodyEdit(var aEdits: TArray<TFinalBodyEdit>; const aOffset,
  aLength: Integer; const aExpectedText, aReplacementText: string);
var
  lIndex: Integer;
begin
  lIndex := Length(aEdits);
  SetLength(aEdits, lIndex + 1);
  aEdits[lIndex].Offset := aOffset;
  aEdits[lIndex].Length := aLength;
  aEdits[lIndex].ExpectedText := aExpectedText;
  aEdits[lIndex].ReplacementText := aReplacementText;
end;

function AddQualifiedBodyEdit(var aEdits: TArray<TFinalBodyEdit>;
  const aBodyText: string; const aOffset, aLength: Integer;
  const aExpectedText, aQualifierText, aMemberText: string;
  const aRefusals: TArray<TFinalReferenceRefusal>; out aReason: string): Boolean;
var
  lExpectedText: string;
  lLength: Integer;
  lMemberText: string;
  lOffset: Integer;
begin
  Result := False;
  if QualificationIsDenied(aRefusals, aOffset, aLength, aReason) then
    Exit;
  lOffset := aOffset;
  lLength := aLength;
  lExpectedText := aExpectedText;
  lMemberText := aMemberText;
  // DS-671: replace the escape with the member, after the new qualifier.
  if (lOffset > 1) and (aBodyText[lOffset - 1] = '&') then
  begin
    Dec(lOffset);
    Inc(lLength);
    lExpectedText := '&' + lExpectedText;
    lMemberText := '&' + lMemberText;
  end;
  AddFinalBodyEdit(aEdits, lOffset, lLength, lExpectedText,
    aQualifierText + '.' + lMemberText);
  aEdits[High(aEdits)].QualifierText := aQualifierText;
  Result := True;
end;

function IsIdentifierTextChar(const aChar: Char): Boolean;
begin
  Result := CharInSet(aChar, ['A'..'Z', 'a'..'z', '0'..'9', '_']);
end;

function BodyTextIdentifierAt(const aText, aName: string; const aOffset: Integer):
  Boolean;
var
  lAfterOffset: Integer;
begin
  Result := False;
  if (aOffset <= 0) or (aName = '') then
    Exit;
  if not SameText(Copy(aText, aOffset, Length(aName)), aName) then
    Exit;
  if (aOffset > 1) and IsIdentifierTextChar(aText[aOffset - 1]) then
    Exit;
  lAfterOffset := aOffset + Length(aName);
  if (lAfterOffset <= Length(aText)) and IsIdentifierTextChar(aText[lAfterOffset]) then
    Exit;
  Result := True;
end;

function BodyOffsetInsideTextOccurrence(const aBodyText, aOccurrenceText: string;
  const aOffset: Integer): Boolean;
var
  lOffset: Integer;
  lOccurrenceText: string;
begin
  Result := False;
  lOccurrenceText := Trim(aOccurrenceText);
  if (aOffset <= 0) or (lOccurrenceText = '') then
    Exit;

  lOffset := PosEx(lOccurrenceText, aBodyText);
  while lOffset > 0 do
  begin
    if ((not IsSimpleIdentifier(lOccurrenceText)) or
      BodyTextIdentifierAt(aBodyText, lOccurrenceText, lOffset)) and
      (aOffset >= lOffset) and
      (aOffset < lOffset + Length(lOccurrenceText)) then
      Exit(True);
    lOffset := PosEx(lOccurrenceText, aBodyText,
      lOffset + Length(lOccurrenceText));
  end;
end;

function BodyOffsetHasTextQualifier(const aBodyText, aQualifierText: string;
  const aOffset: Integer): Boolean;
var
  lPrefixText: string;
  lQualifierText: string;
begin
  Result := False;
  lQualifierText := Trim(aQualifierText);
  if (aOffset <= 1) or (lQualifierText = '') then
    Exit;

  lPrefixText := Copy(aBodyText, 1, aOffset - 1);
  Result := EndsText(lQualifierText + '.', lPrefixText);
end;

function BodyOffsetAppearsQualified(const aBodyText: string;
  const aOffset: Integer): Boolean;
var
  lOffset: Integer;
begin
  Result := False;
  lOffset := aOffset - 1;
  if (lOffset > 0) and (aBodyText[lOffset] = '&') then
    Dec(lOffset);
  while (lOffset > 0) and CharInSet(aBodyText[lOffset], [#9, #10, #13, ' ']) do
    Dec(lOffset);
  Result := IsMemberAccessDot(aBodyText, lOffset);
end;

function LineOffsetAppearsQualified(const aLineText: string;
  const aOffset: Integer): Boolean;
var
  lOffset: Integer;
begin
  Result := False;
  lOffset := aOffset - 1;
  if (lOffset > 0) and (aLineText[lOffset] = '&') then
    Dec(lOffset);
  while (lOffset > 0) and CharInSet(aLineText[lOffset], [#9, ' ']) do
    Dec(lOffset);
  Result := IsMemberAccessDot(aLineText, lOffset);
end;

function BodyOffsetInsideLiteralOrComment(const aText: string;
  const aOffset: Integer): Boolean; forward;

procedure AddDependentSelectorBodyEdits(const aDecisions: TArray<TFinalSelectorDecision>;
  const aBodyText: string; const aRefusals: TArray<TFinalReferenceRefusal>;
  var aBodyEdits: TArray<TFinalBodyEdit>; out aReason: string);
var
  lDecision: TFinalSelectorDecision;
  lOffset: Integer;
begin
  for lDecision in aDecisions do
  begin
    if (not SameText(lDecision.Reason, 'dependent-selector-direct-qualification')) or
      (not IsSimpleIdentifier(lDecision.SelectorText)) then
      Continue;
    lOffset := Pos(lDecision.SelectorText, aBodyText);
    while lOffset > 0 do
    begin
      if BodyTextIdentifierAt(aBodyText, lDecision.SelectorText, lOffset) and
        (not BodyOffsetInsideLiteralOrComment(aBodyText, lOffset)) then
      begin
        if QualificationIsDenied(aRefusals, lOffset,
          Length(lDecision.SelectorText), aReason) then
          Exit;
        AddFinalBodyEdit(aBodyEdits, lOffset, Length(lDecision.SelectorText),
          lDecision.SelectorText, lDecision.QualifierText);
      end;
      lOffset := PosEx(lDecision.SelectorText, aBodyText,
        lOffset + Length(lDecision.SelectorText));
    end;
  end;
end;

function BodyEditOffsetUsed(const aEdits: TArray<TFinalBodyEdit>;
  const aOffset: Integer; const aExpectedText: string): Boolean; forward;

function RoutineScopeSymbolNamed(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aName: string): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  if not TryFindRoutineScopedSymbolForBinding(aFacts, aBinding, aName,
    lSymbol) then
    Exit;
  Result := MatchText(lSymbol.SymbolClass, ['local', 'parameter']);
end;

function SimpleSelectorHasMember(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aDecisions: TArray<TFinalSelectorDecision>; const aName: string): Boolean; forward;

function DecisionKeepsWithMemberScope(const aDecision: TFinalSelectorDecision): Boolean;
begin
  Result := SameText(aDecision.Reason, 'skipped-parent-context');
end;

procedure AddIndexedMemberBodyEdits(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aDecisions: TArray<TFinalSelectorDecision>; const aBodyText: string;
  const aDeclarations: TArray<Boolean>; const aRefusals: TArray<TFinalReferenceRefusal>;
  var aBodyEdits: TArray<TFinalBodyEdit>; out aReason: string);
var
  i: Integer;
  lDecision: TFinalSelectorDecision;
  lDecisionIndex: Integer;
  lName: string;
  lOffset: Integer;
  lSelectorMember: Boolean;
  lStartOffset: Integer;
begin
  i := 1;
  while i <= Length(aBodyText) do
  begin
    if not IsIdentifierTextChar(aBodyText[i]) then
    begin
      Inc(i);
      Continue;
    end;

    lStartOffset := i;
    while (i <= Length(aBodyText)) and IsIdentifierTextChar(aBodyText[i]) do
      Inc(i);
    if (i > Length(aBodyText)) or (aBodyText[i] <> '[') then
      Continue;

    lName := Copy(aBodyText, lStartOffset, i - lStartOffset);
    if BodyOffsetIsDeclaration(aDeclarations, lStartOffset) or
      BodyOffsetInsideLiteralOrComment(aBodyText, lStartOffset) then
      Continue;
    lSelectorMember := SimpleSelectorHasMember(aFacts, aBinding, aDecisions, lName);
    if RoutineScopeSymbolNamed(aFacts, aBinding, lName) and
      (not lSelectorMember) then
      Continue;
    if BodyOffsetAppearsQualified(aBodyText, lStartOffset) then
      Continue;

    for lDecisionIndex := High(aDecisions) downto 0 do
    begin
      lDecision := aDecisions[lDecisionIndex];
      if (Trim(lDecision.QualifierText) = '') or
        (Trim(lDecision.ReceiverType) = '') or
        (not OwnerHasMemberNamed(aFacts, lDecision.ReceiverType, lName)) then
        Continue;
      if DecisionKeepsWithMemberScope(lDecision) then
        Break;
      lOffset := lStartOffset;
      if (BodyOffsetInsideTextOccurrence(aBodyText, aBinding.SelectorText,
        lOffset) and (not lSelectorMember)) or BodyOffsetHasTextQualifier(aBodyText,
        lDecision.QualifierText, lOffset) or
        BodyEditOffsetUsed(aBodyEdits, lOffset, lName) then
        Continue;
      if not AddQualifiedBodyEdit(aBodyEdits, aBodyText, lOffset, Length(lName), lName,
        lDecision.QualifierText, lName, aRefusals, aReason) then
        Exit;
      Break;
    end;
  end;
end;

function RangeRelativeOffset(const aRange: TDelphiSemanticRemoveWithSourceRange;
  const aLineCache: TArray<string>; const aLine, aColumn: Integer;
  const aLineBreak: string): Integer;
var
  lEndColumn: Integer;
  lLineIndex: Integer;
  lStartColumn: Integer;
begin
  Result := 1;
  for lLineIndex := aRange.StartLine to aLine - 1 do
  begin
    lStartColumn := 1;
    if lLineIndex = aRange.StartLine then
      lStartColumn := aRange.StartColumn;
    lEndColumn := Length(aLineCache[lLineIndex - 1]);
    if lEndColumn >= lStartColumn then
      Inc(Result, lEndColumn - lStartColumn + 1);
    Inc(Result, Length(aLineBreak));
  end;
  if aLine = aRange.StartLine then
    Inc(Result, aColumn - aRange.StartColumn)
  else
    Inc(Result, aColumn - 1);
end;

function ReferenceTextMatchesAt(const aBodyText: string;
  const aReference: TDelphiSemanticBoundReference; const aOffset: Integer):
  Boolean;
begin
  Result := (aOffset > 0) and
    SameText(Copy(aBodyText, aOffset, Length(aReference.Name)), aReference.Name);
end;

function ReferenceLineOccurrenceRelativeOffset(
  const aBodyRange: TDelphiSemanticRemoveWithSourceRange;
  const aLines: TArray<string>; const aBodyText: string;
  const aReference: TDelphiSemanticBoundReference; const aLine: Integer;
  const aLineBreak: string): Integer;
var
  lBestDistance: Integer;
  lCandidateOffset: Integer;
  lDistance: Integer;
  lLineText: string;
  lSearchOffset: Integer;
begin
  Result := 0;
  if (aLine < aBodyRange.StartLine) or (aLine > aBodyRange.EndLine) or
    (aLine < 1) or (aLine > Length(aLines)) or (aReference.Name = '') then
    Exit;

  lLineText := aLines[aLine - 1];
  lBestDistance := MaxInt;
  lSearchOffset := PosEx(LowerCase(aReference.Name), LowerCase(lLineText));
  while lSearchOffset > 0 do
  begin
    if BodyTextIdentifierAt(lLineText, aReference.Name, lSearchOffset) and
      (not LineOffsetAppearsQualified(lLineText, lSearchOffset)) then
    begin
      lCandidateOffset := RangeRelativeOffset(aBodyRange, aLines, aLine,
        lSearchOffset, aLineBreak);
      if ReferenceTextMatchesAt(aBodyText, aReference, lCandidateOffset) then
      begin
        lDistance := Abs(lSearchOffset - aReference.Column);
        if lDistance < lBestDistance then
        begin
          Result := lCandidateOffset;
          lBestDistance := lDistance;
        end;
      end;
    end;
    lSearchOffset := PosEx(LowerCase(aReference.Name), LowerCase(lLineText),
      lSearchOffset + Length(aReference.Name));
  end;
end;

function BodyEditOffsetUsed(const aEdits: TArray<TFinalBodyEdit>;
  const aOffset: Integer; const aExpectedText: string): Boolean;
var
  lEdit: TFinalBodyEdit;
  lEditLength: Integer;
begin
  Result := False;
  for lEdit in aEdits do
  begin
    lEditLength := lEdit.Length;
    if lEditLength <= 0 then
      lEditLength := Length(lEdit.ExpectedText);
    if (lEdit.Offset = aOffset) or
      ((lEditLength > 0) and (aOffset > lEdit.Offset) and
      (aOffset < lEdit.Offset + lEditLength)) then
      Exit(True);
  end;
end;

function ReferenceUnusedLineOccurrenceRelativeOffset(
  const aBodyRange: TDelphiSemanticRemoveWithSourceRange;
  const aLines: TArray<string>; const aBodyText: string;
  const aReference: TDelphiSemanticBoundReference; const aLine: Integer;
  const aLineBreak: string; const aExistingEdits: TArray<TFinalBodyEdit>):
  Integer;
var
  lBestDistance: Integer;
  lCandidateOffset: Integer;
  lDistance: Integer;
  lLineText: string;
  lSearchOffset: Integer;
begin
  Result := 0;
  if (aLine < aBodyRange.StartLine) or (aLine > aBodyRange.EndLine) or
    (aLine < 1) or (aLine > Length(aLines)) or (aReference.Name = '') then
    Exit;

  lLineText := aLines[aLine - 1];
  lBestDistance := MaxInt;
  lSearchOffset := PosEx(LowerCase(aReference.Name), LowerCase(lLineText));
  while lSearchOffset > 0 do
  begin
    if BodyTextIdentifierAt(lLineText, aReference.Name, lSearchOffset) and
      (not LineOffsetAppearsQualified(lLineText, lSearchOffset)) then
    begin
      lCandidateOffset := RangeRelativeOffset(aBodyRange, aLines, aLine,
        lSearchOffset, aLineBreak);
      if ReferenceTextMatchesAt(aBodyText, aReference, lCandidateOffset) and
        (not BodyEditOffsetUsed(aExistingEdits, lCandidateOffset,
        aReference.Name)) then
      begin
        lDistance := Abs(lSearchOffset - aReference.Column);
        if lDistance < lBestDistance then
        begin
          Result := lCandidateOffset;
          lBestDistance := lDistance;
        end;
      end;
    end;
    lSearchOffset := PosEx(LowerCase(aReference.Name), LowerCase(lLineText),
      lSearchOffset + Length(aReference.Name));
  end;
end;

function ReferenceLineHasQualifiedOccurrence(
  const aBodyRange: TDelphiSemanticRemoveWithSourceRange;
  const aLines: TArray<string>; const aBodyText: string;
  const aReference: TDelphiSemanticBoundReference; const aLine: Integer;
  const aLineBreak: string): Boolean;
var
  lCandidateOffset: Integer;
  lLineText: string;
  lSearchOffset: Integer;
begin
  Result := False;
  if (aLine < aBodyRange.StartLine) or (aLine > aBodyRange.EndLine) or
    (aLine < 1) or (aLine > Length(aLines)) or (aReference.Name = '') then
    Exit;

  lLineText := aLines[aLine - 1];
  lSearchOffset := PosEx(LowerCase(aReference.Name), LowerCase(lLineText));
  while lSearchOffset > 0 do
  begin
    if BodyTextIdentifierAt(lLineText, aReference.Name, lSearchOffset) and
      LineOffsetAppearsQualified(lLineText, lSearchOffset) then
    begin
      lCandidateOffset := RangeRelativeOffset(aBodyRange, aLines, aLine,
        lSearchOffset, aLineBreak);
      if ReferenceTextMatchesAt(aBodyText, aReference, lCandidateOffset) then
        Exit(True);
    end;
    lSearchOffset := PosEx(LowerCase(aReference.Name), LowerCase(lLineText),
      lSearchOffset + Length(aReference.Name));
  end;
end;

function ReferenceHasQualifiedOccurrenceNearReference(
  const aBodyRange: TDelphiSemanticRemoveWithSourceRange;
  const aLines: TArray<string>; const aBodyText: string;
  const aReference: TDelphiSemanticBoundReference;
  const aLineBreak: string): Boolean;
begin
  Result := ReferenceLineHasQualifiedOccurrence(aBodyRange, aLines, aBodyText,
    aReference, aReference.Line, aLineBreak);
  if Result or (aReference.Line <= aBodyRange.StartLine) then
    Exit;
  Result := ReferenceLineHasQualifiedOccurrence(aBodyRange, aLines, aBodyText,
    aReference, aReference.Line - 1, aLineBreak);
end;

function ReferenceRelativeOffset(const aBodyRange: TDelphiSemanticRemoveWithSourceRange;
  const aLines: TArray<string>; const aBodyText: string;
  const aReference: TDelphiSemanticBoundReference; const aLineBreak: string): Integer;
var
  lCandidateOffset: Integer;
begin
  Result := RangeRelativeOffset(aBodyRange, aLines, aReference.Line,
    aReference.Column, aLineBreak);
  if ReferenceTextMatchesAt(aBodyText, aReference, Result) and
    (not BodyOffsetAppearsQualified(aBodyText, Result)) then
    Exit;

  if aReference.Line > aBodyRange.StartLine then
  begin
    lCandidateOffset := RangeRelativeOffset(aBodyRange, aLines,
      aReference.Line - 1, aReference.Column, aLineBreak);
    if ReferenceTextMatchesAt(aBodyText, aReference, lCandidateOffset) and
      (not BodyOffsetAppearsQualified(aBodyText, lCandidateOffset)) then
      Exit(lCandidateOffset);
  end;

  Result := ReferenceLineOccurrenceRelativeOffset(aBodyRange, aLines, aBodyText,
    aReference, aReference.Line, aLineBreak);
  if Result > 0 then
    Exit;

  if aReference.Line <= aBodyRange.StartLine then
  begin
    Result := 0;
    Exit;
  end;

  Result := ReferenceLineOccurrenceRelativeOffset(aBodyRange, aLines, aBodyText,
    aReference, aReference.Line - 1, aLineBreak);
end;

function ReferenceLookupName(const aReferenceName: string): string;
var
  lDelimiterPos: Integer;

  procedure ConsiderDelimiter(const aPos: Integer);
  begin
    if (aPos > 0) and ((lDelimiterPos = 0) or (aPos < lDelimiterPos)) then
      lDelimiterPos := aPos;
  end;

begin
  Result := aReferenceName;
  lDelimiterPos := 0;
  ConsiderDelimiter(Pos('[', Result));
  ConsiderDelimiter(Pos('.', Result));
  ConsiderDelimiter(Pos('^', Result));
  if lDelimiterPos > 0 then
    Result := Copy(Result, 1, lDelimiterPos - 1);
end;

function ActiveDecisionHasMember(const aFacts: TRemoveWithPlanFacts;
  const aDecisions: TArray<TFinalSelectorDecision>; const aReferenceName: string): Boolean;
var
  i: Integer;
  lDecision: TFinalSelectorDecision;
  lReferenceName: string;
begin
  Result := False;
  lReferenceName := ReferenceLookupName(aReferenceName);
  for i := High(aDecisions) downto 0 do
  begin
    lDecision := aDecisions[i];
    if OwnerHasMemberNamed(aFacts, lDecision.ReceiverType, lReferenceName) then
      Exit(True);
  end;
end;

function SimpleSelectorHasMember(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aDecisions: TArray<TFinalSelectorDecision>; const aName: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  if (not IsSimpleIdentifier(aBinding.SelectorText)) or
    (not SameText(aBinding.SelectorText, ReferenceLookupName(aName))) then
    Exit;
  for i := High(aDecisions) downto 0 do
    if SameText(aDecisions[i].SelectorText, aBinding.SelectorText) then
      Exit(OwnerHasMemberNamed(aFacts, aDecisions[i].ReceiverType,
        aBinding.SelectorText));
end;

function HasHiddenUnresolvedPointerSelectorDecision(
  const aEditDecisions, aValidationDecisions: TArray<TFinalSelectorDecision>):
  Boolean;
var
  lDecision: TFinalSelectorDecision;
begin
  Result := False;
  for lDecision in aValidationDecisions do
  begin
    if (Trim(lDecision.ReceiverType) = '') and
      IsSimplePointerDereferenceSelector(lDecision.SelectorText) and
      (not HasDecisionForSelector(aEditDecisions, lDecision.SelectorText)) then
      Exit(True);
  end;
end;

function IsReceiverValueMemberReference(const aReference: TDelphiSemanticBoundReference): Boolean;
begin
  Result := SameText(aReference.Classification, 'member') and
    SameText(aReference.LookupSource, 'receiver') and
    MatchText(aReference.Kind, ['const', 'typed-const', 'variant-tag']);
end;

function IsBinderReceiverMemberReference(
  const aReference: TDelphiSemanticBoundReference): Boolean;
begin
  Result := SameText(aReference.Classification, 'member') and
    SameText(aReference.LookupSource, 'receiver');
end;

function ReferenceHasLineageDenial(const aFacts: TRemoveWithPlanFacts;
  const aDecisions: TArray<TFinalSelectorDecision>;
  const aReference: TDelphiSemanticBoundReference): Boolean;
var
  i: Integer;
  lDecision: TFinalSelectorDecision;
  lOwnerName, lReferenceName: string;
begin
  Result := False;
  if not SameText(aReference.Classification, 'unsupported') or
    not MatchText(aReference.ReasonCode, ['OWNER_INHERITED_MEMBERS_UNVERIFIED',
      'TYPE_VISIBILITY_UNPROVED']) then
    Exit;
  lReferenceName := ReferenceLookupName(aReference.Name);
  for i := High(aDecisions) downto 0 do
  begin
    lDecision := aDecisions[i];
    if not OwnerHasMemberNamed(aFacts, lDecision.ReceiverType, lReferenceName) and
      not SameText(lDecision.ReceiverType, aReference.ReceiverTypeName) then
      Continue;
    if not TypeIdentityHasVerifiedOrigin(lDecision.ReceiverIdentity) or
      aFacts.LookupIndex.IsProfileRecord(lDecision.ReceiverIdentity, True) then
      Exit;
    lOwnerName := aReference.ReceiverTypeName;
    if lOwnerName = '' then
      lOwnerName := lDecision.ReceiverType;
    Result := not aFacts.LookupIndex.ReceiverLineageDeclaresMember(
      lDecision.ReceiverIdentity, lOwnerName, lReferenceName);
    Exit;
  end;
end;

function QualifierForReference(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aDecisions: TArray<TFinalSelectorDecision>;
  const aReference: TDelphiSemanticBoundReference; out aQualifierText: string):
  TFinalReferenceQualification;
var
  i: Integer;
  lDecision: TFinalSelectorDecision;
  lMatch: Integer;
  lReferenceName: string;
begin
  Result := TFinalReferenceQualification.NoMatch;
  aQualifierText := '';
  lReferenceName := ReferenceLookupName(aReference.Name);
  if IsReceiverValueMemberReference(aReference) then
  begin
    lMatch := -1;
    for i := High(aDecisions) downto 0 do
      if SameText(aDecisions[i].ReceiverType, aReference.ReceiverTypeName) then
      begin
        if lMatch < 0 then
          lMatch := i
        else if not SameText(aDecisions[lMatch].ReceiverIdentity.DeclaredId.Value,
          aDecisions[i].ReceiverIdentity.DeclaredId.Value) then
          Exit;
      end;
    if lMatch < 0 then
      Exit;
    if DecisionKeepsWithMemberScope(aDecisions[lMatch]) then
      Exit(TFinalReferenceQualification.RetainedMember);
    if Trim(aDecisions[lMatch].QualifierText) = '' then
      Exit;
    aQualifierText := aDecisions[lMatch].QualifierText;
    Exit(TFinalReferenceQualification.QualifiedMember);
  end;
  if IsBinderReceiverMemberReference(aReference) and (aReference.ReceiverTypeName <> '') then
    for i := High(aDecisions) downto 0 do
      if TypeIdentityHasVerifiedOrigin(aDecisions[i].ReceiverIdentity) and
        aFacts.LookupIndex.ReceiverLineageDeclaresMember(aDecisions[i].ReceiverIdentity,
          aReference.ReceiverTypeName, lReferenceName) then
      begin
        if DecisionKeepsWithMemberScope(aDecisions[i]) then
          Exit(TFinalReferenceQualification.RetainedMember);
        if Trim(aDecisions[i].QualifierText) = '' then
          Exit;
        aQualifierText := aDecisions[i].QualifierText;
        Exit(TFinalReferenceQualification.QualifiedMember);
      end;
  if ReferenceHasLineageDenial(aFacts, aDecisions, aReference) then
    Exit;
  for i := High(aDecisions) downto 0 do
  begin
    lDecision := aDecisions[i];
    if (Trim(lDecision.ReceiverType) = '') and
      ReferenceIsRoutineScopeValue(aFacts, aBinding, aReference) then
      Continue;
    if OwnerHasMemberNamed(aFacts, lDecision.ReceiverType, lReferenceName) then
    begin
      if DecisionKeepsWithMemberScope(lDecision) then
        Exit(TFinalReferenceQualification.RetainedMember);
      aQualifierText := lDecision.QualifierText;
      Exit(TFinalReferenceQualification.QualifiedMember);
    end;
  end;
  if aReference.ReceiverTypeName = '' then
    Exit;
  for lDecision in aDecisions do
  begin
    if SameText(lDecision.ReceiverType, aReference.ReceiverTypeName) then
    begin
      if DecisionKeepsWithMemberScope(lDecision) then
        Exit(TFinalReferenceQualification.RetainedMember);
      aQualifierText := lDecision.QualifierText;
      Exit(TFinalReferenceQualification.QualifiedMember);
    end;
  end;
end;

function BodyOffsetInsideLiteralOrComment(const aText: string;
  const aOffset: Integer): Boolean;
var
  i: Integer;
  lInBraceComment: Boolean;
  lInLineComment: Boolean;
  lInParenComment: Boolean;
  lInString: Boolean;
begin
  lInBraceComment := False;
  lInLineComment := False;
  lInParenComment := False;
  lInString := False;
  i := 1;
  while (i < aOffset) and (i <= Length(aText)) do
  begin
    if lInLineComment then
    begin
      if CharInSet(aText[i], [#10, #13]) then
        lInLineComment := False;
      Inc(i);
      Continue;
    end;
    if lInBraceComment then
    begin
      if aText[i] = '}' then
        lInBraceComment := False;
      Inc(i);
      Continue;
    end;
    if lInParenComment then
    begin
      if (aText[i] = '*') and (i < Length(aText)) and (aText[i + 1] = ')') then
      begin
        lInParenComment := False;
        Inc(i, 2);
        Continue;
      end;
      Inc(i);
      Continue;
    end;
    if lInString then
    begin
      if (aText[i] = '''') and (i < Length(aText)) and (aText[i + 1] = '''') then
      begin
        Inc(i, 2);
        Continue;
      end;
      if aText[i] = '''' then
        lInString := False;
      Inc(i);
      Continue;
    end;

    if aText[i] = '''' then
      lInString := True
    else if (aText[i] = '/') and (i < Length(aText)) and
      (aText[i + 1] = '/') then
    begin
      lInLineComment := True;
      Inc(i, 2);
      Continue;
    end else if aText[i] = '{' then
      lInBraceComment := True
    else if (aText[i] = '(') and (i < Length(aText)) and
      (aText[i + 1] = '*') then
    begin
      lInParenComment := True;
      Inc(i, 2);
      Continue;
    end;
    Inc(i);
  end;
  Result := lInString or lInLineComment or lInBraceComment or lInParenComment;
end;

function BodyNextNonWhitespaceChar(const aText: string;
  const aOffset: Integer): Char;
var
  i: Integer;
begin
  Result := #0;
  i := aOffset;
  while (i <= Length(aText)) and CharInSet(aText[i], [#9, #10, #13, ' ']) do
    Inc(i);
  if i <= Length(aText) then
    Result := aText[i];
end;

function BodyOffsetInsideCallOrCastArgument(const aText: string;
  const aOffset: Integer): Boolean;
var
  i: Integer;
  lDepth: Integer;
  lNameEnd: Integer;
begin
  Result := False;
  lDepth := 0;
  i := aOffset - 1;
  while i > 0 do
  begin
    if aText[i] = ')' then
      Inc(lDepth)
    else if aText[i] = '(' then
    begin
      if lDepth > 0 then
      begin
        Dec(lDepth);
        Dec(i);
        Continue;
      end;

      lNameEnd := i - 1;
      while (lNameEnd > 0) and CharInSet(aText[lNameEnd],
        [#9, #10, #13, ' ']) do
        Dec(lNameEnd);
      if (lNameEnd > 0) and IsIdentifierTextChar(aText[lNameEnd]) then
        Exit(True);
      Exit;
    end else if (lDepth = 0) and CharInSet(aText[i], [';', #10, #13]) then
      Exit;
    Dec(i);
  end;
end;

function BodyOffsetInsideIndexArgument(const aText: string;
  const aOffset: Integer): Boolean;
var
  i: Integer;
  lDepth: Integer;
  lLimit: Integer;
begin
  Result := False;
  lDepth := 0;
  lLimit := aOffset - 1;
  if lLimit > Length(aText) then
    lLimit := Length(aText);
  for i := 1 to lLimit do
  begin
    if aText[i] = '[' then
      Inc(lDepth)
    else if (aText[i] = ']') and (lDepth > 0) then
      Dec(lDepth);
  end;
  Result := lDepth > 0;
end;

function QualifierForMemberName(const aFacts: TRemoveWithPlanFacts;
  const aDecisions: TArray<TFinalSelectorDecision>; const aName: string;
  out aQualifierText: string): Boolean;
var
  i: Integer;
  lDecision: TFinalSelectorDecision;
begin
  Result := False;
  aQualifierText := '';
  for i := High(aDecisions) downto 0 do
  begin
    lDecision := aDecisions[i];
    if (Trim(lDecision.QualifierText) = '') or
      (Trim(lDecision.ReceiverType) = '') or
      (not OwnerHasMemberNamed(aFacts, lDecision.ReceiverType, aName)) then
      Continue;
    if DecisionKeepsWithMemberScope(lDecision) then
      Exit;
    aQualifierText := lDecision.QualifierText;
    Exit(True);
  end;
end;

function DecisionCanQualifyMemberName(const aFacts: TRemoveWithPlanFacts;
  const aDecisions: TArray<TFinalSelectorDecision>; const aName: string): Boolean;
var
  lQualifierText: string;
begin
  Result := QualifierForMemberName(aFacts, aDecisions, aName, lQualifierText);
end;

function ReferenceNameWithQualifiedArguments(const aFacts: TRemoveWithPlanFacts;
  const aDecisions: TArray<TFinalSelectorDecision>;
  const aReference: TDelphiSemanticBoundReference): string;
var
  i: Integer;
  lName: string;
  lNextChar: Char;
  lNonReferencePositions: TArray<Boolean>;
  lQualifierText: string;
  lReferenceName: string;
  lReplacementText: string;
  lStartOffset: Integer;
begin
  Result := '';
  lReferenceName := aReference.Name;
  if (Pos('[', lReferenceName) > 0) or (Pos('(', lReferenceName) > 0) then
    lNonReferencePositions := BodyNonReferencePositions(lReferenceName, True)
  else
    lNonReferencePositions := nil;
  i := 1;
  while i <= Length(lReferenceName) do
  begin
    if not IsIdentifierTextChar(lReferenceName[i]) then
    begin
      Result := Result + lReferenceName[i];
      Inc(i);
      Continue;
    end;

    lStartOffset := i;
    while (i <= Length(lReferenceName)) and
      IsIdentifierTextChar(lReferenceName[i]) do
      Inc(i);
    lName := Copy(lReferenceName, lStartOffset, i - lStartOffset);
    lReplacementText := lName;
    lNextChar := #0;
    if i <= Length(lReferenceName) then
      lNextChar := lReferenceName[i];

    if (lStartOffset > 1) and
      (not BodyOffsetIsDeclaration(lNonReferencePositions, lStartOffset)) and
      (not BodyOffsetAppearsQualified(lReferenceName, lStartOffset)) and
      (lNextChar <> '(') and
      (BodyOffsetInsideCallOrCastArgument(lReferenceName, lStartOffset) or
      BodyOffsetInsideIndexArgument(lReferenceName, lStartOffset)) and
      QualifierForMemberName(aFacts, aDecisions, lName, lQualifierText) then
    begin
      if (lStartOffset > 1) and (lReferenceName[lStartOffset - 1] = '&') then
      begin
        Delete(Result, Length(Result), 1);
        lReplacementText := lQualifierText + '.&' + lName;
      end else
        lReplacementText := lQualifierText + '.' + lName;
    end;
    Result := Result + lReplacementText;
  end;
end;

procedure AddSimpleMemberBodyEdits(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aDecisions: TArray<TFinalSelectorDecision>; const aBodyText: string;
  const aDeclarations: TArray<Boolean>; const aRefusals: TArray<TFinalReferenceRefusal>;
  var aBodyEdits: TArray<TFinalBodyEdit>; out aReason: string);
var
  i: Integer;
  lName: string;
  lNextChar: Char;
  lQualifierText: string;
  lSelectorMember: Boolean;
  lStartOffset: Integer;
begin
  i := 1;
  while i <= Length(aBodyText) do
  begin
    if not IsIdentifierTextChar(aBodyText[i]) then
    begin
      Inc(i);
      Continue;
    end;

    lStartOffset := i;
    while (i <= Length(aBodyText)) and IsIdentifierTextChar(aBodyText[i]) do
      Inc(i);
    lName := Copy(aBodyText, lStartOffset, i - lStartOffset);

    lSelectorMember := SimpleSelectorHasMember(aFacts, aBinding, aDecisions, lName);
    if ((i <= Length(aBodyText)) and (aBodyText[i] = '[')) or
      BodyOffsetAppearsQualified(aBodyText, lStartOffset) or
      BodyOffsetInsideLiteralOrComment(aBodyText, lStartOffset) or
      (RoutineScopeSymbolNamed(aFacts, aBinding, lName) and (not lSelectorMember)) or
      BodyOffsetIsDeclaration(aDeclarations, lStartOffset) then
      Continue;

    if not QualifierForMemberName(aFacts, aDecisions, lName, lQualifierText) then
      Continue;

    lNextChar := BodyNextNonWhitespaceChar(aBodyText, i);
    if lNextChar = '(' then
      Continue;
    if (BodyOffsetInsideTextOccurrence(aBodyText, aBinding.SelectorText,
      lStartOffset) and (not lSelectorMember)) or
      BodyOffsetHasTextQualifier(aBodyText, lQualifierText, lStartOffset) or
      BodyEditOffsetUsed(aBodyEdits, lStartOffset, lName) then
      Continue;

    if not AddQualifiedBodyEdit(aBodyEdits, aBodyText, lStartOffset, Length(lName), lName,
      lQualifierText, lName, aRefusals, aReason) then
      Exit;
  end;
end;

function ReferenceHasVisibleImportedProcedure(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aReference: TDelphiSemanticBoundReference;
  const aLineCache: TDelphiSemanticSourceContextCache): Boolean;
var
  lDeclaration: TDelphiSemanticInventorySymbol;
  lSelected: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  if (aFacts.UnitVisibility = nil) or
    (not SameText(aReference.Classification, 'external')) or
    (not SameText(aReference.Kind, 'routine')) or
    (not SameText(aReference.ReasonCode, 'EXTERNAL_ROUTINE_CALL')) or
    (Trim(aReference.TypeName) <> '') or (Trim(aReference.ReceiverTypeName) = '') or
    (not IsSimpleIdentifier(aReference.Name)) then
    Exit;
  lSelected := Default(TDelphiSemanticInventorySymbol);
  for lDeclaration in aFacts.LookupIndex.FindSymbolsByName(aReference.Name) do
  begin
    if (not SameText(lDeclaration.SymbolClass, 'declaration')) or
      (not SameText(lDeclaration.Kind, 'routine')) or
      (not SameText(lDeclaration.SectionKind, 'interface')) or
      (not SameText(lDeclaration.UnitName, aReference.ReceiverTypeName)) or
      (lDeclaration.FileName = '') or SameText(lDeclaration.FileName, aBinding.FileName) or
      (lDeclaration.Line <= 0) or (lDeclaration.Column <= 0) or
      (lDeclaration.UnsupportedReason <> '') or (Trim(lDeclaration.TypeName) <> '') then
      Continue;
    if (lSelected.FileName <> '') and
      ((not SameText(lSelected.FileName, lDeclaration.FileName)) or
      (lSelected.Line <> lDeclaration.Line) or (lSelected.Column <> lDeclaration.Column)) then
      Exit;
    lSelected := lDeclaration;
  end;
  Result := (lSelected.FileName <> '') and
    CaptureDeclarationIsVisible(aFacts, aBinding, lSelected, aLineCache);
end;

function ReferenceHasRootProvedVisibleProcedure(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aDecisions: TArray<TFinalSelectorDecision>;
  const aReference: TDelphiSemanticBoundReference): Boolean;
var
  lDeclaration: TDelphiSemanticInventorySymbol;
  lDecision: TFinalSelectorDecision;
  lRootProved: Boolean;
begin
  Result := False;
  if (not SameText(aReference.Classification, 'external')) or
    (not SameText(aReference.Kind, 'routine')) or
    (not SameText(aReference.ReasonCode, 'EXTERNAL_ROUTINE_CALL')) or
    (not IsSimpleIdentifier(aReference.Name)) then
    Exit;
  lRootProved := False;
  for lDecision in aDecisions do
    if aFacts.LookupIndex.ReceiverLineageHasUnindexedRoot(lDecision.ReceiverIdentity) and
      aFacts.LookupIndex.ReceiverMemberAbsenceProved(aBinding.UnitName,
        lDecision.ReceiverType, aReference.Name, lDecision.ReceiverIdentity) then
      lRootProved := True;
  if not lRootProved then
    Exit;
  // Absence does not establish a callable symbol. Require a source-backed unit
  // procedure declared before this site; routine-local and type scopes cannot pass.
  for lDeclaration in aFacts.LookupIndex.FindSymbolsByName(aReference.Name) do
    if SameText(lDeclaration.SymbolClass, 'routine') and
      SameText(lDeclaration.Kind, 'routine') and
      SameText(lDeclaration.FileName, aBinding.FileName) and
      (lDeclaration.OwnerName = '') and (lDeclaration.OwnerType = '') and
      (lDeclaration.RoutineScopeId <> '') and (lDeclaration.ParentScopeId = '') and
      (lDeclaration.UnsupportedReason = '') and (lDeclaration.Line > 0) and
      (lDeclaration.Line < aBinding.Line) then
      Exit(True);
end;

function ReferenceBlocksFinalRewrite(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aDecisions: TArray<TFinalSelectorDecision>;
  const aReference: TDelphiSemanticBoundReference;
  const aLineCache: TDelphiSemanticSourceContextCache;
  out aReason: string): Boolean;
begin
  Result := False;
  aReason := '';
  if aReference.Kind = 'unverified-label' then
  begin
    aReason := 'local-label-not-resolved';
    Exit(True);
  end;
  if MatchText(aReference.Kind, ['label', 'goto-keyword']) and
    (aReference.LookupSource = 'syntax') then
    Exit;
  if ReferenceHasAmbiguousReceiverRoutineMember(aFacts, aDecisions,
    aReference) then
  begin
    aReason := 'multiple-member-candidates';
    Exit(True);
  end;
  if SameText(aReference.Kind, 'routine') and
    ReferenceIsCompilerIntrinsicTypeName(aReference) then
    Exit;
  if SameText(aReference.Classification, 'external') and
    SameText(aReference.Kind, 'routine') and
    MatchText(aReference.ReasonCode, ['EXTERNAL_ROUTINE_CALL',
      'UNKNOWN_ROUTINE_CALL']) and
    (Trim(aReference.TypeName) = '') and
    (Pos('[', aReference.Name) = 0) and
    (not ReferenceLineHasConditionalDirective(aBinding, aReference, aLineCache)) and
    (not ReferenceHasPriorRoutineDeclaration(aFacts, aBinding, aReference,
    aLineCache)) and
    (not ReferenceIsRoutineSymbol(aFacts, aBinding, aReference.Name)) and
    (not ReferenceIsRoutineScopeValue(aFacts, aBinding, aReference)) and
    (not ReferenceQualifiedPrefixIsRoutineScopeValue(aFacts, aBinding, aReference)) and
    (not ReferenceQualifiedPrefixCanRemainUnchanged(aFacts, aBinding, aReference)) and
    (not ReferenceLooksLikeLocalLabel(aBinding, aReference, aLineCache)) and
    (not ReferenceHasKnownRoutineSymbol(aFacts, aReference)) and
    (not ReferenceHasRootProvedVisibleProcedure(aFacts, aBinding, aDecisions, aReference)) and
    (not ReferenceHasVisibleImportedProcedure(aFacts, aBinding, aReference, aLineCache)) then
  begin
    aReason := 'symbol-not-found';
    Exit(True);
  end;
end;

function ProtectedBodySpanAt(const aSpans: TArray<TFinalBodyEdit>;
  const aOffset: Integer; const aName: string): Boolean;
var
  lSpan: TFinalBodyEdit;
begin
  Result := False;
  for lSpan in aSpans do
    if (lSpan.Offset = aOffset) and (lSpan.Length = Length(aName)) and
      (lSpan.ExpectedText = aName) then
      Exit(True);
end;

function ApplyFinalBodyEdits(const aEdits: TArray<TFinalBodyEdit>;
  var aProtectedSpans: TArray<TFinalBodyEdit>; var aText: string): Boolean;
var
  lApplied: TArray<Boolean>;
  lBestIndex: Integer;
  i: Integer;
  j: Integer;
begin
  Result := False;
  SetLength(lApplied, Length(aEdits));
  while True do
  begin
    lBestIndex := -1;
    for i := 0 to High(aEdits) do
    begin
      if lApplied[i] then
        Continue;
      if (lBestIndex < 0) or (aEdits[i].Offset > aEdits[lBestIndex].Offset) then
        lBestIndex := i;
    end;
    if lBestIndex < 0 then
      Break;

    lApplied[lBestIndex] := True;
    if (aEdits[lBestIndex].ExpectedText <> '') and
      (Copy(aText, aEdits[lBestIndex].Offset,
      Length(aEdits[lBestIndex].ExpectedText)) <>
      aEdits[lBestIndex].ExpectedText) then
      Continue;
    for j := 0 to High(aProtectedSpans) do
    begin
      if (aEdits[lBestIndex].Offset = aProtectedSpans[j].Offset) and
        (aEdits[lBestIndex].ExpectedText = aProtectedSpans[j].ExpectedText) and
        (aEdits[lBestIndex].ReplacementText = aProtectedSpans[j].ExpectedText) then
        Continue;
      if aEdits[lBestIndex].Offset + aEdits[lBestIndex].Length <=
        aProtectedSpans[j].Offset then
        Inc(aProtectedSpans[j].Offset, Length(aEdits[lBestIndex].ReplacementText) -
          aEdits[lBestIndex].Length)
      else if aEdits[lBestIndex].Offset < aProtectedSpans[j].Offset +
        aProtectedSpans[j].Length then
        Exit;
    end;
    Delete(aText, aEdits[lBestIndex].Offset, aEdits[lBestIndex].Length);
    Insert(aEdits[lBestIndex].ReplacementText, aText, aEdits[lBestIndex].Offset);
  end;
  for i := 0 to High(aProtectedSpans) do
    if not BodyTextIdentifierAt(aText, aProtectedSpans[i].ExpectedText,
      aProtectedSpans[i].Offset) or
      (Copy(aText, aProtectedSpans[i].Offset, aProtectedSpans[i].Length) <>
      aProtectedSpans[i].ExpectedText) then
      Exit;
  Result := True;
end;

function FinalBodyHasIncompleteReceiverReference(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aDecisions: TArray<TFinalSelectorDecision>;
  const aLineCache: TDelphiSemanticSourceContextCache;
  const aBodyRange: TDelphiSemanticRemoveWithSourceRange; const aBodyText: string;
  const aProtectedSpans: TArray<TFinalBodyEdit>):
  Boolean;
var
  i: Integer;
  lDecision: TFinalSelectorDecision;
  lDecisionIndex: Integer;
  lQualified: Boolean;
  lReference: TDelphiSemanticBoundReference;
  lName: string;
  lDeclarations: TArray<Boolean>;
  lRequiresQualification: Boolean;
  lSelectorMember: Boolean;
  lStartOffset: Integer;

  procedure BodyOffsetToReferenceLocation(var aReference:
    TDelphiSemanticBoundReference; const aOffset: Integer);
  var
    lBodyLine: Integer;
    lColumn: Integer;
    lLineStartOffset: Integer;
    lTextIndex: Integer;
  begin
    lBodyLine := 1;
    lLineStartOffset := 1;
    lTextIndex := 1;
    while (lTextIndex < aOffset) and (lTextIndex <= Length(aBodyText)) do
    begin
      if aBodyText[lTextIndex] = #10 then
      begin
        Inc(lBodyLine);
        lLineStartOffset := lTextIndex + 1;
      end;
      Inc(lTextIndex);
    end;

    lColumn := aOffset - lLineStartOffset + 1;
    aReference.Line := aBodyRange.StartLine + lBodyLine - 1;
    if lBodyLine = 1 then
      aReference.Column := aBodyRange.StartColumn + lColumn - 1
    else
      aReference.Column := lColumn;
    aReference.EndLine := aReference.Line;
    aReference.EndColumn := aReference.Column + Length(aReference.Name) - 1;
  end;
begin
  Result := False;
  lDeclarations := BodyNonReferencePositions(aBodyText, False);
  i := 1;
  while i <= Length(aBodyText) do
  begin
    if not IsIdentifierTextChar(aBodyText[i]) then
    begin
      Inc(i);
      Continue;
    end;

    lStartOffset := i;
    while (i <= Length(aBodyText)) and IsIdentifierTextChar(aBodyText[i]) do
      Inc(i);
    lName := Copy(aBodyText, lStartOffset, i - lStartOffset);

    if ProtectedBodySpanAt(aProtectedSpans, lStartOffset, lName) then
      Continue;

    lSelectorMember := SimpleSelectorHasMember(aFacts, aBinding, aDecisions, lName);
    if BodyOffsetInsideLiteralOrComment(aBodyText, lStartOffset) or
      BodyOffsetAppearsQualified(aBodyText, lStartOffset) or
      (RoutineScopeSymbolNamed(aFacts, aBinding, lName) and (not lSelectorMember)) or
      BodyOffsetIsDeclaration(lDeclarations, lStartOffset) then
      Continue;

    lReference := Default(TDelphiSemanticBoundReference);
    lReference.Name := lName;
    BodyOffsetToReferenceLocation(lReference, lStartOffset);
    if (ReferenceCanRemainUnchanged(aFacts, aBinding, lReference) and
      (not lSelectorMember)) or
      ReferenceLooksLikeLocalLabel(aBinding, lReference, aLineCache) then
      Continue;

    lQualified := False;
    lRequiresQualification := False;
    for lDecisionIndex := High(aDecisions) downto 0 do
    begin
      lDecision := aDecisions[lDecisionIndex];
      if (Trim(lDecision.QualifierText) = '') or
        (Trim(lDecision.ReceiverType) = '') then
        Continue;
      if not OwnerHasMemberNamed(aFacts, lDecision.ReceiverType, lName) then
        Continue;

      if DecisionKeepsWithMemberScope(lDecision) then
        Break;
      lRequiresQualification := True;
      if BodyOffsetInsideTextOccurrence(aBodyText, lDecision.QualifierText,
        lStartOffset) or BodyOffsetHasTextQualifier(aBodyText,
        lDecision.QualifierText, lStartOffset) then
        lQualified := True;
      Break;
    end;
    if lRequiresQualification and (not lQualified) then
      Exit(True);
  end;
end;

function BodyHasEscapedIdentifier(const aText: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 1 to Length(aText) - 1 do
    if (aText[i] = '&') and CharInSet(aText[i + 1], ['A'..'Z', 'a'..'z', '_']) and
      not BodyOffsetInsideLiteralOrComment(aText, i) then
      Exit(True);
end;

function BodyHasUnverifiedEscapedIdentifier(const aText: string;
  const aBinding: TDelphiSemanticWithBinding;
  const aBodyRange: TDelphiSemanticRemoveWithSourceRange;
  const aLines: TArray<string>; const aLineBreak: string): Boolean;
var
  i: Integer;
  lEndOffset: Integer;
  lFound: Boolean;
  lName: string;
  lOffset: Integer;
  lReference: TDelphiSemanticBoundReference;
begin
  Result := False;
  for i := 1 to Length(aText) - 1 do
  begin
    if (aText[i] <> '&') or
      (not CharInSet(aText[i + 1], ['A'..'Z', 'a'..'z', '_'])) or
      BodyOffsetInsideLiteralOrComment(aText, i) or
      BodyOffsetAppearsQualified(aText, i) then
      Continue;
    lEndOffset := i + 1;
    while (lEndOffset <= Length(aText)) and IsIdentifierTextChar(aText[lEndOffset]) do
      Inc(lEndOffset);
    lName := Copy(aText, i + 1, lEndOffset - i - 1);
    lFound := False;
    for lReference in aBinding.References do
    begin
      lOffset := RangeRelativeOffset(aBodyRange, aLines, lReference.Line,
        lReference.Column, aLineBreak);
      if ((lOffset = i) or (lOffset = i + 1)) and
        SameText(ReferenceLookupName(lReference.Name), lName) then
      begin
        lFound := True;
        Break;
      end;
    end;
    if not lFound then
      Exit(True);
  end;
end;

function ReferenceWasRoutineLocalRecordActivityMiss(
  const aBinding: TDelphiSemanticWithBinding;
  const aReference: TDelphiSemanticBoundReference): Boolean;
var
  lSelector: TDelphiSemanticWithSelectorBinding;
begin
  Result := False;
  if (not aBinding.MemberActivityUnverified) or
    (not SameText(aReference.Classification, 'unsupported')) or
    (not SameText(aReference.ReasonCode, 'OWNER_INHERITED_MEMBERS_UNVERIFIED')) then
    Exit;
  for lSelector in aBinding.Selectors do
    if SameText(lSelector.TypeIdentity.ScopeKind, 'routine') and
      SameText(lSelector.TypeIdentity.Kind, 'type') and
      (lSelector.TypeIdentity.BaseTypeName = '') and
      (lSelector.TypeIdentity.HelperTargetName = '') and
      MatchText(lSelector.TypeIdentity.UnderlyingName, ['record', 'packed record']) and
      SameText(lSelector.TypeIdentity.Name, aReference.ReceiverTypeName) then
      Exit(True);
end;

function InventoryFactIsInsideVerifiedTypeBody(const aFacts: TRemoveWithPlanFacts;
  const aSymbol: TDelphiSemanticInventorySymbol;
  const aIdentity: TDelphiSemanticTypeIdentity): Boolean;
var
  lBody: TDelphiSemanticInventorySymbol;
  lMatchCount: Integer;
begin
  Result := False;
  if not TypeIdentityHasVerifiedOrigin(aIdentity) then
    Exit;
  lMatchCount := 0;
  for lBody in aFacts.LookupIndex.FindSymbolsByName(aIdentity.Name) do
  begin
    if not SameText(lBody.SymbolClass, 'type-body-range') or
      not SameText(lBody.UnitName, aIdentity.UnitName) or
      not SameText(lBody.FileName, aIdentity.SourceRange.FileName) or
      (lBody.Line <> aIdentity.SourceRange.Line) or
      (lBody.Column <> aIdentity.SourceRange.Column) or
      not SameText(lBody.SectionKind, aIdentity.SectionKind) or
      not SameText(lBody.OwnerScopeId, aIdentity.OwnerScopeId) or
      not SameText(lBody.OwnerSymbolId, aIdentity.SemanticSymbolId) or
      (lBody.EndLine < lBody.Line) or (lBody.EndColumn <= 0) then
      Continue;
    Inc(lMatchCount);
    Result := SameText(aSymbol.FileName, lBody.FileName) and
      ((aSymbol.Line > lBody.Line) or
        ((aSymbol.Line = lBody.Line) and (aSymbol.Column >= lBody.Column))) and
      ((aSymbol.Line < lBody.EndLine) or
        ((aSymbol.Line = lBody.EndLine) and (aSymbol.Column < lBody.EndColumn)));
  end;
  if lMatchCount <> 1 then
    Exit(False);

end;

function QualificationTargetsVerifiedOwnerMember(const aFacts: TRemoveWithPlanFacts;
  const aDecisions: TArray<TFinalSelectorDecision>; const aEdit: TFinalBodyEdit): Boolean;
var
  lDecision: TFinalSelectorDecision;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  for lDecision in aDecisions do
  begin
    if not TypeIdentityHasVerifiedOrigin(lDecision.ReceiverIdentity) or
      not SameText(aEdit.ReplacementText,
        lDecision.QualifierText + '.' + aEdit.ExpectedText) then
      Continue;
    for lSymbol in aFacts.LookupIndex.FindSymbolsByName(aEdit.ExpectedText) do
    begin
      if not InventorySymbolIsSourceBacked(lSymbol) or
        not MatchText(lSymbol.SymbolClass,
          ['member', 'field', 'property', 'method', 'class-var']) or
        not (TypeNameMatches(lSymbol.OwnerType, lDecision.ReceiverType) or
          TypeNameMatches(lSymbol.OwnerName, lDecision.ReceiverType) or
          TypeNameMatches(lSymbol.SourceOwnerType, lDecision.ReceiverType)) then
        Continue;
      if InventoryFactIsInsideVerifiedTypeBody(aFacts, lSymbol,
        lDecision.ReceiverIdentity) then
        Exit(True);
      // Only the binder's verified access lineage permits a different declaration body.
      if TypeIdentitiesAreSameDeclaration(lSymbol.AccessOwnerIdentity,
        lDecision.ReceiverIdentity) and InventoryFactIsInsideVerifiedTypeBody(aFacts,
          lSymbol, lSymbol.OwnerIdentity) then
        Exit(True);
    end;
  end;
end;

function BodyEditsQualifyNonMemberReference(const aFacts: TRemoveWithPlanFacts;
  const aDecisions: TArray<TFinalSelectorDecision>; const aEdits: TArray<TFinalBodyEdit>;
  const aBinding: TDelphiSemanticWithBinding; const aBodyText: string;
  const aBodyStartLine: Integer): Boolean;
var
  lEdit: TFinalBodyEdit;
  lReference: TDelphiSemanticBoundReference;
  lLine, i: Integer;
  lNonMember, lMember: Boolean;
begin
  for lEdit in aEdits do
  begin
    if (not IsSimpleIdentifier(lEdit.ExpectedText)) or
      (lEdit.ExpectedText = lEdit.ReplacementText) then
      Continue;
    lLine := aBodyStartLine;
    if (lEdit.Offset < 1) or (lEdit.Offset > Length(aBodyText) + 1) then
      Continue;
    for i := 1 to lEdit.Offset - 1 do
      if (aBodyText[i] = #10) or ((aBodyText[i] = #13) and
        ((i = Length(aBodyText)) or (aBodyText[i + 1] <> #10))) then
        Inc(lLine);
    lNonMember := False;
    lMember := False;
    for lReference in aBinding.References do
      if (lReference.Line = lLine) and SameText(lReference.Name, lEdit.ExpectedText) then
      begin
        if MatchText(lReference.Classification, ['lexical', 'unresolved']) then
          lNonMember := True;
        if SameText(lReference.Classification, 'member') then
          lMember := True;
      end;
    if lNonMember and (not lMember) and
      (not QualificationTargetsVerifiedOwnerMember(aFacts, aDecisions, lEdit)) then
      Exit(True);
  end;
  Result := False;
end;

function BodyEditsQualifyReference(const aEdits: TArray<TFinalBodyEdit>;
  const aOffset: Integer; const aName: string): Boolean;
var
  lEdit: TFinalBodyEdit;
begin
  Result := False;
  if aOffset <= 0 then
    Exit;
  for lEdit in aEdits do
    if ((lEdit.Offset = aOffset) and SameText(lEdit.ExpectedText, aName) or
      (lEdit.Offset = aOffset - 1) and SameText(lEdit.ExpectedText, '&' + aName)) and
      (lEdit.ReplacementText <> lEdit.ExpectedText) then
      Exit(True);
end;

type
  TAnonymousRecordIncludeGuard = class(TInterfacedObject, IIncludeHandler)
  private
    fSeen: PBoolean;
  public
    constructor Create(var aSeen: Boolean);
    function GetIncludeFileContent(const aParentFileName, aIncludeName: string;
      out aContent, aFileName: string): Boolean;
  end;

constructor TAnonymousRecordIncludeGuard.Create(var aSeen: Boolean);
begin
  inherited Create;
  fSeen := @aSeen;
end;

function TAnonymousRecordIncludeGuard.GetIncludeFileContent(const aParentFileName,
  aIncludeName: string; out aContent, aFileName: string): Boolean;
begin
  // SimpleParser consumes include tokens internally. Observe without expanding:
  // we lack an anonymous owner identity and reliable expanded declaration origins.
  fSeen^ := True;
  aContent := '';
  aFileName := '';
  Result := False;
end;

function AnonymousRecordScanSource(const aSource, aEvidence: string): string;
var
  lPrefix: string;
begin
  Result := '';
  lPrefix := TDelphiSemanticSourceConditionals.UnavailableActivity;
  if StartsStr(lPrefix, aEvidence) then
  begin
    if Length(aEvidence) <> Length(lPrefix) + Length(aSource) then
      Exit;
  end else if (aEvidence = '') or (Length(aEvidence) <> Length(aSource)) then
    Exit;
  Result := TDelphiSemanticSourceConditionals.SourceForScan(aSource, aEvidence);
end;

function AnonymousRecordActivityIsKnown(const aSource, aEvidence: string): Boolean;
var
  lPrefix: string;
begin
  lPrefix := TDelphiSemanticSourceConditionals.UnavailableActivity;
  if StartsStr(lPrefix, aEvidence) then
    Exit((Length(aEvidence) = Length(lPrefix) + Length(aSource)) and
      (Pos('?', aEvidence) = 0));
  Result := (aEvidence <> '') and (Length(aEvidence) = Length(aSource));
end;

function TPlannerLookupMemo.UnverifiedValueMemberMayApply(
  const aOwnerType, aName: string; const aOwnerIdentity: TDelphiSemanticTypeIdentity): Boolean;
begin
  if TypeIdentityHasVerifiedOrigin(aOwnerIdentity) then
    Exit(fIndex.UnverifiedValueMemberMayApply(aOwnerType, aName, aOwnerIdentity));
  Result := fIndex.UnverifiedValueMemberMayApply(aOwnerType, aName);
end;

function TPlannerLookupMemo.ReceiverLineageDeclaresMember(
  const aOwnerIdentity: TDelphiSemanticTypeIdentity; const aOwnerName, aName: string): Boolean;
begin
  Result := TypeIdentityHasVerifiedOrigin(aOwnerIdentity) and
    fIndex.ReceiverLineageDeclaresMember(aOwnerIdentity, aOwnerName, aName);
end;

function TPlannerLookupMemo.UnverifiedReceiverMemberMayApply(
  const aOwnerType, aName: string; const aOwnerIdentity: TDelphiSemanticTypeIdentity): Boolean;
begin
  if TypeIdentityHasVerifiedOrigin(aOwnerIdentity) then
    Exit(fIndex.UnverifiedReceiverMemberMayApply(aOwnerType, aName, aOwnerIdentity));
  Result := fIndex.UnverifiedReceiverMemberMayApply(aOwnerType, aName,
    Default(TDelphiSemanticTypeIdentity));
end;

function PlannerResolvesNamedReceiverType(const aFacts: TRemoveWithPlanFacts;
  const aTypeName: string; const aLineCache: TDelphiSemanticSourceContextCache): Boolean;
var
  lIncludeSeen: Boolean;
  lLexer: TmwBasePasLex;
  lLines: TArray<string>;
  lName, lText: string;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  for lSymbol in aFacts.LookupIndex.FindDeclarationOrTypeAliasByName(aTypeName) do
  begin
    if (not MatchText(lSymbol.Kind, ['type', 'type-alias'])) or
      (lSymbol.Line < 1) or (lSymbol.Column < 1) or
      (not aLineCache.TryGetValue(lSymbol.FileName, lLines)) or
      (lSymbol.Line > Length(lLines)) then
      Continue;
    if lSymbol.Column > Length(lLines[lSymbol.Line - 1]) then
      Continue;
    // Inventory also synthesizes type entries for anonymous variables. A real
    // named type has a source declaration with '=', not the variable's ':'.
    lName := Copy(lSymbol.Name, LastDelimiter('.', lSymbol.Name) + 1, MaxInt);
    lText := string.Join(sLineBreak, Copy(lLines, lSymbol.Line - 1,
      Length(lLines) - lSymbol.Line + 1));
    lLexer := TmwBasePasLex.Create;
    try
      try
        lIncludeSeen := False;
        lLexer.UseDefines := False;
        lLexer.IncludeHandler := TAnonymousRecordIncludeGuard.Create(lIncludeSeen);
        lLexer.Origin := Copy(lText, lSymbol.Column, MaxInt);
        if not SameText(lLexer.Token, lName) then
          Continue;
        lLexer.NextNoJunk;
        if (lLexer.Token = '=') and (not lIncludeSeen) then
          Exit(True);
      except
        on ERangeError do
          // An unreadable header cannot establish a named type.
          Exit(False);
      end;
    finally
      lLexer.Free;
    end;
  end;
end;

function AnonymousRecordTagNames(const aFacts: TRemoveWithPlanFacts;
  const aDecisions: TArray<TFinalSelectorDecision>;
  const aLineCache: TDelphiSemanticSourceContextCache;
  out aQualifiedFieldTags: TArray<string>;
  out aAnonymousNames: TArray<TArray<string>>): TArray<string>;
var
  i: Integer;
  lActivityKnown, lCaseSelector, lRecordScanned: Boolean;
  lParenthesisDepth, lVariantBaseDepth: Integer;
  lMemberNames: TList<string>;
  lDecision: TFinalSelectorDecision;
  lAnchored: Boolean;
  lDepth: Integer;
  lIncludeSeen: Boolean;
  lLexer: TmwBasePasLex;
  lLines: TArray<string>;
  lNames, lFieldTags: TList<string>;
  lSourceLines: TStringList;
  lScanLines: TArray<string>;
  lScanSource: string;
  lSymbol: TDelphiSemanticInventorySymbol;
  lTagName: string;
  lText: string;
begin
  Result := nil;
  aQualifiedFieldTags := nil;
  SetLength(aAnonymousNames, Length(aDecisions));
  for i := 0 to High(aAnonymousNames) do
    aAnonymousNames[i] := TArray<string>.Create('*');
  lMemberNames := TList<string>.Create;
  lFieldTags := TList<string>.Create;
  lNames := TList<string>.Create;
  try
    // Anonymous types have no verified type DeclaredId. Anchor at the selected
    // declaration; only a complete active record scan can also prove absence.
    for i := 0 to High(aDecisions) do
    begin
      lDecision := aDecisions[i];
      lMemberNames.Clear;
      lRecordScanned := False;
      if TypeIdentityHasVerifiedOrigin(lDecision.ReceiverIdentity) then
        Continue;
      // A planner-resolved named type is handled by TypeValueMembers, even when
      // the binder has no DeclaredId. Synthetic anonymous entries do not count.
      if PlannerResolvesNamedReceiverType(aFacts, lDecision.ReceiverType, aLineCache) then
        Continue;
      lAnchored := False;
      for lSymbol in aFacts.LookupIndex.FindSymbolsByName(lDecision.SelectorText) do
      begin
        if (not SameText(lSymbol.Name, lDecision.SelectorText)) or
          (not SameText(lSymbol.TypeName, lDecision.ReceiverType)) or
          (not MatchText(lSymbol.Kind, ['var', 'threadvar', 'field', 'class-var'])) then
          Continue;
        // Inventory can carry include-local coordinates with the root file name.
        // Missing or unanchored provenance is refusal evidence, never absence.
        if (lSymbol.Line < 1) or (lSymbol.Column < 1) or
          (not aLineCache.TryGetValue(lSymbol.FileName, lLines)) or
          (lSymbol.Line > Length(lLines)) then
          Exit(TArray<string>.Create('*'));
        if lSymbol.Column > Length(lLines[lSymbol.Line - 1]) then
          Exit(TArray<string>.Create('*'));
        if not aFacts.ScanLines.TryGetValue(lSymbol.FileName, lScanLines) then
        begin
          // Match SourceContext's TStringList.Text semantics, including final EOLs.
          // Raw source cannot prove absence of an active tag behind conditionals.
          if (not aFacts.ScanSources.TryGetValue(lSymbol.FileName, lScanSource)) or
            (lScanSource = '') then
            Exit(TArray<string>.Create('*'));
          lSourceLines := TStringList.Create;
          try
            lSourceLines.Text := lScanSource;
            lScanLines := lSourceLines.ToStringArray;
          finally
            lSourceLines.Free;
          end;
          if Length(lScanLines) <> Length(lLines) then
            Exit(TArray<string>.Create('*'));
          aFacts.ScanLines.Add(lSymbol.FileName, lScanLines);
        end;
        lText := string.Join(sLineBreak, Copy(lLines, lSymbol.Line - 1,
          Length(lLines) - lSymbol.Line + 1));
        // SetOrigin owns one buffer; use a fresh lexer for each declaration.
        lLexer := TmwBasePasLex.Create;
        try
          try
            lLexer.UseDefines := False;
            lIncludeSeen := False;
            lLexer.IncludeHandler := TAnonymousRecordIncludeGuard.Create(lIncludeSeen);
            lLexer.Origin := Copy(lText, lSymbol.Column, MaxInt);
            if not SameText(lLexer.Token, lSymbol.Name) then
              Exit(TArray<string>.Create('*'));
            lAnchored := True;
            // Only a physically anchored name blanked by the activity mask is
            // known inactive. A coordinate mismatch cannot establish inactivity.
            if (Length(lScanLines[lSymbol.Line - 1]) >=
              lSymbol.Column + Length(lSymbol.Name) - 1) and
              (Trim(Copy(lScanLines[lSymbol.Line - 1], lSymbol.Column,
                Length(lSymbol.Name))) = '') then
              Continue;
            lLexer.NextNoJunk;
            // Class-var inventory can point at a use rather than a declaration.
            // The name alone is not provenance: a following '.' (or any token
            // other than ':') deliberately keeps the conservative refusal.
            if lLexer.TokenID <> ptColon then
              Exit(TArray<string>.Create('*'));
            lText := string.Join(sLineBreak, Copy(lScanLines, lSymbol.Line - 1,
              Length(lScanLines) - lSymbol.Line + 1));
            // SetOrigin owns one buffer. Recreate instead of resetting it.
            lLexer.Free;
            lLexer := nil;
            lLexer := TmwBasePasLex.Create;
            lIncludeSeen := False;
            lLexer.UseDefines := False;
            lLexer.IncludeHandler := TAnonymousRecordIncludeGuard.Create(lIncludeSeen);
            lLexer.Origin := Copy(lText, lSymbol.Column, MaxInt);
            lLexer.NextNoJunk;
            lLexer.NextNoJunk;
            if lLexer.TokenID = ptPacked then
              lLexer.NextNoJunk;
            if lIncludeSeen then
              Exit(TArray<string>.Create('*'));
            if lLexer.TokenID <> ptRecord then
              Continue;
            if not aFacts.ScanActivityKnown.TryGetValue(
              lSymbol.FileName, lActivityKnown) then
              lActivityKnown := False;
            lDepth := 1;
            lParenthesisDepth := 0;
            lVariantBaseDepth := -1;
            lCaseSelector := False;
            lLexer.NextNoJunk;
            while (lLexer.TokenID <> ptNull) and (lDepth > 0) do
            begin
              if lLexer.TokenID = ptIdentifier then
              begin
                lTagName := lLexer.Token;
                if StartsText('&', lTagName) then
                  Delete(lTagName, 1, 1);
                // Declaration names precede ':', ',' or '='. Exclude ': ('
                // only at the proven outer variant-arm boundary: a field may
                // itself declare an inline enum with that same token pair.
                // Extra compound-type and nested-label names remain conservative.
                lLexer.NextNoJunk;
                if lLexer.TokenID = ptColon then
                begin
                  lLexer.NextNoJunk;
                  if not ((lLexer.TokenID = ptRoundOpen) and (lDepth = 1) and
                    (lVariantBaseDepth >= 0) and
                    (lParenthesisDepth = lVariantBaseDepth)) then
                    lMemberNames.Add(lTagName);
                end else if lLexer.TokenID in [ptComma, ptEqual] then
                  lMemberNames.Add(lTagName);
              end;
              if lLexer.TokenID = ptRecord then
                Inc(lDepth)
              else if lLexer.TokenID = ptEnd then
                Dec(lDepth)
              else if (lDepth = 1) and (lLexer.TokenID = ptCase) then
              begin
                lCaseSelector := True;
                lLexer.NextNoJunk;
                if lLexer.TokenID = ptIdentifier then
                begin
                  lTagName := lLexer.Token;
                  if StartsText('&', lTagName) then
                    Delete(lTagName, 1, 1);
                  lLexer.NextNoJunk;
                  if lLexer.TokenID = ptColon then
                  begin
                    lNames.Add(lTagName);
                    lMemberNames.Add(lTagName);
                    if SameText(lSymbol.Kind, 'field') then
                      lFieldTags.Add(lDecision.QualifierText + '.' + lTagName);
                  end;
                end;
              end;
              if lCaseSelector and (lLexer.TokenID = ptOf) then
              begin
                if lVariantBaseDepth < 0 then
                  lVariantBaseDepth := lParenthesisDepth;
                lCaseSelector := False;
              end;
              if lLexer.TokenID = ptRoundOpen then
                Inc(lParenthesisDepth)
              else if lLexer.TokenID = ptRoundClose then
              begin
                if lParenthesisDepth <= 0 then
                  lMemberNames.Add('*');
                Dec(lParenthesisDepth);
              end;
              lLexer.NextNoJunk;
            end;
            if lIncludeSeen then
              Exit(TArray<string>.Create('*'));
            if (lDepth = 0) and (lParenthesisDepth = 0) and
              (not lCaseSelector) and lActivityKnown then
              lRecordScanned := True
            else
              lMemberNames.Add('*');
          except
            on ERangeError do
              // SimpleParser's include-name reader assumes a '}' terminator and
              // can overrun a (*$I ...*) token before the observer is called.
              // An unreadable declaration explicitly refuses; it proves no absence.
              Exit(TArray<string>.Create('*'));
          end;
        finally
          lLexer.Free;
        end;
      end;
      // Unsupported anonymous declarations and missing anchors prove no absence.
      if not lAnchored then
        Exit(TArray<string>.Create('*'));
      if lRecordScanned and (not MatchText('*', lMemberNames.ToArray)) then
        aAnonymousNames[i] := lMemberNames.ToArray;
    end;
    Result := lNames.ToArray;
    aQualifiedFieldTags := lFieldTags.ToArray;
  finally
    lMemberNames.Free;
    lNames.Free;
    lFieldTags.Free;
  end;
end;

function TPlannerLookupMemo.IsWeakProfileRecord(
  const aIdentity: TDelphiSemanticTypeIdentity): Boolean;
begin
  Result := IsProfileRecord(aIdentity, False);
end;

function TPlannerLookupMemo.IsProfileRecord(
  const aIdentity: TDelphiSemanticTypeIdentity;
  const aAllowStrongAlias: Boolean): Boolean;
var
  lDeclarations: TArray<TDelphiSemanticInventorySymbol>;
  lName: string;
  lMatchCount: Integer;
  lProjectionFound: Boolean;
  lAlias: TDelphiSemanticInventorySymbol;
  lSeen: TList<string>;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  if (aIdentity.DeclaredId.Value = '') or
    (not SameText(aIdentity.Kind, 'type-alias')) or
    SameText(aIdentity.ScopeKind, 'routine') then
    Exit;
  lName := aIdentity.Name.Trim;
  lSeen := TList<string>.Create;
  try
    while True do
    begin
      if MatchText(lName, lSeen.ToArray) then
        Exit;
      lSeen.Add(lName);
      // This only preserves the pre-existing weak RTL record boundary. Strong,
      // generic, scoped and ambiguous targets retain the fail-closed guard.
      if StartsText('&', lName) then
        Delete(lName, 1, 1);
      if (lName = '') or (Pos('.', lName) > 0) or
        (Pos('<', lName) > 0) then
        Exit;
      lDeclarations := FindDeclarationOrTypeAliasByName(lName);
      if Length(lDeclarations) = 1 then
      begin
        lSymbol := lDeclarations[0];
        if SameText(lSymbol.SymbolClass, 'type-member') and
          SameText(lSymbol.SourceOwnerType, 'rtl-source') and
          SameText(lSymbol.UnitName, 'rtl-source') and
          SameText(lSymbol.TypeCategory, 'record') and
          ((not aAllowStrongAlias) or SameText(lSymbol.Name, 'TSearchRec')) then
          Exit(True);
      end;
      // A projected type-member row accompanies the declaration. Only one
      // actual declaration, with matching projection anchors, may extend a chain.
      lMatchCount := 0;
      lAlias := Default(TDelphiSemanticInventorySymbol);
      for lSymbol in lDeclarations do
        if SameText(lSymbol.SymbolClass, 'declaration') then
        begin
          Inc(lMatchCount);
          lAlias := lSymbol;
        end;
      if (lMatchCount <> 1) or (not SameText(lAlias.Kind, 'type-alias')) or
        (not SameText(lAlias.OwnerScopeId, lAlias.UnitName)) then
        Exit;
      lProjectionFound := False;
      for lSymbol in lDeclarations do
      begin
        if (not SameText(lSymbol.UnitName, lAlias.UnitName)) or
          (not SameText(lSymbol.FileName, lAlias.FileName)) or
          (lSymbol.Line <> lAlias.Line) or
          (not MatchText(lSymbol.SymbolClass, ['declaration', 'type-member'])) then
          Exit;
        if SameText(lSymbol.SymbolClass, 'type-member') then
          lProjectionFound := True;
      end;
      // The compatibility exemption requires the alias's actual member projection.
      if not lProjectionFound then
        Exit;
      lName := lAlias.RelatedTypeName.Trim;
      // This option proves only the receiver designator's name absent. It
      // never relaxes the strong-alias guard on body references.
      if aAllowStrongAlias and StartsText('type ', lName) then
        lName := Trim(Copy(lName, 6, MaxInt));
    end;
  finally
    lSeen.Free;
  end;
end;

function TPlannerLookupMemo.ReceiverLineageHasUnindexedRoot(
  const aOwnerIdentity: TDelphiSemanticTypeIdentity): Boolean;
begin
  if not TypeIdentityHasVerifiedOrigin(aOwnerIdentity) then
    Exit(True);
  if not fRootLineages.TryGetValue(aOwnerIdentity.DeclaredId.Value, Result) then
  begin
    Result := fIndex.ReceiverLineageHasUnindexedRoot(aOwnerIdentity);
    fRootLineages.Add(aOwnerIdentity.DeclaredId.Value, Result);
  end;
end;

function TPlannerLookupMemo.ReceiverMemberAbsenceProved(
  const aSiteUnitName, aOwnerType, aName: string;
  const aOwnerIdentity: TDelphiSemanticTypeIdentity): Boolean;
begin
  if TypeIdentityHasVerifiedOrigin(aOwnerIdentity) then
    Result := fIndex.ReceiverMemberAbsenceProved(aSiteUnitName, aOwnerType, aName, aOwnerIdentity)
  else
    Result := fIndex.ReceiverMemberAbsenceProved(aSiteUnitName, aOwnerType, aName,
      Default(TDelphiSemanticTypeIdentity));
end;

function BindingHasUnprovedReceiverReference(const aSiteUnitName: string;
  const aFacts: TRemoveWithPlanFacts; const aBodyFacts: TFinalReceiverBodyFacts;
  const aDecisions: TArray<TFinalSelectorDecision>; out aSafetyReason: string): Boolean;
var
  i, j, lReferenceCount: Integer;
  lGuarded, lWeak, lAlias: TArray<Boolean>;
  lHasGuarded: Boolean;
  lReference: TDelphiSemanticBoundReference;
  lName, lQualifier: string;
  lWitness: TArray<string>;
begin
  Result := False;
  aSafetyReason := '';
  lReferenceCount := Length(aBodyFacts.BareReferences) + Length(aBodyFacts.QualifiedFallbacks);
  if lReferenceCount = 0 then
    Exit;
  SetLength(lGuarded, Length(aDecisions));
  SetLength(lWeak, Length(aDecisions));
  SetLength(lAlias, Length(aDecisions));
  lHasGuarded := False;
  for i := 0 to High(aDecisions) do
  begin
    lAlias[i] := SameText(aDecisions[i].ReceiverIdentity.Kind, 'type-alias');
    lGuarded[i] := (not DecisionKeepsWithMemberScope(aDecisions[i])) and
      (not aDecisions[i].RetainedIdenticalStorageProved) and
      (lAlias[i] or
      aFacts.LookupIndex.ReceiverLineageHasUnindexedRoot(aDecisions[i].ReceiverIdentity));
    if lGuarded[i] then
    begin
      lHasGuarded := True;
      lWeak[i] := aFacts.LookupIndex.IsWeakProfileRecord(aDecisions[i].ReceiverIdentity);
    end;
  end;
  if not lHasGuarded then
    Exit;
  TDelphiSemanticCompilerProfileBuilder.CompatibilityRecordMemberNames('TSearchRec', lWitness);
  for j := 0 to lReferenceCount - 1 do
  begin
    if j < Length(aBodyFacts.BareReferences) then
    begin
      lReference := aBodyFacts.BareReferences[j];
      lQualifier := '';
    end else begin
      i := j - Length(aBodyFacts.BareReferences);
      lReference := aBodyFacts.QualifiedFallbacks[i].Reference;
      lQualifier := aBodyFacts.QualifiedFallbacks[i].QualifierText;
    end;
    lName := ReferenceLookupName(lReference.Name);
    if StartsText('&', lName) then
      Delete(lName, 1, 1);
    for i := High(aDecisions) downto 0 do
    begin
      if (lQualifier <> '') and SameText(lQualifier, aDecisions[i].QualifierText) then
        Break;
      if not lGuarded[i] then
        Continue;
      if lWeak[i] then
      begin
        if (Length(lWitness) > 0) and (not MatchText(lName, lWitness)) then
          Continue;
      end else if aFacts.LookupIndex.ReceiverMemberAbsenceProved(aSiteUnitName,
        aDecisions[i].ReceiverType, lName, aDecisions[i].ReceiverIdentity) or
        aFacts.LookupIndex.ReceiverMemberAbsenceProved(aSiteUnitName,
          'ds742-anonymous:' + aSiteUnitName + #31 + aDecisions[i].ReceiverType,
          'ds742-anonymous-member:' + lName, Default(TDelphiSemanticTypeIdentity)) then
        Continue;
      if lAlias[i] then
        aSafetyReason := 'ALIAS_RECEIVER_MEMBERS_UNVERIFIED'
      else
        aSafetyReason := 'OWNER_INHERITED_MEMBERS_UNVERIFIED';
      Exit(True);
    end;
  end;
end;

function BodyFactsQualifyReceiver(const aBodyFacts: TFinalReceiverBodyFacts;
  const aDecision: TFinalSelectorDecision): Boolean;
var
  lQualification: TFinalSelectorDecision;
begin
  Result := False;
  for lQualification in aBodyFacts.ValueQualifications do
    if SameText(lQualification.QualifierText, aDecision.QualifierText) and
      SameText(lQualification.ReceiverType, aDecision.ReceiverType) and
      SameText(lQualification.ReceiverIdentity.DeclaredId.Value, aDecision.ReceiverIdentity.DeclaredId.Value) then
      Exit(True);
end;

function BodyHasPartiallyVerifiedValueReceiver(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aNestedReplacements: TArray<TFinalNestedReplacement>;
  const aDecisions: TArray<TFinalSelectorDecision>;
  const aBodyRange: TDelphiSemanticRemoveWithSourceRange;
  const aLines: TArray<string>; const aBodyText, aLineBreak: string;
  const aBodyEdits: TArray<TFinalBodyEdit>; const aAnonymousTagNames: TArray<string>;
  const aAnonymousNames: TArray<TArray<string>>;
  const aLineCache: TDelphiSemanticSourceContextCache;
  out aBodyFacts: TFinalReceiverBodyFacts): Boolean;
var
  i: Integer;
  lEdit: TFinalBodyEdit;
  lFallback: TFinalQualifiedFallback;
  lNestedReplacement: TFinalNestedReplacement;
  lOffset: Integer;
  lQualifier: string;
  lReference: TDelphiSemanticBoundReference;
begin
  Result := False;
  aBodyFacts := Default(TFinalReceiverBodyFacts);
  // Child text replaces an entire span. Preserve the verified qualifications and
  // remaining bare references before that replacement hides their source edits.
  for lNestedReplacement in aNestedReplacements do
  begin
    aBodyFacts.StrategyKindContradiction := aBodyFacts.StrategyKindContradiction or
      lNestedReplacement.ReceiverBodyFacts.StrategyKindContradiction;
    aBodyFacts.ValueQualifications := aBodyFacts.ValueQualifications +
      lNestedReplacement.ReceiverBodyFacts.ValueQualifications;
    aBodyFacts.BareReferences := aBodyFacts.BareReferences +
      lNestedReplacement.ReceiverBodyFacts.BareReferences;
  end;
  for lReference in aBinding.References do
  begin
    if (not ReferenceInsideRange(lReference, aBodyRange)) or
      ReferenceAppearsQualified(lReference, aBinding, aLineCache) then
      Continue;
    lOffset := ReferenceRelativeOffset(aBodyRange, aLines, aBodyText, lReference, aLineBreak);
    if not BodyEditsQualifyReference(aBodyEdits, lOffset, lReference.Name) then
      Continue;
    if IsReceiverValueMemberReference(lReference) then
    begin
      if QualifierForReference(aFacts, aBinding, aDecisions, lReference, lQualifier) <>
        TFinalReferenceQualification.QualifiedMember then
        Continue;
    end else if MatchText(lReference.Name, aAnonymousTagNames) then
    begin
      // D3 keeps an inventory qualification only with anonymous-tag evidence.
      lQualifier := '';
      for lEdit in aBodyEdits do
        if (lEdit.Offset = lOffset) and SameText(lEdit.ExpectedText, lReference.Name) then
          for i := 0 to High(aDecisions) do
            if SameText(lEdit.ReplacementText,
              aDecisions[i].QualifierText + '.' + lReference.Name) then
              lQualifier := aDecisions[i].QualifierText;
      if lQualifier = '' then
        Continue;
    end else
      Continue;
    for i := 0 to High(aDecisions) do
      if SameText(aDecisions[i].QualifierText, lQualifier) then
      begin
        if not BodyFactsQualifyReceiver(aBodyFacts, aDecisions[i]) then
          aBodyFacts.ValueQualifications := aBodyFacts.ValueQualifications + [aDecisions[i]];
      end;
  end;
  for lReference in aBinding.References do
  begin
    // Bare references matter only when indexed lineage cannot prove absence.
    // An unindexed class root alone retains base handling (DS-731 M3).
    if not MatchText(lReference.Classification, ['unsupported', 'unresolved', 'lexical', 'ambiguous']) then
      Continue;
    // Native lexical binding follows verified absence on every receiver. A
    // syntax-only lexical claim has no such provenance and still needs the guard.
    if SameText(lReference.Classification, 'lexical') and
      SameText(lReference.LookupSource, 'lexical') and (lReference.ReasonCode = '') then
      Continue;
    if (not ReferenceInsideRange(lReference, aBodyRange)) or
      ReferenceAppearsQualified(lReference, aBinding, aLineCache) then
      Continue;
    lOffset := ReferenceRelativeOffset(aBodyRange, aLines, aBodyText, lReference, aLineBreak);
    if BodyEditsQualifyReference(aBodyEdits, lOffset, lReference.Name) then
    begin
      lFallback := Default(TFinalQualifiedFallback);
      lFallback.Reference := lReference;
      for lEdit in aBodyEdits do
        if ((lEdit.Offset = lOffset) or ((lEdit.Offset = lOffset - 1) and
          StartsText('&', lEdit.ExpectedText))) and
          ((SameText(lEdit.ExpectedText, lReference.Name)) or
          SameText(lEdit.ExpectedText, '&' + lReference.Name)) then
          lFallback.QualifierText := lEdit.QualifierText;
      aBodyFacts.QualifiedFallbacks := aBodyFacts.QualifiedFallbacks + [lFallback];
      Continue;
    end;
    aBodyFacts.BareReferences := aBodyFacts.BareReferences + [lReference];
  end;
  if Length(aBodyFacts.ValueQualifications) = 0 then
    Exit;
  // Combine evidence across the whole receiver body, including sibling and
  // deeper child WITHs. Each child already excluded its own qualified tokens.
  for lReference in aBodyFacts.BareReferences do
  begin
    if not ReferenceInsideRange(lReference, aBodyRange) then
      Continue;
    for i := 0 to High(aDecisions) do
      if BodyFactsQualifyReceiver(aBodyFacts, aDecisions[i]) and
        ((lReference.ReceiverTypeName = '') or
        SameText(lReference.ReceiverTypeName, aDecisions[i].ReceiverType)) and
        // A complete anonymous record has no ancestors. The declaration-wide
        // identifier census contains every field, tag and constant, plus a
        // conservative superset of type/label names; it proves absence only.
        (MatchText('*', aAnonymousNames[i]) or
          MatchText(lReference.Name, aAnonymousNames[i])) and
        aFacts.LookupIndex.UnverifiedReceiverMemberMayApply(aDecisions[i].ReceiverType,
          lReference.Name, aDecisions[i].ReceiverIdentity) then
        Exit(True);
  end;
end;

function PrepareFinalBodyText(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aEditDecisions, aValidationDecisions: TArray<TFinalSelectorDecision>;
  const aNestedReplacements: TArray<TFinalNestedReplacement>;
  const aLineCache: TDelphiSemanticSourceContextCache;
  const aPreserveLeadingIndent: Boolean; out aReplacementText, aReason: string;
  out aBodyFacts: TFinalReceiverBodyFacts): Boolean;
var
  lAnonymousTagNames, lQualifiedFieldTags: TArray<string>;
  lAnonymousNames: TArray<TArray<string>>;
  lBodyEdits: TArray<TFinalBodyEdit>;
  lProtectedSpans: TArray<TFinalBodyEdit>;
  lReferenceRefusals: TArray<TFinalReferenceRefusal>;
  lRefusal: TFinalReferenceRefusal;
  lDeclarations: TArray<Boolean>;
  lDecision: TFinalSelectorDecision;
  lBodyRange: TDelphiSemanticRemoveWithSourceRange;
  lBodyStartsWithBegin, lRootAbsenceProved: Boolean;
  lLineBreak: string;
  lLines: TArray<string>;
  lNestedRange: TDelphiSemanticRemoveWithSourceRange;
  lNestedReplacement: TFinalNestedReplacement;
  lOffset: Integer;
  lQualification: TFinalReferenceQualification;
  lQualifierText: string;
  lReference: TDelphiSemanticBoundReference;
  lReferenceName: string;
  lSourceReference: TDelphiSemanticBoundReference;
begin
  Result := False;
  aReason := '';
  lBodyRange := BindingBodyRange(aBinding);
  TrimRangeBeforeOuterElse(aBinding, aLineCache, lBodyRange);
  aReplacementText := SourceTextForRange(aBinding.FileName, lBodyRange, aLineCache);
  if aReplacementText = '' then
  begin
    aReason := 'body-range-not-resolved';
    Exit;
  end;
  if not aLineCache.TryGetValue(aBinding.FileName, lLines) then
  begin
    aReason := 'body-range-not-resolved';
    Exit;
  end;
  lBodyStartsWithBegin := (aBinding.Line > 0) and
    (aBinding.Line < Length(lLines)) and SameText(Trim(lLines[aBinding.Line]),
    'begin');
  lLineBreak := SourceLineBreakForFile(aBinding.FileName, aLineCache);
  if BodyHasUnverifiedEscapedIdentifier(aReplacementText, aBinding, lBodyRange,
    lLines, lLineBreak) then
  begin
    aReason := 'escaped-identifier-unsupported';
    Exit;
  end;
  // Dependent selector replacement needs a separate escaped-origin proof.
  for lDecision in aEditDecisions do
    if SameText(lDecision.Reason, 'dependent-selector-direct-qualification') and
      BodyHasEscapedIdentifier(aReplacementText) then
    begin
      aReason := 'escaped-identifier-unsupported';
      Exit;
    end;
  for lNestedReplacement in aNestedReplacements do
  begin
    lNestedRange := lNestedReplacement.Range;
    if lBodyStartsWithBegin then
      lNestedRange.StartColumn := 1;
    lOffset := RangeRelativeOffset(lBodyRange, lLines, lNestedRange.StartLine,
      lNestedRange.StartColumn, lLineBreak);
    AddFinalBodyEdit(lBodyEdits, lOffset,
      Length(SourceTextForRange(aBinding.FileName, lNestedRange, aLineCache)),
      SourceTextForRange(aBinding.FileName, lNestedRange, aLineCache),
      lNestedReplacement.ReplacementText);
  end;

  // D5: retain a reference's denial before any fallback body scan can qualify it.
  for lReference in aBinding.References do
    if ReferenceInsideRange(lReference, lBodyRange) and
      ReferenceHasLineageDenial(aFacts, aEditDecisions, lReference) then
    begin
      lRefusal.Offset := RangeRelativeOffset(lBodyRange, lLines,
        lReference.Line, lReference.Column, lLineBreak);
      lRefusal.Length := Length(lReference.Name);
      lRefusal.Reason := lReference.ReasonCode;
      aBodyFacts.LineageDenialReason := lRefusal.Reason;
      lReferenceRefusals := lReferenceRefusals + [lRefusal];
    end;

  lDeclarations := BodyNonReferencePositions(aReplacementText, False);
  // Seed identity edits so fallback member scans cannot rewrite proven label tokens.
  for lReference in aBinding.References do
    if (lReference.LookupSource = 'syntax') and
      MatchText(lReference.Kind, ['label', 'goto-keyword']) and
      ReferenceInsideRange(lReference, lBodyRange) then
    begin
      lOffset := RangeRelativeOffset(lBodyRange, lLines, lReference.Line,
        lReference.Column, lLineBreak);
      if not BodyTextIdentifierAt(aReplacementText, lReference.Name, lOffset) then
      begin
        aReason := 'label-source-range-not-resolved';
        Exit;
      end;
      lReferenceName := Copy(aReplacementText, lOffset, Length(lReference.Name));
      AddFinalBodyEdit(lProtectedSpans, lOffset, Length(lReferenceName),
        lReferenceName, lReferenceName);
      AddFinalBodyEdit(lBodyEdits, lOffset, Length(lReferenceName),
        lReferenceName, lReferenceName);
    end;
  for lReference in aBinding.References do
  begin
    if not ReferenceInsideRange(lReference, lBodyRange) then
      Continue;
    lOffset := RangeRelativeOffset(lBodyRange, lLines, lReference.Line,
      lReference.Column, lLineBreak);
    if BodyOffsetIsDeclaration(lDeclarations, lOffset) then
      Continue;
    if (lReference.LookupSource = 'syntax') and
      MatchText(lReference.Kind, ['label', 'goto-keyword']) then
      Continue;
    if ReferenceBlocksFinalRewrite(aFacts, aBinding, aEditDecisions, lReference,
      aLineCache, aReason) then
      Exit;
    if ReferenceLineHasConditionalDirective(aBinding, lReference, aLineCache) or
      ReferenceInsideInactiveNeverConditionalRegion(aBinding, lReference,
      aLineCache) then
      Continue;
    if (not ActiveDecisionHasMember(aFacts, aEditDecisions, lReference.Name)) and
      ReferenceIsInlineLocalDeclaredInBinding(aBinding, lReference, aLineCache) then
      Continue;
    if ReferenceAppearsQualified(lReference, aBinding, aLineCache) then
      Continue;
    if (not IsReceiverValueMemberReference(lReference)) and
      (not IsBinderReceiverMemberReference(lReference)) and
      ReferenceShouldRemainUnchanged(aFacts, aBinding, lReference) then
    begin
      if SameText(lReference.Kind, 'routine') or
        (not ActiveDecisionHasMember(aFacts, aEditDecisions, lReference.Name)) then
        Continue;
    end;
    lSourceReference := lReference;
    // The new local-record barrier names its receiver for evidence, not as
    // proof that this missing name is a member. Keep the ordinary miss path.
    if ReferenceWasRoutineLocalRecordActivityMiss(aBinding, lReference) then
      lSourceReference.ReceiverTypeName := '';
    lQualification := QualifierForReference(aFacts, aBinding, aEditDecisions,
      lSourceReference, lQualifierText);
    if lQualification = TFinalReferenceQualification.RetainedMember then
      Continue;
    if lQualification = TFinalReferenceQualification.NoMatch then
    begin
      if IsBinderReceiverMemberReference(lReference) then
      begin
        aReason := 'receiver-member-unqualified';
        Exit;
      end;
      if HasHiddenUnresolvedPointerSelectorDecision(aEditDecisions,
        aValidationDecisions) and
        (not ReferenceCanRemainUnchanged(aFacts, aBinding, lReference)) and
        (not ReferenceLooksLikeLocalLabel(aBinding, lReference, aLineCache)) and
        (not ReferenceAppearsQualified(lReference, aBinding, aLineCache)) then
      begin
        aReason := 'semantic-rewrite-incomplete';
        Exit;
      end;
      if SameText(lReference.Classification, 'unresolved') or
        ReferenceWasRoutineLocalRecordActivityMiss(aBinding, lReference) then
      begin
        if ReferenceHasKnownRoutineSymbol(aFacts, lReference) or
          ReferenceIsKnownTypeName(aFacts, lReference) or
          ReferenceLooksLikeLocalLabel(aBinding, lReference, aLineCache) or
          ReferenceAppearsQualified(lReference, aBinding, aLineCache) then
          Continue;
        if ReferenceCanRemainUnchanged(aFacts, aBinding, lReference) then
          Continue;
        // DS-742: an unresolved SDK name may remain bare only after the binder
        // recorded this site's root absence. Indexed-record absence alone is
        // deliberately insufficient. The final reverse guard checks all receivers.
        lRootAbsenceProved := False;
        if SameText(lReference.Classification, 'unresolved') and
          SameText(lReference.ReasonCode, 'NAME_NOT_FOUND') and
          IsSimpleIdentifier(lReference.Name) then
          for lDecision in aEditDecisions do
            if aFacts.LookupIndex.ReceiverLineageHasUnindexedRoot(lDecision.ReceiverIdentity) and
              aFacts.LookupIndex.ReceiverMemberAbsenceProved(aBinding.UnitName,
                lDecision.ReceiverType, lReference.Name, lDecision.ReceiverIdentity) then
              lRootAbsenceProved := True;
        if lRootAbsenceProved then
          Continue;
        aReason := ReceiverMemberMissReason(lReference, aBinding, aLineCache);
        Exit;
      end;
      Continue;
    end;
    lOffset := ReferenceRelativeOffset(lBodyRange, lLines, aReplacementText,
      lReference, lLineBreak);
    if lOffset <= 0 then
    begin
      if ReferenceHasQualifiedOccurrenceNearReference(lBodyRange, lLines,
        aReplacementText, lReference, lLineBreak) then
        Continue;
      aReason := 'reference-offset-not-resolved';
      Exit;
    end;
    if (BodyOffsetInsideTextOccurrence(aReplacementText, aBinding.SelectorText,
      lOffset) and (not SimpleSelectorHasMember(aFacts, aBinding,
      aEditDecisions, lReference.Name))) or
      BodyOffsetHasTextQualifier(aReplacementText, aBinding.SelectorText, lOffset) then
      Continue;
    if BodyEditOffsetUsed(lBodyEdits, lOffset, lReference.Name) then
    begin
      lOffset := ReferenceUnusedLineOccurrenceRelativeOffset(lBodyRange, lLines,
        aReplacementText, lReference, lReference.Line, lLineBreak, lBodyEdits);
      if (lOffset <= 0) and (lReference.Line > lBodyRange.StartLine) then
        lOffset := ReferenceUnusedLineOccurrenceRelativeOffset(lBodyRange, lLines,
          aReplacementText, lReference, lReference.Line - 1, lLineBreak,
          lBodyEdits);
      if lOffset <= 0 then
        Continue;
    end;
    // Cached binding names may have another occurrence's casing. Keep this source spelling
    // for replacement text and the exact edit guard after case-insensitive lookup (T-350).
    lSourceReference := lReference;
    lSourceReference.Name := Copy(aReplacementText, lOffset, Length(lReference.Name));
    lReferenceName := ReferenceNameWithQualifiedArguments(aFacts, aEditDecisions, lSourceReference);
    if not AddQualifiedBodyEdit(lBodyEdits, aReplacementText, lOffset, Length(lReference.Name),
      lSourceReference.Name, lQualifierText, lReferenceName, lReferenceRefusals, aReason) then
      Exit;
  end;
  AddSimpleMemberBodyEdits(aFacts, aBinding, aEditDecisions, aReplacementText,
    lDeclarations, lReferenceRefusals, lBodyEdits, aReason);
  if aReason <> '' then
    Exit;
  AddIndexedMemberBodyEdits(aFacts, aBinding, aEditDecisions, aReplacementText,
    lDeclarations, lReferenceRefusals, lBodyEdits, aReason);
  if aReason <> '' then
    Exit;
  AddDependentSelectorBodyEdits(aEditDecisions, aReplacementText, lReferenceRefusals,
    lBodyEdits, aReason);
  if aReason <> '' then
    Exit;
  if BodyEditsQualifyNonMemberReference(aFacts, aEditDecisions, lBodyEdits, aBinding, aReplacementText,
    lBodyRange.StartLine) then
  begin
    aReason := 'receiver-member-owner-conflict';
    Exit;
  end;
  // A value member must have an actual source edit, not just a successful name lookup.
  // Scan each anonymous declaration once per body, rather than per reference.
  lAnonymousTagNames := AnonymousRecordTagNames(aFacts, aEditDecisions, aLineCache,
    lQualifiedFieldTags, lAnonymousNames);
  for lReference in aBinding.References do
  begin
    if (not ReferenceInsideRange(lReference, lBodyRange)) or
      ReferenceAppearsQualified(lReference, aBinding, aLineCache) then
      Continue;
    if IsReceiverValueMemberReference(lReference) then
    begin
      lQualification := QualifierForReference(aFacts, aBinding, aEditDecisions,
        lReference, lQualifierText);
      if lQualification = TFinalReferenceQualification.RetainedMember then
        Continue;
      lOffset := ReferenceRelativeOffset(lBodyRange, lLines, aReplacementText, lReference,
        lLineBreak);
      if (lQualification <> TFinalReferenceQualification.QualifiedMember) or
        (not BodyEditsQualifyReference(lBodyEdits, lOffset, lReference.Name)) then
      begin
        aReason := 'receiver-member-unqualified';
        Exit;
      end;
    end;
    // A named declaration or selector DeclaredId alone is not value-member coverage.
    // Verified member/helper references keep their path. A bare unverified name
    // needs collision evidence from the receiver/alias chain, or the project set
    // when that chain cannot be verified (including indexed receiver fallbacks).
    if MatchText(lReference.Classification, ['lexical', 'unresolved', 'unsupported']) then
    begin
      lOffset := ReferenceRelativeOffset(lBodyRange, lLines, aReplacementText, lReference,
        lLineBreak);
      if not BodyEditsQualifyReference(lBodyEdits, lOffset, lReference.Name) then
        for lDecision in aEditDecisions do
          if (TypeIdentityHasVerifiedOrigin(lDecision.ReceiverIdentity) or
            PlannerResolvesNamedReceiverType(aFacts, lDecision.ReceiverType, aLineCache)) and
            aFacts.LookupIndex.UnverifiedValueMemberMayApply(lDecision.ReceiverType,
              lReference.Name, lDecision.ReceiverIdentity) then
          begin
            aReason := 'TYPE_VALUE_MEMBERS_UNVERIFIED';
            Exit;
          end;
    end;
    if MatchText(lReference.Classification, ['lexical', 'unresolved', 'unsupported']) and
      (MatchText('*', lAnonymousTagNames) or
        MatchText(lReference.Name, lAnonymousTagNames)) then
    begin
      // DS-731 option (b): preserve inventory-qualified no-homonym plans (num_rec),
      // but never emit a bare lexical/global homonym of an anonymous-record tag.
      // An anchored field receiver may already have its exact tag qualification.
      lOffset := ReferenceRelativeOffset(lBodyRange, lLines, aReplacementText, lReference,
        lLineBreak);
      lQualifierText := '';
      for var lEdit in lBodyEdits do
        if (lEdit.Offset = lOffset) and SameText(lEdit.ExpectedText, lReference.Name) then
          lQualifierText := lEdit.ReplacementText;
      if MatchText('*', lAnonymousTagNames) or
        (ReferenceShouldRemainUnchanged(aFacts, aBinding, lReference) and
          (not MatchText(lQualifierText, lQualifiedFieldTags))) or
        (not BodyEditsQualifyReference(lBodyEdits, lOffset, lReference.Name)) then
      begin
        aReason := 'TYPE_VALUE_MEMBERS_UNVERIFIED';
        Exit;
      end;
    end;
  end;
  if BodyHasPartiallyVerifiedValueReceiver(aFacts, aBinding, aNestedReplacements, aEditDecisions,
    lBodyRange, lLines, aReplacementText, lLineBreak, lBodyEdits, lAnonymousTagNames,
    lAnonymousNames, aLineCache, aBodyFacts) then
  begin
    aReason := 'RECEIVER_MEMBERS_PARTIALLY_VERIFIED';
    Exit;
  end;
  if not ApplyFinalBodyEdits(lBodyEdits, lProtectedSpans, aReplacementText) then
  begin
    aReason := 'label-source-range-overlap';
    Exit;
  end;
  if FinalBodyHasIncompleteReceiverReference(aFacts, aBinding, aValidationDecisions,
    aLineCache, lBodyRange, aReplacementText, lProtectedSpans) then
  begin
    aReason := 'semantic-rewrite-incomplete';
    Exit;
  end;
  while StartsText(lLineBreak, aReplacementText) do
    Delete(aReplacementText, 1, Length(lLineBreak));
  while StartsText(#13, aReplacementText) or StartsText(#10, aReplacementText) do
    Delete(aReplacementText, 1, 1);
  if (not aPreserveLeadingIndent) and
    StartsText(IndentText(aBinding.Column), aReplacementText) then
    Delete(aReplacementText, 1, Length(IndentText(aBinding.Column)));

  Result := True;
end;

function RendererRange(const aRange: TDelphiSemanticRemoveWithSourceRange):
  TFinalBodyRendererRange;
begin
  Result.StartLine := aRange.StartLine;
  Result.StartColumn := aRange.StartColumn;
  Result.EndLine := aRange.EndLine;
  Result.EndColumn := aRange.EndColumn;
end;

function PlannerRange(const aRange: TFinalBodyRendererRange):
  TDelphiSemanticRemoveWithSourceRange;
begin
  Result.StartLine := aRange.StartLine;
  Result.StartColumn := aRange.StartColumn;
  Result.EndLine := aRange.EndLine;
  Result.EndColumn := aRange.EndColumn;
end;

function RendererSelectorDecision(const aDecision: TFinalSelectorDecision):
  TFinalBodyRendererSelectorDecision;
begin
  Result.SelectorText := aDecision.SelectorText;
  Result.QualifierText := aDecision.QualifierText;
  Result.Strategy := aDecision.Strategy;
  Result.ReceiverType := aDecision.ReceiverType;
  Result.TempName := aDecision.TempName;
  Result.DeclarationText := aDecision.DeclarationText;
  Result.InitializationText := aDecision.InitializationText;
  Result.Reason := aDecision.Reason;
end;

function RendererSelectorDecisions(const aDecisions: TArray<TFinalSelectorDecision>):
  TArray<TFinalBodyRendererSelectorDecision>;
var
  i: Integer;
begin
  SetLength(Result, Length(aDecisions));
  for i := 0 to High(aDecisions) do
    Result[i] := RendererSelectorDecision(aDecisions[i]);
end;

function HasRecordPointerTempDecision(const aDecisions: TArray<TFinalSelectorDecision>): Boolean;
var
  lDecision: TFinalSelectorDecision;
begin
  Result := False;
  for lDecision in aDecisions do
  begin
    if SameText(lDecision.Strategy, 'record-pointer-temp') then
      Exit(True);
  end;
end;

function RoutineDeclarationIsProcedure(const aBinding: TDelphiSemanticWithBinding;
  const aLineCache: TDelphiSemanticSourceContextCache): Boolean;
var
  lLineIndex: Integer;
  lLines: TArray<string>;
  lText: string;
begin
  Result := False;
  if (Trim(aBinding.RoutineName) = '') or
    (not aLineCache.TryGetValue(aBinding.FileName, lLines)) then
    Exit;

  for lLineIndex := aBinding.Line downto 1 do
  begin
    lText := LowerCase(Trim(lLines[lLineIndex - 1]));
    if not ContainsText(lText, aBinding.RoutineName) then
      Continue;
    if StartsText('procedure ', lText) or StartsText('class procedure ', lText) then
      Exit(True);
    if StartsText('function ', lText) or StartsText('class function ', lText) or
      StartsText('constructor ', lText) or StartsText('destructor ', lText) then
      Exit(False);
  end;
end;

function RoutineLocalArrayReferenceNeedsSkip(
  const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aTempDecisions: TArray<TFinalSelectorDecision>): Boolean;
var
  lBodyRange: TDelphiSemanticRemoveWithSourceRange;
  lReference: TDelphiSemanticBoundReference;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  if not HasRecordPointerTempDecision(aTempDecisions) then
    Exit;

  lBodyRange := BindingBodyRange(aBinding);
  for lReference in aBinding.References do
  begin
    if (not ReferenceInsideRange(lReference, lBodyRange)) or
      (not SameText(lReference.Classification, 'lexical')) then
      Continue;
    if not aFacts.LookupIndex.FindRoutineSymbol(aBinding.RoutineName,
      lReference.Name, lSymbol) then
      Continue;
    if SameText(lSymbol.SymbolClass, 'local') and SameText(lSymbol.Kind, 'var') and
      StartsText('array ', Trim(LowerCase(lSymbol.TypeName))) then
      Exit(True);
  end;
end;

function SelectorBaseRoutineLocalArrayTypeName(
  const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aSelectorText: string):
  string;
var
  lBaseName: string;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := '';
  lBaseName := SelectorBaseIdentifier(aSelectorText);
  if lBaseName = '' then
    Exit;
  if not aFacts.LookupIndex.FindRoutineSymbol(aBinding.RoutineName, lBaseName,
    lSymbol) then
    Exit;
  if SameText(lSymbol.SymbolClass, 'local') and SameText(lSymbol.Kind, 'var') and
    StartsText('array ', Trim(LowerCase(lSymbol.TypeName))) then
    Result := lSymbol.TypeName;
end;

function SelectorBaseIsRoutineLocalArray(
  const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aSelectorText: string):
  Boolean;
begin
  Result := SelectorBaseRoutineLocalArrayTypeName(aFacts, aBinding,
    aSelectorText) <> '';
end;

function RoutineLocalArraySelectorCanUsePointerTemp(
  const aFacts: TRemoveWithPlanFacts; const aDecision: TFinalSelectorDecision;
  const aArrayTypeName: string): Boolean;
var
  lArrayTypeName: string;
begin
  lArrayTypeName := Trim(LowerCase(aArrayTypeName));
  Result := SameText(aDecision.Strategy, 'record-pointer-temp') and
    (Trim(aDecision.TempName) <> '') and
    (Trim(aDecision.InitializationText) <> '') and
    StartsText('array [', lArrayTypeName) and
    TypeIsRecordLike(aFacts, aDecision.ReceiverType);
end;

function RoutineLocalArraySelectorNeedsSkip(
  const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aTempDecisions: TArray<TFinalSelectorDecision>): Boolean;
var
  lArrayTypeName: string;
  lDecision: TFinalSelectorDecision;
begin
  Result := False;
  if not HasRecordPointerTempDecision(aTempDecisions) then
    Exit;
  for lDecision in aTempDecisions do
  begin
    lArrayTypeName := SelectorBaseRoutineLocalArrayTypeName(aFacts, aBinding,
      lDecision.SelectorText);
    if (lArrayTypeName <> '') and
      (not RoutineLocalArraySelectorCanUsePointerTemp(aFacts, lDecision,
      lArrayTypeName)) then
      Exit(True);
  end;
end;

function RoutineDeclarationIsMethod(const aBinding: TDelphiSemanticWithBinding;
  const aLineCache: TDelphiSemanticSourceContextCache): Boolean;
var
  lDeclarationName: string;
  lLineIndex: Integer;
  lLines: TArray<string>;
  lNameLength: Integer;
  lRoutineName: string;
  lText: string;
begin
  Result := False;
  lRoutineName := LowerCase(RoutineLeafName(aBinding.RoutineName));
  if (lRoutineName = '') or (not aLineCache.TryGetValue(aBinding.FileName,
    lLines)) then
    Exit;

  for lLineIndex := aBinding.Line downto 1 do
  begin
    lText := LowerCase(Trim(lLines[lLineIndex - 1]));
    if not ContainsText(lText, lRoutineName) then
      Continue;
    lDeclarationName := '';
    if StartsText('class procedure ', lText) then
      lDeclarationName := Trim(Copy(lText, Length('class procedure ') + 1,
        MaxInt))
    else if StartsText('procedure ', lText) then
      lDeclarationName := Trim(Copy(lText, Length('procedure ') + 1, MaxInt))
    else if StartsText('class function ', lText) then
      lDeclarationName := Trim(Copy(lText, Length('class function ') + 1,
        MaxInt))
    else if StartsText('function ', lText) then
      lDeclarationName := Trim(Copy(lText, Length('function ') + 1, MaxInt))
    else if StartsText('constructor ', lText) then
      lDeclarationName := Trim(Copy(lText, Length('constructor ') + 1, MaxInt))
    else if StartsText('destructor ', lText) then
      lDeclarationName := Trim(Copy(lText, Length('destructor ') + 1, MaxInt));
    if lDeclarationName = '' then
      Continue;
    lNameLength := 0;
    while (lNameLength < Length(lDeclarationName)) and
      (IsIdentifierChar(lDeclarationName[lNameLength + 1]) or
      (lDeclarationName[lNameLength + 1] = '.')) do
      Inc(lNameLength);
    lDeclarationName := Copy(lDeclarationName, 1, lNameLength);
    // Match the declared name, not an occurrence of the method name inside its owner.
    if Pos('.', aBinding.RoutineName) > 0 then
    begin
      if not SameText(lDeclarationName, aBinding.RoutineName) then
        Continue;
    end else if not SameText(RoutineLeafName(lDeclarationName), lRoutineName) then
      Continue;
    Exit(Pos('.', lDeclarationName) > 0);
  end;
end;

function HasIndexedPointerDirectDecision(
  const aDecisions: TArray<TFinalSelectorDecision>): Boolean;
var
  lDecision: TFinalSelectorDecision;
begin
  Result := False;
  for lDecision in aDecisions do
  begin
    if SameText(lDecision.Strategy, 'direct-qualification') then
      Exit(True);
  end;
end;

function TryRenderFinalReplacementText(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aVisibleDecisions, aValidationDecisions,
  aTempDecisions: TArray<TFinalSelectorDecision>;
  const aNestedReplacements: TArray<TFinalNestedReplacement>;
  const aLineCache: TDelphiSemanticSourceContextCache; out aReplacementText,
  aReason: string; out aReplacementRange: TDelphiSemanticRemoveWithSourceRange;
  out aBodyFacts: TFinalReceiverBodyFacts): Boolean;
var
  lBodyText: string;
  lControlledStatement: Boolean;
  lOriginalRange: TDelphiSemanticRemoveWithSourceRange;
  lRendererRange: TFinalBodyRendererRange;
  lRequest: TFinalBodyRendererRequest;
  lTrimmedBeforeOuterElse: Boolean;
begin
  Result := False;
  aReplacementRange := BindingRange(aBinding);
  lOriginalRange := aReplacementRange;
  if RoutineLocalArrayReferenceNeedsSkip(aFacts, aBinding, aTempDecisions) then
  begin
    aReason := 'symbol-not-found';
    Exit;
  end;
  if RoutineLocalArraySelectorNeedsSkip(aFacts, aBinding, aTempDecisions) then
  begin
    aReason := 'symbol-not-found';
    Exit;
  end;
  lControlledStatement := BindingFollowsControlStatement(aBinding, aLineCache);
  lTrimmedBeforeOuterElse := TrimRangeBeforeOuterElse(aBinding, aLineCache,
    aReplacementRange);
  if (not lTrimmedBeforeOuterElse) and
    RangeIsFollowedByOuterElse(aBinding, aLineCache, aReplacementRange) then
    lTrimmedBeforeOuterElse := True;
  if not PrepareFinalBodyText(aFacts, aBinding, aVisibleDecisions,
    aValidationDecisions, aNestedReplacements, aLineCache, lControlledStatement,
    lBodyText, aReason, aBodyFacts) then
  begin
    Exit;
  end;

  lRequest := Default(TFinalBodyRendererRequest);
  lRequest.Binding := aBinding;
  lRequest.BodyText := lBodyText;
  lRequest.OriginalRange := RendererRange(lOriginalRange);
  lRequest.ReplacementRange := RendererRange(aReplacementRange);
  lRequest.TempDecisions := RendererSelectorDecisions(aTempDecisions);
  lRequest.ControlledStatement := lControlledStatement;
  lRequest.TrimmedBeforeOuterElse := lTrimmedBeforeOuterElse;
  lRequest.UseArchitectureStableRoutineEndTrim :=
    aFacts.UseArchitectureStableRoutineEndTrim;
  Result := DelphiSemantics.RemoveWithPlan.FinalBodyRenderer.BuildFinalReplacementText(
    lRequest, aLineCache, aReplacementText, lRendererRange, aReason);
  aReplacementRange := PlannerRange(lRendererRange);
end;

function ReplacementRangeCoversExpectedWithRange(
  const aBinding: TDelphiSemanticWithBinding;
  const aReplacementRange: TDelphiSemanticRemoveWithSourceRange;
  const aLineCache: TDelphiSemanticSourceContextCache): Boolean;
var
  lExpectedRange: TDelphiSemanticRemoveWithSourceRange;
begin
  lExpectedRange := BindingRange(aBinding);
  TrimRangeBeforeOuterElse(aBinding, aLineCache, lExpectedRange);
  Result := ((aReplacementRange.StartLine < lExpectedRange.StartLine) or
    ((aReplacementRange.StartLine = lExpectedRange.StartLine) and
    (aReplacementRange.StartColumn <= lExpectedRange.StartColumn))) and
    ((aReplacementRange.EndLine > lExpectedRange.EndLine) or
    ((aReplacementRange.EndLine = lExpectedRange.EndLine) and
    (aReplacementRange.EndColumn >= lExpectedRange.EndColumn)));
end;

function FinalVerification(const aEdit: TDelphiSemanticRemoveWithEdit):
  TDelphiSemanticRemoveWithSourceVerification;
begin
  Result.ExpectedFileHash := aEdit.ExpectedFileHash;
  Result.ExpectedSourceText := aEdit.ExpectedSourceText;
  Result.Range := aEdit.Range;
end;

function FinalTempDecision(const aDecision: TFinalSelectorDecision;
  const aSemanticId: string): TDelphiSemanticRemoveWithFinalTempDecision;
begin
  Result := Default(TDelphiSemanticRemoveWithFinalTempDecision);
  Result.SelectorText := aDecision.SelectorText;
  Result.QualifierText := aDecision.QualifierText;
  Result.Strategy := aDecision.Strategy;
  Result.ReceiverType := aDecision.ReceiverType;
  Result.TempName := aDecision.TempName;
  Result.DeclarationText := aDecision.DeclarationText;
  Result.InitializationText := aDecision.InitializationText;
  Result.Reason := aDecision.Reason;
  Result.SemanticId := aSemanticId;
end;

function FinalRewriteDecisionInputs(const aDecisions: TArray<TFinalSelectorDecision>;
  const aSemanticId: string):
  TArray<TDelphiSemanticRemoveWithFinalRewriteSelectorDecisionInput>;
var
  i: Integer;
begin
  SetLength(Result, Length(aDecisions));
  for i := 0 to High(aDecisions) do
  begin
    Result[i].SelectorText := aDecisions[i].SelectorText;
    Result[i].QualifierText := aDecisions[i].QualifierText;
    Result[i].Strategy := aDecisions[i].Strategy;
    Result[i].ReceiverType := aDecisions[i].ReceiverType;
    Result[i].TempName := aDecisions[i].TempName;
    Result[i].DeclarationText := aDecisions[i].DeclarationText;
    Result[i].InitializationText := aDecisions[i].InitializationText;
    Result[i].Reason := aDecisions[i].Reason;
    Result[i].SemanticId := aSemanticId;
  end;
end;

function HasFinalTextEditKind(const aStatement:
  TDelphiSemanticRemoveWithFinalStatement; const aKind: string): Boolean;
var
  lEdit: TDelphiSemanticRemoveWithFinalTextEdit;
begin
  Result := False;
  for lEdit in aStatement.Edits do
    if SameText(lEdit.Kind, aKind) then
      Exit(True);
end;

procedure AddFinalStatement(var aPlan: TDelphiSemanticRemoveWithPlan;
  const aStatement: TDelphiSemanticRemoveWithFinalStatement);
var
  lIndex: Integer;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lStatement := aStatement;
  EnsureFinalStatementRewriteRecipe(lStatement);
  lIndex := Length(aPlan.FinalStatements);
  SetLength(aPlan.FinalStatements, lIndex + 1);
  aPlan.FinalStatements[lIndex] := lStatement;
end;

function BuildSkippedFinalStatement(const aBinding: TDelphiSemanticWithBinding;
  const aStatementId, aReason, aSafetyReason: string):
  TDelphiSemanticRemoveWithFinalStatement;
begin
  Result := Default(TDelphiSemanticRemoveWithFinalStatement);
  Result.FileName := aBinding.FileName;
  Result.StatementId := aStatementId;
  Result.SemanticId := aBinding.SemanticId;
  Result.RoutineName := aBinding.RoutineName;
  Result.Status := 'skipped';
  Result.Reason := aReason;
  Result.SafetyReason := aSafetyReason;
  Result.Range := BindingRange(aBinding);
end;

function BindingSkipReason(const aBinding: TDelphiSemanticWithBinding): string;
begin
  if SameText(aBinding.SkipReason, 'UNRESOLVED_REFERENCE') then
    Result := 'symbol-not-found'
  else if SameText(aBinding.SkipReason, 'UNSUPPORTED_REFERENCE') then
    Result := 'unsupported-reference'
  else if SameText(aBinding.SkipReason, 'SCOPED_DECLARATION') then
    Result := 'scoped-declaration'
  else if aBinding.SkipReason <> '' then
    Result := LowerCase(StringReplace(aBinding.SkipReason, '_', '-', [rfReplaceAll]))
  else
    Result := 'semantic-binding-skipped';
end;

function ControlContextTokens(const aFacts: TRemoveWithPlanFacts;
  const aFileName: string): TArray<TControlContextToken>;
var
  lLexer: TmwBasePasLex;
  lNextOffset: Integer;
  lSource: string;
  lToken: TControlContextToken;
  lTokens: TList<TControlContextToken>;
begin
  if aFacts.ControlTokens.TryGetValue(aFileName, Result) then
    Exit;
  Result := nil;
  if not aFacts.ControlSources.TryGetValue(aFileName, lSource) then
    Exit;
  lTokens := TList<TControlContextToken>.Create;
  lLexer := TmwBasePasLex.Create;
  try
    // Keep directives as barriers, including includes, without expanding them.
    // The lexer ignores directive-like text inside strings and plain comments.
    lLexer.UseDefines := False;
    lNextOffset := 0;
    lLexer.Origin := lSource;
    while lLexer.TokenID <> ptNull do
    begin
      // SimpleParser advances past brace includes inside Next, even with
      // UseDefines=False and no include handler. Its skipped source gap is a
      // directive barrier before the token it returns; no include is opened.
      if lLexer.TokenPos > lNextOffset then
      begin
        lToken.Kind := ptIncludeDirect;
        lToken.Line := lLexer.PosXY.Y;
        lToken.Column := lLexer.PosXY.X;
        lToken.IsDirective := True;
        lTokens.Add(lToken);
      end;
      lNextOffset := lLexer.TokenPos + Length(lLexer.Token);
      lToken.IsDirective := StartsText('{$', lLexer.Token) or
        StartsText('(*$', lLexer.Token);
      if (not lLexer.IsJunk) or lToken.IsDirective then
      begin
        lToken.Kind := lLexer.TokenID;
        lToken.Line := lLexer.PosXY.Y;
        lToken.Column := lLexer.PosXY.X;
        lTokens.Add(lToken);
      end;
      lLexer.Next;
    end;
    Result := lTokens.ToArray;
    aFacts.ControlTokens.Add(aFileName, Result);
  finally
    lLexer.Free;
    lTokens.Free;
  end;
end;

function FinalBindingNeedsControlWrapper(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aBindingSource: TRemoveWithPlanBindingSource;
  const aBindingTree: TFinalBindingTree; const aBindingIndex: Integer;
  const aInheritedDecisions: TArray<TFinalSelectorDecision>): Boolean;
var
  lFirst, lLast, lMiddle: Integer;
  lParent: TDelphiSemanticWithBinding;
  lToken: TControlContextToken;
  lTokens: TArray<TControlContextToken>;
begin
  // Unknown context still permits a safe single-statement replacement.
  Result := True;
  lTokens := ControlContextTokens(aFacts, aBinding.FileName);
  lFirst := 0;
  lLast := High(lTokens);
  // Locate this WITH in the one token table shared by every binding in its file.
  while lFirst <= lLast do
  begin
    lMiddle := lFirst + (lLast - lFirst) div 2;
    lToken := lTokens[lMiddle];
    if (lToken.Line < aBinding.Line) or
      ((lToken.Line = aBinding.Line) and (lToken.Column < aBinding.Column)) then
      lFirst := lMiddle + 1
    else
      lLast := lMiddle - 1;
  end;
  if (lFirst > High(lTokens)) or (lTokens[lFirst].Kind <> ptWith) or
    (lTokens[lFirst].Line <> aBinding.Line) or
    (lTokens[lFirst].Column <> aBinding.Column) then
    Exit;
  Dec(lFirst);
  // Whitespace and ordinary comments were discarded; a passed directive wraps.
  if lFirst < 0 then
    Exit(False);
  lToken := lTokens[lFirst];
  if lToken.IsDirective then
    Exit;
  if lToken.Kind in [ptSemiColon, ptBegin, ptRepeat, ptTry, ptExcept, ptFinally,
    ptInitialization, ptFinalization] then
    Result := False
  else if lToken.Kind = ptDo then
  begin
    if (aBindingTree.ParentIndexes[aBindingIndex] < 0) or
      (Length(aInheritedDecisions) = 0) then
      Exit;
    lParent := aBindingSource.BindingByIndex(aBindingTree.ParentIndexes[aBindingIndex]);
    // Only a direct child of an already planned parent is absorbed. A loop
    // or exception-handler DO inside the parent's body still controls it.
    if (lToken.Line < lParent.BodyLine) or
      ((lToken.Line = lParent.BodyLine) and
      (lToken.Column + 2 <= lParent.BodyColumn)) then
      Result := SameText(aInheritedDecisions[High(aInheritedDecisions)].Reason,
        'skipped-parent-context');
  end;
end;

function BuildFinalStatement(const aFacts: TRemoveWithPlanFacts;
  const aBindingSource: TRemoveWithPlanBindingSource;
  const aBindingTree: TFinalBindingTree; const aBindingIndex: Integer;
  const aStatementId: string;
  const aCandidateEdits: TArray<TDelphiSemanticRemoveWithEdit>;
  const aReservedNames: TDictionary<string, Integer>;
  const aLineCache: TDelphiSemanticSourceContextCache;
  const aInheritedDecisions: TArray<TFinalSelectorDecision>;
  const aCheckControlContext: Boolean;
  out aBodyFacts: TFinalReceiverBodyFacts): TDelphiSemanticRemoveWithFinalStatement; overload; forward;

function SymbolUnsupportedReasonForName(const aFacts: TRemoveWithPlanFacts;
  const aName: string): string;
var
  lBaseName: string;
  lGenericPos: Integer;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := '';
  lBaseName := Trim(aName);
  if lBaseName = '' then
    Exit;
  lGenericPos := Pos('<', lBaseName);
  if lGenericPos > 1 then
    lBaseName := Copy(lBaseName, 1, lGenericPos - 1);
  for lSymbol in aFacts.LookupIndex.FindDeclarationOrTypeAliasByName(lBaseName) do
    if lSymbol.UnsupportedReason <> '' then
      Exit(lSymbol.UnsupportedReason);
  for lSymbol in aFacts.LookupIndex.FindSymbolsByName(lBaseName) do
    if lSymbol.UnsupportedReason <> '' then
      Exit(lSymbol.UnsupportedReason);
end;

function SourceBackedTypeKnown(const aFacts: TRemoveWithPlanFacts;
  const aTypeName: string): Boolean;
var
  lBaseName: string;
  lGenericPos: Integer;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  lBaseName := Trim(aTypeName);
  lGenericPos := Pos('<', lBaseName);
  if lGenericPos > 1 then
    lBaseName := Copy(lBaseName, 1, lGenericPos - 1);
  Result := False;
  if lBaseName = '' then
    Exit;
  for lSymbol in aFacts.LookupIndex.FindDeclarationOrTypeAliasByName(lBaseName) do
    if not SameText(lSymbol.SymbolClass, 'external') then
      Exit(True);
  for lSymbol in aFacts.LookupIndex.FindSymbolsByName(lBaseName) do
  begin
    if SameText(lSymbol.SymbolClass, 'external') then
      Continue;
    if MatchText(lSymbol.SourceOwnerType, ['compiler-intrinsic', 'rtl-source']) or
      ((lSymbol.FileName <> '') and (lSymbol.Line > 0)) then
      Exit(True);
  end;
end;

function SelectorNamesRoutine(const aFacts: TRemoveWithPlanFacts;
  const aSelectorText: string): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  if not IsSimpleIdentifier(aSelectorText) then
    Exit;
  for lSymbol in aFacts.LookupIndex.FindSymbolsByName(aSelectorText) do
    if SameText(lSymbol.SymbolClass, 'routine') or
      SameText(lSymbol.Kind, 'routine') then
      Exit(True);
end;

function BindingSelectorDeclaredTypeName(const aFacts:
  TRemoveWithPlanFacts; const aBinding: TDelphiSemanticWithBinding;
  const aSelectorText: string): string;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := '';
  if not IsSimpleIdentifier(aSelectorText) then
    Exit;
  for lSymbol in aFacts.LookupIndex.FindSymbolsByName(aSelectorText) do
  begin
    if not MatchText(lSymbol.SymbolClass, ['local', 'parameter']) then
      Continue;
    if SameText(lSymbol.FileName, aBinding.FileName) and
      RoutineNameMatchesOrEncloses(lSymbol.RoutineName, aBinding.RoutineName) then
      Exit(lSymbol.TypeName);
  end;
end;

function SameStorageDeclaration(const aLeft, aRight:
  TDelphiSemanticInventorySymbol): Boolean;
begin
  Result := SameText(aLeft.FileName, aRight.FileName) and
    (aLeft.Line = aRight.Line) and (aLeft.Column = aRight.Column) and
    SameText(aLeft.TypeName, aRight.TypeName);
end;

function IsSameUnitRecordDeclaration(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aTypeName: string): Boolean;
var
  lDeclaration: TDelphiSemanticInventorySymbol;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  lDeclaration := Default(TDelphiSemanticInventorySymbol);
  if not IsSimpleIdentifier(aTypeName) then
    Exit;
  for lSymbol in aFacts.LookupIndex.FindDeclarationOrTypeAliasByName(aTypeName) do
  begin
    if not SameText(lSymbol.SymbolClass, 'declaration') then
      Continue;
    if (not SameText(lSymbol.FileName, aBinding.FileName)) or
      (not SameText(lSymbol.TypeName, 'record')) or
      (lSymbol.RoutineName <> '') or (lSymbol.Line <= 0) or
      (lSymbol.Line >= aBinding.Line) then
      Exit(False);
    if Result and (not SameStorageDeclaration(lDeclaration, lSymbol)) then
      Exit(False);
    lDeclaration := lSymbol;
    Result := True;
  end;
end;

function ControlledRecordArraySelectorIsEligible(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aLineCache: TDelphiSemanticSourceContextCache): Boolean;
var
  lArrayType: string;
  lBracket: Integer;
  lElementType: string;
  lField: TDelphiSemanticInventorySymbol;
  lFieldName: string;
  lIndexName: string;
  lParts: TArray<string>;
  lReceiverType: string;
  lRoot: TDelphiSemanticInventorySymbol;
  lRootClass: string;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  if (aBinding.RoutineName = '') or (Length(aBinding.Selectors) <> 1) or
    BindingBodyContainsNestedWith(aBinding, aLineCache) or
    (not TrySplitSelectorChainParts(aBinding.SelectorText, lParts)) then
    Exit;
  if (Length(lParts) <> 2) or (not IsSimpleIdentifier(lParts[0])) then
    Exit;
  lBracket := Pos('[', lParts[1]);
  if (lBracket <= 1) or (not EndsText(']', lParts[1])) then
    Exit;
  lFieldName := Trim(Copy(lParts[1], 1, lBracket - 1));
  lIndexName := Trim(Copy(lParts[1], lBracket + 1,
    Length(lParts[1]) - lBracket - 1));
  if (not IsSimpleIdentifier(lFieldName)) or (not IsSimpleIdentifier(lIndexName)) then
    Exit;
  if TryFindRoutineScopedSymbolForBinding(aFacts, aBinding, lParts[0], lSymbol) then
    Exit;

  lRoot := Default(TDelphiSemanticInventorySymbol);
  for lSymbol in aFacts.LookupIndex.FindUnitOrGlobalByName(lParts[0]) do
  begin
    if not SameText(lSymbol.SymbolClass, 'unit-global') then
      Continue;
    if (not SameText(lSymbol.FileName, aBinding.FileName)) or
      (not SameText(lSymbol.Kind, 'unit-global')) or (lSymbol.Line <= 0) or
      (lSymbol.Line >= aBinding.Line) then
      Exit;
    if (lRoot.Line > 0) and (not SameStorageDeclaration(lRoot, lSymbol)) then
      Exit;
    lRoot := lSymbol;
  end;
  if (lRoot.Line = 0) or
    (not IsSameUnitRecordDeclaration(aFacts, aBinding, lRoot.TypeName)) then
    Exit;
  // Require one storage declaration; member and routine shadows remain excluded.
  for lSymbol in aFacts.LookupIndex.FindSymbolsByName(lParts[0]) do
  begin
    if (not MatchText(lSymbol.SymbolClass, ['declaration', 'unit-global'])) or
      (not MatchText(lSymbol.Kind, ['var', 'unit-global'])) or
      (not SameStorageDeclaration(lRoot, lSymbol)) then
      Exit;
  end;

  lField := Default(TDelphiSemanticInventorySymbol);
  for lSymbol in aFacts.LookupIndex.FindMembersByOwnerAndName(lRoot.TypeName,
    lFieldName) do
  begin
    if (not SameText(lSymbol.Kind, 'field')) or
      (not SameText(lSymbol.FileName, aBinding.FileName)) or
      (lSymbol.Line <= 0) or (lSymbol.Line >= aBinding.Line) then
      Exit;
    if (lField.Line > 0) and (not SameStorageDeclaration(lField, lSymbol)) then
      Exit;
    lField := lSymbol;
  end;
  lArrayType := Trim(lField.TypeName);
  if (not StartsText('array[', lArrayType)) or (Pos('] of ', lArrayType) = 0) then
    Exit;
  lElementType := ArrayElementTypeText(lArrayType);
  if not IsSameUnitRecordDeclaration(aFacts, aBinding, lElementType) then
    Exit;
  // Type inference also accepts getters; storage evidence above is required first.
  Result := TryResolveSourceBackedSelectorChainType(aFacts, aBinding,
    aBinding.SelectorText, lReceiverType, lRootClass) and
    SameText(lReceiverType, lElementType) and SameText(lRootClass, 'unit-global');
end;

function BindingFactSkipReason(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aLineCache: TDelphiSemanticSourceContextCache;
  out aReason: string): Boolean;
var
  lOpenParen: Integer;
  lPrefixText: string;
  lSelector: TDelphiSemanticWithSelectorBinding;
  lSelectorTypeName: string;
begin
  Result := True;
  aReason := '';
  lOpenParen := Pos('(', aBinding.SelectorText);
  if lOpenParen > 0 then
  begin
    lPrefixText := Trim(Copy(aBinding.SelectorText, 1, lOpenParen - 1));
    if Length(aFacts.LookupIndex.FindDeclarationOrTypeAliasByName(lPrefixText)) = 0 then
    begin
      aReason := 'call-selector';
      Exit;
    end;
  end;
  if (BindingSelectorDeclaredTypeName(aFacts, aBinding, aBinding.SelectorText) = '') and
    SelectorNamesRoutine(aFacts, aBinding.SelectorText) then
  begin
    aReason := 'call-selector';
    Exit;
  end;

  if ContainsText(aBinding.SelectorText, '.') and
    (Pos('^', aBinding.SelectorText) = 0) and
    BindingFollowsControlStatement(aBinding, aLineCache) and
    (not ControlledRecordArraySelectorIsEligible(aFacts, aBinding, aLineCache)) then
  begin
    aReason := 'controlled-with-statement';
    Exit;
  end;

  for lSelector in aBinding.Selectors do
  begin
    lSelectorTypeName := lSelector.TypeName;
    if lSelectorTypeName = '' then
      lSelectorTypeName := SelectorTypeName(aFacts, aBinding, lSelector.SelectorText);
    if lSelectorTypeName = '' then
      lSelectorTypeName := BindingSelectorDeclaredTypeName(aFacts, aBinding,
        lSelector.SelectorText);
    if ContainsText(lSelectorTypeName, '<') then
    begin
      aReason := 'unsupported-source-model-generic-declaration';
      Exit;
    end;
    aReason := SymbolUnsupportedReasonForName(aFacts, lSelectorTypeName);
    if aReason <> '' then
      Exit;
  end;

  for lSelector in aBinding.Selectors do
  begin
    lSelectorTypeName := lSelector.TypeName;
    if lSelectorTypeName = '' then
      lSelectorTypeName := SelectorTypeName(aFacts, aBinding, lSelector.SelectorText);
    if lSelectorTypeName = '' then
      lSelectorTypeName := BindingSelectorDeclaredTypeName(aFacts, aBinding,
        lSelector.SelectorText);
    if (Trim(lSelectorTypeName) <> '') and
      (not SourceBackedTypeKnown(aFacts, lSelectorTypeName)) then
    begin
      aReason := 'type-source-not-indexed';
      Exit;
    end;
  end;

  Result := False;
end;

function SelectorTextWithDependentQualifiers(
  const aFacts: TRemoveWithPlanFacts;
  const aDecisions: TArray<TFinalSelectorDecision>;
  const aSelectorText: string): string;
var
  i: Integer;
  lDecisionIndex: Integer;
  lDecision: TFinalSelectorDecision;
  lName: string;
  lNextChar: Char;
  lPreviousChar: Char;
  lReplacementText: string;
  lStartOffset: Integer;
begin
  Result := '';
  i := 1;
  while i <= Length(aSelectorText) do
  begin
    if not IsIdentifierTextChar(aSelectorText[i]) then
    begin
      Result := Result + aSelectorText[i];
      Inc(i);
      Continue;
    end;

    lStartOffset := i;
    while (i <= Length(aSelectorText)) and
      IsIdentifierTextChar(aSelectorText[i]) do
      Inc(i);
    lName := Copy(aSelectorText, lStartOffset, i - lStartOffset);
    lReplacementText := lName;
    lPreviousChar := #0;
    lNextChar := #0;
    if lStartOffset > 1 then
      lPreviousChar := aSelectorText[lStartOffset - 1];
    if i <= Length(aSelectorText) then
      lNextChar := aSelectorText[i];

    if (not CharInSet(lPreviousChar, ['.', '$'])) and (lNextChar <> '(') and
      (not BodyOffsetInsideLiteralOrComment(aSelectorText, lStartOffset)) then
    begin
      for lDecisionIndex := High(aDecisions) downto 0 do
      begin
        lDecision := aDecisions[lDecisionIndex];
        if (Trim(lDecision.QualifierText) = '') or
          (Trim(lDecision.ReceiverType) = '') or
          (not OwnerHasMemberNamed(aFacts, lDecision.ReceiverType, lName)) then
          Continue;
        if not DecisionKeepsWithMemberScope(lDecision) then
          lReplacementText := lDecision.QualifierText + '.' + lName;
        Break;
      end;
    end;
    Result := Result + lReplacementText;
  end;
end;

procedure QualifyDecisionInitializationDependencies(
  const aFacts: TRemoveWithPlanFacts;
  const aPriorDecisions: TArray<TFinalSelectorDecision>;
  var aDecision: TFinalSelectorDecision);
var
  lQualifiedSelectorText: string;
begin
  if (aDecision.InitializationText = '') or (Length(aPriorDecisions) = 0) then
    Exit;
  lQualifiedSelectorText := SelectorTextWithDependentQualifiers(aFacts,
    aPriorDecisions, aDecision.SelectorText);
  if lQualifiedSelectorText = aDecision.SelectorText then
    Exit;
  if SameText(aDecision.Strategy, 'record-pointer-temp') then
    lQualifiedSelectorText := '@' + lQualifiedSelectorText;
  aDecision.InitializationText := aDecision.TempName + ' := ' +
    lQualifiedSelectorText + ';';
end;

function AdmissionDeniedBindingIndex(const aBindingSource: TRemoveWithPlanBindingSource;
  const aBindingTree: TFinalBindingTree; const aBindingIndex: Integer): Integer;
var
  lChildIndex: Integer;
begin
  if BindingReceiverVisibilityDenies(aBindingSource.BindingByIndex(aBindingIndex)) then
    Exit(aBindingIndex);
  for lChildIndex in aBindingTree.ChildIndexes[aBindingIndex] do
  begin
    Result := AdmissionDeniedBindingIndex(aBindingSource, aBindingTree, lChildIndex);
    if Result >= 0 then
      Exit;
  end;
  Result := -1;
end;

procedure ApplyReceiverAdmission(const aBindingSource: TRemoveWithPlanBindingSource;
  const aBindingTree: TFinalBindingTree; const aBindingIndex: Integer;
  var aStatement: TDelphiSemanticRemoveWithFinalStatement;
  var aBodyFacts: TFinalReceiverBodyFacts);
var
  lDeniedIndex: Integer;
begin
  // All recursive decisions remain provisional until this publishing boundary.
  // Established selector, renderer, activity and kind refusals retain precedence.
  if not SameText(aStatement.Status, 'planned') then
    Exit;
  lDeniedIndex := AdmissionDeniedBindingIndex(aBindingSource, aBindingTree, aBindingIndex);
  if lDeniedIndex < 0 then
    Exit;
  aStatement := BuildSkippedFinalStatement(aBindingSource.BindingByIndex(aBindingIndex),
    aStatement.StatementId, 'receiver-type-not-visible', 'receiver-type-not-visible');
  aBodyFacts := Default(TFinalReceiverBodyFacts);
  aBodyFacts.CaptureDenied := True;
  // A refused covered child does not turn its admitted parent into an A5 barrier.
  aBodyFacts.AdmissionDenied := lDeniedIndex = aBindingIndex;
end;

function BuildFinalStatement(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aStatementId: string;
  const aCandidateEdit: TDelphiSemanticRemoveWithEdit;
  const aReservedNames: TDictionary<string, Integer>;
  const aLineCache: TDelphiSemanticSourceContextCache):
  TDelphiSemanticRemoveWithFinalStatement; overload;
var
  lBodyFacts: TFinalReceiverBodyFacts;
  lBindingTree: TFinalBindingTree;
  lBindingList: TArray<TDelphiSemanticWithBinding>;
  lBindingSource: TArrayRemoveWithPlanBindingSource;
  lCandidateEdits: TArray<TDelphiSemanticRemoveWithEdit>;
  lInheritedDecisions: TArray<TFinalSelectorDecision>;
begin
  SetLength(lBindingList, 1);
  SetLength(lBindingTree.ParentIndexes, 1);
  lBindingTree.ParentIndexes[0] := -1;
  SetLength(lBindingTree.RootIndexes, 1);
  SetLength(lBindingTree.ChildIndexes, 1);
  SetLength(lCandidateEdits, 1);
  lBindingList[0] := aBinding;
  lBindingTree.RootIndexes[0] := 0;
  lCandidateEdits[0] := aCandidateEdit;
  lInheritedDecisions := nil;
  lBindingSource := TArrayRemoveWithPlanBindingSource.Create(lBindingList);
  try
    Result := BuildFinalStatement(aFacts, lBindingSource, lBindingTree, 0,
      aStatementId, lCandidateEdits, aReservedNames, aLineCache,
      lInheritedDecisions, True, lBodyFacts);
    if SameText(Result.Status, 'planned') and BindingReceiverVisibilityDenies(aBinding) then
      RollbackReservedTempNamesForFinalTemps(aReservedNames, aBinding.RoutineName, Result.Temps);
    ApplyReceiverAdmission(lBindingSource, lBindingTree, 0, Result, lBodyFacts);
  finally
    lBindingSource.Free;
  end;
end;

function SelectorDecisionsWithAdditional(
  const aBaseDecisions, aAdditionalDecisions: TArray<TFinalSelectorDecision>):
  TArray<TFinalSelectorDecision>;
var
  lDecision: TFinalSelectorDecision;
  lIndex: Integer;
begin
  Result := Copy(aBaseDecisions);
  for lDecision in aAdditionalDecisions do
  begin
    lIndex := Length(Result);
    SetLength(Result, lIndex + 1);
    Result[lIndex] := lDecision;
  end;
end;

function TryUniqueReceiverStorage(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aName: string;
  out aStorage: TDelphiSemanticInventorySymbol): Boolean;
var
  lBestScore, lScore, lMatches: Integer;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  aStorage := Default(TDelphiSemanticInventorySymbol);
  if not IsSimpleIdentifier(aName) then
    Exit;
  lBestScore := -1;
  lMatches := 0;
  for lSymbol in aFacts.LookupIndex.FindSymbolsByName(aName) do
  begin
    if not InventorySymbolIsSourceBacked(lSymbol) then
      Continue;
    lScore := RoutineScopedSymbolBindingScore(aFacts, lSymbol, aBinding);
    if (lScore < 0) and SameText(lSymbol.FileName, aBinding.FileName) and
      SameText(lSymbol.UnitName, aBinding.UnitName) and
      (lSymbol.RoutineName = '') and
      MatchText(lSymbol.Kind, ['variable', 'var']) and
      MatchText(lSymbol.SymbolClass, ['unit', 'global', 'declaration']) then
      lScore := 0;
    if lScore < 0 then
      Continue;
    if lScore > lBestScore then
    begin
      lBestScore := lScore;
      lMatches := 0;
    end;
    if lScore = lBestScore then
    begin
      Inc(lMatches);
      aStorage := lSymbol;
    end;
  end;
  Result := (lMatches = 1) and (aStorage.Line > 0) and
    (aStorage.Column > 0) and
    (not MatchText(aStorage.Kind, ['function', 'procedure', 'property']));
end;

function RetainedIdenticalReceiverStorageProved(const aFacts: TRemoveWithPlanFacts;
  const aBindingSource: TRemoveWithPlanBindingSource;
  const aBindingTree: TFinalBindingTree; const aBindingIndex: Integer;
  const aDecision: TFinalSelectorDecision;
  const aInheritedDecisions: TArray<TFinalSelectorDecision>;
  const aLineCache: TDelphiSemanticSourceContextCache): Boolean;
var
  lParentIndex: Integer;
  lBinding, lParent: TDelphiSemanticWithBinding;
  lInnerStorage, lOuterStorage, lSymbol: TDelphiSemanticInventorySymbol;
  lPrefixRange: TDelphiSemanticRemoveWithSourceRange;
  lPrefix, lName: string;
  lWitness: TArray<string>;
  lOuterDecision: TFinalSelectorDecision;
  lLexer: TmwBasePasLex;
  lAbsent: Boolean;
begin
  Result := False;
  lName := aDecision.SelectorText;
  if not IsSimpleIdentifier(lName) then
    Exit;
  lBinding := aBindingSource.BindingByIndex(aBindingIndex);
  if not TryUniqueReceiverStorage(aFacts, lBinding, lName, lInnerStorage) then
    Exit;
  lParentIndex := aBindingTree.ParentIndexes[aBindingIndex];
  while lParentIndex >= 0 do
  begin
    lParent := aBindingSource.BindingByIndex(lParentIndex);
    for lOuterDecision in aInheritedDecisions do
    begin
      if (not DecisionKeepsWithMemberScope(lOuterDecision)) or
        (not SameText(lOuterDecision.SelectorText, lName)) or
        (not SameText(lParent.SelectorText, lName)) or
        (not TypeIdentityHasVerifiedOrigin(lOuterDecision.ReceiverIdentity)) then
        Continue;
      if (not TryUniqueReceiverStorage(aFacts, lParent, lName, lOuterStorage)) or
        (not SameStorageDeclaration(lInnerStorage, lOuterStorage)) or
        (not SameText(lInnerStorage.OwnerScopeId, lOuterStorage.OwnerScopeId)) or
        (not SameText(lInnerStorage.RoutineScopeId, lOuterStorage.RoutineScopeId)) then
        Continue;
      lAbsent := aFacts.LookupIndex.ReceiverMemberAbsenceProved(lBinding.UnitName,
        lOuterDecision.ReceiverType, lName, lOuterDecision.ReceiverIdentity);
      if (not lAbsent) and
        aFacts.LookupIndex.IsProfileRecord(lOuterDecision.ReceiverIdentity, True) then
      begin
        // The compiler profile's complete TSearchRec witness also applies
        // across a strong alias, but helpers require their own proof.
        TDelphiSemanticCompilerProfileBuilder.CompatibilityRecordMemberNames('TSearchRec', lWitness);
        lAbsent := (Length(lWitness) > 0) and (not MatchText(lName, lWitness));
        for lSymbol in aFacts.Symbols do
          if lSymbol.IsHelper then
            lAbsent := False;
      end;
      if not lAbsent then
        Continue;
      lPrefixRange := BindingBodyRange(lParent);
      lPrefixRange.EndLine := lBinding.Line;
      lPrefixRange.EndColumn := lBinding.Column;
      if not aLineCache.TryExtractRange(lBinding.FileName,
        lPrefixRange.StartLine, lPrefixRange.StartColumn,
        lPrefixRange.EndLine, lPrefixRange.EndColumn, lPrefix) then
        Continue;
      // Source ranges include their final character: discard the first W
      // of the nested WITH, which is not part of the intervening prefix.
      if (lPrefix = '') or (not SameText(Copy(lPrefix, Length(lPrefix), 1), 'w')) then
        Continue;
      SetLength(lPrefix, Length(lPrefix) - 1);
      // Only empty compound-statement prefixes are proved stable here.
      // Calls, assignments, selectors, indexing and getters fail closed.
      lLexer := TmwBasePasLex.Create;
      try
        lLexer.UseDefines := False;
        lLexer.Origin := lPrefix;
        while lLexer.TokenID <> ptNull do
        begin
          if (lLexer.TokenID <> ptBegin) and (not lLexer.IsJunk) then
            Break;
          lLexer.Next;
        end;
        if lLexer.TokenID = ptNull then
          Exit(True);
      finally
        lLexer.Free;
      end;
    end;
    lParentIndex := aBindingTree.ParentIndexes[lParentIndex];
  end;
end;

function BuildFinalStatement(const aFacts: TRemoveWithPlanFacts;
  const aBindingSource: TRemoveWithPlanBindingSource;
  const aBindingTree: TFinalBindingTree; const aBindingIndex: Integer;
  const aStatementId: string;
  const aCandidateEdits: TArray<TDelphiSemanticRemoveWithEdit>;
  const aReservedNames: TDictionary<string, Integer>;
  const aLineCache: TDelphiSemanticSourceContextCache;
  const aInheritedDecisions: TArray<TFinalSelectorDecision>;
  const aCheckControlContext: Boolean;
  out aBodyFacts: TFinalReceiverBodyFacts): TDelphiSemanticRemoveWithFinalStatement; overload;
var
  lChildStatement: TDelphiSemanticRemoveWithFinalStatement;
  lChildBodyFacts: TFinalReceiverBodyFacts;
  lDecision: TFinalSelectorDecision;
  lDecisions: TArray<TFinalSelectorDecision>;
  lEdit: TDelphiSemanticRemoveWithFinalTextEdit;
  lIndex: Integer;
  lNestedReplacement: TFinalNestedReplacement;
  lNestedReplacements: TArray<TFinalNestedReplacement>;
  lValueReference: TDelphiSemanticBoundReference;
  lReplacementRange: TDelphiSemanticRemoveWithSourceRange;
  lReason: string;
  lReplacementText: string;
  lRecipe: TDelphiSemanticRemoveWithRewriteRecipe;
  lSelectorOccurrences: Integer;
  lSelectorQualifierText: string;
  lSelectorDecisions: TArray<TFinalSelectorDecision>;
  lChildIndex: Integer;
  i: Integer;
  lOwnTempIndex: Integer;
  lOwnSelectors: TArray<string>;
  lOwnStart: Integer;
  lSelectorIndex: Integer;
  lParentBinding: TDelphiSemanticWithBinding;
  lPreserveLinePrefix: Boolean;
  lControlledReplacement, lHasInitialization: Boolean;
  lBindingLines: TArray<string>;
  lTrailingSemicolon: Boolean;
  lTempIndex: Integer;
  lVisibleDecisions: TArray<TFinalSelectorDecision>;
  lBinding: TDelphiSemanticWithBinding;
  lSelector: TDelphiSemanticWithSelectorBinding;
begin
  aBodyFacts := Default(TFinalReceiverBodyFacts);
  lBinding := aBindingSource.BindingByIndex(aBindingIndex);
  Result := Default(TDelphiSemanticRemoveWithFinalStatement);
  Result.FileName := lBinding.FileName;
  Result.StatementId := aStatementId;
  Result.SemanticId := lBinding.SemanticId;
  Result.RoutineName := lBinding.RoutineName;
  Result.Range := BindingRange(lBinding);
  Result.Verification := FinalVerification(aCandidateEdits[aBindingIndex]);
  Result.ReferenceIds := aCandidateEdits[aBindingIndex].ReferenceIds;
  lVisibleDecisions := Copy(aInheritedDecisions);
  if (SameText(lBinding.SkipReason, 'MEMBERS_UNVERIFIED') and
    (not lBinding.MemberActivityUnverified)) or
    SameText(lBinding.SkipReason, 'MEMBERS_INCOMPLETE') or
    SameText(lBinding.SkipReason, 'SCOPE_UNVERIFIED') then
  begin
    Result.Status := 'skipped';
    Result.Reason := LowerCase(StringReplace(lBinding.SkipReason, '_', '-', [rfReplaceAll]));
    Result.SafetyReason := lBinding.SkipReason;
    Exit;
  end;
  if BindingFactSkipReason(aFacts, lBinding, aLineCache, lReason) then
  begin
    Result.Status := 'skipped';
    Result.Reason := lReason;
    Result.SafetyReason := Result.Reason;
    Exit;
  end;

  lPreserveLinePrefix := aLineCache.TryGetValue(lBinding.FileName, lBindingLines) and
    (lBinding.Line >= 1) and (lBinding.Line <= Length(lBindingLines)) and
    (Trim(Copy(lBindingLines[lBinding.Line - 1], 1, lBinding.Column - 1)) <> '');
  lOwnStart := 0;
  if aBindingTree.ParentIndexes[aBindingIndex] >= 0 then
  begin
    lParentBinding := aBindingSource.BindingByIndex(aBindingTree.ParentIndexes[aBindingIndex]);
    lOwnStart := Length(lParentBinding.Selectors);
  end;
  lReason := 'selector-binding-incomplete';
  if TrySplitTopLevelCommaList(lBinding.SelectorText, lOwnSelectors) and
    (Length(lBinding.Selectors) = lOwnStart + Length(lOwnSelectors)) then
  begin
    lReason := '';
    for i := 0 to High(lOwnSelectors) do
      if not SameText(lOwnSelectors[i], lBinding.Selectors[lOwnStart + i].SelectorText) then
        lReason := 'selector-binding-incomplete';
  end;
  if lReason <> '' then
  begin
    Result.Status := 'skipped';
    Result.Reason := lReason;
    Result.SafetyReason := Result.Reason;
    Exit;
  end;

  for lSelectorIndex := lOwnStart to High(lBinding.Selectors) do
  begin
    lSelector := lBinding.Selectors[lSelectorIndex];
    lSelectorOccurrences := 0;
    for i := 0 to High(lOwnSelectors) do
      if SameText(lOwnSelectors[i], lSelector.SelectorText) then
        Inc(lSelectorOccurrences);
    if lSelectorOccurrences > 1 then
    begin
      RollbackReservedTempNamesForDecisions(aReservedNames,
        lBinding.RoutineName, lSelectorDecisions);
      Result.Status := 'skipped';
      Result.Reason := 'repeated-selector';
      Result.SafetyReason := Result.Reason;
      Exit;
    end;
    if HasDecisionForSelector(lSelectorDecisions, lSelector.SelectorText) then
      Continue;
    if IsSimplePointerDereferenceSelector(lSelector.SelectorText) and
      SkippedParentContextHasIndexedSelector(aInheritedDecisions) then
    begin
      RollbackReservedTempNamesForDecisions(aReservedNames,
        lBinding.RoutineName, lSelectorDecisions);
      Result.Status := 'skipped';
      Result.Reason := 'symbol-not-found';
      Result.SafetyReason := Result.Reason;
      Exit;
    end;
    if not BuildSelectorDecision(aFacts, lBinding, lSelector.SelectorText, lSelector,
      aReservedNames, lVisibleDecisions, aLineCache, lDecision, lReason) then
    begin
      RollbackReservedTempNamesForDecisions(aReservedNames,
        lBinding.RoutineName, lSelectorDecisions);
      Result.Status := 'skipped';
      Result.Reason := lReason;
      Result.SafetyReason := Result.Reason;
      aBodyFacts.CaptureDenied := lDecision.CaptureDenied;
      Exit;
    end;
    lDecision.RetainedIdenticalStorageProved := RetainedIdenticalReceiverStorageProved(
      aFacts, aBindingSource, aBindingTree, aBindingIndex, lDecision,
      aInheritedDecisions, aLineCache);
    QualifyDecisionInitializationDependencies(aFacts, lVisibleDecisions,
      lDecision);
    if SameText(lDecision.Strategy, 'direct-qualification') and
      DependentSelectorQualifier(aFacts, lBinding, lSelectorDecisions,
      lSelector.SelectorText, lSelectorQualifierText) then
    begin
      lDecision.Strategy := 'direct-qualification';
      lDecision.TempName := '';
      lDecision.DeclarationText := '';
      lDecision.InitializationText := '';
      lDecision.QualifierText := lSelectorQualifierText;
      lDecision.Reason := 'dependent-selector-direct-qualification';
    end else if SameText(lDecision.Strategy, 'direct-qualification') and
      DependentSelectorQualifier(aFacts, lBinding, aInheritedDecisions,
      lSelector.SelectorText, lSelectorQualifierText) then
    begin
      lDecision.QualifierText := lSelectorQualifierText;
      lDecision.Reason := 'dependent-selector-direct-qualification';
    end else if (not SameText(lDecision.Strategy, 'direct-qualification')) and
      IsSimpleIdentifier(lSelector.SelectorText) and
      (not ActiveDecisionHasMember(aFacts, lSelectorDecisions, lSelector.SelectorText)) and
      SkippedParentContextHasMember(aFacts, aInheritedDecisions, lSelector.SelectorText) then
    begin
      lDecision.Strategy := 'direct-qualification';
      lDecision.TempName := '';
      lDecision.DeclarationText := '';
      lDecision.InitializationText := '';
      lDecision.QualifierText := lSelector.SelectorText;
      lDecision.Reason := 'inherited-selector-direct-qualification';
    end;
    lIndex := Length(lSelectorDecisions);
    SetLength(lSelectorDecisions, lIndex + 1);
    lSelectorDecisions[lIndex] := lDecision;
    lIndex := Length(lVisibleDecisions);
    SetLength(lVisibleDecisions, lIndex + 1);
    lVisibleDecisions[lIndex] := lDecision;
  end;

  for lChildIndex in aBindingTree.ChildIndexes[aBindingIndex] do
  begin
    lChildStatement := BuildFinalStatement(aFacts, aBindingSource, aBindingTree,
      lChildIndex, FinalStatementId(lChildIndex + 1), aCandidateEdits,
      aReservedNames, aLineCache, lVisibleDecisions, aCheckControlContext, lChildBodyFacts);
    if not SameText(lChildStatement.Status, 'planned') then
    begin
      RollbackReservedTempNamesForDecisions(aReservedNames,
        lBinding.RoutineName, lSelectorDecisions);
      RollbackReservedTempNamesForFinalTemps(aReservedNames,
        lBinding.RoutineName, Result.Temps);
      Result.Temps := nil;
      Result.Status := lChildStatement.Status;
      aBodyFacts.CaptureDenied := lChildBodyFacts.CaptureDenied;
      // Preserve the removed parent's own refusal before propagating a child
      // failure. A retained parent then permits a fresh child-only proof.
      if SameText(lChildStatement.SafetyReason, 'OWNER_INHERITED_MEMBERS_UNVERIFIED') and
        SameText(aBindingSource.BindingByIndex(lChildIndex).SelectorText, lBinding.SelectorText) and
        BindingHasUnprovedReceiverReference(lBinding.UnitName, aFacts,
        lChildBodyFacts, lSelectorDecisions, Result.SafetyReason) then
      begin
        Result.Reason := 'receiver-member-not-found';
        Exit;
      end;
      if SameText(lChildStatement.Reason, 'semantic-rewrite-incomplete') or
        SameText(lChildStatement.Reason, 'covered-child-rewrite-incomplete') then
      begin
        Result.Reason := 'covered-child-rewrite-incomplete';
        Result.SafetyReason := Result.Reason;
      end else
      begin
        Result.Reason := lChildStatement.Reason;
        Result.SafetyReason := lChildStatement.SafetyReason;
      end;
      Exit;
    end;
    lNestedReplacement.Range := lChildStatement.Range;
    lNestedReplacement.ReplacementText := lChildStatement.ReplacementText;
    lNestedReplacement.ReceiverBodyFacts := lChildBodyFacts;
    lIndex := Length(lNestedReplacements);
    SetLength(lNestedReplacements, lIndex + 1);
    lNestedReplacements[lIndex] := lNestedReplacement;
    for lTempIndex := 0 to High(lChildStatement.Temps) do
    begin
      SetLength(Result.Temps, Length(Result.Temps) + 1);
      Result.Temps[High(Result.Temps)] := lChildStatement.Temps[lTempIndex];
    end;
  end;

  lDecisions := SelectorDecisionsWithAdditional(aInheritedDecisions,
    lSelectorDecisions);
  if not TryRenderFinalReplacementText(aFacts, lBinding, lVisibleDecisions,
    lDecisions, lSelectorDecisions, lNestedReplacements, aLineCache,
    lReplacementText, lReason, lReplacementRange, aBodyFacts) then
  begin
    RollbackReservedTempNamesForDecisions(aReservedNames,
      lBinding.RoutineName, lSelectorDecisions);
    RollbackReservedTempNamesForFinalTemps(aReservedNames,
      lBinding.RoutineName, Result.Temps);
    Result.Temps := nil;
    Result.Status := 'skipped';
    Result.Reason := lReason;
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if not ReplacementRangeCoversExpectedWithRange(lBinding, lReplacementRange,
    aLineCache) then
  begin
    RollbackReservedTempNamesForDecisions(aReservedNames,
      lBinding.RoutineName, lSelectorDecisions);
    RollbackReservedTempNamesForFinalTemps(aReservedNames,
      lBinding.RoutineName, Result.Temps);
    Result.Temps := nil;
    Result.Status := 'skipped';
    Result.Reason := 'replace-statement-range-mismatch';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;

  // DS-720: defer helper refusal until established selector/renderer refusals finish.
  if BindingHelperUnverifiedReason(lBinding, aLineCache, lReason) then
  begin
    RollbackReservedTempNamesForDecisions(aReservedNames,
      lBinding.RoutineName, lSelectorDecisions);
    RollbackReservedTempNamesForFinalTemps(aReservedNames,
      lBinding.RoutineName, Result.Temps);
    Result.Temps := nil;
    Result.Status := 'skipped';
    Result.Reason := lReason;
    Result.SafetyReason := 'RECORD_HELPER_MEMBERS_UNVERIFIED';
    Exit;
  end;

  // DS-741: a local alias keeps its established binder reason. Refuse only
  // after the existing selector/renderer checks would otherwise permit a plan.
  if BindingHasUnverifiedLocalAlias(aFacts, lBinding) then
  begin
    RollbackReservedTempNamesForDecisions(aReservedNames,
      lBinding.RoutineName, lSelectorDecisions);
    RollbackReservedTempNamesForFinalTemps(aReservedNames,
      lBinding.RoutineName, Result.Temps);
    Result.Temps := nil;
    Result.Status := 'skipped';
    Result.Reason := 'selector-type-not-resolved';
    Result.SafetyReason := 'ROUTINE_LOCAL_TYPE_UNSUPPORTED';
    Exit;
  end;

  for lValueReference in lBinding.References do
    if SameText(lValueReference.Classification, 'unsupported') and
      MatchText(lValueReference.ReasonCode, ['TYPE_VALUE_MEMBERS_UNVERIFIED',
      'TYPE_VALUE_MEMBER_ACCESS_UNVERIFIED', 'ALIAS_RECEIVER_MEMBERS_UNVERIFIED']) then
    begin
      RollbackReservedTempNamesForDecisions(aReservedNames,
        lBinding.RoutineName, lSelectorDecisions);
      RollbackReservedTempNamesForFinalTemps(aReservedNames,
        lBinding.RoutineName, Result.Temps);
      Result.Temps := nil;
      Result.Status := 'skipped';
      Result.Reason := ReceiverMemberMissReason(lValueReference, lBinding, aLineCache);
      if SameText(lValueReference.ReasonCode, 'ALIAS_RECEIVER_MEMBERS_UNVERIFIED') then
        Result.SafetyReason := 'ALIAS_RECEIVER_MEMBERS_UNVERIFIED'
      else
        Result.SafetyReason := 'TYPE_VALUE_MEMBERS_UNVERIFIED';
      Exit;
    end;
  // Established selector, renderer, helper and value-member reasons win.
  if BindingHasUnprovedReceiverReference(lBinding.UnitName, aFacts, aBodyFacts,
    lDecisions, Result.SafetyReason) then
  begin
    RollbackReservedTempNamesForDecisions(aReservedNames,
      lBinding.RoutineName, lSelectorDecisions);
    RollbackReservedTempNamesForFinalTemps(aReservedNames,
      lBinding.RoutineName, Result.Temps);
    Result.Temps := nil;
    Result.Status := 'skipped';
    Result.Reason := 'receiver-member-not-found';
    Exit;
  end;
  // DS-740: preserving a prefix is independent of whether it controls the result.
  // A planned parent absorbs its child; a retained parent keeps its DO in output.
  lHasInitialization := False;
  for lDecision in lSelectorDecisions do
    lHasInitialization := lHasInitialization or (lDecision.InitializationText <> '');
  for lTempIndex := 0 to High(Result.Temps) do
    lHasInitialization := lHasInitialization or
      (Result.Temps[lTempIndex].InitializationText <> '');
  lControlledReplacement := False;
  if aCheckControlContext and lHasInitialization then
    lControlledReplacement := FinalBindingNeedsControlWrapper(aFacts, lBinding,
      aBindingSource, aBindingTree, aBindingIndex, aInheritedDecisions);
  if lHasInitialization and lControlledReplacement and
    (not StartsText('begin', TrimLeft(lReplacementText))) then
  begin
    lTrailingSemicolon := not RangeIsFollowedByOuterElse(lBinding, aLineCache,
      lReplacementRange);
    lReplacementText := 'begin' + sLineBreak + lReplacementText + sLineBreak +
      IndentText(lBinding.Column) + 'end';
    if lTrailingSemicolon then
      lReplacementText := lReplacementText + ';';
  end;
  // A2.3a: defer kind refusal until all established refusal checks have run.
  // Propagate covered children's contradictions with their body facts.
  for lDecision in lSelectorDecisions do
    aBodyFacts.StrategyKindContradiction := aBodyFacts.StrategyKindContradiction or
      lDecision.StrategyKindContradiction;
  Result.Status := 'planned';
  Result.ReplacementText := lReplacementText;
  lOwnTempIndex := 0;
  for lIndex := 0 to High(lSelectorDecisions) do
  begin
    if lSelectorDecisions[lIndex].TempName = '' then
      Continue;
    lTempIndex := Length(Result.Temps);
    SetLength(Result.Temps, lTempIndex + 1);
    for i := High(Result.Temps) downto lOwnTempIndex + 1 do
      Result.Temps[i] := Result.Temps[i - 1];
    Result.Temps[lOwnTempIndex] := FinalTempDecision(lSelectorDecisions[lIndex],
      lBinding.SemanticId);
    Inc(lOwnTempIndex);
  end;

  lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
  lEdit.Kind := 'replace-statement';
  lEdit.FileName := lBinding.FileName;
  lEdit.StatementId := aStatementId;
  lEdit.Range := lReplacementRange;
  if lPreserveLinePrefix then
    lEdit.Range.StartColumn := lBinding.Column
  else
    lEdit.Range.StartColumn := 1;
  lEdit.ReplacementText := Result.ReplacementText;
  lEdit.SemanticId := lBinding.SemanticId;
  lEdit.Verification := Result.Verification;
  lRecipe := FinalStatementRewriteRecipe(Result,
    FinalRewriteDecisionInputs(lSelectorDecisions, Result.SemanticId));
  lRecipe.ReplacementRange := lEdit.Range;
  lRecipe.RenderInstruction := 'render-final-edits';
  SetLength(lRecipe.TextEdits, 1);
  lRecipe.TextEdits[0] := lEdit;
  ApplyFinalStatementRewriteRecipe(Result, lRecipe);
end;

function FindRoutineDeclarationRange(const aFileName: string;
  const aBeforeLine: Integer; const aRoutineName: string;
  const aLineCache: TDelphiSemanticSourceContextCache;
  out aRange: TDelphiSemanticRemoveWithSourceRange; out aHasVarSection: Boolean):
  Boolean;
var
  lBeginLine: Integer;
  lInsertLine: Integer;
  lLineIndex: Integer;
  lLines: TArray<string>;
  lText: string;
  lRoutineLine: Integer;
begin
  Result := False;
  aHasVarSection := False;
  aRange := Default(TDelphiSemanticRemoveWithSourceRange);
  if not aLineCache.TryGetValue(aFileName, lLines) then
    Exit;
  lRoutineLine := 0;
  for lLineIndex := aBeforeLine downto 1 do
  begin
    if (aRoutineName <> '') and ContainsText(lLines[lLineIndex - 1],
      aRoutineName) and (ContainsText(lLines[lLineIndex - 1], 'procedure') or
      ContainsText(lLines[lLineIndex - 1], 'function') or
      ContainsText(lLines[lLineIndex - 1], 'constructor') or
      ContainsText(lLines[lLineIndex - 1], 'destructor')) then
    begin
      lRoutineLine := lLineIndex;
      Break;
    end;
  end;
  lInsertLine := 0;
  if lRoutineLine > 0 then
  begin
    lBeginLine := 0;
    for lLineIndex := lRoutineLine + 1 to Length(lLines) do
    begin
      lText := Trim(lLines[lLineIndex - 1]);
      if SameText(lText, 'var') then
        aHasVarSection := True;
      if aHasVarSection and (SameText(lText, 'label') or SameText(lText, 'const') or
        SameText(lText, 'type') or StartsText('procedure ', lText) or
        StartsText('function ', lText) or StartsText('constructor ', lText) or
        StartsText('destructor ', lText)) then
      begin
        lInsertLine := lLineIndex;
        Break;
      end else if (not aHasVarSection) and (SameText(lText, 'label') or
        SameText(lText, 'const') or SameText(lText, 'type')) then
      begin
        lBeginLine := lLineIndex;
        lInsertLine := lLineIndex;
        Break;
      end else if StartsText('procedure ', lText) or StartsText('function ', lText) or
        StartsText('constructor ', lText) or StartsText('destructor ', lText) then
      begin
        lBeginLine := lLineIndex;
        lInsertLine := lLineIndex;
        Break;
      end else if StartsText('begin', lText) and ((Length(lText) = Length('begin')) or
        StartsText('{', Trim(Copy(lText, Length('begin') + 1, MaxInt))) or
        StartsText('//', Trim(Copy(lText, Length('begin') + 1, MaxInt)))) then
      begin
        lBeginLine := lLineIndex;
        lInsertLine := lLineIndex;
        Break;
      end;
    end;
    if (lBeginLine <> 0) or (lInsertLine <> 0) then
    begin
      aRange.StartLine := lInsertLine;
      aRange.StartColumn := 1;
      aRange.EndLine := lInsertLine;
      aRange.EndColumn := 1;
      Exit(True);
    end;
  end;
  for lLineIndex := aBeforeLine downto 1 do
  begin
    lText := Trim(lLines[lLineIndex - 1]);
    if StartsText('begin', lText) and ((Length(lText) = Length('begin')) or
      StartsText('{', Trim(Copy(lText, Length('begin') + 1, MaxInt))) or
      StartsText('//', Trim(Copy(lText, Length('begin') + 1, MaxInt)))) then
    begin
      aRange.StartLine := lLineIndex;
      aRange.StartColumn := 1;
      aRange.EndLine := lLineIndex;
      aRange.EndColumn := 1;
      Exit(True);
    end;
  end;
end;

procedure AddRoutineDeclarationEdits(var aPlan: TDelphiSemanticRemoveWithPlan;
  const aLineCache: TDelphiSemanticSourceContextCache;
  const aHashCache: TDictionary<string, string>);
var
  lDeclarationByRoutine: TDictionary<string, string>;
  lDeclarationText: string;
  lEdit: TDelphiSemanticRemoveWithFinalTextEdit;
  lFirstIndexByRoutine: TDictionary<string, Integer>;
  lHasVarSection: Boolean;
  lKey: string;
  lManualDeclarationRoutine: TDictionary<string, Boolean>;
  lRange: TDelphiSemanticRemoveWithSourceRange;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
  lTemp: TDelphiSemanticRemoveWithFinalTempDecision;
  i: Integer;
begin
  lDeclarationByRoutine := TDictionary<string, string>.Create;
  lFirstIndexByRoutine := TDictionary<string, Integer>.Create;
  lManualDeclarationRoutine := TDictionary<string, Boolean>.Create;
  try
    for i := 0 to High(aPlan.FinalStatements) do
    begin
      lStatement := aPlan.FinalStatements[i];
      if not SameText(lStatement.Status, 'planned') then
        Continue;
      if HasFinalTextEditKind(lStatement, 'declare-temp') then
      begin
        if FindRoutineDeclarationRange(lStatement.FileName,
          lStatement.Range.StartLine, lStatement.RoutineName, aLineCache,
          lRange, lHasVarSection) then
        begin
          lKey := lStatement.FileName + #31 + lStatement.RoutineName;
          lManualDeclarationRoutine.AddOrSetValue(lKey, True);
        end;
        Continue;
      end;
    end;

    for i := 0 to High(aPlan.FinalStatements) do
    begin
      lStatement := aPlan.FinalStatements[i];
      if not SameText(lStatement.Status, 'planned') then
        Continue;
      if HasFinalTextEditKind(lStatement, 'declare-temp') then
        Continue;
      if not FindRoutineDeclarationRange(lStatement.FileName,
        lStatement.Range.StartLine, lStatement.RoutineName, aLineCache, lRange,
        lHasVarSection) then
        Continue;
      lKey := lStatement.FileName + #31 + lStatement.RoutineName;
      if lManualDeclarationRoutine.ContainsKey(lKey) then
        Continue;
      for lTemp in lStatement.Temps do
      begin
        if lTemp.DeclarationText = '' then
          Continue;
        if not lFirstIndexByRoutine.ContainsKey(lKey) then
          lFirstIndexByRoutine.Add(lKey, i);
        if not lDeclarationByRoutine.TryGetValue(lKey, lDeclarationText) then
        begin
          if lHasVarSection then
            lDeclarationText := ''
          else
            lDeclarationText := 'var' + sLineBreak;
        end;
        lDeclarationText := lDeclarationText + IndentText(3) +
          lTemp.DeclarationText + sLineBreak;
        lDeclarationByRoutine.AddOrSetValue(lKey, lDeclarationText);
      end;
    end;

    for lKey in lDeclarationByRoutine.Keys do
    begin
      i := lFirstIndexByRoutine[lKey];
      if not FindRoutineDeclarationRange(aPlan.FinalStatements[i].FileName,
        aPlan.FinalStatements[i].Range.StartLine,
        aPlan.FinalStatements[i].RoutineName, aLineCache, lRange,
        lHasVarSection) then
        Continue;
      lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
      lEdit.Kind := 'declare-temp';
      lEdit.FileName := aPlan.FinalStatements[i].FileName;
      lEdit.StatementId := aPlan.FinalStatements[i].StatementId;
      lEdit.Range := lRange;
      lEdit.ReplacementText := lDeclarationByRoutine[lKey];
      lEdit.SemanticId := aPlan.FinalStatements[i].SemanticId;
      lEdit.Verification.ExpectedFileHash := SourceFileHash(lEdit.FileName, aHashCache);
      lEdit.Verification.ExpectedSourceText := '';
      lEdit.Verification.Range := lEdit.Range;
      lStatement := aPlan.FinalStatements[i];
      AddFinalTextEdit(lStatement, lEdit, True);
      aPlan.FinalStatements[i] := lStatement;
    end;
  finally
    lFirstIndexByRoutine.Free;
    lDeclarationByRoutine.Free;
    lManualDeclarationRoutine.Free;
  end;
end;

procedure AddVerification(var aPlan: TDelphiSemanticRemoveWithPlan; const aKind,
  aDescription: string);
var
  lIndex: Integer;
begin
  lIndex := Length(aPlan.RequiredVerification);
  SetLength(aPlan.RequiredVerification, lIndex + 1);
  aPlan.RequiredVerification[lIndex].Kind := aKind;
  aPlan.RequiredVerification[lIndex].Description := aDescription;
end;

function AddEdit(var aPlan: TDelphiSemanticRemoveWithPlan;
  const aBinding: TDelphiSemanticWithBinding; const aHashCache:
  TDictionary<string, string>; const aLineCache: TDelphiSemanticSourceContextCache):
  TDelphiSemanticRemoveWithEdit;
var
  lIndex: Integer;
begin
  Result := Default(TDelphiSemanticRemoveWithEdit);
  Result.Kind := 'remove-with-candidate';
  Result.FileName := aBinding.FileName;
  Result.StatementId := aBinding.SemanticId;
  Result.Range := BindingRange(aBinding);
  Result.ExpectedFileHash := SourceFileHash(aBinding.FileName, aHashCache);
  Result.ExpectedSourceText := SourceTextForRange(aBinding.FileName, Result.Range,
    aLineCache);
  Result.ReplacementText := Result.ExpectedSourceText;
  Result.ApplyMode := 'requires-dak-compatibility-adapter';
  Result.SemanticReason := 'semantic-with-binding-candidate';
  Result.SemanticId := aBinding.SemanticId;
  Result.ReferenceIds := ReferenceIdsForBinding(aBinding);

  lIndex := Length(aPlan.Edits);
  SetLength(aPlan.Edits, lIndex + 1);
  aPlan.Edits[lIndex] := Result;
end;

function SkippedStatementFromStatement(
  const aStatement: TDelphiSemanticRemoveWithStatement):
  TDelphiSemanticRemoveWithSkippedStatement;
begin
  Result.FileName := aStatement.FileName;
  Result.StatementId := aStatement.StatementId;
  Result.Range := aStatement.Range;
  Result.Reason := aStatement.Reason;
  Result.SafetyReason := aStatement.SafetyReason;
  Result.SemanticId := aStatement.SemanticId;
end;

function FindFinalStatementById(const aPlan: TDelphiSemanticRemoveWithPlan;
  const aStatementId: string;
  out aStatement: TDelphiSemanticRemoveWithFinalStatement): Boolean;
var
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  Result := False;
  aStatement := Default(TDelphiSemanticRemoveWithFinalStatement);
  for lStatement in aPlan.FinalStatements do
  begin
    if SameText(lStatement.StatementId, aStatementId) then
    begin
      aStatement := lStatement;
      Exit(True);
    end;
  end;
end;

function FinalBindingParentIndexesFromTree(
  const aBindingTree: TFinalBindingTree): TFinalBindingIndexArray;
var
  lChildIndex: Integer;
  lIndex: Integer;
  lParentIndex: Integer;
begin
  SetLength(Result, Length(aBindingTree.ChildIndexes));
  for lIndex := 0 to High(Result) do
    Result[lIndex] := -1;

  for lParentIndex := 0 to High(aBindingTree.ChildIndexes) do
    for lChildIndex in aBindingTree.ChildIndexes[lParentIndex] do
      Result[lChildIndex] := lParentIndex;
end;

function CoveringFinalStatementId(const aPlan: TDelphiSemanticRemoveWithPlan;
  const aParentIndexes: TFinalBindingIndexArray; const aBindingIndex: Integer):
  string;
var
  lParentIndex: Integer;
  lParentStatement: TDelphiSemanticRemoveWithFinalStatement;
  lParentStatementId: string;
begin
  Result := '';
  lParentIndex := aParentIndexes[aBindingIndex];
  while lParentIndex >= 0 do
  begin
    lParentStatementId := FinalStatementId(lParentIndex + 1);
    if FindFinalStatementById(aPlan, lParentStatementId, lParentStatement) and
      SameText(lParentStatement.Status, 'planned') then
      Exit(lParentStatementId);
    lParentIndex := aParentIndexes[lParentIndex];
  end;
end;

function StatementFromBinding(const aBinding: TDelphiSemanticWithBinding;
  const aStatementId: string): TDelphiSemanticRemoveWithStatement;
begin
  Result := Default(TDelphiSemanticRemoveWithStatement);
  Result.FileName := aBinding.FileName;
  Result.StatementId := aStatementId;
  Result.Range := BindingRange(aBinding);
  Result.SemanticId := aBinding.SemanticId;
end;

procedure ApplyFinalStatementToStatement(
  const aFinalStatement: TDelphiSemanticRemoveWithFinalStatement;
  var aStatement: TDelphiSemanticRemoveWithStatement);
begin
  aStatement.FileName := aFinalStatement.FileName;
  aStatement.StatementId := aFinalStatement.StatementId;
  aStatement.Range := aFinalStatement.Range;
  aStatement.Status := aFinalStatement.Status;
  aStatement.Reason := aFinalStatement.Reason;
  aStatement.SafetyReason := aFinalStatement.SafetyReason;
  aStatement.SemanticId := aFinalStatement.SemanticId;
  aStatement.CoveredByStatementId := '';
end;

procedure RefreshSkippedStatementsFromStatements(
  var aPlan: TDelphiSemanticRemoveWithPlan);
var
  lIndex: Integer;
  lStatementIndex: Integer;
begin
  SetLength(aPlan.SkippedStatements, 0);
  for lStatementIndex := 0 to High(aPlan.Statements) do
  begin
    if not SameText(aPlan.Statements[lStatementIndex].Status, 'skipped') then
      Continue;
    lIndex := Length(aPlan.SkippedStatements);
    SetLength(aPlan.SkippedStatements, lIndex + 1);
    aPlan.SkippedStatements[lIndex] := SkippedStatementFromStatement(
      aPlan.Statements[lStatementIndex]);
  end;
end;

procedure RefreshStatementsFromBindings(var aPlan: TDelphiSemanticRemoveWithPlan;
  const aBindingSource: TRemoveWithPlanBindingSource;
  const aBindingTree: TFinalBindingTree);
var
  lBinding: TDelphiSemanticWithBinding;
  lBindingIndex: Integer;
  lCoveredByStatementId: string;
  lFinalStatement: TDelphiSemanticRemoveWithFinalStatement;
  lParentIndexes: TFinalBindingIndexArray;
  lStatement: TDelphiSemanticRemoveWithStatement;
  lStatementId: string;
begin
  lParentIndexes := FinalBindingParentIndexesFromTree(aBindingTree);
  SetLength(aPlan.Statements, aBindingSource.BindingCount);
  for lBindingIndex := 0 to aBindingSource.BindingCount - 1 do
  begin
    lBinding := aBindingSource.BindingByIndex(lBindingIndex);
    lStatementId := FinalStatementId(lBindingIndex + 1);
    lStatement := StatementFromBinding(lBinding, lStatementId);
    if FindFinalStatementById(aPlan, lStatementId, lFinalStatement) then
      ApplyFinalStatementToStatement(lFinalStatement, lStatement)
    else
    begin
      lCoveredByStatementId := CoveringFinalStatementId(aPlan, lParentIndexes,
        lBindingIndex);
      if lCoveredByStatementId <> '' then
      begin
        lStatement.Status := 'planned';
        lStatement.Reason := 'covered-by-parent-rewrite';
        lStatement.CoveredByStatementId := lCoveredByStatementId;
      end else
      begin
        lStatement.Status := 'skipped';
        lStatement.Reason := 'planner-status-unresolved';
        lStatement.SafetyReason :=
          'planner did not produce a final decision for this with statement';
      end;
    end;
    aPlan.Statements[lBindingIndex] := lStatement;
  end;
end;

function HasStableSourceRange(const aBinding: TDelphiSemanticWithBinding): Boolean;
begin
  Result := (Trim(aBinding.FileName) <> '') and TFile.Exists(aBinding.FileName) and
    (aBinding.Line > 0) and (aBinding.Column > 0) and (aBinding.EndLine >= aBinding.Line) and
    (aBinding.EndColumn > 0);
end;

function ParityRangeText(const aRange: TDelphiSemanticRemoveWithSourceRange): string;
begin
  Result := Format('%d:%d-%d:%d', [aRange.StartLine, aRange.StartColumn,
    aRange.EndLine, aRange.EndColumn]);
end;

function ParityTextDigest(const aText: string): string;
begin
  Result := Format('len=%d', [Length(aText)]);
end;

function ParityTextExcerpt(const aText: string): string;
begin
  Result := StringReplace(aText, sLineBreak, '\n', [rfReplaceAll]);
  Result := StringReplace(Result, #13, '\r', [rfReplaceAll]);
  Result := StringReplace(Result, #10, '\n', [rfReplaceAll]);
  if Length(Result) > 96 then
    Result := Copy(Result, 1, 96) + '...';
end;

function ParityFullPath(const aFileName: string): string;
begin
  Result := Trim(aFileName);
  if Result = '' then
    Exit;
  Result := TPath.GetFullPath(Result);
end;

function SameParityFile(const aLeft, aRight: string): Boolean;
begin
  Result := SameText(ParityFullPath(aLeft), ParityFullPath(aRight));
end;

function SameParityRange(const aLeft, aRight: TDelphiSemanticRemoveWithSourceRange): Boolean;
begin
  Result := (aLeft.StartLine = aRight.StartLine) and
    (aLeft.StartColumn = aRight.StartColumn) and
    (aLeft.EndLine = aRight.EndLine) and
    (aLeft.EndColumn = aRight.EndColumn);
end;

function RangeContainsRange(const aOuter, aInner: TDelphiSemanticRemoveWithSourceRange):
  Boolean;
begin
  Result := ((aOuter.StartLine < aInner.StartLine) or
    ((aOuter.StartLine = aInner.StartLine) and
    (aOuter.StartColumn <= aInner.StartColumn))) and
    ((aOuter.EndLine > aInner.EndLine) or
    ((aOuter.EndLine = aInner.EndLine) and
    (aOuter.EndColumn >= aInner.EndColumn)));
end;

function BindingContainsBinding(const aOuter, aInner: TDelphiSemanticWithBinding):
  Boolean;
begin
  Result := SameText(aOuter.FileName, aInner.FileName) and
    (not SameText(aOuter.SemanticId, aInner.SemanticId)) and
    RangeContainsRange(BindingRange(aOuter), BindingRange(aInner)) and
    (not SameParityRange(BindingRange(aOuter), BindingRange(aInner)));
end;

function TRemoveWithPlanBindingSource.BindingContainsBindingByIndex(
  const aOuterIndex, aInnerIndex: Integer): Boolean;
begin
  Result := BindingContainsBinding(BindingByIndex(aOuterIndex),
    BindingByIndex(aInnerIndex));
end;

function TRemoveWithPlanBindingSource.BindingHasStableSourceRange(
  const aIndex: Integer): Boolean;
begin
  Result := HasStableSourceRange(BindingByIndex(aIndex));
end;

procedure AddFinalBindingIndex(var aIndexes: TFinalBindingIndexArray;
  const aIndex: Integer);
var
  lIndex: Integer;
begin
  lIndex := Length(aIndexes);
  SetLength(aIndexes, lIndex + 1);
  aIndexes[lIndex] := aIndex;
end;

function CompareRangeStart(const aLeft, aRight: TDelphiSemanticRemoveWithSourceRange):
  Integer;
begin
  if aLeft.StartLine <> aRight.StartLine then
    Exit(aLeft.StartLine - aRight.StartLine);
  Result := aLeft.StartColumn - aRight.StartColumn;
end;

function CompareRangeEndDescending(const aLeft, aRight:
  TDelphiSemanticRemoveWithSourceRange): Integer;
begin
  if aLeft.EndLine <> aRight.EndLine then
    Exit(aRight.EndLine - aLeft.EndLine);
  Result := aRight.EndColumn - aLeft.EndColumn;
end;

function CompareFinalBindingInfo(const aLeft, aRight: TFinalBindingInfo): Integer;
begin
  Result := CompareText(aLeft.FileName, aRight.FileName);
  if Result <> 0 then
    Exit;
  Result := CompareRangeStart(aLeft.Range, aRight.Range);
  if Result <> 0 then
    Exit;
  Result := CompareRangeEndDescending(aLeft.Range, aRight.Range);
  if Result <> 0 then
    Exit;
  Result := aLeft.Index - aRight.Index;
end;

function RangeEndsBeforeRangeStart(const aLeft, aRight:
  TDelphiSemanticRemoveWithSourceRange): Boolean;
begin
  Result := (aLeft.EndLine < aRight.StartLine) or
    ((aLeft.EndLine = aRight.StartLine) and (aLeft.EndColumn < aRight.StartColumn));
end;

function FinalBindingInfoContains(const aOuter, aInner: TFinalBindingInfo): Boolean;
begin
  Result := SameText(aOuter.FileName, aInner.FileName) and
    (not SameText(aOuter.SemanticId, aInner.SemanticId)) and
    RangeContainsRange(aOuter.Range, aInner.Range) and
    (not SameParityRange(aOuter.Range, aInner.Range));
end;

function BuildFinalBindingInfos(
  const aBindingSource: TRemoveWithPlanBindingSource;
  const aLineCache: TDelphiSemanticSourceContextCache): TFinalBindingInfoArray;
var
  lBinding: TDelphiSemanticWithBinding;
  lBindingCount: Integer;
  lBindingIndex: Integer;
begin
  lBindingCount := aBindingSource.BindingCount;
  SetLength(Result, lBindingCount);
  for lBindingIndex := 0 to lBindingCount - 1 do
  begin
    lBinding := aBindingSource.BindingByIndex(lBindingIndex);
    Result[lBindingIndex].Index := lBindingIndex;
    Result[lBindingIndex].FileName := lBinding.FileName;
    Result[lBindingIndex].SemanticId := lBinding.SemanticId;
    Result[lBindingIndex].Range := BindingRange(lBinding);
    if Assigned(aLineCache) then
      TrimRangeBeforeOuterElse(lBinding, aLineCache, Result[lBindingIndex].Range);
  end;
end;

procedure PruneInactiveFinalBindingParents(var aActive: TFinalBindingInfoArray;
  var aActiveCount: Integer; const aCurrent: TFinalBindingInfo);
var
  i: Integer;
  lWriteIndex: Integer;
begin
  lWriteIndex := 0;
  for i := 0 to aActiveCount - 1 do
  begin
    if SameText(aActive[i].FileName, aCurrent.FileName) and
      (not RangeEndsBeforeRangeStart(aActive[i].Range, aCurrent.Range)) then
    begin
      aActive[lWriteIndex] := aActive[i];
      Inc(lWriteIndex);
    end;
  end;
  aActiveCount := lWriteIndex;
end;

function FindActiveFinalBindingParent(const aActive: TFinalBindingInfoArray;
  const aActiveCount: Integer; const aCurrent: TFinalBindingInfo): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := aActiveCount - 1 downto 0 do
  begin
    if FinalBindingInfoContains(aActive[i], aCurrent) then
      Exit(aActive[i].Index);
  end;
end;

function BuildFinalBindingParentIndexes(
  const aBindingInfos: TFinalBindingInfoArray): TFinalBindingIndexArray;
var
  lActive: TFinalBindingInfoArray;
  lActiveCount: Integer;
  lInfo: TFinalBindingInfo;
  lSorted: TFinalBindingInfoArray;
  i: Integer;
begin
  SetLength(Result, Length(aBindingInfos));
  for i := 0 to High(Result) do
    Result[i] := -1;

  lSorted := Copy(aBindingInfos);
  TArray.Sort<TFinalBindingInfo>(lSorted, TComparer<TFinalBindingInfo>.Construct(
    CompareFinalBindingInfo));

  SetLength(lActive, Length(lSorted));
  lActiveCount := 0;
  for lInfo in lSorted do
  begin
    PruneInactiveFinalBindingParents(lActive, lActiveCount, lInfo);
    Result[lInfo.Index] := FindActiveFinalBindingParent(lActive, lActiveCount, lInfo);
    lActive[lActiveCount] := lInfo;
    Inc(lActiveCount);
  end;
end;

function BuildFinalBindingTree(
  const aBindingSource: TRemoveWithPlanBindingSource;
  const aLineCache: TDelphiSemanticSourceContextCache): TFinalBindingTree;
var
  lBindingCount: Integer;
  lBindingIndex: Integer;
  lBindingInfos: TFinalBindingInfoArray;
  lParentIndex: Integer;
  lParentIndexes: TFinalBindingIndexArray;
begin
  Result := Default(TFinalBindingTree);
  lBindingCount := aBindingSource.BindingCount;
  lBindingInfos := BuildFinalBindingInfos(aBindingSource, aLineCache);
  lParentIndexes := BuildFinalBindingParentIndexes(lBindingInfos);
  Result.ParentIndexes := lParentIndexes;
  SetLength(Result.ChildIndexes, lBindingCount);
  for lBindingIndex := 0 to lBindingCount - 1 do
  begin
    lParentIndex := lParentIndexes[lBindingIndex];
    if lParentIndex < 0 then
      AddFinalBindingIndex(Result.RootIndexes, lBindingIndex)
    else
      AddFinalBindingIndex(Result.ChildIndexes[lParentIndex], lBindingIndex);
  end;
end;

procedure AddPartiallyVerifiedDescendants(var aPlan: TDelphiSemanticRemoveWithPlan;
  const aBindingSource: TRemoveWithPlanBindingSource;
  const aBindingTree: TFinalBindingTree; const aBindingIndex: Integer;
  const aReason, aSafetyReason: string;
  const aAdmissionRefusal: Boolean = False);
var
  lChildIndex, lEditIndex: Integer;
begin
  for lChildIndex in aBindingTree.ChildIndexes[aBindingIndex] do
  begin
    if aAdmissionRefusal then
      for lEditIndex := High(aPlan.Edits) downto 0 do
        if SameText(aPlan.Edits[lEditIndex].Kind, 'remove-with-candidate') and
          (aPlan.Edits[lEditIndex].StatementId =
          aBindingSource.BindingByIndex(lChildIndex).SemanticId) then
          Delete(aPlan.Edits, lEditIndex, 1);
    AddFinalStatement(aPlan, BuildSkippedFinalStatement(
      aBindingSource.BindingByIndex(lChildIndex), FinalStatementId(lChildIndex + 1),
      aReason, aSafetyReason));
    AddPartiallyVerifiedDescendants(aPlan, aBindingSource, aBindingTree, lChildIndex,
      aReason, aSafetyReason, aAdmissionRefusal);
  end;
end;

procedure AddFinalStatementTree(var aPlan: TDelphiSemanticRemoveWithPlan;
  const aFacts: TRemoveWithPlanFacts;
  const aBindingSource: TRemoveWithPlanBindingSource;
  const aBindingTree: TFinalBindingTree;
  const aCandidateEdits: TArray<TDelphiSemanticRemoveWithEdit>;
  const aSafetyReasons: TArray<string>;
  const aActivityUnverified, aMemberActivityUnverified,
  aInactiveNestedWithShadow: TArray<Boolean>;
  const aBindingIndex: Integer;
  const aReservedNames: TDictionary<string, Integer>;
  const aLineCache: TDelphiSemanticSourceContextCache;
  const aInheritedDecisions: TArray<TFinalSelectorDecision>);
var
  lPartialIndexedReceiver: Boolean;
  lProvisionalNames: TDictionary<string, Integer>;
  lReservedName: TPair<string, Integer>;
  lChildIndex: Integer;
  lChildInheritedDecisions: TArray<TFinalSelectorDecision>;
  lBodyFacts: TFinalReceiverBodyFacts;
  lDecision: TFinalSelectorDecision;
  lIndex: Integer;
  lBinding: TDelphiSemanticWithBinding;
  lSelector: TDelphiSemanticWithSelectorBinding;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lBodyFacts := Default(TFinalReceiverBodyFacts);
  lBinding := aBindingSource.BindingByIndex(aBindingIndex);
  if aSafetyReasons[aBindingIndex] <> '' then
  begin
    lStatement := BuildSkippedFinalStatement(lBinding,
      FinalStatementId(aBindingIndex + 1),
      LowerCase(StringReplace(aSafetyReasons[aBindingIndex], '_', '-', [rfReplaceAll])),
      aSafetyReasons[aBindingIndex]);
  end else
  begin
    // Keep every provisional reservation private, including absorbed children.
    // A refused tree cannot consume a sibling's temp name or counter.
    lProvisionalNames := TDictionary<string, Integer>.Create;
    try
      for lReservedName in aReservedNames do
        lProvisionalNames.Add(lReservedName.Key, lReservedName.Value);
      lStatement := BuildFinalStatement(aFacts, aBindingSource, aBindingTree,
        aBindingIndex, FinalStatementId(aBindingIndex + 1), aCandidateEdits,
        lProvisionalNames, aLineCache, aInheritedDecisions,
        not (aMemberActivityUnverified[aBindingIndex] or
        aActivityUnverified[aBindingIndex] or aInactiveNestedWithShadow[aBindingIndex]),
        lBodyFacts);
    finally
      lProvisionalNames.Free;
    end;
  end;
  // DS-740 runs in the same render pass, only when no activity refusal is pending.
  // Existing selector and renderer refusals still precede its context check.
  // Compute the complete ordinary DTO, including nested rewrites.
  // Activity changes only an otherwise applicable result; existing refusals
  // retain exactly their own Status, Reason and SafetyReason.
  // D5 cannot replace the existing member-activity refusal it interrupted.
  if aMemberActivityUnverified[aBindingIndex] and
    (SameText(lStatement.Status, 'planned') or
     ((lBodyFacts.LineageDenialReason <> '') and
      SameText(lStatement.SafetyReason, lBodyFacts.LineageDenialReason))) then
  begin
    RollbackReservedTempNamesForFinalTemps(aReservedNames, lBinding.RoutineName,
      lStatement.Temps);
    lStatement := BuildSkippedFinalStatement(lBinding, FinalStatementId(aBindingIndex + 1),
      'members-unverified', 'MEMBERS_UNVERIFIED');
  end;
  if aActivityUnverified[aBindingIndex] and SameText(lStatement.Status, 'planned') then
  begin
    RollbackReservedTempNamesForFinalTemps(aReservedNames, lBinding.RoutineName,
      lStatement.Temps);
    lStatement := BuildSkippedFinalStatement(lBinding,
      FinalStatementId(aBindingIndex + 1), 'activity-unverified', 'ACTIVITY_UNVERIFIED');
  end;
  // DS-724: established selector, renderer and activity refusals retain precedence.
  if aInactiveNestedWithShadow[aBindingIndex] and SameText(lStatement.Status, 'planned') then
  begin
    RollbackReservedTempNamesForFinalTemps(aReservedNames, lBinding.RoutineName,
      lStatement.Temps);
    lStatement := BuildSkippedFinalStatement(lBinding, FinalStatementId(aBindingIndex + 1),
      'inactive-nested-with-shadowing', 'INACTIVE_NESTED_WITH_SHADOW');
  end;
  // A2.3a: ordinary selector, renderer and activity reasons retain precedence.
  if SameText(lStatement.Status, 'planned') and lBodyFacts.StrategyKindContradiction then
  begin
    RollbackReservedTempNamesForFinalTemps(aReservedNames, lBinding.RoutineName,
      lStatement.Temps);
    lStatement := BuildSkippedFinalStatement(lBinding, FinalStatementId(aBindingIndex + 1),
      'receiver-type-not-visible', 'receiver-type-not-visible');
  end;
  ApplyReceiverAdmission(aBindingSource, aBindingTree, aBindingIndex,
    lStatement, lBodyFacts);
  if SameText(lStatement.Status, 'planned') then
    for lIndex := 0 to High(lStatement.Temps) do
      aReservedNames.AddOrSetValue(lBinding.RoutineName + #31 +
        lStatement.Temps[lIndex].TempName, 1);
  if lBodyFacts.CaptureDenied then
    for lIndex := High(aPlan.Edits) downto 0 do
      if SameText(aPlan.Edits[lIndex].Kind, 'remove-with-candidate') and
        (aPlan.Edits[lIndex].StatementId = lBinding.SemanticId) then
        Delete(aPlan.Edits, lIndex, 1);
  AddFinalStatement(aPlan, lStatement);
  if SameText(lStatement.Status, 'planned') then
    Exit;

  // A5: a retained admission-refused receiver can capture any descendant name.
  // Only this binding's own admission refusal creates the barrier; a recursive
  // child's refusal does not turn its admitted ancestors into barriers.
  if lBodyFacts.AdmissionDenied then
  begin
    AddPartiallyVerifiedDescendants(aPlan, aBindingSource, aBindingTree, aBindingIndex,
      'enclosing-admission-refusal:' + lStatement.Reason, lStatement.SafetyReason, True);
    Exit;
  end;

  lPartialIndexedReceiver := False;
  if SameText(lStatement.SafetyReason, 'OWNER_INHERITED_MEMBERS_UNVERIFIED') then
    for lSelector in lBinding.Selectors do
      if aFacts.LookupIndex.UnverifiedReceiverMemberMayApply(lSelector.TypeName, '',
        lSelector.TypeIdentity) then
        lPartialIndexedReceiver := True;
  // A missing indexed ancestor body retains DS-731's descendant barrier even
  // when DS-742 detects the failure first and changes its refusal reason.
  if SameText(lStatement.SafetyReason, 'RECEIVER_MEMBERS_PARTIALLY_VERIFIED') or
    lPartialIndexedReceiver then
  begin
    AddPartiallyVerifiedDescendants(aPlan, aBindingSource, aBindingTree, aBindingIndex,
      lStatement.Reason, lStatement.SafetyReason);
    Exit;
  end;

  lChildInheritedDecisions := Copy(aInheritedDecisions);
  if SameText(lStatement.Reason, 'selector-type-not-resolved') and
    (Pos('[', lBinding.SelectorText) > 0) then
  begin
    lDecision := Default(TFinalSelectorDecision);
    lDecision.SelectorText := lBinding.SelectorText;
    lDecision.Strategy := 'direct-qualification';
    lDecision.Reason := 'skipped-parent-context';
    lIndex := Length(lChildInheritedDecisions);
    SetLength(lChildInheritedDecisions, lIndex + 1);
    lChildInheritedDecisions[lIndex] := lDecision;
  end;
  for lSelector in lBinding.Selectors do
  begin
    if not SelectorTextDeclaredInBinding(lBinding.SelectorText,
      lSelector.SelectorText) then
      Continue;
    lDecision := Default(TFinalSelectorDecision);
    lDecision.SelectorText := lSelector.SelectorText;
    lDecision.QualifierText := lSelector.SelectorText;
    lDecision.Strategy := 'direct-qualification';
    lDecision.Reason := 'skipped-parent-context';
    // An ambiguous, unresolved or untyped parent receiver may still own any name
    // a child uses. It stays in the context without a receiver type or identity,
    // so the dependent-selector gate refuses the children instead of letting a
    // homonym outside the with bind their receivers.
    if SameText(lSelector.Status, 'resolved') and (Trim(lSelector.TypeName) <> '') then
    begin
      lDecision.ReceiverType := lSelector.TypeName;
      lDecision.ReceiverIdentity := lSelector.TypeIdentity;
    end;
    lIndex := Length(lChildInheritedDecisions);
    SetLength(lChildInheritedDecisions, lIndex + 1);
    lChildInheritedDecisions[lIndex] := lDecision;
  end;

  for lChildIndex in aBindingTree.ChildIndexes[aBindingIndex] do
  begin
    if (aSafetyReasons[lChildIndex] <> '') or
      aBindingSource.BindingHasStableSourceRange(lChildIndex) then
      AddFinalStatementTree(aPlan, aFacts, aBindingSource, aBindingTree,
        aCandidateEdits, aSafetyReasons, aActivityUnverified, aMemberActivityUnverified,
        aInactiveNestedWithShadow, lChildIndex, aReservedNames, aLineCache,
        lChildInheritedDecisions);
  end;
end;

function FinalStatementsFromPlan(const aPlan: TDelphiSemanticRemoveWithPlan):
  TArray<TDelphiSemanticRemoveWithPlanParityStatement>;
var
  i: Integer;
  lEdit: TDelphiSemanticRemoveWithFinalTextEdit;
  lIndex: Integer;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  SetLength(Result, Length(aPlan.FinalStatements));
  for lIndex := 0 to High(aPlan.FinalStatements) do
  begin
    lStatement := aPlan.FinalStatements[lIndex];
    Result[lIndex].StatementId := lStatement.StatementId;
    Result[lIndex].FileName := lStatement.FileName;
    Result[lIndex].Status := lStatement.Status;
    Result[lIndex].Reason := lStatement.Reason;
    Result[lIndex].UnsupportedIdentifierRole := lStatement.UnsupportedIdentifierRole;
    Result[lIndex].ReplacementText := lStatement.ReplacementText;
    SetLength(Result[lIndex].Edits, Length(lStatement.Edits));
    for i := 0 to High(lStatement.Edits) do
    begin
      lEdit := lStatement.Edits[i];
      Result[lIndex].Edits[i].Kind := lEdit.Kind;
      Result[lIndex].Edits[i].FileName := lEdit.FileName;
      Result[lIndex].Edits[i].StatementId := lEdit.StatementId;
      Result[lIndex].Edits[i].Range := lEdit.Range;
      Result[lIndex].Edits[i].ReplacementText := lEdit.ReplacementText;
    end;
  end;
end;

procedure AddParityMismatch(var aReport: TDelphiSemanticRemoveWithPlanParityReport;
  const aMismatch: TDelphiSemanticRemoveWithPlanParityMismatch);
var
  lIndex: Integer;
begin
  lIndex := Length(aReport.Mismatches);
  SetLength(aReport.Mismatches, lIndex + 1);
  aReport.Mismatches[lIndex] := aMismatch;
  aReport.MismatchCount := Length(aReport.Mismatches);
end;

function FindParityStatement(const aStatements: TArray<TDelphiSemanticRemoveWithPlanParityStatement>;
  const aExpected: TDelphiSemanticRemoveWithPlanParityStatement;
  out aActual: TDelphiSemanticRemoveWithPlanParityStatement): Boolean;
var
  lStatement: TDelphiSemanticRemoveWithPlanParityStatement;
begin
  Result := False;
  aActual := Default(TDelphiSemanticRemoveWithPlanParityStatement);
  for lStatement in aStatements do
  begin
    if SameText(lStatement.StatementId, aExpected.StatementId) and
      SameParityFile(lStatement.FileName, aExpected.FileName) then
    begin
      aActual := lStatement;
      Exit(True);
    end;
  end;
end;

procedure AddStatementMismatch(var aReport: TDelphiSemanticRemoveWithPlanParityReport;
  const aKind: string; const aExpected, aActual: TDelphiSemanticRemoveWithPlanParityStatement);
var
  lMismatch: TDelphiSemanticRemoveWithPlanParityMismatch;
begin
  lMismatch := Default(TDelphiSemanticRemoveWithPlanParityMismatch);
  lMismatch.Kind := aKind;
  lMismatch.StatementId := aExpected.StatementId;
  lMismatch.FileName := aExpected.FileName;
  lMismatch.ExpectedStatus := aExpected.Status;
  lMismatch.ActualStatus := aActual.Status;
  lMismatch.Reason := aExpected.Reason;
  lMismatch.ReplacementTextDigest := ParityTextDigest(aExpected.ReplacementText);
  lMismatch.ReplacementTextExcerpt := ParityTextExcerpt(aExpected.ReplacementText);
  lMismatch.Message := Format('%s statement=%s file=%s status=%s actualStatus=%s reason=%s actualReason=%s replacement=%s excerpt="%s"',
    [aKind, lMismatch.StatementId, lMismatch.FileName, lMismatch.ExpectedStatus,
    lMismatch.ActualStatus, lMismatch.Reason, aActual.Reason, lMismatch.ReplacementTextDigest,
    lMismatch.ReplacementTextExcerpt]);
  AddParityMismatch(aReport, lMismatch);
end;

procedure AddEditMismatch(var aReport: TDelphiSemanticRemoveWithPlanParityReport;
  const aKind: string; const aExpectedStatement: TDelphiSemanticRemoveWithPlanParityStatement;
  const aExpectedEdit: TDelphiSemanticRemoveWithPlanParityEdit);
var
  lMismatch: TDelphiSemanticRemoveWithPlanParityMismatch;
begin
  lMismatch := Default(TDelphiSemanticRemoveWithPlanParityMismatch);
  lMismatch.Kind := aKind;
  lMismatch.StatementId := aExpectedStatement.StatementId;
  lMismatch.FileName := aExpectedEdit.FileName;
  lMismatch.ExpectedStatus := aExpectedStatement.Status;
  lMismatch.Reason := aExpectedStatement.Reason;
  lMismatch.EditKind := aExpectedEdit.Kind;
  lMismatch.EditRange := ParityRangeText(aExpectedEdit.Range);
  lMismatch.ReplacementTextDigest := ParityTextDigest(aExpectedEdit.ReplacementText);
  lMismatch.ReplacementTextExcerpt := ParityTextExcerpt(aExpectedEdit.ReplacementText);
  lMismatch.Message := Format('%s statement=%s file=%s status=%s reason=%s edit=%s range=%s replacement=%s excerpt="%s"',
    [aKind, lMismatch.StatementId, lMismatch.FileName, lMismatch.ExpectedStatus,
    lMismatch.Reason, lMismatch.EditKind, lMismatch.EditRange,
    lMismatch.ReplacementTextDigest, lMismatch.ReplacementTextExcerpt]);
  AddParityMismatch(aReport, lMismatch);
end;

procedure AddEditReplacementMismatch(var aReport: TDelphiSemanticRemoveWithPlanParityReport;
  const aExpectedStatement: TDelphiSemanticRemoveWithPlanParityStatement;
  const aExpectedEdit, aActualEdit: TDelphiSemanticRemoveWithPlanParityEdit);
var
  lMismatch: TDelphiSemanticRemoveWithPlanParityMismatch;
begin
  lMismatch := Default(TDelphiSemanticRemoveWithPlanParityMismatch);
  lMismatch.Kind := 'replacement-text-mismatch';
  lMismatch.StatementId := aExpectedEdit.StatementId;
  lMismatch.FileName := aExpectedEdit.FileName;
  lMismatch.ExpectedStatus := aExpectedStatement.Status;
  lMismatch.Reason := aExpectedStatement.Reason;
  lMismatch.EditKind := aExpectedEdit.Kind;
  lMismatch.EditRange := ParityRangeText(aExpectedEdit.Range);
  lMismatch.ReplacementTextDigest := ParityTextDigest(aExpectedEdit.ReplacementText);
  lMismatch.ReplacementTextExcerpt := ParityTextExcerpt(aExpectedEdit.ReplacementText);
  lMismatch.Message := Format('%s statement=%s file=%s status=%s reason=%s edit=%s range=%s replacement=%s excerpt="%s" actualReplacement=%s actualExcerpt="%s"',
    [lMismatch.Kind, lMismatch.StatementId, lMismatch.FileName, lMismatch.ExpectedStatus,
    lMismatch.Reason, lMismatch.EditKind, lMismatch.EditRange,
    lMismatch.ReplacementTextDigest, lMismatch.ReplacementTextExcerpt,
    ParityTextDigest(aActualEdit.ReplacementText), ParityTextExcerpt(aActualEdit.ReplacementText)]);
  AddParityMismatch(aReport, lMismatch);
end;

function FindParityEdit(const aEdits: TArray<TDelphiSemanticRemoveWithPlanParityEdit>;
  const aExpected: TDelphiSemanticRemoveWithPlanParityEdit;
  out aActual: TDelphiSemanticRemoveWithPlanParityEdit): Boolean;
var
  lEdit: TDelphiSemanticRemoveWithPlanParityEdit;
begin
  Result := False;
  aActual := Default(TDelphiSemanticRemoveWithPlanParityEdit);
  for lEdit in aEdits do
  begin
    if SameText(lEdit.Kind, aExpected.Kind) and
      SameParityFile(lEdit.FileName, aExpected.FileName) and
      SameParityRange(lEdit.Range, aExpected.Range) then
    begin
      aActual := lEdit;
      Exit(True);
    end;
  end;
end;

procedure CompareParityEdits(var aReport: TDelphiSemanticRemoveWithPlanParityReport;
  const aExpectedStatement, aActualStatement: TDelphiSemanticRemoveWithPlanParityStatement);
var
  lActualEdit: TDelphiSemanticRemoveWithPlanParityEdit;
  lExpectedEdit: TDelphiSemanticRemoveWithPlanParityEdit;
begin
  for lExpectedEdit in aExpectedStatement.Edits do
  begin
    if not FindParityEdit(aActualStatement.Edits, lExpectedEdit, lActualEdit) then
    begin
      AddEditMismatch(aReport, 'missing-final-edit', aExpectedStatement, lExpectedEdit);
      Continue;
    end;
    if lActualEdit.ReplacementText <> lExpectedEdit.ReplacementText then
      AddEditReplacementMismatch(aReport, aExpectedStatement, lExpectedEdit, lActualEdit);
  end;
  for lActualEdit in aActualStatement.Edits do
  begin
    if not FindParityEdit(aExpectedStatement.Edits, lActualEdit, lExpectedEdit) then
      AddEditMismatch(aReport, 'unexpected-final-edit', aActualStatement, lActualEdit);
  end;
end;

function BuildParitySummary(const aReport: TDelphiSemanticRemoveWithPlanParityReport): string;
var
  lBuilder: TStringBuilder;
  lMismatch: TDelphiSemanticRemoveWithPlanParityMismatch;
begin
  lBuilder := TStringBuilder.Create;
  try
    lBuilder.AppendFormat('mismatches=%d', [aReport.MismatchCount]);
    for lMismatch in aReport.Mismatches do
      lBuilder.AppendLine.Append(lMismatch.Message);
    Result := lBuilder.ToString;
  finally
    lBuilder.Free;
  end;
end;

procedure CompleteCorePlanMetrics(
  var aMetrics: TDelphiSemanticRemoveWithPlannerMetrics;
  const aElapsedMilliseconds: Int64;
  const aLookupIndex: TPlannerLookupMemo);
var
  lAccountedMilliseconds: Int64;
begin
  aMetrics.CorePlanMilliseconds := aElapsedMilliseconds;
  lAccountedMilliseconds := aMetrics.CandidateEditMilliseconds +
    aMetrics.BindingTreeMilliseconds + aMetrics.DecisionMilliseconds +
    aMetrics.RoutineDeclarationMilliseconds +
    aMetrics.StatementRefreshMilliseconds;
  if aMetrics.CorePlanMilliseconds > lAccountedMilliseconds then
    aMetrics.CorePlanUnattributedMilliseconds :=
      aMetrics.CorePlanMilliseconds - lAccountedMilliseconds
  else
    aMetrics.CorePlanUnattributedMilliseconds := 0;
  aMetrics.LookupRequestCount := aLookupIndex.RequestCount;
  aMetrics.LookupResultMaterializationCount :=
    aLookupIndex.ResultMaterializationCount;
  aMetrics.LookupResultReuseCount := aLookupIndex.ResultReuseCount;
  aMetrics.LookupMaterializedSymbolCount :=
    aLookupIndex.MaterializedSymbolCount;
end;

function PlanFromBindingSource(const aFacts: TRemoveWithPlanFacts;
  const aBindingSource: TRemoveWithPlanBindingSource;
  const aModelVersion: string;
  var aMetrics: TDelphiSemanticRemoveWithPlannerMetrics):
  TDelphiSemanticRemoveWithPlan;
var
  lBinding: TDelphiSemanticWithBinding;
  lBindingCount: Integer;
  lBindingTree: TFinalBindingTree;
  lBindingIndex: Integer;
  lCandidateEdits: TArray<TDelphiSemanticRemoveWithEdit>;
  lEdit: TDelphiSemanticRemoveWithEdit;
  lFinalStatement: TDelphiSemanticRemoveWithFinalStatement;
  lHashCache: TDictionary<string, string>;
  lHasPlannedStatement: Boolean;
  lInheritedDecisions: TArray<TFinalSelectorDecision>;
  lLineCache: TDelphiSemanticSourceContextCache;
  lParentIndex: Integer;
  lCoreStopwatch: TStopwatch;
  lPhaseStopwatch: TStopwatch;
  lReservedNames: TDictionary<string, Integer>;
  lRootIndex: Integer;
  lRetainedEditCount: Integer;
  lRejectedCandidate: Boolean;
  lSafetyReasons: TArray<string>;
  lActivityUnverified, lMemberActivityUnverified, lInactiveNestedWithShadow: TArray<Boolean>;
  lSafetyReason: string;
  lStatementIndex: Integer;
begin
  lCoreStopwatch := TStopwatch.StartNew;
  try
    Result := Default(TDelphiSemanticRemoveWithPlan);
    Result.Operation := 'remove-with';
    Result.Status := 'planned';
    Result.ContextFingerprint := aFacts.ContextFingerprint;
    Result.BaselineSemanticModelVersion := aModelVersion;

    AddVerification(Result, 'baseline-compile',
      'Compile the project before source-changing apply.');
    AddVerification(Result, 'context-fingerprint',
      'Apply only when the semantic context fingerprint still matches.');
    AddVerification(Result, 'source-range',
      'Apply only when expected file hashes and source ranges still match.');
    AddVerification(Result, 'post-edit-compile',
      'Compile the project after source-changing apply.');
    AddVerification(Result, 'rollback-on-failure',
      'Rollback edited files when post-edit verification fails.');

    if Result.ContextFingerprint = '' then
    begin
      Result.Status := 'blocked';
      Result.Diagnostic := 'Missing semantic context fingerprint.';
      Exit;
    end;

    lHashCache := TDictionary<string, string>.Create;
    lLineCache := TDelphiSemanticSourceContextCache.Create;
    lReservedNames := TDictionary<string, Integer>.Create;
    try
      lBindingCount := aBindingSource.BindingCount;
      lPhaseStopwatch := TStopwatch.StartNew;
      try
        lBindingTree := BuildFinalBindingTree(aBindingSource, lLineCache);
      finally
        lPhaseStopwatch.Stop;
        aMetrics.BindingTreeMilliseconds :=
          lPhaseStopwatch.ElapsedMilliseconds;
      end;
      SetLength(lSafetyReasons, lBindingCount);
      SetLength(lActivityUnverified, lBindingCount);
      SetLength(lMemberActivityUnverified, lBindingCount);
      SetLength(lInactiveNestedWithShadow, lBindingCount);
      for lBindingIndex := 0 to lBindingCount - 1 do
      begin
        lBinding := aBindingSource.BindingByIndex(lBindingIndex);
        if lBinding.InactiveSpanSkipReason = 'INACTIVE_NESTED_WITH_SHADOW' then
        begin
          lInactiveNestedWithShadow[lBindingIndex] := True;
          lParentIndex := lBindingTree.ParentIndexes[lBindingIndex];
          while lParentIndex >= 0 do
          begin
            lInactiveNestedWithShadow[lParentIndex] := True;
            lParentIndex := lBindingTree.ParentIndexes[lParentIndex];
          end;
        end;
        if lBinding.MemberActivityUnverified then
        begin
          lMemberActivityUnverified[lBindingIndex] := True;
          lParentIndex := lBindingTree.ParentIndexes[lBindingIndex];
          while lParentIndex >= 0 do
          begin
            lMemberActivityUnverified[lParentIndex] := True;
            lParentIndex := lBindingTree.ParentIndexes[lParentIndex];
          end;
        end;
        if MatchText(lBinding.SkipReason,
          ['MEMBERS_UNVERIFIED', 'MEMBERS_INCOMPLETE', 'SCOPE_UNVERIFIED']) and
          (not lBinding.MemberActivityUnverified) then
        begin
          if lSafetyReasons[lBindingIndex] = '' then
            lSafetyReasons[lBindingIndex] := lBinding.SkipReason;
          lParentIndex := lBindingTree.ParentIndexes[lBindingIndex];
          while lParentIndex >= 0 do
          begin
            if lSafetyReasons[lParentIndex] = '' then
              lSafetyReasons[lParentIndex] := lBinding.SkipReason;
            lParentIndex := lBindingTree.ParentIndexes[lParentIndex];
          end;
        end;
        if not (lBinding.ActivityUnverified or
          SameText(lBinding.SkipReason, 'ACTIVITY_UNVERIFIED')) then
          Continue;
        lActivityUnverified[lBindingIndex] := True;
        lParentIndex := lBindingTree.ParentIndexes[lBindingIndex];
        while lParentIndex >= 0 do
        begin
          // A parent replacement covers its child's source, so activity is
          // propagated independently of ordinary member/scope refusals.
          lActivityUnverified[lParentIndex] := True;
          lParentIndex := lBindingTree.ParentIndexes[lParentIndex];
        end;
      end;
      // A refused range retains its original scopes. No contained WITH may
      // independently rewrite that text after the covering statement refuses.
      for lBindingIndex := 0 to lBindingCount - 1 do
      begin
        lParentIndex := lBindingTree.ParentIndexes[lBindingIndex];
        while lParentIndex >= 0 do
        begin
          if lInactiveNestedWithShadow[lParentIndex] then
          begin
            lInactiveNestedWithShadow[lBindingIndex] := True;
            Break;
          end;
          lParentIndex := lBindingTree.ParentIndexes[lParentIndex];
        end;
      end;
      lPhaseStopwatch := TStopwatch.StartNew;
      try
        lStatementIndex := 0;
        SetLength(lCandidateEdits, lBindingCount);
        for lBindingIndex := 0 to lBindingCount - 1 do
        begin
          lBinding := aBindingSource.BindingByIndex(lBindingIndex);
          Inc(lStatementIndex);
          if lSafetyReasons[lBindingIndex] <> '' then
            Continue
          else if aBindingSource.BindingHasStableSourceRange(lBindingIndex) then
          begin
            lEdit := AddEdit(Result, lBinding, lHashCache, lLineCache);
            lCandidateEdits[lBindingIndex] := lEdit;
            // Keep the candidate for the ordinary decision, but never expose
            // an activity-refused source range as candidate apply coverage.
            if lActivityUnverified[lBindingIndex] or lMemberActivityUnverified[lBindingIndex] then
              SetLength(Result.Edits, Length(Result.Edits) - 1);
          end else
          begin
            AddFinalStatement(Result, BuildSkippedFinalStatement(lBinding,
              FinalStatementId(lStatementIndex), 'SOURCE_RANGE_UNAVAILABLE',
              'stable source file, hash, and source range are required'));
          end;
        end;
      finally
        lPhaseStopwatch.Stop;
        aMetrics.CandidateEditMilliseconds :=
          lPhaseStopwatch.ElapsedMilliseconds;
      end;
      lPhaseStopwatch := TStopwatch.StartNew;
      try
        for lRootIndex in lBindingTree.RootIndexes do
        begin
          lBinding := aBindingSource.BindingByIndex(lRootIndex);
          if (lSafetyReasons[lRootIndex] <> '') or
            aBindingSource.BindingHasStableSourceRange(lRootIndex) then
          begin
            lInheritedDecisions := nil;
            AddFinalStatementTree(Result, aFacts, aBindingSource, lBindingTree,
              lCandidateEdits, lSafetyReasons, lActivityUnverified, lMemberActivityUnverified,
              lInactiveNestedWithShadow, lRootIndex, lReservedNames, lLineCache,
              lInheritedDecisions);
          end;
        end;
      finally
        lPhaseStopwatch.Stop;
        aMetrics.DecisionMilliseconds := lPhaseStopwatch.ElapsedMilliseconds;
      end;
      lPhaseStopwatch := TStopwatch.StartNew;
      try
        // Refused qualifications cannot remain as candidate apply coverage.
        lRetainedEditCount := 0;
        for lEdit in Result.Edits do
        begin
          lRejectedCandidate := False;
          if SameText(lEdit.Kind, 'remove-with-candidate') then
            for lFinalStatement in Result.FinalStatements do
              if (SameText(lFinalStatement.Reason, 'receiver-member-owner-conflict') or
                SameText(lFinalStatement.Reason, 'receiver-member-unqualified') or
                SameText(lFinalStatement.SafetyReason, 'TYPE_VISIBILITY_UNPROVED') or
                SameText(lFinalStatement.SafetyReason, 'TYPE_VALUE_MEMBERS_UNVERIFIED') or
                SameText(lFinalStatement.SafetyReason, 'RECEIVER_MEMBERS_PARTIALLY_VERIFIED') or
                SameText(lFinalStatement.SafetyReason, 'RECORD_HELPER_MEMBERS_UNVERIFIED') or
                SameText(lFinalStatement.SafetyReason, 'ALIAS_RECEIVER_MEMBERS_UNVERIFIED') or
                SameText(lFinalStatement.SafetyReason, 'OWNER_INHERITED_MEMBERS_UNVERIFIED') or
                SameText(lFinalStatement.SafetyReason, 'ROUTINE_LOCAL_TYPE_UNSUPPORTED') or
                SameText(lFinalStatement.SafetyReason, 'INACTIVE_NESTED_WITH_SHADOW')) and
                (lFinalStatement.SemanticId = lEdit.StatementId) then
              begin
                lRejectedCandidate := True;
                Break;
              end;
          if lRejectedCandidate then
            Continue;
          Result.Edits[lRetainedEditCount] := lEdit;
          Inc(lRetainedEditCount);
        end;
        SetLength(Result.Edits, lRetainedEditCount);
        AddRoutineDeclarationEdits(Result, lLineCache, lHashCache);
      finally
        lPhaseStopwatch.Stop;
        aMetrics.RoutineDeclarationMilliseconds :=
          lPhaseStopwatch.ElapsedMilliseconds;
      end;
      lPhaseStopwatch := TStopwatch.StartNew;
      try
        RefreshStatementsFromBindings(Result, aBindingSource, lBindingTree);
        RefreshSkippedStatementsFromStatements(Result);
        lHasPlannedStatement := False;
        lSafetyReason := '';
        for lFinalStatement in Result.FinalStatements do
        begin
          if SameText(lFinalStatement.Status, 'planned') then
            lHasPlannedStatement := True;
          if (lSafetyReason = '') and
            (SameText(lFinalStatement.SafetyReason, 'MEMBERS_UNVERIFIED') or
            SameText(lFinalStatement.SafetyReason, 'MEMBERS_INCOMPLETE')) then
            lSafetyReason := lFinalStatement.SafetyReason;
        end;
        if (not lHasPlannedStatement) and (lSafetyReason <> '') then
        begin
          Result.Status := 'blocked';
          Result.Diagnostic := lSafetyReason + ': no verified WITH statement can be planned.';
        end;
      finally
        lPhaseStopwatch.Stop;
        aMetrics.StatementRefreshMilliseconds :=
          lPhaseStopwatch.ElapsedMilliseconds;
      end;
    finally
      lReservedNames.Free;
      lLineCache.Free;
      lHashCache.Free;
    end;
  finally
    lCoreStopwatch.Stop;
    CompleteCorePlanMetrics(aMetrics, lCoreStopwatch.ElapsedMilliseconds,
      aFacts.LookupIndex);
  end;
end;

function UnverifiedFactsReason(const aFacts: TDelphiSemanticProjectWithBindingFacts): string;
var
  lBinding: TDelphiSemanticWithBinding;
  lModel: TDelphiSemanticUnitModel;
  lUnsafeCount: Integer;
begin
  Result := '';
  lUnsafeCount := 0;
  for lModel in aFacts.UnitModels do
    if SameText(lModel.ScopeModelStatus, 'include-with-unverified') and
      (Length(aFacts.Bindings) = 0) then
      Exit('WITH_IN_INCLUDE_UNVERIFIED: ' + lModel.FileName);
  for lBinding in aFacts.Bindings do
    for lModel in aFacts.UnitModels do
      if SameText(lBinding.FileName, lModel.FileName) and
        not SameText(lModel.ScopeModelStatus, 'ast') then
      begin
        Inc(lUnsafeCount);
        if Result = '' then
          Result := 'SCOPE_UNVERIFIED: ' + lModel.FileName + ' (' +
            lModel.ScopeModelStatus + ')';
        Break;
      end;
  if lUnsafeCount <> Length(aFacts.Bindings) then
    Result := '';
end;

class function TDelphiSemanticRemoveWithPlanner.Plan(
  const aFacts: TDelphiSemanticProjectWithBindingFacts): TDelphiSemanticRemoveWithPlan;
var
  i: Integer;
  j: Integer;
  lBinding: TDelphiSemanticWithBinding;
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lBindingSource: TArrayRemoveWithPlanBindingSource;
  lMetrics: TDelphiSemanticRemoveWithPlannerMetrics;
  lModel: TDelphiSemanticUnitModel;
  lPlanFacts: TRemoveWithPlanFacts;
  lSafetyReason: string;
begin
  lSafetyReason := UnverifiedFactsReason(aFacts);
  if lSafetyReason <> '' then
  begin
    Result := Default(TDelphiSemanticRemoveWithPlan);
    Result.Operation := 'remove-with';
    Result.Status := 'blocked';
    Result.Diagnostic := lSafetyReason;
    Result.ContextFingerprint := aFacts.ContextFingerprint;
    Result.BaselineSemanticModelVersion := 'project-with-binding-v1';
    Exit;
  end;
  lMetrics := Default(TDelphiSemanticRemoveWithPlannerMetrics);
  lPlanFacts := Default(TRemoveWithPlanFacts);
  lPlanFacts.ContextFingerprint := aFacts.ContextFingerprint;
  lPlanFacts.Symbols := aFacts.Symbols;
  lPlanFacts.UseArchitectureStableRoutineEndTrim := True;
  lBindingSource := nil;
  try
    lPlanFacts.ScanSources := TDictionary<string, string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
    lPlanFacts.ControlSources := TDictionary<string, string>.Create(
      TFastCaseAwareComparer.OrdinalIgnoreCase);
    lPlanFacts.ControlTokens := TDictionary<string, TArray<TControlContextToken>>.Create(
      TFastCaseAwareComparer.OrdinalIgnoreCase);
    lPlanFacts.ScanActivityKnown := TDictionary<string, Boolean>.Create(
      TFastCaseAwareComparer.OrdinalIgnoreCase);
    lPlanFacts.ScanLines := TDictionary<string, TArray<string>>.Create(
      TFastCaseAwareComparer.OrdinalIgnoreCase);
    for lModel in aFacts.UnitModels do
    begin
      lPlanFacts.ControlSources.AddOrSetValue(lModel.FileName, lModel.SourceText);
      lPlanFacts.ScanActivityKnown.AddOrSetValue(lModel.FileName,
        AnonymousRecordActivityIsKnown(lModel.SourceText, lModel.VerifiedActiveSourceText));
      lPlanFacts.ScanSources.AddOrSetValue(lModel.FileName,
        AnonymousRecordScanSource(lModel.SourceText,
          lModel.VerifiedActiveSourceText));
    end;
    lPlanFacts.LookupIndex := TPlannerLookupMemo.Create;
    lPlanFacts.LookupIndex.Initialize(aFacts.LookupIndex);
    lPlanFacts.UnitVisibility := TRemoveWithUnitVisibility.Create(aFacts.UnitModels);
    lBindings := Copy(aFacts.Bindings);
    for i := 0 to High(lBindings) do
    begin
      lBinding := lBindings[i];
      for j := 0 to High(aFacts.UnitModels) do
      begin
        lModel := aFacts.UnitModels[j];
        if SameText(lBinding.FileName, lModel.FileName) and
          not SameText(lModel.ScopeModelStatus, 'ast') then
        begin
          lBinding.Status := 'skipped';
          lBinding.SkipReason := 'SCOPE_UNVERIFIED';
          Break;
        end;
      end;
      lBindings[i] := lBinding;
    end;
    lBindingSource := TArrayRemoveWithPlanBindingSource.Create(lBindings);
    Result := PlanFromBindingSource(lPlanFacts, lBindingSource,
      'project-with-binding-v1', lMetrics);
    if SameText(Result.Status, 'planned') then
      for lModel in aFacts.UnitModels do
        if SameText(lModel.ScopeModelStatus, 'include-with-unverified') then
        begin
          Result.Diagnostic := 'WITH_IN_INCLUDE_UNVERIFIED: ' + lModel.FileName;
          Break;
        end;
  finally
    lPlanFacts.ControlTokens.Free;
    lPlanFacts.ControlSources.Free;
    lPlanFacts.ScanActivityKnown.Free;
    lPlanFacts.ScanLines.Free;
    lPlanFacts.ScanSources.Free;
    lPlanFacts.UnitVisibility.Free;
    lBindingSource.Free;
    lPlanFacts.LookupIndex.Free;
  end;
end;

function SnapshotHasFlag(const aFlags, aFlag: Cardinal): Boolean;
begin
  Result := (aFlags and aFlag) <> 0;
end;

function SnapshotTypeIdentity(const aSnapshot: TDelphiProjectSnapshot;
  const aFact: TSemanticRemoveWithTypeIdentityFact): TDelphiSemanticTypeIdentity;
begin
  Result := Default(TDelphiSemanticTypeIdentity);
  if aFact.DeclaredIdId = 0 then
    Exit;
  Result.UnitId.Value := aSnapshot.ExactTextOf(aFact.UnitIdId);
  Result.UnitName := aSnapshot.ExactTextOf(aFact.UnitNameId);
  Result.Name := aSnapshot.ExactTextOf(aFact.NameId);
  Result.Kind := aSnapshot.ExactTextOf(aFact.KindId);
  Result.DeclaredId.Value := aSnapshot.ExactTextOf(aFact.DeclaredIdId);
  Result.CanonicalId.Value := aSnapshot.ExactTextOf(aFact.CanonicalIdId);
  Result.UnderlyingId.Value := aSnapshot.ExactTextOf(aFact.UnderlyingIdId);
  Result.CanonicalName := aSnapshot.ExactTextOf(aFact.CanonicalNameId);
  Result.UnderlyingName := aSnapshot.ExactTextOf(aFact.UnderlyingNameId);
  Result.BaseTypeName := aSnapshot.ExactTextOf(aFact.BaseTypeNameId);
  Result.HelperTargetName := aSnapshot.ExactTextOf(aFact.HelperTargetNameId);
  Result.SectionKind := aSnapshot.ExactTextOf(aFact.SectionKindId);
  Result.ScopeKind := aSnapshot.ExactTextOf(aFact.ScopeKindId);
  Result.OwnerScopeId := aSnapshot.ExactTextOf(aFact.OwnerScopeIdId);
  Result.SemanticSymbolId := aSnapshot.ExactTextOf(aFact.SemanticSymbolIdId);
  Result.SourceRange.FileName := aSnapshot.ExactTextOf(aFact.FileNameId);
  Result.SourceRange.Line := aFact.Line;
  Result.SourceRange.Column := aFact.Column;
  Result.SourceRange.EndLine := aFact.EndLine;
  Result.SourceRange.EndColumn := aFact.EndColumn;
end;

function SnapshotInventorySymbol(const aSnapshot: TDelphiProjectSnapshot;
  const aSymbol: TSemanticRemoveWithInventorySymbolFact): TDelphiSemanticInventorySymbol;
begin
  Result := Default(TDelphiSemanticInventorySymbol);
  Result.Name := aSnapshot.ExactTextOf(aSymbol.NameId);
  Result.SymbolClass := aSnapshot.ExactTextOf(aSymbol.SymbolClassId);
  Result.Kind := aSnapshot.ExactTextOf(aSymbol.KindId);
  Result.TypeName := aSnapshot.ExactTextOf(aSymbol.TypeNameId);
  Result.Modifier := aSnapshot.ExactTextOf(aSymbol.ModifierId);
  Result.OwnerName := aSnapshot.ExactTextOf(aSymbol.OwnerNameId);
  Result.OwnerType := aSnapshot.ExactTextOf(aSymbol.OwnerTypeId);
  Result.SourceOwnerType := aSnapshot.ExactTextOf(aSymbol.SourceOwnerTypeId);
  Result.RelatedTypeName := aSnapshot.ExactTextOf(aSymbol.RelatedTypeNameId);
  Result.RoutineName := aSnapshot.ExactTextOf(aSymbol.RoutineNameId);
  Result.RoutineScopeId := aSnapshot.ExactTextOf(aSymbol.RoutineScopeIdId);
  Result.ParentScopeId := aSnapshot.ExactTextOf(aSymbol.ParentScopeIdId);
  Result.OwnerScopeId := aSnapshot.ExactTextOf(aSymbol.OwnerScopeIdId);
  Result.OwnerSymbolId := aSnapshot.ExactTextOf(aSymbol.OwnerSymbolIdId);
  Result.UnitName := aSnapshot.ExactTextOf(aSymbol.UnitNameId);
  Result.FileName := aSnapshot.ExactTextOf(aSymbol.FileNameId);
  Result.SectionKind := aSnapshot.ExactTextOf(aSymbol.SectionKindId);
  Result.Line := aSymbol.Line;
  Result.Column := aSymbol.Column;
  Result.EndLine := aSymbol.EndLine;
  Result.EndColumn := aSymbol.EndColumn;
  Result.UnsupportedReason := aSnapshot.ExactTextOf(aSymbol.UnsupportedReasonId);
  Result.IsHelper := SnapshotHasFlag(aSymbol.Flags,
    cSemanticRemoveWithSymbolFlagIsHelper);
  Result.IsOverride := SnapshotHasFlag(aSymbol.Flags,
    cSemanticRemoveWithSymbolFlagIsOverride);
  Result.IsDefault := SnapshotHasFlag(aSymbol.Flags,
    cSemanticRemoveWithSymbolFlagIsDefault);
  Result.IsIndexed := SnapshotHasFlag(aSymbol.Flags,
    cSemanticRemoveWithSymbolFlagIsIndexed);
  Result.IndexParameterCount := aSymbol.IndexParameterCount;
  Result.TypeCategory := aSnapshot.ExactTextOf(aSymbol.TypeCategoryId);
  Result.OwnerIdentity := SnapshotTypeIdentity(aSnapshot, aSymbol.OwnerIdentity);
  Result.AccessOwnerIdentity := SnapshotTypeIdentity(aSnapshot,
    aSymbol.AccessOwnerIdentity);
end;

function SnapshotSelectorBinding(const aSnapshot: TDelphiProjectSnapshot;
  const aSelector: TSemanticRemoveWithSelectorBindingFact):
  TDelphiSemanticWithSelectorBinding;
begin
  Result := Default(TDelphiSemanticWithSelectorBinding);
  Result.SelectorText := aSnapshot.ExactTextOf(aSelector.SelectorTextId);
  Result.Status := aSnapshot.ExactTextOf(aSelector.StatusId);
  Result.ReasonCode := aSnapshot.ExactTextOf(aSelector.ReasonCodeId);
  Result.TypeName := aSnapshot.ExactTextOf(aSelector.TypeNameId);
  Result.TypeIdentity := SnapshotTypeIdentity(aSnapshot, aSelector.TypeIdentity);
  Result.CaptureTypeIdentity := SnapshotTypeIdentity(aSnapshot, aSelector.CaptureTypeIdentity);
  Result.CaptureTypeName := aSnapshot.ExactTextOf(aSelector.CaptureTypeNameId);
  Result.CaptureTypeStatus := aSnapshot.ExactTextOf(aSelector.CaptureTypeStatusId);
end;

function SnapshotBoundReference(const aSnapshot: TDelphiProjectSnapshot;
  const aReference: TSemanticRemoveWithBoundReferenceFact):
  TDelphiSemanticBoundReference;
begin
  Result := Default(TDelphiSemanticBoundReference);
  Result.SemanticId := aSnapshot.ExactTextOf(aReference.SemanticIdId);
  Result.Name := aSnapshot.ExactTextOf(aReference.NameId);
  Result.Classification := aSnapshot.ExactTextOf(aReference.ClassificationId);
  Result.LookupSource := aSnapshot.ExactTextOf(aReference.LookupSourceId);
  Result.ReceiverTypeName := aSnapshot.ExactTextOf(aReference.ReceiverTypeNameId);
  Result.Kind := aSnapshot.ExactTextOf(aReference.KindId);
  Result.TypeName := aSnapshot.ExactTextOf(aReference.TypeNameId);
  Result.ReasonCode := aSnapshot.ExactTextOf(aReference.ReasonCodeId);
  Result.ScopeConflictKind := aSnapshot.ExactTextOf(aReference.ScopeConflictKindId);
  Result.ScopeConflictName := aSnapshot.ExactTextOf(aReference.ScopeConflictNameId);
  Result.Line := aReference.Line;
  Result.Column := aReference.Column;
  Result.EndLine := aReference.EndLine;
  Result.EndColumn := aReference.EndColumn;
end;

function SnapshotWithBinding(const aSnapshot: TDelphiProjectSnapshot;
  const aBinding: TSemanticRemoveWithBindingFact): TDelphiSemanticWithBinding;
var
  i: Integer;
begin
  Result := Default(TDelphiSemanticWithBinding);
  Result.SemanticId := aSnapshot.ExactTextOf(aBinding.SemanticIdId);
  Result.Provenance := aSnapshot.ExactTextOf(aBinding.ProvenanceId);
  Result.FileName := aSnapshot.ExactTextOf(aBinding.FileNameId);
  Result.UnitName := aSnapshot.ExactTextOf(aBinding.UnitNameId);
  Result.RoutineName := aSnapshot.ExactTextOf(aBinding.RoutineNameId);
  Result.RoutineScopeId := aSnapshot.ExactTextOf(aBinding.RoutineScopeIdId);
  Result.Line := aBinding.Line;
  Result.Column := aBinding.Column;
  Result.EndLine := aBinding.EndLine;
  Result.EndColumn := aBinding.EndColumn;
  Result.BodyLine := aBinding.BodyLine;
  Result.BodyColumn := aBinding.BodyColumn;
  Result.BodyEndLine := aBinding.BodyEndLine;
  Result.BodyEndColumn := aBinding.BodyEndColumn;
  Result.SelectorText := aSnapshot.ExactTextOf(aBinding.SelectorTextId);
  Result.Status := aSnapshot.ExactTextOf(aBinding.StatusId);
  Result.SkipReason := aSnapshot.ExactTextOf(aBinding.SkipReasonId);
  Result.HasScopedDeclaration := SnapshotHasFlag(aBinding.Flags,
    cSemanticRemoveWithBindingFlagHasScopedDeclaration);
  Result.ActivityUnverified := SnapshotHasFlag(aBinding.Flags,
    cSemanticRemoveWithBindingFlagActivityUnverified);
  Result.MemberActivityUnverified := SnapshotHasFlag(aBinding.Flags,
    cSemanticRemoveWithBindingFlagMemberActivityUnverified);
  Result.InactiveSpanSkipReason := aSnapshot.ExactTextOf(aBinding.InactiveSpanSkipReasonId);
  Result.MemberReferenceCount := aBinding.MemberReferenceCount;
  Result.LexicalReferenceCount := aBinding.LexicalReferenceCount;
  Result.ExternalReferenceCount := aBinding.ExternalReferenceCount;
  Result.IntrinsicReferenceCount := aBinding.IntrinsicReferenceCount;
  Result.UnsupportedReferenceCount := aBinding.UnsupportedReferenceCount;
  Result.UnresolvedReferenceCount := aBinding.UnresolvedReferenceCount;
  SetLength(Result.Selectors, Length(aBinding.Selectors));
  for i := 0 to High(aBinding.Selectors) do
    Result.Selectors[i] := SnapshotSelectorBinding(aSnapshot, aBinding.Selectors[i]);
  SetLength(Result.References, Length(aBinding.References));
  for i := 0 to High(aBinding.References) do
    Result.References[i] := SnapshotBoundReference(aSnapshot, aBinding.References[i]);
  SetLength(Result.InactiveSpanReferences, Length(aBinding.InactiveSpanReferences));
  for i := 0 to High(aBinding.InactiveSpanReferences) do
    Result.InactiveSpanReferences[i] := SnapshotBoundReference(aSnapshot, aBinding.InactiveSpanReferences[i]);
end;

constructor TSnapshotRemoveWithPlanBindingSource.Create(
  const aSnapshot: TDelphiProjectSnapshot);
var
  i: Integer;
  j: Integer;
  lBinding: TDelphiSemanticWithBinding;
  lUnit: TUnitSnapshot;
begin
  inherited Create;
  fSnapshot := aSnapshot;
  SetLength(fBindings, fSnapshot.RemoveWithPlanningBindingCount);
  for i := 0 to High(fBindings) do
  begin
    lBinding := SnapshotWithBinding(fSnapshot,
      fSnapshot.RemoveWithPlanningBindingByIndex(i));
    for j := 0 to fSnapshot.UnitCount - 1 do
    begin
      lUnit := fSnapshot.UnitByIndex(j);
      if SameText(lBinding.FileName, fSnapshot.TextOf(lUnit.FileNameId)) and
        not SameText(fSnapshot.TextOf(lUnit.ScopeModelStatusId), 'ast') then
      begin
        lBinding.Status := 'skipped';
        lBinding.SkipReason := 'SCOPE_UNVERIFIED';
        Break;
      end;
    end;
    // Expand the private verification view once; hot-path access returns this cache.
    fBindings[i] := WithBindingForPlanning(lBinding);
  end;
end;

function TSnapshotRemoveWithPlanBindingSource.BindingByIndex(
  const aIndex: Integer): TDelphiSemanticWithBinding;
begin
  Result := fBindings[aIndex];
end;

function TSnapshotRemoveWithPlanBindingSource.BindingCount: Integer;
begin
  Result := Length(fBindings);
end;

function RemoveWithBindingFactRange(const aBinding:
  TSemanticRemoveWithBindingFact): TDelphiSemanticRemoveWithSourceRange;
begin
  Result.StartLine := aBinding.Line;
  Result.StartColumn := aBinding.Column;
  Result.EndLine := aBinding.EndLine;
  Result.EndColumn := aBinding.EndColumn;
end;

function TSnapshotRemoveWithPlanBindingSource.BindingContainsBindingByIndex(
  const aOuterIndex, aInnerIndex: Integer): Boolean;
var
  lInner: TSemanticRemoveWithBindingFact;
  lOuter: TSemanticRemoveWithBindingFact;
begin
  lOuter := fSnapshot.RemoveWithPlanningBindingByIndex(aOuterIndex);
  lInner := fSnapshot.RemoveWithPlanningBindingByIndex(aInnerIndex);
  Result := SameText(fSnapshot.ExactTextOf(lOuter.FileNameId),
    fSnapshot.ExactTextOf(lInner.FileNameId)) and
    (not SameText(fSnapshot.ExactTextOf(lOuter.SemanticIdId),
    fSnapshot.ExactTextOf(lInner.SemanticIdId))) and
    RangeContainsRange(RemoveWithBindingFactRange(lOuter),
    RemoveWithBindingFactRange(lInner)) and
    (not SameParityRange(RemoveWithBindingFactRange(lOuter),
    RemoveWithBindingFactRange(lInner)));
end;

function TSnapshotRemoveWithPlanBindingSource.BindingHasStableSourceRange(
  const aIndex: Integer): Boolean;
var
  lBinding: TSemanticRemoveWithBindingFact;
  lFileName: string;
begin
  lBinding := fSnapshot.RemoveWithPlanningBindingByIndex(aIndex);
  lFileName := fSnapshot.ExactTextOf(lBinding.FileNameId);
  Result := (Trim(lFileName) <> '') and TFile.Exists(lFileName) and
    (lBinding.Line > 0) and (lBinding.Column > 0) and
    (lBinding.EndLine >= lBinding.Line) and (lBinding.EndColumn > 0);
end;

function BindingFactsFromSnapshot(
  const aSnapshot: TDelphiProjectSnapshot): TDelphiSemanticProjectWithBindingFacts;
var
  i: Integer;
  lBindingCount: Integer;
  lRoutineOwnerCount: Integer;
begin
  Result := Default(TDelphiSemanticProjectWithBindingFacts);
  Result.ContextFingerprint := aSnapshot.ExactTextOf(
    aSnapshot.RemoveWithPlanningContextFingerprintId);
  lRoutineOwnerCount := aSnapshot.RemoveWithPlanningRoutineOwnerCount;
  SetLength(Result.Symbols, lRoutineOwnerCount);
  for i := 0 to High(Result.Symbols) do
    Result.Symbols[i] := SnapshotInventorySymbol(aSnapshot,
      aSnapshot.RemoveWithPlanningRoutineOwnerByIndex(i));
  lBindingCount := aSnapshot.RemoveWithPlanningBindingCount;
  SetLength(Result.Bindings, lBindingCount);
  for i := 0 to High(Result.Bindings) do
    Result.Bindings[i] := SnapshotWithBinding(aSnapshot,
      aSnapshot.RemoveWithPlanningBindingByIndex(i));
  Result.LookupIndex := aSnapshot.RemoveWithPlanningLookupIndex;
  Result.Metrics.UnitCount := aSnapshot.UnitCount;
  Result.Metrics.WithStatementCount := Length(Result.Bindings);
  Result.Metrics.BindingCount := Length(Result.Bindings);
end;

class function TDelphiSemanticRemoveWithPlanner.Plan(
  const aSnapshot: TDelphiProjectSnapshot): TDelphiSemanticRemoveWithPlan;
var
  lMetrics: TDelphiSemanticRemoveWithPlannerMetrics;
begin
  Result := Plan(aSnapshot, lMetrics);
end;

class function TDelphiSemanticRemoveWithPlanner.Plan(
  const aSnapshot: TDelphiProjectSnapshot;
  out aMetrics: TDelphiSemanticRemoveWithPlannerMetrics):
  TDelphiSemanticRemoveWithPlan;
var
  i: Integer;
  j: Integer;
  lBinding: TSemanticRemoveWithBindingFact;
  lBindingSource: TSnapshotRemoveWithPlanBindingSource;
  lMaterializationStopwatch: TStopwatch;
  lPlanFacts: TRemoveWithPlanFacts;
  lRoutineOwnerCount: Integer;
  lScopeStatus: string;
  lUnit: TUnitSnapshot;
  lUnsafeCount: Integer;
  lSafetyReason: string;
begin
  aMetrics := Default(TDelphiSemanticRemoveWithPlannerMetrics);
  Result := Default(TDelphiSemanticRemoveWithPlan);
  Result.Operation := 'remove-with';
  Result.Status := 'blocked';
  Result.BaselineSemanticModelVersion := 'project-snapshot-v1';
  if aSnapshot = nil then
  begin
    Result.Diagnostic := 'Missing project snapshot.';
    Exit;
  end;
  if not aSnapshot.HasRemoveWithPlanningFacts then
  begin
    Result.Diagnostic := 'Project snapshot has no remove-with planning facts.';
    Exit;
  end;

  lUnsafeCount := 0;
  lSafetyReason := '';
  for i := 0 to aSnapshot.UnitCount - 1 do
  begin
    lUnit := aSnapshot.UnitByIndex(i);
    lScopeStatus := aSnapshot.TextOf(lUnit.ScopeModelStatusId);
    if SameText(lScopeStatus, 'include-with-unverified') then
    begin
      if lSafetyReason = '' then
        lSafetyReason := 'WITH_IN_INCLUDE_UNVERIFIED: ' +
          aSnapshot.TextOf(lUnit.FileNameId);
    end;
    for j := 0 to aSnapshot.RemoveWithPlanningBindingCount - 1 do
    begin
      lBinding := aSnapshot.RemoveWithPlanningBindingByIndex(j);
      if not SameText(aSnapshot.ExactTextOf(lBinding.FileNameId),
        aSnapshot.TextOf(lUnit.FileNameId)) then
        Continue;
      if not SameText(lScopeStatus, 'ast') then
      begin
        Inc(lUnsafeCount);
        if lSafetyReason = '' then
          lSafetyReason := 'SCOPE_UNVERIFIED: ' +
            aSnapshot.TextOf(lUnit.FileNameId) + ' (' + lScopeStatus + ')';
      end;
    end;
  end;
  if (lSafetyReason <> '') and
    ((aSnapshot.RemoveWithPlanningBindingCount = 0) or
    (lUnsafeCount = aSnapshot.RemoveWithPlanningBindingCount)) then
  begin
    Result.Diagnostic := lSafetyReason;
    Exit;
  end;

  lPlanFacts := Default(TRemoveWithPlanFacts);
  lBindingSource := nil;
  try
    lMaterializationStopwatch := TStopwatch.StartNew;
    try
      lPlanFacts.ContextFingerprint := aSnapshot.ExactTextOf(
        aSnapshot.RemoveWithPlanningContextFingerprintId);
      lPlanFacts.ScanSources := TDictionary<string, string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
      lPlanFacts.ControlSources := TDictionary<string, string>.Create(
        TFastCaseAwareComparer.OrdinalIgnoreCase);
      lPlanFacts.ControlTokens := TDictionary<string, TArray<TControlContextToken>>.Create(
        TFastCaseAwareComparer.OrdinalIgnoreCase);
      lPlanFacts.ScanActivityKnown := TDictionary<string, Boolean>.Create(
        TFastCaseAwareComparer.OrdinalIgnoreCase);
      lPlanFacts.ScanLines := TDictionary<string, TArray<string>>.Create(
        TFastCaseAwareComparer.OrdinalIgnoreCase);
      for i := 0 to aSnapshot.UnitCount - 1 do
      begin
        lUnit := aSnapshot.UnitByIndex(i);
        lPlanFacts.ControlSources.AddOrSetValue(aSnapshot.TextOf(lUnit.FileNameId),
          aSnapshot.ExactTextOf(lUnit.SourceTextId));
        lPlanFacts.ScanActivityKnown.AddOrSetValue(aSnapshot.TextOf(lUnit.FileNameId),
          AnonymousRecordActivityIsKnown(aSnapshot.ExactTextOf(lUnit.SourceTextId),
            aSnapshot.ExactTextOf(lUnit.VerifiedActiveSourceTextId)));
        lPlanFacts.ScanSources.AddOrSetValue(aSnapshot.TextOf(lUnit.FileNameId),
          AnonymousRecordScanSource(aSnapshot.ExactTextOf(lUnit.SourceTextId),
            aSnapshot.ExactTextOf(lUnit.VerifiedActiveSourceTextId)));
      end;
      lPlanFacts.LookupIndex := TPlannerLookupMemo.Create;
      lPlanFacts.LookupIndex.Initialize(
        aSnapshot.RemoveWithPlanningLookupIndex);
      lRoutineOwnerCount := aSnapshot.RemoveWithPlanningRoutineOwnerCount;
      SetLength(lPlanFacts.Symbols, lRoutineOwnerCount);
      for i := 0 to High(lPlanFacts.Symbols) do
        lPlanFacts.Symbols[i] := SnapshotInventorySymbol(aSnapshot,
          aSnapshot.RemoveWithPlanningRoutineOwnerByIndex(i));
      if not TryGetRemoveWithVisibility(aSnapshot, lPlanFacts.UnitVisibility) then
        lPlanFacts.UnitVisibility := nil;
      lBindingSource := TSnapshotRemoveWithPlanBindingSource.Create(aSnapshot);
    finally
      lMaterializationStopwatch.Stop;
      aMetrics.SnapshotBindingMaterializationMilliseconds :=
        lMaterializationStopwatch.ElapsedMilliseconds;
    end;
    Result := PlanFromBindingSource(lPlanFacts, lBindingSource,
      'project-snapshot-v1', aMetrics);
    if (lSafetyReason <> '') and SameText(Result.Status, 'planned') then
      Result.Diagnostic := lSafetyReason;
  finally
    lPlanFacts.ControlTokens.Free;
    lPlanFacts.ControlSources.Free;
    lPlanFacts.ScanActivityKnown.Free;
    lPlanFacts.ScanLines.Free;
    lPlanFacts.ScanSources.Free;
    lBindingSource.Free;
    lPlanFacts.LookupIndex.Free;
  end;
end;

class function TDelphiSemanticRemoveWithPlanParity.Compare(
  const aSemanticPlan: TDelphiSemanticRemoveWithPlan;
  const aExpectedStatements: TArray<TDelphiSemanticRemoveWithPlanParityStatement>):
  TDelphiSemanticRemoveWithPlanParityReport;
var
  lActualStatement: TDelphiSemanticRemoveWithPlanParityStatement;
  lActualStatementIndex: Integer;
  lExpectedStatement: TDelphiSemanticRemoveWithPlanParityStatement;
  lExpectedStatementIndex: Integer;
  lFinalStatements: TArray<TDelphiSemanticRemoveWithPlanParityStatement>;
  lMatchedActualStatements: TArray<Boolean>;
begin
  Result := Default(TDelphiSemanticRemoveWithPlanParityReport);
  lFinalStatements := FinalStatementsFromPlan(aSemanticPlan);
  SetLength(lMatchedActualStatements, Length(lFinalStatements));
  for lExpectedStatementIndex := 0 to High(aExpectedStatements) do
  begin
    lExpectedStatement := aExpectedStatements[lExpectedStatementIndex];
    if not FindParityStatement(lFinalStatements, lExpectedStatement, lActualStatement) then
    begin
      AddStatementMismatch(Result, 'missing-final-statement', lExpectedStatement, lActualStatement);
      if Length(lExpectedStatement.Edits) > 0 then
        AddEditMismatch(Result, 'missing-final-edit', lExpectedStatement, lExpectedStatement.Edits[0]);
      Continue;
    end;
    if (not SameText(lActualStatement.Status, lExpectedStatement.Status)) or
      (not SameText(lActualStatement.Reason, lExpectedStatement.Reason)) then
      AddStatementMismatch(Result, 'statement-status-mismatch', lExpectedStatement, lActualStatement);
    if lActualStatement.ReplacementText <> lExpectedStatement.ReplacementText then
      AddStatementMismatch(Result, 'statement-replacement-mismatch', lExpectedStatement, lActualStatement);
    CompareParityEdits(Result, lExpectedStatement, lActualStatement);
    for lActualStatementIndex := 0 to High(lFinalStatements) do
    begin
      if SameText(lFinalStatements[lActualStatementIndex].StatementId, lActualStatement.StatementId) and
        SameParityFile(lFinalStatements[lActualStatementIndex].FileName, lActualStatement.FileName) then
      begin
        lMatchedActualStatements[lActualStatementIndex] := True;
        Break;
      end;
    end;
  end;
  for lActualStatementIndex := 0 to High(lFinalStatements) do
  begin
    if lMatchedActualStatements[lActualStatementIndex] then
      Continue;
    lActualStatement := lFinalStatements[lActualStatementIndex];
    AddStatementMismatch(Result, 'unexpected-final-statement', lActualStatement,
      Default(TDelphiSemanticRemoveWithPlanParityStatement));
    if Length(lActualStatement.Edits) > 0 then
      AddEditMismatch(Result, 'unexpected-final-edit', lActualStatement, lActualStatement.Edits[0]);
  end;
  Result.SummaryText := BuildParitySummary(Result);
end;

end.
