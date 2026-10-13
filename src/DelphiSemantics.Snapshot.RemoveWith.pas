unit DelphiSemantics.Snapshot.RemoveWith;

interface

uses
  DelphiSemantics.Snapshot, DelphiSemantics.WithBinding;

type
  TSemanticRemoveWithTypeIdentityFact = record
    UnitIdId: TSemanticStringId;
    UnitNameId: TSemanticStringId;
    NameId: TSemanticStringId;
    KindId: TSemanticStringId;
    DeclaredIdId: TSemanticStringId;
    CanonicalIdId: TSemanticStringId;
    UnderlyingIdId: TSemanticStringId;
    CanonicalNameId: TSemanticStringId;
    UnderlyingNameId: TSemanticStringId;
    BaseTypeNameId: TSemanticStringId;
    HelperTargetNameId: TSemanticStringId;
    SectionKindId: TSemanticStringId;
    ScopeKindId: TSemanticStringId;
    OwnerScopeIdId: TSemanticStringId;
    SemanticSymbolIdId: TSemanticStringId;
    FileNameId: TSemanticStringId;
    Line: Integer;
    Column: Integer;
    EndLine: Integer;
    EndColumn: Integer;
  end;

  TSemanticRemoveWithInventorySymbolFact = record
    NameId: TSemanticStringId;
    SymbolClassId: TSemanticStringId;
    KindId: TSemanticStringId;
    TypeNameId: TSemanticStringId;
    ModifierId: TSemanticStringId;
    OwnerNameId: TSemanticStringId;
    OwnerTypeId: TSemanticStringId;
    SourceOwnerTypeId: TSemanticStringId;
    RelatedTypeNameId: TSemanticStringId;
    RoutineNameId: TSemanticStringId;
    RoutineScopeIdId: TSemanticStringId;
    ParentScopeIdId: TSemanticStringId;
    OwnerScopeIdId: TSemanticStringId;
    OwnerSymbolIdId: TSemanticStringId;
    UnitNameId: TSemanticStringId;
    FileNameId: TSemanticStringId;
    SectionKindId: TSemanticStringId;
    Line: Integer;
    Column: Integer;
    EndLine: Integer;
    EndColumn: Integer;
    UnsupportedReasonId: TSemanticStringId;
    Flags: Cardinal;
    IndexParameterCount: Integer;
    TypeCategoryId: TSemanticStringId;
    OwnerIdentity: TSemanticRemoveWithTypeIdentityFact;
    AccessOwnerIdentity: TSemanticRemoveWithTypeIdentityFact;
  end;

  TSemanticRemoveWithSelectorBindingFact = record
    SelectorTextId: TSemanticStringId;
    StatusId: TSemanticStringId;
    ReasonCodeId: TSemanticStringId;
    TypeNameId: TSemanticStringId;
    TypeIdentity: TSemanticRemoveWithTypeIdentityFact;
  end;

  TSemanticRemoveWithBoundReferenceFact = record
    SemanticIdId: TSemanticStringId;
    NameId: TSemanticStringId;
    ClassificationId: TSemanticStringId;
    LookupSourceId: TSemanticStringId;
    ReceiverTypeNameId: TSemanticStringId;
    KindId: TSemanticStringId;
    TypeNameId: TSemanticStringId;
    ReasonCodeId: TSemanticStringId;
    ScopeConflictKindId: TSemanticStringId;
    ScopeConflictNameId: TSemanticStringId;
    Line: Integer;
    Column: Integer;
    EndLine: Integer;
    EndColumn: Integer;
  end;

  TSemanticRemoveWithBindingFact = record
    SemanticIdId: TSemanticStringId;
    ProvenanceId: TSemanticStringId;
    FileNameId: TSemanticStringId;
    UnitNameId: TSemanticStringId;
    RoutineNameId: TSemanticStringId;
    RoutineScopeIdId: TSemanticStringId;
    Line: Integer;
    Column: Integer;
    EndLine: Integer;
    EndColumn: Integer;
    BodyLine: Integer;
    BodyColumn: Integer;
    BodyEndLine: Integer;
    BodyEndColumn: Integer;
    SelectorTextId: TSemanticStringId;
    StatusId: TSemanticStringId;
    SkipReasonId: TSemanticStringId;
    InactiveSpanSkipReasonId: TSemanticStringId;
    Flags: Cardinal;
    MemberReferenceCount: Integer;
    LexicalReferenceCount: Integer;
    ExternalReferenceCount: Integer;
    IntrinsicReferenceCount: Integer;
    UnsupportedReferenceCount: Integer;
    UnresolvedReferenceCount: Integer;
    Selectors: TArray<TSemanticRemoveWithSelectorBindingFact>;
    References: TArray<TSemanticRemoveWithBoundReferenceFact>;
    InactiveSpanReferences: TArray<TSemanticRemoveWithBoundReferenceFact>;
  end;

  TSemanticRemoveWithPlanningFacts = record
    ContextFingerprintId: TSemanticStringId;
    LookupIndex: TDelphiSemanticRemoveWithLookupIndex;
    RoutineOwners: TArray<TSemanticRemoveWithInventorySymbolFact>;
    Symbols: TArray<TSemanticRemoveWithInventorySymbolFact>;
    Bindings: TArray<TSemanticRemoveWithBindingFact>;
  end;

  TDelphiProjectSnapshotRemoveWithHelper = class helper for TDelphiProjectSnapshot
  public
    function HasRemoveWithPlanningFacts: Boolean;
    function RemoveWithPlanningBindingByIndex(const aIndex: Integer):
      TSemanticRemoveWithBindingFact;
    function RemoveWithPlanningBindingCount: Integer;
    function RemoveWithPlanningContextFingerprintId: TSemanticStringId;
    function RemoveWithPlanningFacts: TSemanticRemoveWithPlanningFacts;
    function RemoveWithPlanningLookupIndex: TDelphiSemanticRemoveWithLookupIndex;
    function RemoveWithPlanningRoutineOwnerByIndex(const aIndex: Integer):
      TSemanticRemoveWithInventorySymbolFact;
    function RemoveWithPlanningRoutineOwnerCount: Integer;
    function RemoveWithPlanningSymbolByIndex(const aIndex: Integer):
      TSemanticRemoveWithInventorySymbolFact;
    function RemoveWithPlanningSymbolCount: Integer;
  end;

  TDelphiProjectSnapshotBuilderRemoveWithHelper = class helper for TDelphiProjectSnapshotBuilder
  public
    procedure SetRemoveWithPlanningFacts(const aFacts: TSemanticRemoveWithPlanningFacts);
    procedure SetRemoveWithPlanningFactsOwned(var aFacts: TSemanticRemoveWithPlanningFacts);
  end;

const
  cSemanticRemoveWithSymbolFlagIsHelper = 1 shl 0;
  cSemanticRemoveWithSymbolFlagIsOverride = 1 shl 1;
  cSemanticRemoveWithSymbolFlagIsDefault = 1 shl 2;
  cSemanticRemoveWithSymbolFlagIsIndexed = 1 shl 3;
  cSemanticRemoveWithBindingFlagHasScopedDeclaration = 1 shl 0;
  cSemanticRemoveWithBindingFlagActivityUnverified = 1 shl 1;
  cSemanticRemoveWithBindingFlagMemberActivityUnverified = 1 shl 2;

function CopyRemoveWithPlanningFacts(
  const aFacts: TSemanticRemoveWithPlanningFacts): TSemanticRemoveWithPlanningFacts;

implementation

uses
  System.SysUtils;

const
  cRemoveWithPlanningExtensionName = 'DelphiSemantics.RemoveWithPlanningFacts';

type
  TRemoveWithPlanningFactsExtension = class
  private
    fFacts: TSemanticRemoveWithPlanningFacts;
  public
    constructor Create(const aFacts: TSemanticRemoveWithPlanningFacts); overload;
    constructor CreateOwned(var aFacts: TSemanticRemoveWithPlanningFacts); overload;
    function HasFacts: Boolean;
    property Facts: TSemanticRemoveWithPlanningFacts read fFacts;
  end;

function CopyRemoveWithPlanningFacts(
  const aFacts: TSemanticRemoveWithPlanningFacts): TSemanticRemoveWithPlanningFacts;
var
  i: Integer;
begin
  Result := Default(TSemanticRemoveWithPlanningFacts);
  Result.ContextFingerprintId := aFacts.ContextFingerprintId;
  Result.LookupIndex := aFacts.LookupIndex;
  Result.RoutineOwners := Copy(aFacts.RoutineOwners);
  Result.Symbols := Copy(aFacts.Symbols);
  SetLength(Result.Bindings, Length(aFacts.Bindings));
  for i := 0 to High(aFacts.Bindings) do
  begin
    Result.Bindings[i] := aFacts.Bindings[i];
    Result.Bindings[i].Selectors := Copy(aFacts.Bindings[i].Selectors);
    Result.Bindings[i].References := Copy(aFacts.Bindings[i].References);
    Result.Bindings[i].InactiveSpanReferences := Copy(aFacts.Bindings[i].InactiveSpanReferences);
  end;
end;

constructor TRemoveWithPlanningFactsExtension.Create(
  const aFacts: TSemanticRemoveWithPlanningFacts);
begin
  inherited Create;
  fFacts := CopyRemoveWithPlanningFacts(aFacts);
end;

constructor TRemoveWithPlanningFactsExtension.CreateOwned(
  var aFacts: TSemanticRemoveWithPlanningFacts);
begin
  inherited Create;
  fFacts := aFacts;
  aFacts := Default(TSemanticRemoveWithPlanningFacts);
end;

function TRemoveWithPlanningFactsExtension.HasFacts: Boolean;
begin
  Result := (fFacts.ContextFingerprintId <> 0)
    or (Length(fFacts.Bindings) > 0)
    or (Length(fFacts.Symbols) > 0);
end;

function TryRemoveWithPlanningExtension(const aSnapshot: TDelphiProjectSnapshot;
  out aExtension: TRemoveWithPlanningFactsExtension): Boolean;
var
  lExtension: TObject;
begin
  aExtension := nil;
  Result := (aSnapshot <> nil)
    and aSnapshot.TryGetExtension(cRemoveWithPlanningExtensionName, lExtension)
    and (lExtension is TRemoveWithPlanningFactsExtension);
  if Result then
    aExtension := lExtension as TRemoveWithPlanningFactsExtension;
end;

function TDelphiProjectSnapshotRemoveWithHelper.HasRemoveWithPlanningFacts: Boolean;
var
  lExtension: TRemoveWithPlanningFactsExtension;
begin
  Result := TryRemoveWithPlanningExtension(Self, lExtension)
    and lExtension.HasFacts;
end;

function TDelphiProjectSnapshotRemoveWithHelper.RemoveWithPlanningBindingByIndex(
  const aIndex: Integer): TSemanticRemoveWithBindingFact;
var
  lExtension: TRemoveWithPlanningFactsExtension;
begin
  if not TryRemoveWithPlanningExtension(Self, lExtension) then
    raise Exception.Create('Project snapshot has no remove-with planning facts.');
  Result := lExtension.Facts.Bindings[aIndex];
end;

function TDelphiProjectSnapshotRemoveWithHelper.RemoveWithPlanningBindingCount:
  Integer;
var
  lExtension: TRemoveWithPlanningFactsExtension;
begin
  if not TryRemoveWithPlanningExtension(Self, lExtension) then
    Exit(0);
  Result := Length(lExtension.Facts.Bindings);
end;

function TDelphiProjectSnapshotRemoveWithHelper.RemoveWithPlanningContextFingerprintId:
  TSemanticStringId;
var
  lExtension: TRemoveWithPlanningFactsExtension;
begin
  if not TryRemoveWithPlanningExtension(Self, lExtension) then
    Exit(0);
  Result := lExtension.Facts.ContextFingerprintId;
end;

function TDelphiProjectSnapshotRemoveWithHelper.RemoveWithPlanningFacts:
  TSemanticRemoveWithPlanningFacts;
var
  lExtension: TRemoveWithPlanningFactsExtension;
begin
  if not TryRemoveWithPlanningExtension(Self, lExtension) then
    Exit(Default(TSemanticRemoveWithPlanningFacts));
  Result := CopyRemoveWithPlanningFacts(lExtension.Facts);
end;

function TDelphiProjectSnapshotRemoveWithHelper.RemoveWithPlanningLookupIndex:
  TDelphiSemanticRemoveWithLookupIndex;
var
  lExtension: TRemoveWithPlanningFactsExtension;
begin
  if not TryRemoveWithPlanningExtension(Self, lExtension) then
    Exit(Default(TDelphiSemanticRemoveWithLookupIndex));
  Result := lExtension.Facts.LookupIndex;
end;

function TDelphiProjectSnapshotRemoveWithHelper.RemoveWithPlanningRoutineOwnerByIndex(
  const aIndex: Integer): TSemanticRemoveWithInventorySymbolFact;
var
  lExtension: TRemoveWithPlanningFactsExtension;
begin
  if not TryRemoveWithPlanningExtension(Self, lExtension) then
    raise Exception.Create('Project snapshot has no remove-with planning facts.');
  Result := lExtension.Facts.RoutineOwners[aIndex];
end;

function TDelphiProjectSnapshotRemoveWithHelper.RemoveWithPlanningRoutineOwnerCount:
  Integer;
var
  lExtension: TRemoveWithPlanningFactsExtension;
begin
  if not TryRemoveWithPlanningExtension(Self, lExtension) then
    Exit(0);
  Result := Length(lExtension.Facts.RoutineOwners);
end;

function TDelphiProjectSnapshotRemoveWithHelper.RemoveWithPlanningSymbolByIndex(
  const aIndex: Integer): TSemanticRemoveWithInventorySymbolFact;
var
  lExtension: TRemoveWithPlanningFactsExtension;
begin
  if not TryRemoveWithPlanningExtension(Self, lExtension) then
    raise Exception.Create('Project snapshot has no remove-with planning facts.');
  Result := lExtension.Facts.Symbols[aIndex];
end;

function TDelphiProjectSnapshotRemoveWithHelper.RemoveWithPlanningSymbolCount:
  Integer;
var
  lExtension: TRemoveWithPlanningFactsExtension;
begin
  if not TryRemoveWithPlanningExtension(Self, lExtension) then
    Exit(0);
  Result := Length(lExtension.Facts.Symbols);
end;

procedure TDelphiProjectSnapshotBuilderRemoveWithHelper.SetRemoveWithPlanningFacts(
  const aFacts: TSemanticRemoveWithPlanningFacts);
var
  lExtension: TRemoveWithPlanningFactsExtension;
begin
  lExtension := TRemoveWithPlanningFactsExtension.Create(aFacts);
  try
    SetExtensionOwned(cRemoveWithPlanningExtensionName, lExtension);
    lExtension := nil;
  finally
    lExtension.Free;
  end;
end;

procedure TDelphiProjectSnapshotBuilderRemoveWithHelper.SetRemoveWithPlanningFactsOwned(
  var aFacts: TSemanticRemoveWithPlanningFacts);
var
  lExtension: TRemoveWithPlanningFactsExtension;
begin
  lExtension := TRemoveWithPlanningFactsExtension.CreateOwned(aFacts);
  try
    SetExtensionOwned(cRemoveWithPlanningExtensionName, lExtension);
    lExtension := nil;
  finally
    lExtension.Free;
  end;
end;

end.
