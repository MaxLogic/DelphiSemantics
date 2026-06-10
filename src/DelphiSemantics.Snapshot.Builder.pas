unit DelphiSemantics.Snapshot.Builder;

interface

uses
  System.Generics.Collections,
  DelphiSemantics.Model, DelphiSemantics.Snapshot, DelphiSemantics.WithBinding;

type
  TDelphiSnapshotBuildOptions = record
    ResolveReferenceTargets: Boolean;
    WorkerCount: Integer;
  end;

  TDelphiSnapshotBuilderMetrics = record
    UnitCount: Integer;
    SymbolCount: Integer;
    ReferenceCount: Integer;
    WithStatementCount: Integer;
    BuildMilliseconds: Int64;
    WorkerCount: Integer;
    QueueMilliseconds: Int64;
    ParseExtractMilliseconds: Int64;
    MergeMilliseconds: Int64;
    DeterministicFactCount: Integer;
  end;

function BuildProjectSnapshotFromModels(
  const aModels: TArray<TDelphiSemanticUnitModel>;
  const aRemoveWithFacts: TDelphiSemanticProjectWithBindingFacts;
  const aOptions: TDelphiSnapshotBuildOptions;
  out aMetrics: TDelphiSnapshotBuilderMetrics): TDelphiProjectSnapshot;

implementation

uses
  System.Classes, System.Diagnostics, System.IOUtils, System.SysUtils,
  MaxLogic.StrUtils,
  DelphiSemantics.Index, DelphiSemantics.Query, DelphiSemantics.Symbols;

const
  cSnapshotDeclarationKindAlias = 'alias';
  cSnapshotDeclarationKindTypeAlias = 'type-alias';
  cSnapshotSymbolFlagIsDefault = 1;
  cSnapshotSymbolFlagIsIndexed = 2;
  cSnapshotSymbolKindLocal = 'local';
  cSnapshotSymbolKindParameter = 'parameter';
  cSnapshotSymbolKindRoutine = 'routine';
  cSnapshotSourceKindProject = 'project-source';
  cSnapshotWithFlagHasScopedDeclaration = 1;

type
  TSnapshotUnitBuildResult = record
    Strings: TSemanticStringPool;
    UnitSnapshot: TUnitSnapshot;
    UnitCount: Integer;
    SymbolCount: Integer;
    ReferenceCount: Integer;
    WithStatementCount: Integer;
  end;

  TSnapshotBuildWorkerContext = class
  private
    fLock: TObject;
    fNextIndex: Integer;
    fReferenceTargets: TDictionary<string, TSemanticSymbolRef>;
    fUnitModels: TArray<TDelphiSemanticUnitModel>;
  public
    Results: TArray<TSnapshotUnitBuildResult>;
    constructor Create(const aModels: TArray<TDelphiSemanticUnitModel>;
      const aReferenceTargets: TDictionary<string, TSemanticSymbolRef>);
    destructor Destroy; override;
    function UnitModelByIndex(const aIndex: Integer): TDelphiSemanticUnitModel;
    function TryTakeNextIndex(out aIndex: Integer): Boolean;
    property ReferenceTargets: TDictionary<string, TSemanticSymbolRef>
      read fReferenceTargets;
  end;

  TSnapshotBuildWorkerThread = class(TThread)
  private
    fContext: TSnapshotBuildWorkerContext;
  protected
    procedure Execute; override;
  public
    constructor Create(const aContext: TSnapshotBuildWorkerContext);
  end;

function SnapshotDeclarationKind(const aKind: string): string;
begin
  if SameText(aKind, cSnapshotDeclarationKindTypeAlias) then
    Exit(cSnapshotDeclarationKindAlias);

  Result := aKind;
end;

function SnapshotEndColumn(const aColumn: Integer; const aName: string): Integer;
begin
  if (aColumn <= 0) or (aName = '') then
    Exit(0);

  Result := aColumn + Length(aName) - 1;
end;

function SnapshotFullPath(const aFileName: string): string;
begin
  if Trim(aFileName) = '' then
    Exit('');

  Result := TPath.GetFullPath(aFileName);
end;

function SnapshotRoutineName(const aRoutine: TDelphiSemanticRoutine): string;
begin
  if aRoutine.OwnerName <> '' then
    Exit(aRoutine.OwnerName + '.' + aRoutine.Name);

  Result := aRoutine.Name;
end;

function SnapshotRoutineNameForLine(const aModel: TDelphiSemanticUnitModel;
  const aLine: Integer): string;
var
  lBestLine: Integer;
  lRoutine: TDelphiSemanticRoutine;
begin
  Result := '';
  lBestLine := 0;
  if aLine <= 0 then
    Exit;

  for lRoutine in aModel.Routines do
  begin
    if (lRoutine.Line <= 0) or (lRoutine.Line > aLine) then
      Continue;
    if lRoutine.Line < lBestLine then
      Continue;

    lBestLine := lRoutine.Line;
    Result := SnapshotRoutineName(lRoutine);
  end;
end;

function SnapshotWithIdForLine(const aUnit: TUnitSnapshot; const aLine: Integer):
  TSemanticWithId;
begin
  Result := 0;
  aUnit.TryFindInnermostWithStatementAtLine(aLine, Result);
end;

function SnapshotSymbolMatchKey(const aUnitName, aKind, aOwnerName, aName,
  aSignature: string; const aLine, aColumn: Integer): string;
begin
  Result := aUnitName + #9 + aKind + #9 + aOwnerName + #9 + aName + #9 +
    aSignature + #9 + IntToStr(aLine) + #9 + IntToStr(aColumn);
end;

function SnapshotReferenceMatchKey(const aUnitName, aRoutineName, aName: string;
  const aLine, aColumn: Integer): string;
begin
  Result := aUnitName + #9 + aRoutineName + #9 + aName + #9 + IntToStr(aLine) +
    #9 + IntToStr(aColumn);
end;

procedure AddSnapshotSymbolOrigin(
  const aMap: TDictionary<string, TSemanticSymbolRef>;
  const aUnitName, aKind, aOwnerName, aName, aSignature: string; const aLine,
  aColumn: Integer; const aUnitId: TSemanticUnitId;
  var aNextSymbolId: TSemanticSymbolId);
var
  lRef: TSemanticSymbolRef;
begin
  Inc(aNextSymbolId);
  if aName = '' then
    Exit;

  lRef.UnitId := aUnitId;
  lRef.SymbolId := aNextSymbolId;
  aMap.AddOrSetValue(SnapshotSymbolMatchKey(aUnitName, aKind, aOwnerName, aName,
    aSignature, aLine, aColumn), lRef);
end;

function BuildSnapshotSymbolRefsByOrigin(
  const aModels: TArray<TDelphiSemanticUnitModel>):
  TDictionary<string, TSemanticSymbolRef>;
var
  lDeclaration: TDelphiSemanticDeclaration;
  lLocal: TDelphiSemanticLocal;
  lMember: TDelphiSemanticMember;
  lParameter: TDelphiSemanticParameter;
  lRoutine: TDelphiSemanticRoutine;
  lSymbolId: TSemanticSymbolId;
  lUnitId: TSemanticUnitId;
  lUnitModel: TDelphiSemanticUnitModel;
begin
  Result := TDictionary<string, TSemanticSymbolRef>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  for lUnitId := 1 to TSemanticUnitId(Length(aModels)) do
  begin
    lUnitModel := aModels[Integer(lUnitId) - 1];
    lSymbolId := 0;
    for lDeclaration in lUnitModel.Declarations do
      AddSnapshotSymbolOrigin(Result, lUnitModel.UnitName, lDeclaration.Kind, '',
        lDeclaration.Name, '', lDeclaration.Line, lDeclaration.Column, lUnitId,
        lSymbolId);
    for lMember in lUnitModel.Members do
      AddSnapshotSymbolOrigin(Result, lUnitModel.UnitName, lMember.Kind,
        lMember.OwnerName, lMember.Name, lMember.Signature, lMember.Line,
        lMember.Column, lUnitId, lSymbolId);
    for lRoutine in lUnitModel.Routines do
    begin
      AddSnapshotSymbolOrigin(Result, lUnitModel.UnitName,
        cSnapshotSymbolKindRoutine, lRoutine.OwnerName, lRoutine.Name,
        lRoutine.Signature, lRoutine.Line, lRoutine.Column, lUnitId, lSymbolId);
      for lParameter in lRoutine.Parameters do
        AddSnapshotSymbolOrigin(Result, lUnitModel.UnitName,
          cSnapshotSymbolKindParameter, SnapshotRoutineName(lRoutine),
          lParameter.Name, '', lParameter.Line, lParameter.Column, lUnitId,
          lSymbolId);
    end;
    for lLocal in lUnitModel.Locals do
      AddSnapshotSymbolOrigin(Result, lUnitModel.UnitName, lLocal.Kind,
        lLocal.RoutineName, lLocal.Name, '', lLocal.Line, lLocal.Column, lUnitId,
        lSymbolId);
  end;
end;

function BuildProjectSymbolIndexContext(
  const aModels: TArray<TDelphiSemanticUnitModel>): TDelphiSemanticSymbolQueryContext;
var
  i: Integer;
begin
  Result := Default(TDelphiSemanticSymbolQueryContext);
  if Length(aModels) = 0 then
    Exit;

  Result.UnitModel := aModels[0];
  SetLength(Result.IndexedUnitModels, Length(aModels) - 1);
  SetLength(Result.IndexedUnitSourceKinds, Length(aModels) - 1);
  for i := 1 to High(aModels) do
  begin
    Result.IndexedUnitModels[i - 1] := aModels[i];
    Result.IndexedUnitSourceKinds[i - 1] := cSnapshotSourceKindProject;
  end;
end;

function BuildSnapshotReferenceTargets(
  const aModels: TArray<TDelphiSemanticUnitModel>):
  TDictionary<string, TSemanticSymbolRef>;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lIndex: TDelphiSemanticProjectSymbolIndex;
  lReference: TDelphiSemanticIndexedReference;
  lSymbol: TDelphiSemanticIndexedSymbol;
  lSymbolRef: TSemanticSymbolRef;
  lSymbolRefByLegacyId: TDictionary<string, TSemanticSymbolRef>;
  lSymbolRefsByOrigin: TDictionary<string, TSemanticSymbolRef>;
begin
  Result := TDictionary<string, TSemanticSymbolRef>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  lSymbolRefsByOrigin := BuildSnapshotSymbolRefsByOrigin(aModels);
  lSymbolRefByLegacyId := TDictionary<string, TSemanticSymbolRef>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  try
    lContext := BuildProjectSymbolIndexContext(aModels);
    lIndex := TDelphiSemanticProjectSymbolIndexer.Build(lContext);

    for lSymbol in lIndex.Symbols do
      if lSymbolRefsByOrigin.TryGetValue(SnapshotSymbolMatchKey(lSymbol.UnitName,
        lSymbol.Kind, lSymbol.OwnerName, lSymbol.Name, lSymbol.Signature, lSymbol.Line,
        lSymbol.Column), lSymbolRef) then
        lSymbolRefByLegacyId.AddOrSetValue(lSymbol.Id.Value, lSymbolRef);

    for lReference in lIndex.References do
      if SameText(lReference.Status, 'resolved') and
        lSymbolRefByLegacyId.TryGetValue(lReference.SymbolId.Value, lSymbolRef) then
        Result.AddOrSetValue(SnapshotReferenceMatchKey(lReference.UnitName,
          lReference.RoutineName, lReference.Name, lReference.Line, lReference.Column),
          lSymbolRef);
  finally
    lSymbolRefByLegacyId.Free;
    lSymbolRefsByOrigin.Free;
  end;
end;

procedure AddSnapshotWithStatement(const aStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot; const aModel: TDelphiSemanticUnitModel;
  const aWith: TDelphiSemanticWithStatement;
  var aMetrics: TSnapshotUnitBuildResult);
var
  lWith: TSemanticWithStatementFact;
begin
  lWith := Default(TSemanticWithStatementFact);
  lWith.RoutineId := aStrings.Intern(SnapshotRoutineNameForLine(aModel, aWith.Line));
  lWith.SelectorStartLine := aWith.Line;
  lWith.SelectorStartColumn := aWith.Column;
  lWith.BodyStartLine := aWith.BodyLine;
  lWith.BodyStartColumn := aWith.BodyColumn;
  lWith.BodyEndLine := aWith.BodyEndLine;
  lWith.BodyEndColumn := aWith.BodyEndColumn;
  if aWith.HasScopedDeclaration then
    lWith.Flags := cSnapshotWithFlagHasScopedDeclaration;
  aUnit.AddWithStatement(lWith);
  Inc(aMetrics.WithStatementCount);
end;

procedure AddSnapshotDeclaration(const aStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot; const aDeclaration: TDelphiSemanticDeclaration;
  var aMetrics: TSnapshotUnitBuildResult);
var
  lSymbol: TSemanticSymbolFact;
begin
  lSymbol := Default(TSemanticSymbolFact);
  lSymbol.NameId := aStrings.Intern(aDeclaration.Name);
  lSymbol.TypeId := aStrings.Intern(aDeclaration.TypeName);
  lSymbol.KindId := aStrings.Intern(SnapshotDeclarationKind(aDeclaration.Kind));
  lSymbol.SectionKindId := aStrings.Intern(aDeclaration.SectionKind);
  lSymbol.SourceKindId := aStrings.Intern(cSnapshotSourceKindProject);
  lSymbol.Line := aDeclaration.Line;
  lSymbol.Column := aDeclaration.Column;
  lSymbol.EndLine := aDeclaration.Line;
  lSymbol.EndColumn := SnapshotEndColumn(aDeclaration.Column, aDeclaration.Name);
  aUnit.AddSymbol(lSymbol);
  Inc(aMetrics.SymbolCount);
end;

procedure AddSnapshotMember(const aStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot; const aMember: TDelphiSemanticMember;
  var aMetrics: TSnapshotUnitBuildResult);
var
  lSymbol: TSemanticSymbolFact;
begin
  lSymbol := Default(TSemanticSymbolFact);
  lSymbol.NameId := aStrings.Intern(aMember.Name);
  lSymbol.OwnerTypeId := aStrings.Intern(aMember.OwnerName);
  lSymbol.TypeId := aStrings.Intern(aMember.TypeName);
  lSymbol.KindId := aStrings.Intern(aMember.Kind);
  lSymbol.SourceKindId := aStrings.Intern(cSnapshotSourceKindProject);
  lSymbol.VisibilityId := aStrings.Intern(aMember.Visibility);
  lSymbol.SignatureId := aStrings.Intern(aMember.Signature);
  lSymbol.Line := aMember.Line;
  lSymbol.Column := aMember.Column;
  lSymbol.EndLine := aMember.Line;
  lSymbol.EndColumn := SnapshotEndColumn(aMember.Column, aMember.Name);
  if aMember.IsDefault then
    lSymbol.Flags := lSymbol.Flags or cSnapshotSymbolFlagIsDefault;
  if aMember.IsIndexed then
    lSymbol.Flags := lSymbol.Flags or cSnapshotSymbolFlagIsIndexed;
  aUnit.AddSymbol(lSymbol);
  Inc(aMetrics.SymbolCount);
end;

procedure AddSnapshotParameter(const aStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot; const aRoutineName: string;
  const aParameter: TDelphiSemanticParameter;
  var aMetrics: TSnapshotUnitBuildResult);
var
  lSymbol: TSemanticSymbolFact;
begin
  lSymbol := Default(TSemanticSymbolFact);
  lSymbol.NameId := aStrings.Intern(aParameter.Name);
  lSymbol.TypeId := aStrings.Intern(aParameter.TypeName);
  lSymbol.RoutineId := aStrings.Intern(aRoutineName);
  lSymbol.KindId := aStrings.Intern(cSnapshotSymbolKindParameter);
  lSymbol.SourceKindId := aStrings.Intern(cSnapshotSourceKindProject);
  lSymbol.Line := aParameter.Line;
  lSymbol.Column := aParameter.Column;
  lSymbol.EndLine := aParameter.Line;
  lSymbol.EndColumn := SnapshotEndColumn(aParameter.Column, aParameter.Name);
  aUnit.AddSymbol(lSymbol);
  Inc(aMetrics.SymbolCount);
end;

procedure AddSnapshotRoutine(const aStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot; const aRoutine: TDelphiSemanticRoutine;
  var aMetrics: TSnapshotUnitBuildResult);
var
  lParameter: TDelphiSemanticParameter;
  lRoutineName: string;
  lSymbol: TSemanticSymbolFact;
begin
  lRoutineName := SnapshotRoutineName(aRoutine);
  lSymbol := Default(TSemanticSymbolFact);
  lSymbol.NameId := aStrings.Intern(aRoutine.Name);
  lSymbol.OwnerTypeId := aStrings.Intern(aRoutine.OwnerName);
  lSymbol.TypeId := aStrings.Intern(aRoutine.ReturnType);
  lSymbol.RoutineId := aStrings.Intern(lRoutineName);
  lSymbol.KindId := aStrings.Intern(cSnapshotSymbolKindRoutine);
  lSymbol.SectionKindId := aStrings.Intern(aRoutine.SectionKind);
  lSymbol.SourceKindId := aStrings.Intern(cSnapshotSourceKindProject);
  lSymbol.SignatureId := aStrings.Intern(aRoutine.Signature);
  lSymbol.Line := aRoutine.Line;
  lSymbol.Column := aRoutine.Column;
  lSymbol.EndLine := aRoutine.Line;
  lSymbol.EndColumn := SnapshotEndColumn(aRoutine.Column, aRoutine.Name);
  aUnit.AddSymbol(lSymbol);
  Inc(aMetrics.SymbolCount);

  for lParameter in aRoutine.Parameters do
    AddSnapshotParameter(aStrings, aUnit, lRoutineName, lParameter, aMetrics);
end;

procedure AddSnapshotLocal(const aStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot; const aLocal: TDelphiSemanticLocal;
  var aMetrics: TSnapshotUnitBuildResult);
var
  lKind: string;
  lSymbol: TSemanticSymbolFact;
begin
  lKind := aLocal.Kind;
  if lKind = '' then
    lKind := cSnapshotSymbolKindLocal;
  lSymbol := Default(TSemanticSymbolFact);
  lSymbol.NameId := aStrings.Intern(aLocal.Name);
  lSymbol.TypeId := aStrings.Intern(aLocal.TypeName);
  lSymbol.RoutineId := aStrings.Intern(aLocal.RoutineName);
  lSymbol.KindId := aStrings.Intern(lKind);
  lSymbol.SourceKindId := aStrings.Intern(cSnapshotSourceKindProject);
  lSymbol.Line := aLocal.Line;
  lSymbol.Column := aLocal.Column;
  lSymbol.EndLine := aLocal.Line;
  lSymbol.EndColumn := SnapshotEndColumn(aLocal.Column, aLocal.Name);
  aUnit.AddSymbol(lSymbol);
  Inc(aMetrics.SymbolCount);
end;

procedure AddSnapshotReference(const aStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot; const aUnitName: string;
  const aReference: TDelphiSemanticReference;
  const aReferenceTargets: TDictionary<string, TSemanticSymbolRef>;
  var aMetrics: TSnapshotUnitBuildResult);
var
  lReference: TSemanticReferenceFact;
  lTarget: TSemanticSymbolRef;
begin
  lReference := Default(TSemanticReferenceFact);
  lReference.WithId := SnapshotWithIdForLine(aUnit, aReference.Line);
  lReference.NameId := aStrings.Intern(aReference.Name);
  lReference.RoutineId := aStrings.Intern(aReference.RoutineName);
  lReference.SectionKindId := aStrings.Intern(aReference.SectionKind);
  lReference.SourceKindId := aStrings.Intern(cSnapshotSourceKindProject);
  lReference.ClassificationId := aStrings.Intern(aReference.Role);
  lReference.Line := aReference.Line;
  lReference.Column := aReference.Column;
  lReference.EndLine := aReference.EndLine;
  if lReference.EndLine <= 0 then
    lReference.EndLine := aReference.Line;
  lReference.EndColumn := aReference.EndColumn;
  if lReference.EndColumn <= 0 then
    lReference.EndColumn := SnapshotEndColumn(aReference.Column, aReference.Name);
  if (aReferenceTargets <> nil) and aReferenceTargets.TryGetValue(
    SnapshotReferenceMatchKey(aUnitName, aReference.RoutineName, aReference.Name,
    aReference.Line, aReference.Column), lTarget) then
  begin
    lReference.TargetUnitId := lTarget.UnitId;
    lReference.TargetSymbolId := lTarget.SymbolId;
  end;
  aUnit.AddReference(lReference);
  Inc(aMetrics.ReferenceCount);
end;

function CreateSnapshotUnitModel(const aStrings: TSemanticStringPool;
  const aModel: TDelphiSemanticUnitModel; const aUnitId: TSemanticUnitId;
  const aReferenceTargets: TDictionary<string, TSemanticSymbolRef>;
  var aMetrics: TSnapshotUnitBuildResult): TUnitSnapshot;
var
  lDeclaration: TDelphiSemanticDeclaration;
  lLocal: TDelphiSemanticLocal;
  lMember: TDelphiSemanticMember;
  lReference: TDelphiSemanticReference;
  lRoutine: TDelphiSemanticRoutine;
  lWith: TDelphiSemanticWithStatement;
begin
  Result := TUnitSnapshot.Create(aUnitId, aStrings.Intern(SnapshotFullPath(aModel.FileName)),
    aStrings.Intern(aModel.UnitName));
  try
    for lWith in aModel.WithStatements do
      AddSnapshotWithStatement(aStrings, Result, aModel, lWith, aMetrics);
    for lDeclaration in aModel.Declarations do
      AddSnapshotDeclaration(aStrings, Result, lDeclaration, aMetrics);
    for lMember in aModel.Members do
      AddSnapshotMember(aStrings, Result, lMember, aMetrics);
    for lRoutine in aModel.Routines do
      AddSnapshotRoutine(aStrings, Result, lRoutine, aMetrics);
    for lLocal in aModel.Locals do
      AddSnapshotLocal(aStrings, Result, lLocal, aMetrics);
    for lReference in aModel.References do
      AddSnapshotReference(aStrings, Result, aModel.UnitName, lReference,
        aReferenceTargets, aMetrics);
  except
    Result.Free;
    raise;
  end;
end;

procedure AddSnapshotFlag(var aFlags: Cardinal; const aFlag: Cardinal;
  const aEnabled: Boolean);
begin
  if aEnabled then
    aFlags := aFlags or aFlag;
end;

function SnapshotInventorySymbol(const aExactStrings: TSemanticStringPool;
  const aSymbol: TDelphiSemanticInventorySymbol): TSemanticRemoveWithInventorySymbolFact;
begin
  Result := Default(TSemanticRemoveWithInventorySymbolFact);
  Result.NameId := aExactStrings.Intern(aSymbol.Name);
  Result.SymbolClassId := aExactStrings.Intern(aSymbol.SymbolClass);
  Result.KindId := aExactStrings.Intern(aSymbol.Kind);
  Result.TypeNameId := aExactStrings.Intern(aSymbol.TypeName);
  Result.ModifierId := aExactStrings.Intern(aSymbol.Modifier);
  Result.OwnerNameId := aExactStrings.Intern(aSymbol.OwnerName);
  Result.OwnerTypeId := aExactStrings.Intern(aSymbol.OwnerType);
  Result.SourceOwnerTypeId := aExactStrings.Intern(aSymbol.SourceOwnerType);
  Result.RelatedTypeNameId := aExactStrings.Intern(aSymbol.RelatedTypeName);
  Result.RoutineNameId := aExactStrings.Intern(aSymbol.RoutineName);
  Result.UnitNameId := aExactStrings.Intern(aSymbol.UnitName);
  Result.FileNameId := aExactStrings.Intern(aSymbol.FileName);
  Result.SectionKindId := aExactStrings.Intern(aSymbol.SectionKind);
  Result.Line := aSymbol.Line;
  Result.Column := aSymbol.Column;
  Result.EndLine := aSymbol.EndLine;
  Result.EndColumn := aSymbol.EndColumn;
  Result.UnsupportedReasonId := aExactStrings.Intern(aSymbol.UnsupportedReason);
  AddSnapshotFlag(Result.Flags, cSemanticRemoveWithSymbolFlagIsHelper,
    aSymbol.IsHelper);
  AddSnapshotFlag(Result.Flags, cSemanticRemoveWithSymbolFlagIsOverride,
    aSymbol.IsOverride);
  AddSnapshotFlag(Result.Flags, cSemanticRemoveWithSymbolFlagIsDefault,
    aSymbol.IsDefault);
  AddSnapshotFlag(Result.Flags, cSemanticRemoveWithSymbolFlagIsIndexed,
    aSymbol.IsIndexed);
  Result.IndexParameterCount := aSymbol.IndexParameterCount;
  Result.TypeCategoryId := aExactStrings.Intern(aSymbol.TypeCategory);
end;

function SnapshotSelectorBinding(const aExactStrings: TSemanticStringPool;
  const aSelector: TDelphiSemanticWithSelectorBinding):
  TSemanticRemoveWithSelectorBindingFact;
begin
  Result := Default(TSemanticRemoveWithSelectorBindingFact);
  Result.SelectorTextId := aExactStrings.Intern(aSelector.SelectorText);
  Result.StatusId := aExactStrings.Intern(aSelector.Status);
  Result.ReasonCodeId := aExactStrings.Intern(aSelector.ReasonCode);
  Result.TypeNameId := aExactStrings.Intern(aSelector.TypeName);
end;

function SnapshotBoundReference(const aExactStrings: TSemanticStringPool;
  const aReference: TDelphiSemanticBoundReference):
  TSemanticRemoveWithBoundReferenceFact;
begin
  Result := Default(TSemanticRemoveWithBoundReferenceFact);
  Result.SemanticIdId := aExactStrings.Intern(aReference.SemanticId);
  Result.NameId := aExactStrings.Intern(aReference.Name);
  Result.ClassificationId := aExactStrings.Intern(aReference.Classification);
  Result.LookupSourceId := aExactStrings.Intern(aReference.LookupSource);
  Result.ReceiverTypeNameId := aExactStrings.Intern(aReference.ReceiverTypeName);
  Result.KindId := aExactStrings.Intern(aReference.Kind);
  Result.TypeNameId := aExactStrings.Intern(aReference.TypeName);
  Result.ReasonCodeId := aExactStrings.Intern(aReference.ReasonCode);
  Result.ScopeConflictKindId := aExactStrings.Intern(aReference.ScopeConflictKind);
  Result.ScopeConflictNameId := aExactStrings.Intern(aReference.ScopeConflictName);
  Result.Line := aReference.Line;
  Result.Column := aReference.Column;
  Result.EndLine := aReference.EndLine;
  Result.EndColumn := aReference.EndColumn;
end;

function SnapshotWithBinding(const aExactStrings: TSemanticStringPool;
  const aBinding: TDelphiSemanticWithBinding): TSemanticRemoveWithBindingFact;
var
  i: Integer;
begin
  Result := Default(TSemanticRemoveWithBindingFact);
  Result.SemanticIdId := aExactStrings.Intern(aBinding.SemanticId);
  Result.ProvenanceId := aExactStrings.Intern(aBinding.Provenance);
  Result.FileNameId := aExactStrings.Intern(aBinding.FileName);
  Result.UnitNameId := aExactStrings.Intern(aBinding.UnitName);
  Result.RoutineNameId := aExactStrings.Intern(aBinding.RoutineName);
  Result.Line := aBinding.Line;
  Result.Column := aBinding.Column;
  Result.EndLine := aBinding.EndLine;
  Result.EndColumn := aBinding.EndColumn;
  Result.BodyLine := aBinding.BodyLine;
  Result.BodyColumn := aBinding.BodyColumn;
  Result.BodyEndLine := aBinding.BodyEndLine;
  Result.BodyEndColumn := aBinding.BodyEndColumn;
  Result.SelectorTextId := aExactStrings.Intern(aBinding.SelectorText);
  Result.StatusId := aExactStrings.Intern(aBinding.Status);
  Result.SkipReasonId := aExactStrings.Intern(aBinding.SkipReason);
  AddSnapshotFlag(Result.Flags, cSemanticRemoveWithBindingFlagHasScopedDeclaration,
    aBinding.HasScopedDeclaration);
  Result.MemberReferenceCount := aBinding.MemberReferenceCount;
  Result.LexicalReferenceCount := aBinding.LexicalReferenceCount;
  Result.ExternalReferenceCount := aBinding.ExternalReferenceCount;
  Result.IntrinsicReferenceCount := aBinding.IntrinsicReferenceCount;
  Result.UnsupportedReferenceCount := aBinding.UnsupportedReferenceCount;
  Result.UnresolvedReferenceCount := aBinding.UnresolvedReferenceCount;
  SetLength(Result.Selectors, Length(aBinding.Selectors));
  for i := 0 to High(aBinding.Selectors) do
    Result.Selectors[i] := SnapshotSelectorBinding(aExactStrings, aBinding.Selectors[i]);
  SetLength(Result.References, Length(aBinding.References));
  for i := 0 to High(aBinding.References) do
    Result.References[i] := SnapshotBoundReference(aExactStrings, aBinding.References[i]);
end;

function CreateRemoveWithPlanningFacts(const aExactStrings: TSemanticStringPool;
  const aFacts: TDelphiSemanticProjectWithBindingFacts): TSemanticRemoveWithPlanningFacts;
var
  i: Integer;
begin
  Result := Default(TSemanticRemoveWithPlanningFacts);
  Result.ContextFingerprintId := aExactStrings.Intern(aFacts.ContextFingerprint);
  SetLength(Result.Symbols, Length(aFacts.Symbols));
  for i := 0 to High(aFacts.Symbols) do
    Result.Symbols[i] := SnapshotInventorySymbol(aExactStrings, aFacts.Symbols[i]);
  SetLength(Result.Bindings, Length(aFacts.Bindings));
  for i := 0 to High(aFacts.Bindings) do
    Result.Bindings[i] := SnapshotWithBinding(aExactStrings, aFacts.Bindings[i]);
end;

function RemapStringId(const aSourceStrings, aTargetStrings: TSemanticStringPool;
  const aId: TSemanticStringId): TSemanticStringId;
begin
  if aId = 0 then
    Exit(0);

  Result := aTargetStrings.Intern(aSourceStrings.TextOf(aId));
end;

function RemapSymbolFact(const aSourceStrings, aTargetStrings: TSemanticStringPool;
  const aSymbol: TSemanticSymbolFact): TSemanticSymbolFact;
begin
  Result := aSymbol;
  Result.NameId := RemapStringId(aSourceStrings, aTargetStrings, aSymbol.NameId);
  Result.OwnerTypeId := RemapStringId(aSourceStrings, aTargetStrings,
    aSymbol.OwnerTypeId);
  Result.TypeId := RemapStringId(aSourceStrings, aTargetStrings, aSymbol.TypeId);
  Result.RoutineId := RemapStringId(aSourceStrings, aTargetStrings,
    aSymbol.RoutineId);
  Result.KindId := RemapStringId(aSourceStrings, aTargetStrings, aSymbol.KindId);
  Result.SectionKindId := RemapStringId(aSourceStrings, aTargetStrings,
    aSymbol.SectionKindId);
  Result.SourceKindId := RemapStringId(aSourceStrings, aTargetStrings,
    aSymbol.SourceKindId);
  Result.VisibilityId := RemapStringId(aSourceStrings, aTargetStrings,
    aSymbol.VisibilityId);
  Result.SignatureId := RemapStringId(aSourceStrings, aTargetStrings,
    aSymbol.SignatureId);
end;

function RemapWithFact(const aSourceStrings, aTargetStrings: TSemanticStringPool;
  const aWith: TSemanticWithStatementFact): TSemanticWithStatementFact;
begin
  Result := aWith;
  Result.RoutineId := RemapStringId(aSourceStrings, aTargetStrings, aWith.RoutineId);
end;

function RemapReferenceFact(const aSourceStrings, aTargetStrings: TSemanticStringPool;
  const aReference: TSemanticReferenceFact): TSemanticReferenceFact;
begin
  Result := aReference;
  Result.NameId := RemapStringId(aSourceStrings, aTargetStrings, aReference.NameId);
  Result.ReceiverTypeId := RemapStringId(aSourceStrings, aTargetStrings,
    aReference.ReceiverTypeId);
  Result.TypeId := RemapStringId(aSourceStrings, aTargetStrings, aReference.TypeId);
  Result.RoutineId := RemapStringId(aSourceStrings, aTargetStrings,
    aReference.RoutineId);
  Result.SectionKindId := RemapStringId(aSourceStrings, aTargetStrings,
    aReference.SectionKindId);
  Result.SourceKindId := RemapStringId(aSourceStrings, aTargetStrings,
    aReference.SourceKindId);
  Result.ClassificationId := RemapStringId(aSourceStrings, aTargetStrings,
    aReference.ClassificationId);
  Result.LookupSourceId := RemapStringId(aSourceStrings, aTargetStrings,
    aReference.LookupSourceId);
  Result.ReasonId := RemapStringId(aSourceStrings, aTargetStrings, aReference.ReasonId);
end;

function RemapUnitSnapshot(const aSourceStrings: TSemanticStringPool;
  const aTargetStrings: TSemanticStringPool; const aUnit: TUnitSnapshot):
  TUnitSnapshot;
var
  lReferenceId: TSemanticReferenceId;
  lSymbolId: TSemanticSymbolId;
  lWithId: TSemanticWithId;
begin
  Result := TUnitSnapshot.Create(aUnit.UnitId, RemapStringId(aSourceStrings,
    aTargetStrings, aUnit.FileNameId), RemapStringId(aSourceStrings,
    aTargetStrings, aUnit.UnitNameId));
  try
    for lSymbolId := 1 to TSemanticSymbolId(aUnit.SymbolCount) do
      Result.AddSymbol(RemapSymbolFact(aSourceStrings, aTargetStrings,
        aUnit.SymbolById(lSymbolId)));
    for lWithId := 1 to TSemanticWithId(aUnit.WithStatementCount) do
      Result.AddWithStatement(RemapWithFact(aSourceStrings, aTargetStrings,
        aUnit.WithStatementById(lWithId)));
    for lReferenceId := 1 to TSemanticReferenceId(aUnit.ReferenceCount) do
      Result.AddReference(RemapReferenceFact(aSourceStrings, aTargetStrings,
        aUnit.ReferenceById(lReferenceId)));
  except
    Result.Free;
    raise;
  end;
end;

function EffectiveWorkerCount(const aRequestedWorkerCount, aUnitCount: Integer):
  Integer;
begin
  if aUnitCount <= 0 then
    Exit(0);

  Result := aRequestedWorkerCount;
  if Result <= 0 then
    Result := TThread.ProcessorCount;
  if Result < 1 then
    Result := 1;
  if Result > aUnitCount then
    Result := aUnitCount;
end;

procedure AddSequentialSnapshotUnit(const aBuilder: TDelphiProjectSnapshotBuilder;
  const aModel: TDelphiSemanticUnitModel; const aUnitId: TSemanticUnitId;
  const aReferenceTargets: TDictionary<string, TSemanticSymbolRef>;
  var aMetrics: TDelphiSnapshotBuilderMetrics);
var
  lUnit: TUnitSnapshot;
  lUnitMetrics: TSnapshotUnitBuildResult;
begin
  lUnitMetrics := Default(TSnapshotUnitBuildResult);
  lUnit := CreateSnapshotUnitModel(aBuilder.Strings, aModel, aUnitId, aReferenceTargets,
    lUnitMetrics);
  try
    aBuilder.AddUnit(lUnit);
    lUnit := nil;
    Inc(aMetrics.UnitCount);
    Inc(aMetrics.SymbolCount, lUnitMetrics.SymbolCount);
    Inc(aMetrics.ReferenceCount, lUnitMetrics.ReferenceCount);
    Inc(aMetrics.WithStatementCount, lUnitMetrics.WithStatementCount);
  finally
    lUnit.Free;
  end;
end;

function BuildSequentialProjectSnapshotFromModels(
  const aModels: TArray<TDelphiSemanticUnitModel>;
  const aRemoveWithFacts: TDelphiSemanticProjectWithBindingFacts;
  const aReferenceTargets: TDictionary<string, TSemanticSymbolRef>;
  var aMetrics: TDelphiSnapshotBuilderMetrics): TDelphiProjectSnapshot;
var
  i: Integer;
  lBuilder: TDelphiProjectSnapshotBuilder;
  lMergeStopwatch: TStopwatch;
  lWorkerStopwatch: TStopwatch;
begin
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  try
    aMetrics.WorkerCount := 0;
    if Length(aModels) > 0 then
      aMetrics.WorkerCount := 1;

    lWorkerStopwatch := TStopwatch.StartNew;
    try
      for i := 0 to High(aModels) do
        AddSequentialSnapshotUnit(lBuilder, aModels[i], TSemanticUnitId(i + 1),
          aReferenceTargets, aMetrics);
    finally
      lWorkerStopwatch.Stop;
      aMetrics.ParseExtractMilliseconds := lWorkerStopwatch.ElapsedMilliseconds;
    end;

    lMergeStopwatch := TStopwatch.StartNew;
    try
      lBuilder.SetRemoveWithPlanningFacts(CreateRemoveWithPlanningFacts(
        lBuilder.ExactStrings, aRemoveWithFacts));
      aMetrics.DeterministicFactCount := aMetrics.UnitCount + aMetrics.SymbolCount +
        aMetrics.ReferenceCount + aMetrics.WithStatementCount;
      Result := lBuilder.Build;
    finally
      lMergeStopwatch.Stop;
      aMetrics.MergeMilliseconds := lMergeStopwatch.ElapsedMilliseconds;
    end;
  finally
    lBuilder.Free;
  end;
end;

function BuildUnitResult(const aModel: TDelphiSemanticUnitModel;
  const aUnitId: TSemanticUnitId;
  const aReferenceTargets: TDictionary<string, TSemanticSymbolRef>):
  TSnapshotUnitBuildResult;
begin
  Result := Default(TSnapshotUnitBuildResult);
  Result.Strings := TSemanticStringPool.Create;
  try
    Result.UnitSnapshot := CreateSnapshotUnitModel(Result.Strings, aModel, aUnitId,
      aReferenceTargets, Result);
    Result.UnitCount := 1;
  except
    Result.UnitSnapshot.Free;
    Result.Strings.Free;
    Result := Default(TSnapshotUnitBuildResult);
    raise;
  end;
end;

procedure FreeUnitBuildResults(var aResults: TArray<TSnapshotUnitBuildResult>);
var
  i: Integer;
begin
  for i := 0 to High(aResults) do
  begin
    aResults[i].UnitSnapshot.Free;
    aResults[i].UnitSnapshot := nil;
    aResults[i].Strings.Free;
    aResults[i].Strings := nil;
  end;
end;

procedure RaiseThreadException(const aThread: TThread);
var
  lException: TObject;
begin
  lException := aThread.FatalException;
  if lException = nil then
    Exit;

  if lException is Exception then
    raise Exception.Create(Exception(lException).Message);

  raise Exception.Create(lException.ClassName);
end;

constructor TSnapshotBuildWorkerContext.Create(
  const aModels: TArray<TDelphiSemanticUnitModel>;
  const aReferenceTargets: TDictionary<string, TSemanticSymbolRef>);
begin
  inherited Create;
  fLock := TObject.Create;
  fNextIndex := 0;
  fReferenceTargets := aReferenceTargets;
  fUnitModels := Copy(aModels);
  SetLength(Results, Length(aModels));
end;

destructor TSnapshotBuildWorkerContext.Destroy;
begin
  fLock.Free;
  inherited;
end;

function TSnapshotBuildWorkerContext.TryTakeNextIndex(out aIndex: Integer):
  Boolean;
begin
  TMonitor.Enter(fLock);
  try
    Result := fNextIndex <= High(fUnitModels);
    if not Result then
      Exit;

    aIndex := fNextIndex;
    Inc(fNextIndex);
  finally
    TMonitor.Exit(fLock);
  end;
end;

function TSnapshotBuildWorkerContext.UnitModelByIndex(
  const aIndex: Integer): TDelphiSemanticUnitModel;
begin
  Result := fUnitModels[aIndex];
end;

constructor TSnapshotBuildWorkerThread.Create(
  const aContext: TSnapshotBuildWorkerContext);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  fContext := aContext;
end;

procedure TSnapshotBuildWorkerThread.Execute;
var
  lIndex: Integer;
begin
  while fContext.TryTakeNextIndex(lIndex) do
  begin
    fContext.Results[lIndex] := BuildUnitResult(fContext.UnitModelByIndex(lIndex),
      TSemanticUnitId(lIndex + 1), fContext.ReferenceTargets);
  end;
end;

function BuildUnitResults(const aModels: TArray<TDelphiSemanticUnitModel>;
  const aReferenceTargets: TDictionary<string, TSemanticSymbolRef>;
  const aWorkerCount: Integer; var aMetrics: TDelphiSnapshotBuilderMetrics):
  TArray<TSnapshotUnitBuildResult>;
var
  i: Integer;
  lContext: TSnapshotBuildWorkerContext;
  lCreatedCount: Integer;
  lQueueStopwatch: TStopwatch;
  lStartedCount: Integer;
  lThreads: TArray<TSnapshotBuildWorkerThread>;
  lThreadsJoined: Boolean;
  lWorkerStopwatch: TStopwatch;
begin
  SetLength(Result, Length(aModels));
  aMetrics.WorkerCount := EffectiveWorkerCount(aWorkerCount, Length(aModels));
  if Length(aModels) = 0 then
    Exit;

  if aMetrics.WorkerCount <= 1 then
  begin
    lWorkerStopwatch := TStopwatch.StartNew;
    try
      for i := 0 to High(aModels) do
        Result[i] := BuildUnitResult(aModels[i], TSemanticUnitId(i + 1),
          aReferenceTargets);
    finally
      lWorkerStopwatch.Stop;
      aMetrics.ParseExtractMilliseconds := lWorkerStopwatch.ElapsedMilliseconds;
    end;
    Exit;
  end;

  lContext := TSnapshotBuildWorkerContext.Create(aModels, aReferenceTargets);
  try
    try
      lCreatedCount := 0;
      lStartedCount := 0;
      lThreadsJoined := False;
      try
        lQueueStopwatch := TStopwatch.StartNew;
        try
          SetLength(lThreads, aMetrics.WorkerCount);
          for i := 0 to High(lThreads) do
          begin
            lThreads[i] := TSnapshotBuildWorkerThread.Create(lContext);
            Inc(lCreatedCount);
          end;
          for i := 0 to lCreatedCount - 1 do
          begin
            lThreads[i].Start;
            Inc(lStartedCount);
          end;
        finally
          lQueueStopwatch.Stop;
          aMetrics.QueueMilliseconds := lQueueStopwatch.ElapsedMilliseconds;
        end;

        lWorkerStopwatch := TStopwatch.StartNew;
        try
          for i := 0 to lStartedCount - 1 do
            lThreads[i].WaitFor;
          lThreadsJoined := True;
          for i := 0 to lStartedCount - 1 do
            RaiseThreadException(lThreads[i]);
        finally
          lWorkerStopwatch.Stop;
          aMetrics.ParseExtractMilliseconds := lWorkerStopwatch.ElapsedMilliseconds;
        end;

        Result := lContext.Results;
        SetLength(lContext.Results, 0);
      finally
        if not lThreadsJoined then
        begin
          for i := 0 to lStartedCount - 1 do
            lThreads[i].WaitFor;
        end;
        for i := 0 to lCreatedCount - 1 do
          lThreads[i].Free;
      end;
    except
      FreeUnitBuildResults(lContext.Results);
      raise;
    end;
  finally
    lContext.Free;
  end;
end;

function MergeUnitResults(
  const aResults: TArray<TSnapshotUnitBuildResult>;
  const aRemoveWithFacts: TDelphiSemanticProjectWithBindingFacts;
  var aMetrics: TDelphiSnapshotBuilderMetrics): TDelphiProjectSnapshot;
var
  i: Integer;
  lBuilder: TDelphiProjectSnapshotBuilder;
  lMergedUnit: TUnitSnapshot;
  lStopwatch: TStopwatch;
begin
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  lStopwatch := TStopwatch.StartNew;
  try
    for i := 0 to High(aResults) do
    begin
      lMergedUnit := RemapUnitSnapshot(aResults[i].Strings, lBuilder.Strings,
        aResults[i].UnitSnapshot);
      try
        lBuilder.AddUnit(lMergedUnit);
        lMergedUnit := nil;
      finally
        lMergedUnit.Free;
      end;

      Inc(aMetrics.UnitCount, aResults[i].UnitCount);
      Inc(aMetrics.SymbolCount, aResults[i].SymbolCount);
      Inc(aMetrics.ReferenceCount, aResults[i].ReferenceCount);
      Inc(aMetrics.WithStatementCount, aResults[i].WithStatementCount);
    end;
    lBuilder.SetRemoveWithPlanningFacts(CreateRemoveWithPlanningFacts(
      lBuilder.ExactStrings, aRemoveWithFacts));
    aMetrics.DeterministicFactCount := aMetrics.UnitCount + aMetrics.SymbolCount +
      aMetrics.ReferenceCount + aMetrics.WithStatementCount;
    Result := lBuilder.Build;
  finally
    lStopwatch.Stop;
    aMetrics.MergeMilliseconds := lStopwatch.ElapsedMilliseconds;
    lBuilder.Free;
  end;
end;

function BuildProjectSnapshotFromModels(
  const aModels: TArray<TDelphiSemanticUnitModel>;
  const aRemoveWithFacts: TDelphiSemanticProjectWithBindingFacts;
  const aOptions: TDelphiSnapshotBuildOptions;
  out aMetrics: TDelphiSnapshotBuilderMetrics): TDelphiProjectSnapshot;
var
  lReferenceTargets: TDictionary<string, TSemanticSymbolRef>;
  lResults: TArray<TSnapshotUnitBuildResult>;
  lStopwatch: TStopwatch;
begin
  aMetrics := Default(TDelphiSnapshotBuilderMetrics);
  lReferenceTargets := nil;
  lResults := nil;
  lStopwatch := TStopwatch.StartNew;
  try
    if aOptions.ResolveReferenceTargets then
      lReferenceTargets := BuildSnapshotReferenceTargets(aModels);
    if aOptions.WorkerCount <= 1 then
      Result := BuildSequentialProjectSnapshotFromModels(aModels, aRemoveWithFacts,
        lReferenceTargets, aMetrics)
    else begin
      lResults := BuildUnitResults(aModels, lReferenceTargets, aOptions.WorkerCount,
        aMetrics);
      Result := MergeUnitResults(lResults, aRemoveWithFacts, aMetrics);
    end;
  finally
    lStopwatch.Stop;
    aMetrics.BuildMilliseconds := lStopwatch.ElapsedMilliseconds;
    FreeUnitBuildResults(lResults);
    lReferenceTargets.Free;
  end;
end;

end.
