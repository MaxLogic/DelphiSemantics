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
function BuildProjectSnapshotFromUnitSnapshots(
  const aSnapshots: TArray<TDelphiProjectSnapshot>;
  out aMetrics: TDelphiSnapshotBuilderMetrics): TDelphiProjectSnapshot;
function BuildProjectUnitSnapshotFromModels(
  const aModels: TArray<TDelphiSemanticUnitModel>; const aModelIndex: Integer;
  const aUnitId: TSemanticUnitId; out aMetrics: TDelphiSnapshotBuilderMetrics):
  TDelphiProjectSnapshot;
function BuildRemoveWithPlanningSnapshotFromFacts(
  const aFacts: TDelphiSemanticProjectWithBindingFacts): TDelphiProjectSnapshot;
function BuildSnapshotReferenceTargets(
  const aModels: TArray<TDelphiSemanticUnitModel>):
  TDictionary<string, TSemanticSymbolRef>;

implementation

uses
  System.Classes, System.Diagnostics, System.IOUtils, System.StrUtils, System.SysUtils,
  MaxLogic.StrUtils,
  DelphiSemantics.Snapshot.RemoveWith;

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

  TSnapshotTargetSymbol = record
    Ref: TSemanticSymbolRef;
    Name: string;
    Kind: string;
    OwnerName: string;
    UnitName: string;
    SectionKind: string;
    Signature: string;
  end;

  TSnapshotTargetSymbolList = TList<TSnapshotTargetSymbol>;
  TSnapshotTargetSymbolsByName = TObjectDictionary<string, TSnapshotTargetSymbolList>;

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

function SnapshotReferenceMatchKey(const aUnitName, aRoutineName, aName: string;
  const aLine, aColumn: Integer): string;
begin
  Result := aUnitName + #9 + aRoutineName + #9 + aName + #9 + IntToStr(aLine) +
    #9 + IntToStr(aColumn);
end;

procedure AddTargetSymbolByName(const aMap: TSnapshotTargetSymbolsByName;
  const aSymbol: TSnapshotTargetSymbol);
var
  lSymbols: TSnapshotTargetSymbolList;
begin
  if not aMap.TryGetValue(aSymbol.Name, lSymbols) then
  begin
    lSymbols := TSnapshotTargetSymbolList.Create;
    try
      aMap.Add(aSymbol.Name, lSymbols);
    except
      lSymbols.Free;
      raise;
    end;
  end;
  lSymbols.Add(aSymbol);
end;

procedure AddSnapshotTargetSymbol(const aSymbols: TSnapshotTargetSymbolList;
  const aSymbolsByName: TSnapshotTargetSymbolsByName; const aUnitName, aKind,
  aOwnerName, aName, aSectionKind, aSignature: string; const aUnitId: TSemanticUnitId;
  var aNextSymbolId: TSemanticSymbolId);
var
  lSymbol: TSnapshotTargetSymbol;
begin
  Inc(aNextSymbolId);
  if aName = '' then
    Exit;

  lSymbol := Default(TSnapshotTargetSymbol);
  lSymbol.Ref.UnitId := aUnitId;
  lSymbol.Ref.SymbolId := aNextSymbolId;
  lSymbol.Name := aName;
  lSymbol.Kind := aKind;
  lSymbol.OwnerName := aOwnerName;
  lSymbol.UnitName := aUnitName;
  lSymbol.SectionKind := aSectionKind;
  lSymbol.Signature := aSignature;
  aSymbols.Add(lSymbol);
  AddTargetSymbolByName(aSymbolsByName, lSymbol);
end;

procedure AddModelSnapshotTargetSymbols(const aSymbols: TSnapshotTargetSymbolList;
  const aSymbolsByName: TSnapshotTargetSymbolsByName;
  const aModel: TDelphiSemanticUnitModel; const aUnitId: TSemanticUnitId);
var
  lDeclaration: TDelphiSemanticDeclaration;
  lLocal: TDelphiSemanticLocal;
  lMember: TDelphiSemanticMember;
  lParameter: TDelphiSemanticParameter;
  lRoutine: TDelphiSemanticRoutine;
  lSymbolId: TSemanticSymbolId;
begin
  lSymbolId := 0;
  for lDeclaration in aModel.Declarations do
    AddSnapshotTargetSymbol(aSymbols, aSymbolsByName, aModel.UnitName,
      SnapshotDeclarationKind(lDeclaration.Kind), '', lDeclaration.Name,
      lDeclaration.SectionKind, '', aUnitId, lSymbolId);
  for lMember in aModel.Members do
    AddSnapshotTargetSymbol(aSymbols, aSymbolsByName, aModel.UnitName,
      lMember.Kind, lMember.OwnerName, lMember.Name, '', lMember.Signature,
      aUnitId, lSymbolId);
  for lRoutine in aModel.Routines do
  begin
    AddSnapshotTargetSymbol(aSymbols, aSymbolsByName, aModel.UnitName,
      cSnapshotSymbolKindRoutine, lRoutine.OwnerName, lRoutine.Name,
      lRoutine.SectionKind, lRoutine.Signature, aUnitId, lSymbolId);
    for lParameter in lRoutine.Parameters do
      AddSnapshotTargetSymbol(aSymbols, aSymbolsByName, aModel.UnitName,
        cSnapshotSymbolKindParameter, SnapshotRoutineName(lRoutine),
        lParameter.Name, '', '', aUnitId, lSymbolId);
  end;
  for lLocal in aModel.Locals do
    AddSnapshotTargetSymbol(aSymbols, aSymbolsByName, aModel.UnitName,
      lLocal.Kind, lLocal.RoutineName, lLocal.Name, '', '', aUnitId, lSymbolId);
end;

function BuildSnapshotTargetSymbolsByName(
  const aModels: TArray<TDelphiSemanticUnitModel>;
  out aSymbols: TSnapshotTargetSymbolList): TSnapshotTargetSymbolsByName;
var
  i: Integer;
begin
  Result := nil;
  aSymbols := TSnapshotTargetSymbolList.Create;
  try
    Result := TSnapshotTargetSymbolsByName.Create([doOwnsValues],
      TFastCaseAwareComparer.OrdinalIgnoreCase);
    try
      for i := 0 to High(aModels) do
        AddModelSnapshotTargetSymbols(aSymbols, Result, aModels[i],
          TSemanticUnitId(i + 1));
    except
      Result.Free;
      Result := nil;
      raise;
    end;
  except
    aSymbols.Free;
    raise;
  end;
end;

function SymbolRefInList(const aRefs: TList<TSemanticSymbolRef>;
  const aRef: TSemanticSymbolRef): Boolean;
var
  lRef: TSemanticSymbolRef;
begin
  for lRef in aRefs do
    if (lRef.UnitId = aRef.UnitId) and (lRef.SymbolId = aRef.SymbolId) then
      Exit(True);

  Result := False;
end;

procedure AddCandidateRef(const aRefs: TList<TSemanticSymbolRef>;
  const aSymbol: TSnapshotTargetSymbol);
begin
  if not SymbolRefInList(aRefs, aSymbol.Ref) then
    aRefs.Add(aSymbol.Ref);
end;

function SnapshotLocalSymbolKind(const aKind: string): Boolean;
begin
  Result := MatchText(aKind, [cSnapshotSymbolKindLocal,
    cSnapshotSymbolKindParameter, 'var']);
end;

function SnapshotRoutineSimpleName(const aRoutineName: string): string;
var
  lIndex: Integer;
begin
  lIndex := LastDelimiter('.', aRoutineName);
  if lIndex > 0 then
    Exit(Copy(aRoutineName, lIndex + 1, MaxInt));

  Result := aRoutineName;
end;

function SnapshotQualifiedRoutineName(const aSymbol: TSnapshotTargetSymbol): string;
begin
  if aSymbol.OwnerName <> '' then
    Exit(aSymbol.OwnerName + '.' + aSymbol.Name);

  Result := aSymbol.Name;
end;

function NormalizeSnapshotSignature(const aSignature: string): string;
begin
  Result := LowerCase(StringReplace(aSignature.Trim, ' ', '', [rfReplaceAll]));
end;

function TryResolveUniqueSnapshotRoutineRef(
  const aSymbolsByName: TSnapshotTargetSymbolsByName;
  const aModel: TDelphiSemanticUnitModel; const aRoutineName: string;
  out aRoutineRef: TSemanticSymbolRef; out aAmbiguous: Boolean): Boolean;
var
  lCount: Integer;
  lSignature: string;
  lSymbol: TSnapshotTargetSymbol;
  lSymbols: TSnapshotTargetSymbolList;
begin
  aRoutineRef := Default(TSemanticSymbolRef);
  aAmbiguous := False;
  lCount := 0;
  lSignature := '';
  if not aSymbolsByName.TryGetValue(SnapshotRoutineSimpleName(aRoutineName),
    lSymbols) then
    Exit(False);

  for lSymbol in lSymbols do
    if SameText(lSymbol.UnitName, aModel.UnitName)
      and SameText(lSymbol.Kind, cSnapshotSymbolKindRoutine)
      and SameText(SnapshotQualifiedRoutineName(lSymbol), aRoutineName) then
    begin
      if lCount = 0 then
      begin
        Inc(lCount);
        aRoutineRef := lSymbol.Ref;
        lSignature := NormalizeSnapshotSignature(lSymbol.Signature);
      end else if not SameText(lSignature,
        NormalizeSnapshotSignature(lSymbol.Signature)) then
      begin
        Inc(lCount);
        aRoutineRef := Default(TSemanticSymbolRef);
        aAmbiguous := True;
        Exit(False);
      end;
    end;

  Result := lCount = 1;
end;

function AddLocalReferenceCandidates(const aSymbolsByName: TSnapshotTargetSymbolsByName;
  const aModel: TDelphiSemanticUnitModel; const aReference: TDelphiSemanticReference;
  const aCandidateRefs: TList<TSemanticSymbolRef>): Boolean;
var
  lAmbiguousRoutine: Boolean;
  lRoutineRef: TSemanticSymbolRef;
  lSymbol: TSnapshotTargetSymbol;
  lSymbols: TSnapshotTargetSymbolList;
begin
  Result := False;
  if aReference.RoutineName = '' then
    Exit;
  if not TryResolveUniqueSnapshotRoutineRef(aSymbolsByName, aModel,
    aReference.RoutineName, lRoutineRef, lAmbiguousRoutine) then
  begin
    Result := lAmbiguousRoutine;
    Exit;
  end;
  if lRoutineRef.SymbolId = 0 then
    Exit;
  if not aSymbolsByName.TryGetValue(aReference.Name, lSymbols) then
    Exit;

  for lSymbol in lSymbols do
    if SameText(lSymbol.UnitName, aModel.UnitName)
      and SameText(lSymbol.OwnerName, aReference.RoutineName)
      and SnapshotLocalSymbolKind(lSymbol.Kind) then
      AddCandidateRef(aCandidateRefs, lSymbol);

  Result := aCandidateRefs.Count > 0;
end;

function OwnedSymbolIsVisibleFromReference(const aModel: TDelphiSemanticUnitModel;
  const aReference: TDelphiSemanticReference;
  const aSymbol: TSnapshotTargetSymbol): Boolean;
begin
  if aSymbol.OwnerName = '' then
    Exit(False);
  if not SameText(aModel.UnitName, aSymbol.UnitName) then
    Exit(False);
  if MatchText(aSymbol.Kind, ['field', 'class-var', 'property']) then
    Exit(StartsText(aSymbol.OwnerName + '.', aReference.RoutineName));

  Result := False;
end;

function IsOwnedMethodCandidate(const aModel: TDelphiSemanticUnitModel;
  const aSymbol: TSnapshotTargetSymbol): Boolean;
begin
  Result := (aSymbol.OwnerName <> '') and SameText(aModel.UnitName, aSymbol.UnitName)
    and SameText(aSymbol.Kind, 'method');
end;

procedure AddOwnedReferenceCandidates(const aSymbolsByName: TSnapshotTargetSymbolsByName;
  const aModel: TDelphiSemanticUnitModel; const aReference: TDelphiSemanticReference;
  const aCandidateRefs: TList<TSemanticSymbolRef>);
var
  lMethodCandidate: TSnapshotTargetSymbol;
  lMethodCount: Integer;
  lMethodOwnerName: string;
  lSymbol: TSnapshotTargetSymbol;
  lSymbols: TSnapshotTargetSymbolList;
begin
  if not aSymbolsByName.TryGetValue(aReference.Name, lSymbols) then
    Exit;

  lMethodCandidate := Default(TSnapshotTargetSymbol);
  lMethodCount := 0;
  lMethodOwnerName := '';
  for lSymbol in lSymbols do
  begin
    if OwnedSymbolIsVisibleFromReference(aModel, aReference, lSymbol) then
      AddCandidateRef(aCandidateRefs, lSymbol);
    if IsOwnedMethodCandidate(aModel, lSymbol) and not SameText(lSymbol.OwnerName,
      lMethodOwnerName) then
    begin
      Inc(lMethodCount);
      lMethodOwnerName := lSymbol.OwnerName;
      lMethodCandidate := lSymbol;
    end;
  end;

  if lMethodCount = 1 then
    AddCandidateRef(aCandidateRefs, lMethodCandidate);
end;

function SectionCanSeeImplementationSymbols(const aSectionKind: string): Boolean;
begin
  Result := MatchText(aSectionKind, ['implementation', 'initialization',
    'finalization']);
end;

function TopLevelSymbolIsVisibleFromReference(const aModel: TDelphiSemanticUnitModel;
  const aSectionKind: string; const aSymbol: TSnapshotTargetSymbol): Boolean;
begin
  if aSymbol.OwnerName <> '' then
    Exit(False);

  if not (SameText(aSymbol.Kind, 'unit') or SameText(aSymbol.Kind, 'type') or
    SameText(aSymbol.Kind, cSnapshotDeclarationKindAlias) or
    SameText(aSymbol.Kind, cSnapshotDeclarationKindTypeAlias) or
    SameText(aSymbol.Kind, 'var') or SameText(aSymbol.Kind, 'const') or
    SameText(aSymbol.Kind, cSnapshotSymbolKindRoutine)) then
    Exit(False);

  if SameText(aModel.UnitName, aSymbol.UnitName) then
    Exit(SectionCanSeeImplementationSymbols(aSectionKind)
      or SameText(aSymbol.SectionKind, 'interface') or SameText(aSymbol.Kind, 'unit'));

  Result := SameText(aSymbol.SectionKind, 'interface') or SameText(aSymbol.Kind, 'unit');
end;

function ModelUsesUnitInSection(const aModel: TDelphiSemanticUnitModel;
  const aSectionKind, aUnitName: string): Boolean;
var
  s: string;
begin
  if SameText(aModel.UnitName, aUnitName) then
    Exit(True);

  for s in aModel.InterfaceUses do
    if SameText(s, aUnitName) then
      Exit(True);

  if SameText(aSectionKind, 'implementation') then
    for s in aModel.ImplementationUses do
      if SameText(s, aUnitName) then
        Exit(True);

  Result := False;
end;

procedure AddTopLevelReferenceCandidates(const aSymbolsByName: TSnapshotTargetSymbolsByName;
  const aModel: TDelphiSemanticUnitModel; const aReference: TDelphiSemanticReference;
  const aCandidateRefs: TList<TSemanticSymbolRef>);
var
  lSectionKind: string;
  lSymbol: TSnapshotTargetSymbol;
  lSymbols: TSnapshotTargetSymbolList;
begin
  if not aSymbolsByName.TryGetValue(aReference.Name, lSymbols) then
    Exit;

  lSectionKind := aReference.SectionKind;
  if lSectionKind = '' then
    lSectionKind := 'implementation';

  for lSymbol in lSymbols do
    if ModelUsesUnitInSection(aModel, lSectionKind, lSymbol.UnitName)
      and TopLevelSymbolIsVisibleFromReference(aModel, lSectionKind, lSymbol) then
      AddCandidateRef(aCandidateRefs, lSymbol);
end;

function TryResolveSnapshotReferenceTarget(const aSymbolsByName: TSnapshotTargetSymbolsByName;
  const aModel: TDelphiSemanticUnitModel; const aReference: TDelphiSemanticReference;
  out aTargetRef: TSemanticSymbolRef): Boolean;
var
  lCandidateRefs: TList<TSemanticSymbolRef>;
begin
  aTargetRef := Default(TSemanticSymbolRef);
  lCandidateRefs := TList<TSemanticSymbolRef>.Create;
  try
    if not AddLocalReferenceCandidates(aSymbolsByName, aModel, aReference,
      lCandidateRefs) then
    begin
      AddOwnedReferenceCandidates(aSymbolsByName, aModel, aReference,
        lCandidateRefs);
      AddTopLevelReferenceCandidates(aSymbolsByName, aModel, aReference,
        lCandidateRefs);
    end;

    Result := lCandidateRefs.Count = 1;
    if Result then
      aTargetRef := lCandidateRefs[0];
  finally
    lCandidateRefs.Free;
  end;
end;

function BuildSnapshotReferenceTargets(
  const aModels: TArray<TDelphiSemanticUnitModel>):
  TDictionary<string, TSemanticSymbolRef>;
var
  lReference: TDelphiSemanticReference;
  lSymbols: TSnapshotTargetSymbolList;
  lSymbolsByName: TSnapshotTargetSymbolsByName;
  lTargetRef: TSemanticSymbolRef;
  lUnitModel: TDelphiSemanticUnitModel;
begin
  Result := TDictionary<string, TSemanticSymbolRef>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  lSymbolsByName := BuildSnapshotTargetSymbolsByName(aModels, lSymbols);
  try
    for lUnitModel in aModels do
      for lReference in lUnitModel.References do
        if TryResolveSnapshotReferenceTarget(lSymbolsByName, lUnitModel, lReference,
          lTargetRef) then
          Result.AddOrSetValue(SnapshotReferenceMatchKey(lUnitModel.UnitName,
            lReference.RoutineName, lReference.Name, lReference.Line,
            lReference.Column), lTargetRef);
  finally
    lSymbolsByName.Free;
    lSymbols.Free;
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
  lRoutineOwners: TList<TSemanticRemoveWithInventorySymbolFact>;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := Default(TSemanticRemoveWithPlanningFacts);
  Result.ContextFingerprintId := aExactStrings.Intern(aFacts.ContextFingerprint);
  if aFacts.LookupIndex.IsAvailable then
    Result.LookupIndex := aFacts.LookupIndex
  else
    Result.LookupIndex := TDelphiSemanticRemoveWithLookupIndex.Build(
      aFacts.UnitModels, aFacts.Symbols);
  lRoutineOwners := TList<TSemanticRemoveWithInventorySymbolFact>.Create;
  try
    for lSymbol in aFacts.Symbols do
      if SameText(lSymbol.SymbolClass, 'routine') or SameText(lSymbol.Kind, 'routine') then
        lRoutineOwners.Add(SnapshotInventorySymbol(aExactStrings, lSymbol));
    Result.RoutineOwners := lRoutineOwners.ToArray;
  finally
    lRoutineOwners.Free;
  end;
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

function TargetNameKey(const aUnitId: TSemanticUnitId; const aName: string): string;
begin
  Result := IntToStr(Integer(aUnitId)) + '|' + aName;
end;

function BuildUniqueTargetSymbolsByName(
  const aSnapshots: TArray<TDelphiProjectSnapshot>): TDictionary<string, TSemanticSymbolRef>;
var
  i: Integer;
  lAmbiguous: TDictionary<string, Byte>;
  lKey: string;
  lRef: TSemanticSymbolRef;
  lSnapshot: TDelphiProjectSnapshot;
  lSymbol: TSemanticSymbolFact;
  lSymbolId: TSemanticSymbolId;
  lUnit: TUnitSnapshot;
begin
  Result := TDictionary<string, TSemanticSymbolRef>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  lAmbiguous := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  try
    for i := 0 to High(aSnapshots) do
    begin
      lSnapshot := aSnapshots[i];
      if (lSnapshot = nil) or (lSnapshot.UnitCount <> 1) then
        Continue;
      lUnit := lSnapshot.UnitByIndex(0);
      for lSymbolId := 1 to TSemanticSymbolId(lUnit.SymbolCount) do
      begin
        lSymbol := lUnit.SymbolById(lSymbolId);
        lKey := TargetNameKey(lUnit.UnitId, lSnapshot.TextOf(lSymbol.NameId));
        if lAmbiguous.ContainsKey(lKey) then
          Continue;
        lRef.UnitId := lUnit.UnitId;
        lRef.SymbolId := lSymbol.Id;
        if Result.ContainsKey(lKey) then
        begin
          Result.Remove(lKey);
          lAmbiguous.Add(lKey, 0);
        end else
          Result.Add(lKey, lRef);
      end;
    end;
  finally
    lAmbiguous.Free;
  end;
end;

function RemapReferenceFactWithResolvedTargets(const aSourceStrings,
  aTargetStrings: TSemanticStringPool; const aReference: TSemanticReferenceFact;
  const aTargetSymbolsByName: TDictionary<string, TSemanticSymbolRef>):
  TSemanticReferenceFact;
var
  lKey: string;
  lReferenceName: string;
  lTargetRef: TSemanticSymbolRef;
begin
  Result := RemapReferenceFact(aSourceStrings, aTargetStrings, aReference);
  if (aReference.TargetUnitId = 0) or (aReference.TargetSymbolId = 0) then
    Exit;

  lReferenceName := aSourceStrings.TextOf(aReference.NameId);
  lKey := TargetNameKey(aReference.TargetUnitId, lReferenceName);
  if aTargetSymbolsByName.TryGetValue(lKey, lTargetRef) then
  begin
    Result.TargetUnitId := lTargetRef.UnitId;
    Result.TargetSymbolId := lTargetRef.SymbolId;
  end else begin
    Result.TargetUnitId := 0;
    Result.TargetSymbolId := 0;
  end;
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

function RemapUnitSnapshotWithResolvedTargets(const aSourceStrings: TSemanticStringPool;
  const aTargetStrings: TSemanticStringPool; const aUnit: TUnitSnapshot;
  const aTargetSymbolsByName: TDictionary<string, TSemanticSymbolRef>):
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
      Result.AddReference(RemapReferenceFactWithResolvedTargets(aSourceStrings,
        aTargetStrings, aUnit.ReferenceById(lReferenceId), aTargetSymbolsByName));
  except
    Result.Free;
    raise;
  end;
end;

function CloneSnapshotStrings(const aSnapshot: TDelphiProjectSnapshot): TSemanticStringPool;
var
  i: Cardinal;
begin
  Result := TSemanticStringPool.Create;
  try
    for i := 1 to aSnapshot.StringCount do
      Result.Intern(aSnapshot.TextOf(TSemanticStringId(i)));
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
  lPlanningFacts: TSemanticRemoveWithPlanningFacts;
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
      lPlanningFacts := CreateRemoveWithPlanningFacts(lBuilder.ExactStrings,
        aRemoveWithFacts);
      lBuilder.SetRemoveWithPlanningFactsOwned(lPlanningFacts);
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
  lPlanningFacts: TSemanticRemoveWithPlanningFacts;
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
    lPlanningFacts := CreateRemoveWithPlanningFacts(lBuilder.ExactStrings,
      aRemoveWithFacts);
    lBuilder.SetRemoveWithPlanningFactsOwned(lPlanningFacts);
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

function BuildProjectUnitSnapshotFromModels(
  const aModels: TArray<TDelphiSemanticUnitModel>; const aModelIndex: Integer;
  const aUnitId: TSemanticUnitId; out aMetrics: TDelphiSnapshotBuilderMetrics):
  TDelphiProjectSnapshot;
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lReferenceTargets: TDictionary<string, TSemanticSymbolRef>;
  lResults: TArray<TSnapshotUnitBuildResult>;
  lStopwatch: TStopwatch;
begin
  aMetrics := Default(TDelphiSnapshotBuilderMetrics);
  lFacts := Default(TDelphiSemanticProjectWithBindingFacts);
  lReferenceTargets := nil;
  lResults := nil;
  lStopwatch := TStopwatch.StartNew;
  try
    lReferenceTargets := BuildSnapshotReferenceTargets(aModels);
    SetLength(lResults, 1);
    lResults[0] := BuildUnitResult(aModels[aModelIndex], aUnitId, lReferenceTargets);
    Result := MergeUnitResults(lResults, lFacts, aMetrics);
  finally
    lStopwatch.Stop;
    aMetrics.BuildMilliseconds := lStopwatch.ElapsedMilliseconds;
    FreeUnitBuildResults(lResults);
    lReferenceTargets.Free;
  end;
end;

function BuildProjectSnapshotFromUnitSnapshots(
  const aSnapshots: TArray<TDelphiProjectSnapshot>;
  out aMetrics: TDelphiSnapshotBuilderMetrics): TDelphiProjectSnapshot;
var
  i: Integer;
  lBuilder: TDelphiProjectSnapshotBuilder;
  lMergedUnit: TUnitSnapshot;
  lSourceStrings: TSemanticStringPool;
  lStopwatch: TStopwatch;
  lTargetSymbolsByName: TDictionary<string, TSemanticSymbolRef>;
  lUnit: TUnitSnapshot;
begin
  aMetrics := Default(TDelphiSnapshotBuilderMetrics);
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  lTargetSymbolsByName := nil;
  lStopwatch := TStopwatch.StartNew;
  try
    lTargetSymbolsByName := BuildUniqueTargetSymbolsByName(aSnapshots);
    for i := 0 to High(aSnapshots) do
    begin
      if (aSnapshots[i] = nil) or (aSnapshots[i].UnitCount <> 1) then
        raise Exception.Create('Project snapshot merge requires one-unit snapshot inputs.');

      lUnit := aSnapshots[i].UnitByIndex(0);
      lSourceStrings := CloneSnapshotStrings(aSnapshots[i]);
      try
        lMergedUnit := RemapUnitSnapshotWithResolvedTargets(lSourceStrings,
          lBuilder.Strings, lUnit, lTargetSymbolsByName);
        try
          lBuilder.AddUnit(lMergedUnit);
          lMergedUnit := nil;
        finally
          lMergedUnit.Free;
        end;
      finally
        lSourceStrings.Free;
      end;

      Inc(aMetrics.UnitCount);
      Inc(aMetrics.SymbolCount, lUnit.SymbolCount);
      Inc(aMetrics.ReferenceCount, lUnit.ReferenceCount);
      Inc(aMetrics.WithStatementCount, lUnit.WithStatementCount);
    end;
    aMetrics.DeterministicFactCount := aMetrics.UnitCount + aMetrics.SymbolCount +
      aMetrics.ReferenceCount + aMetrics.WithStatementCount;
    aMetrics.WorkerCount := 0;
    Result := lBuilder.Build;
  finally
    lStopwatch.Stop;
    aMetrics.MergeMilliseconds := lStopwatch.ElapsedMilliseconds;
    aMetrics.BuildMilliseconds := aMetrics.MergeMilliseconds;
    lTargetSymbolsByName.Free;
    lBuilder.Free;
  end;
end;

function BuildRemoveWithPlanningSnapshotFromFacts(
  const aFacts: TDelphiSemanticProjectWithBindingFacts): TDelphiProjectSnapshot;
var
  lBuilder: TDelphiProjectSnapshotBuilder;
  lPlanningFacts: TSemanticRemoveWithPlanningFacts;
begin
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  try
    lPlanningFacts := CreateRemoveWithPlanningFacts(lBuilder.ExactStrings,
      aFacts);
    lBuilder.SetRemoveWithPlanningFactsOwned(lPlanningFacts);
    Result := lBuilder.Build;
  finally
    lBuilder.Free;
  end;
end;

end.
