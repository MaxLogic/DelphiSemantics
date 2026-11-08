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
  System.IOUtils, System.SysUtils,
  DelphiSemantics.Snapshot.QuerySupport;

function PhysicalPositionMatches(const aSnapshot: TDelphiProjectSnapshot;
  const aFileId: TSemanticStringId; const aFileName: string;
  const aLine, aColumn, aEndLine, aEndColumn, aQueryLine, aQueryColumn: Integer): Boolean;
begin
  Result := SameText(SnapshotText(aSnapshot, aFileId), aFileName) and
    (aLine > 0) and (aColumn > 0) and (aQueryLine >= aLine) and (aQueryLine <= aEndLine) and
    ((aQueryLine > aLine) or (aQueryColumn >= aColumn)) and
    ((aQueryLine < aEndLine) or (aQueryColumn <= aEndColumn));
end;

function TryPhysicalSnapshotPosition(const aSnapshot: TDelphiProjectSnapshot;
  const aFileName: string; const aLine, aColumn: Integer; const aToken: string;
  out aResolution: TDelphiSemanticSnapshotPositionResolution; out aHandled: Boolean): Boolean;
var
  i, j, k, lCount: Integer;
  lUnit: TUnitSnapshot;
  lOccurrence: TSemanticPhysicalSymbolOccurrence;
  lReference: TSemanticPhysicalReferenceOccurrence;
  lSource: TSemanticCapturedSourceFact;
  lFile: string;

  procedure SelectSymbol(const aOccurrence: TSemanticPhysicalSymbolOccurrence);
  var
    lSymbol: TSemanticSymbolFact;
  begin
    if not aOccurrence.Verified or (aOccurrence.ProjectionStatus <> cPhysicalProjectionLinked) or
      (aOccurrence.SnapshotSymbolId = 0) then
      Exit;
    lSymbol := lUnit.SymbolById(aOccurrence.SnapshotSymbolId);
    if (lSymbol.Line <= 0) or (lSymbol.Column <= 0) then
      Exit;
    Inc(lCount);
    aResolution.Status := 'snapshot-physical-position-match';
    aResolution.SymbolFound := True;
    aResolution.SymbolRef.UnitId := lUnit.UnitId;
    aResolution.SymbolRef.SymbolId := aOccurrence.SnapshotSymbolId;
    aResolution.Symbol := lSymbol;
    aResolution.SymbolUnit := lUnit;
  end;

begin
  aHandled := False;
  aResolution := Default(TDelphiSemanticSnapshotPositionResolution);
  lCount := 0;
  try
    lFile := TPath.GetFullPath(StringReplace(aFileName, '/', '\', [rfReplaceAll]));
  except
    // An invalid requested path cannot identify any captured occurrence.
    Exit(False);
  end;
  for i := 0 to aSnapshot.UnitCount - 1 do
  begin
    lUnit := aSnapshot.UnitByIndex(i);
    if not lUnit.HasIncludes then
      Continue;
    for j := 0 to lUnit.CapturedSourceCount - 1 do
    begin
      lSource := lUnit.CapturedSourceByIndex(j);
      if SameText(SnapshotText(aSnapshot, lSource.FileId), lFile) and
        (lSource.FileId <> lUnit.FileNameId) then
        aHandled := True;
    end;
    if not lUnit.PhysicalSymbolOccurrencesAvailable then
      Continue;
    for j := 0 to lUnit.PhysicalSymbolOccurrenceCount - 1 do
    begin
      lOccurrence := lUnit.PhysicalSymbolOccurrenceByIndex(j);
      if SameText(SnapshotText(aSnapshot, lOccurrence.FileId), lFile) and
        (lOccurrence.FileId <> lUnit.FileNameId) then
        aHandled := True;
      if PhysicalPositionMatches(aSnapshot, lOccurrence.FileId, lFile, lOccurrence.Line,
        lOccurrence.Column, lOccurrence.EndLine, lOccurrence.EndColumn, aLine, aColumn) and
        ((aToken = '') or SameText(SnapshotText(aSnapshot, lOccurrence.NameId), aToken)) then
        SelectSymbol(lOccurrence);
    end;
    if not lUnit.PhysicalReferenceOccurrencesAvailable then
      Continue;
    for j := 0 to lUnit.PhysicalReferenceOccurrenceCount - 1 do
    begin
      lReference := lUnit.PhysicalReferenceOccurrenceByIndex(j);
      if not lReference.Verified or (lReference.RoutineScopeId = 0) or
        not PhysicalPositionMatches(aSnapshot, lReference.FileId, lFile, lReference.Line,
          lReference.Column, lReference.EndLine, lReference.EndColumn, aLine, aColumn) or
        ((aToken <> '') and not SameText(SnapshotText(aSnapshot, lReference.NameId), aToken)) then
        Continue;
      for k := 0 to lUnit.PhysicalSymbolOccurrenceCount - 1 do
      begin
        lOccurrence := lUnit.PhysicalSymbolOccurrenceByIndex(k);
        if (SnapshotText(aSnapshot, lOccurrence.FactKindId) = 'local') and
          (lOccurrence.NameId = lReference.NameId) and
          (lOccurrence.RoutineScopeId = lReference.RoutineScopeId) then
          SelectSymbol(lOccurrence);
      end;
    end;
  end;
  Result := lCount = 1;
  if not Result then
    aResolution := Default(TDelphiSemanticSnapshotPositionResolution);
end;

function TryResolveSnapshotPosition(const aSnapshot: TDelphiProjectSnapshot;
  const aFileName: string; const aLine, aColumn: Integer; const aToken: string;
  out aResolution: TDelphiSemanticSnapshotPositionResolution): Boolean;
var
  lPhysicalHandled: Boolean;
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

  if TryPhysicalSnapshotPosition(aSnapshot, aFileName, aLine, aColumn, aToken,
    aResolution, lPhysicalHandled) then
    Exit(True);
  if lPhysicalHandled then
    Exit(False);

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
