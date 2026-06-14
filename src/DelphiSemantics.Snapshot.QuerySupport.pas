unit DelphiSemantics.Snapshot.QuerySupport;

interface

uses
  DelphiSemantics.Query, DelphiSemantics.Snapshot, DelphiSemantics.Symbols;

function ContextProjectSnapshot(const aContext: TDelphiSemanticSymbolQueryContext):
  TDelphiProjectSnapshot;
function SnapshotText(const aSnapshot: TDelphiProjectSnapshot;
  const aId: TSemanticStringId): string;
function SnapshotSymbolId(const aSymbolRef: TSemanticSymbolRef): TDelphiSemanticSymbolId;
function SnapshotSymbolOwnerName(const aSnapshot: TDelphiProjectSnapshot;
  const aSymbol: TSemanticSymbolFact; const aKind: string): string;

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

function SnapshotSymbolOwnerName(const aSnapshot: TDelphiProjectSnapshot;
  const aSymbol: TSemanticSymbolFact; const aKind: string): string;
begin
  if aSymbol.OwnerTypeId <> 0 then
    Exit(aSnapshot.TextOf(aSymbol.OwnerTypeId));
  if (aSymbol.RoutineId <> 0) and MatchText(aKind, ['local', 'parameter', 'var']) then
    Exit(aSnapshot.TextOf(aSymbol.RoutineId));

  Result := '';
end;

end.
