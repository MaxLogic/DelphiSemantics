unit DelphiSemantics.Snapshot.PositionResolver;

interface

uses
  DelphiSemantics.Snapshot;

type
  TDelphiSemanticSnapshotPositionResolution = record
    Status: string;
    ReferenceFound: Boolean;
    SymbolFound: Boolean;
    ReferenceRef: TSemanticReferenceRef;
    Reference: TSemanticReferenceFact;
    SourceUnit: TUnitSnapshot;
    SymbolRef: TSemanticSymbolRef;
    Symbol: TSemanticSymbolFact;
    SymbolUnit: TUnitSnapshot;
  end;

function TryResolveSnapshotPosition(const aSnapshot: TDelphiProjectSnapshot;
  const aFileName: string; const aLine, aColumn: Integer; const aToken: string;
  out aResolution: TDelphiSemanticSnapshotPositionResolution): Boolean;

implementation

uses
  System.SysUtils,
  DelphiSemantics.Snapshot.QuerySupport;

function TryResolveSnapshotPosition(const aSnapshot: TDelphiProjectSnapshot;
  const aFileName: string; const aLine, aColumn: Integer; const aToken: string;
  out aResolution: TDelphiSemanticSnapshotPositionResolution): Boolean;
var
  lReference: TSemanticReferenceFact;
  lReferenceRef: TSemanticReferenceRef;
  lSymbol: TSemanticSymbolFact;
  lSymbolRef: TSemanticSymbolRef;
  lTargetSymbol: TSemanticSymbolFact;
  lTargetUnit: TUnitSnapshot;
  lUnit: TUnitSnapshot;
begin
  Result := False;
  aResolution := Default(TDelphiSemanticSnapshotPositionResolution);
  if aSnapshot = nil then
    Exit;

  if aSnapshot.TryReferenceAt(aFileName, aLine, aColumn, lReferenceRef) and
    aSnapshot.TryFindUnitById(lReferenceRef.UnitId, lUnit) then
  begin
    lReference := lUnit.ReferenceById(lReferenceRef.ReferenceId);
    if ((aToken = '') or SameText(SnapshotText(aSnapshot, lReference.NameId), aToken)) and
      (lReference.TargetUnitId <> 0) and (lReference.TargetSymbolId <> 0) and
      aSnapshot.TryFindUnitById(lReference.TargetUnitId, lTargetUnit) then
    begin
      lTargetSymbol := lTargetUnit.SymbolById(lReference.TargetSymbolId);
      if lTargetSymbol.NameId <> 0 then
      begin
        aResolution.Status := 'snapshot-reference-target';
        aResolution.ReferenceFound := True;
        aResolution.SymbolFound := True;
        aResolution.ReferenceRef := lReferenceRef;
        aResolution.Reference := lReference;
        aResolution.SourceUnit := lUnit;
        aResolution.SymbolRef.UnitId := lReference.TargetUnitId;
        aResolution.SymbolRef.SymbolId := lReference.TargetSymbolId;
        aResolution.Symbol := lTargetSymbol;
        aResolution.SymbolUnit := lTargetUnit;
        Exit(True);
      end;
    end;
  end;

  if aSnapshot.TrySymbolAt(aFileName, aLine, aColumn, lSymbolRef) and
    aSnapshot.TryFindUnitById(lSymbolRef.UnitId, lUnit) then
  begin
    lSymbol := lUnit.SymbolById(lSymbolRef.SymbolId);
    if lSymbol.NameId = 0 then
      Exit(False);
    aResolution.Status := 'snapshot-position-match';
    aResolution.SymbolFound := True;
    aResolution.SymbolRef := lSymbolRef;
    aResolution.Symbol := lSymbol;
    aResolution.SymbolUnit := lUnit;
    Exit(True);
  end;
end;

end.
