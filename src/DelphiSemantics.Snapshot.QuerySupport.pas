unit DelphiSemantics.Snapshot.QuerySupport;

interface

uses
  DelphiSemantics.Query, DelphiSemantics.Snapshot, DelphiSemantics.Symbols;

function ContextProjectSnapshot(const aContext: TDelphiSemanticSymbolQueryContext):
  TDelphiProjectSnapshot;
function SnapshotText(const aSnapshot: TDelphiProjectSnapshot;
  const aId: TSemanticStringId): string;
function SnapshotSymbolId(const aSymbolRef: TSemanticSymbolRef): TDelphiSemanticSymbolId;
function SnapshotUnitSymbolId(const aUnit: TUnitSnapshot): TDelphiSemanticSymbolId;
function SnapshotEndLine(const aLine, aEndLine: Integer): Integer;
function SnapshotEndColumn(const aColumn: Integer; const aName: string;
  const aEndColumn: Integer): Integer;
function SnapshotSourceKindForUnit(const aSnapshot: TDelphiProjectSnapshot;
  const aUnit: TUnitSnapshot): string;
function SnapshotUnitIndexedSymbol(const aSnapshot: TDelphiProjectSnapshot;
  const aUnit: TUnitSnapshot): TDelphiSemanticIndexedSymbol;
function SnapshotIndexedSymbol(const aSnapshot: TDelphiProjectSnapshot;
  const aUnit: TUnitSnapshot; const aSymbolRef: TSemanticSymbolRef;
  const aSymbol: TSemanticSymbolFact): TDelphiSemanticIndexedSymbol;
function SnapshotIndexedReference(const aSnapshot: TDelphiProjectSnapshot;
  const aUnit: TUnitSnapshot; const aReference: TSemanticReferenceFact):
  TDelphiSemanticIndexedReference;
function SnapshotSymbolOwnerName(const aSnapshot: TDelphiProjectSnapshot;
  const aSymbol: TSemanticSymbolFact; const aKind: string): string;
// DS-659: the file that holds a fact: its include file, or else its unit's file.
function SnapshotFactFileName(const aSnapshot: TDelphiProjectSnapshot;
  const aUnit: TUnitSnapshot; const aFileId: TSemanticStringId): string;
function SnapshotSymbolVisibleToPublicNameQuery(const aSnapshot: TDelphiProjectSnapshot;
  const aSymbol: TSemanticSymbolFact): Boolean;

implementation

uses
  System.StrUtils, System.SysUtils;

function ContextProjectSnapshot(const aContext: TDelphiSemanticSymbolQueryContext):
  TDelphiProjectSnapshot;
begin
  if aContext.ProjectSnapshot = nil then
    Exit(nil);

  Result := aContext.ProjectSnapshot.Snapshot;
end;

function SnapshotText(const aSnapshot: TDelphiProjectSnapshot;
  const aId: TSemanticStringId): string;
begin
  if (aSnapshot = nil) or (aId = 0) then
    Exit('');

  Result := aSnapshot.TextOf(aId);
end;

function SnapshotSymbolId(const aSymbolRef: TSemanticSymbolRef): TDelphiSemanticSymbolId;
begin
  Result.Value := 'snapshot:' + IntToStr(Integer(aSymbolRef.UnitId)) + ':' +
    IntToStr(Integer(aSymbolRef.SymbolId));
end;

function SnapshotUnitSymbolId(const aUnit: TUnitSnapshot): TDelphiSemanticSymbolId;
begin
  Result.Value := 'snapshot:' + IntToStr(Integer(aUnit.UnitId)) + ':unit';
end;

function SnapshotEndLine(const aLine, aEndLine: Integer): Integer;
begin
  Result := aEndLine;
  if Result <= 0 then
    Result := aLine;
end;

function SnapshotEndColumn(const aColumn: Integer; const aName: string;
  const aEndColumn: Integer): Integer;
begin
  Result := aEndColumn;
  if Result <= 0 then
    Result := aColumn + Length(aName) - 1;
end;

function SnapshotSourceKindForUnit(const aSnapshot: TDelphiProjectSnapshot;
  const aUnit: TUnitSnapshot): string;
var
  lSymbol: TSemanticSymbolFact;
begin
  Result := 'project-snapshot';
  if aUnit.SymbolCount <= 0 then
    Exit;

  lSymbol := aUnit.SymbolById(TSemanticSymbolId(1));
  if SnapshotText(aSnapshot, lSymbol.SourceKindId) <> '' then
    Result := SnapshotText(aSnapshot, lSymbol.SourceKindId);
end;

function SnapshotUnitIndexedSymbol(const aSnapshot: TDelphiProjectSnapshot;
  const aUnit: TUnitSnapshot): TDelphiSemanticIndexedSymbol;
begin
  Result := Default(TDelphiSemanticIndexedSymbol);
  Result.Id := SnapshotUnitSymbolId(aUnit);
  Result.Name := SnapshotText(aSnapshot, aUnit.UnitNameId);
  Result.Kind := 'unit';
  Result.UnitName := Result.Name;
  Result.SectionKind := 'interface';
  Result.SourceKind := SnapshotSourceKindForUnit(aSnapshot, aUnit);
  Result.FileName := SnapshotText(aSnapshot, aUnit.FileNameId);
  Result.Line := 1;
  Result.Column := 1;
end;

function SnapshotIndexedSymbol(const aSnapshot: TDelphiProjectSnapshot;
  const aUnit: TUnitSnapshot; const aSymbolRef: TSemanticSymbolRef;
  const aSymbol: TSemanticSymbolFact): TDelphiSemanticIndexedSymbol;
var
  lKind: string;
begin
  lKind := SnapshotPublicSymbolKind(SnapshotText(aSnapshot, aSymbol.KindId));
  Result := Default(TDelphiSemanticIndexedSymbol);
  Result.Id := SnapshotSymbolId(aSymbolRef);
  Result.Name := SnapshotText(aSnapshot, aSymbol.NameId);
  Result.Kind := lKind;
  Result.OwnerName := SnapshotSymbolOwnerName(aSnapshot, aSymbol, lKind);
  Result.UnitName := SnapshotText(aSnapshot, aUnit.UnitNameId);
  Result.SectionKind := SnapshotText(aSnapshot, aSymbol.SectionKindId);
  Result.SourceKind := SnapshotText(aSnapshot, aSymbol.SourceKindId);
  if Result.SourceKind = '' then
    Result.SourceKind := 'project-snapshot';
  Result.Visibility := SnapshotText(aSnapshot, aSymbol.VisibilityId);
  Result.Signature := SnapshotText(aSnapshot, aSymbol.SignatureId);
  Result.FileName := SnapshotFactFileName(aSnapshot, aUnit, aSymbol.FileId);
  Result.Line := aSymbol.Line;
  Result.Column := aSymbol.Column;
  if SameText(lKind, 'routine') then
    Result.ScopeId := SnapshotText(aSnapshot, aSymbol.RoutineScopeId);
  Result.FromInclude := aSymbol.FileId <> 0;
end;

function SnapshotIndexedReference(const aSnapshot: TDelphiProjectSnapshot;
  const aUnit: TUnitSnapshot; const aReference: TSemanticReferenceFact):
  TDelphiSemanticIndexedReference;
var
  lReferenceSymbolRef: TSemanticSymbolRef;
begin
  Result := Default(TDelphiSemanticIndexedReference);
  Result.Name := SnapshotText(aSnapshot, aReference.NameId);
  Result.RoutineName := SnapshotText(aSnapshot, aReference.RoutineId);
  Result.UnitName := SnapshotText(aSnapshot, aUnit.UnitNameId);
  Result.SourceKind := SnapshotText(aSnapshot, aReference.SourceKindId);
  if Result.SourceKind = '' then
    Result.SourceKind := 'project-snapshot';
  Result.FileName := SnapshotFactFileName(aSnapshot, aUnit, aReference.FileId);
  Result.SectionKind := SnapshotText(aSnapshot, aReference.SectionKindId);
  if Result.SectionKind = '' then
    Result.SectionKind := 'implementation';
  Result.Line := aReference.Line;
  Result.Column := aReference.Column;
  Result.EndLine := SnapshotEndLine(aReference.Line, aReference.EndLine);
  Result.EndColumn := SnapshotEndColumn(aReference.Column, Result.Name,
    aReference.EndColumn);
  if (aReference.TargetUnitId <> 0) and (aReference.TargetSymbolId <> 0) then
  begin
    lReferenceSymbolRef.UnitId := aReference.TargetUnitId;
    lReferenceSymbolRef.SymbolId := aReference.TargetSymbolId;
    Result.SymbolId := SnapshotSymbolId(lReferenceSymbolRef);
    Result.CandidateSymbolIds := [Result.SymbolId];
    Result.Status := 'resolved';
    Result.Confidence := 'snapshot-target';
  end else
  begin
    Result.Status := 'unresolved';
    Result.Confidence := 'no-candidates';
  end;
end;

function SnapshotSymbolOwnerName(const aSnapshot: TDelphiProjectSnapshot;
  const aSymbol: TSemanticSymbolFact; const aKind: string): string;
begin
  if aSymbol.OwnerTypeId <> 0 then
    Exit(aSnapshot.TextOf(aSymbol.OwnerTypeId));
  if (aSymbol.RoutineId <> 0) and MatchText(aKind, ['local', 'parameter', 'var']) then
    Exit(aSnapshot.TextOf(aSymbol.RoutineId));

  Result := '';
end;

function SnapshotFactFileName(const aSnapshot: TDelphiProjectSnapshot;
  const aUnit: TUnitSnapshot; const aFileId: TSemanticStringId): string;
begin
  if aFileId <> 0 then
    Exit(SnapshotText(aSnapshot, aFileId));
  Result := SnapshotText(aSnapshot, aUnit.FileNameId);
end;

function SnapshotSymbolVisibleToPublicNameQuery(const aSnapshot: TDelphiProjectSnapshot;
  const aSymbol: TSemanticSymbolFact): Boolean;
var
  lKind: string;
begin
  lKind := SnapshotText(aSnapshot, aSymbol.KindId);
  if SameText(lKind, 'unit') or SameText(lKind, 'local') or SameText(lKind,
    'parameter') then
    Exit(False);
  if (aSymbol.RoutineId <> 0) and (aSymbol.OwnerTypeId = 0) and
    not SameText(lKind, 'routine') then
    Exit(False);

  Result := True;
end;

end.
