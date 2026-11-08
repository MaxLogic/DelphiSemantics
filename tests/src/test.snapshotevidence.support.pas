unit Test.SnapshotEvidence.Support;

interface

uses
  DelphiSemantics.Model, DelphiSemantics.Snapshot;

function PhysicalEvidenceModel(const aRoot, aName: string): TDelphiSemanticUnitModel;
procedure AssertPhysicalEvidence(const aSnapshot: TDelphiProjectSnapshot;
  const aModel: TDelphiSemanticUnitModel);

implementation

uses
  System.IOUtils, System.SysUtils,
  DUnitX.TestFramework,
  DelphiSemantics.Source;

function PhysicalEvidenceModel(const aRoot, aName: string): TDelphiSemanticUnitModel;
var
  lOptions: TDelphiSemanticModelOptions;
begin
  TFile.WriteAllText(TPath.Combine(aRoot, 'field.inc'), 'Field: Integer;', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(aRoot, 'body.inc'), 'GF := GF + 1;', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(aRoot, 'nested.inc'), '{$I body.inc}', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(aRoot, aName + '.pas'),
    'unit ' + aName + ';'#13#10'interface'#13#10'uses SysUtils;'#13#10 +
    'type TAlias = Integer; TOne = class'#13#10'const Value = 1;'#13#10'public'#13#10'{$I field.inc}'#13#10'end;'#13#10 +
    'TTwo = class'#13#10'{$I field.inc}'#13#10'end;'#13#10 +
    'var GF: Integer;'#13#10'implementation'#13#10'procedure Run(P: Integer);'#13#10 +
    'var L: Integer;'#13#10'begin'#13#10'{$I body.inc} {$I nested.inc}'#13#10 +
    'end;'#13#10'end.', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(aRoot, aName + '.pas');
  lOptions.SearchPaths := [aRoot];
  lOptions.ProjectContextApplied := True;
  Result := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(Result.Success);
  Assert.IsTrue(Result.PhysicalReferenceOccurrencesAvailable);
  Assert.IsTrue(Result.PhysicalSymbolOccurrencesAvailable);
end;

procedure AssertPhysicalEvidence(const aSnapshot: TDelphiProjectSnapshot;
  const aModel: TDelphiSemanticUnitModel);
var
  i: Integer;
  id: TSemanticUnitId;
  lFileId: TSemanticStringId;
  lRawReference: TDelphiSemanticPhysicalReferenceOccurrence;
  lRawSymbol: TDelphiSemanticPhysicalSymbolOccurrence;
  lReference: TSemanticPhysicalReferenceOccurrence;
  lSource: TDelphiSemanticSourceText;
  lSourceFact: TSemanticCapturedSourceFact;
  lSymbol: TSemanticPhysicalSymbolOccurrence;
  lUnit: TUnitSnapshot;
begin
  Assert.IsTrue(aSnapshot.TryFindUnitByFileName(aModel.FileName, id));
  Assert.IsTrue(aSnapshot.TryFindUnitById(id, lUnit));
  Assert.IsTrue(lUnit.PhysicalReferenceOccurrencesAvailable,
    'A captured complete model must project reference availability.');
  Assert.IsTrue(lUnit.PhysicalSymbolOccurrencesAvailable,
    'A captured complete model must project symbol availability.');
  Assert.IsTrue(lUnit.CapturedSourcesAvailable);
  Assert.IsTrue(lUnit.VisibleUnitNamesAvailable);
  Assert.IsTrue(lUnit.HasIncludes);
  Assert.AreEqual(Integer(Length(aModel.PhysicalReferenceOccurrences)), lUnit.PhysicalReferenceOccurrenceCount);
  Assert.AreEqual(Integer(Length(aModel.PhysicalSymbolOccurrences)), lUnit.PhysicalSymbolOccurrenceCount);
  Assert.IsTrue(lUnit.PhysicalReferenceOccurrenceCount > 3);
  Assert.IsTrue(lUnit.PhysicalSymbolOccurrenceCount > 5);
  for i := 0 to High(aModel.PhysicalReferenceOccurrences) do
  begin
    lRawReference := aModel.PhysicalReferenceOccurrences[i];
    lReference := lUnit.PhysicalReferenceOccurrenceByIndex(i);
    Assert.IsTrue(SameText(lRawReference.Name, aSnapshot.TextOf(lReference.NameId)));
    Assert.IsTrue(SameText(lRawReference.Role, aSnapshot.TextOf(lReference.RoleId)));
    Assert.IsTrue(SameText(lRawReference.RoutineName, aSnapshot.TextOf(lReference.RoutineNameId)));
    Assert.IsTrue(SameText(lRawReference.RoutineScopeId, aSnapshot.TextOf(lReference.RoutineScopeId)));
    if lRawReference.FileName = '' then
      Assert.AreEqual(0, Integer(lReference.FileId))
    else
      Assert.IsTrue(SameText(TPath.GetFullPath(lRawReference.FileName), aSnapshot.TextOf(lReference.FileId)));
    Assert.AreEqual(lRawReference.ExpansionId, aSnapshot.ExactTextOf(lReference.ExpansionId));
    Assert.AreEqual(lRawReference.OutputStartOffset, lReference.OutputStartOffset);
    Assert.AreEqual(lRawReference.OutputEndOffset, lReference.OutputEndOffset);
    Assert.AreEqual(lRawReference.Line, lReference.Line);
    Assert.AreEqual(lRawReference.Column, lReference.Column);
    Assert.AreEqual(lRawReference.EndLine, lReference.EndLine);
    Assert.AreEqual(lRawReference.EndColumn, lReference.EndColumn);
    Assert.AreEqual(lRawReference.Verified, lReference.Verified);
  end;
  for i := 0 to High(aModel.PhysicalSymbolOccurrences) do
  begin
    lRawSymbol := aModel.PhysicalSymbolOccurrences[i];
    lSymbol := lUnit.PhysicalSymbolOccurrenceByIndex(i);
    Assert.IsTrue(SameText(lRawSymbol.FactKind, aSnapshot.TextOf(lSymbol.FactKindId)));
    Assert.AreEqual(lRawSymbol.FactIndex, lSymbol.FactIndex);
    Assert.AreEqual(lRawSymbol.ParentFactIndex, lSymbol.ParentFactIndex);
    Assert.IsTrue(SameText(lRawSymbol.Name, aSnapshot.TextOf(lSymbol.NameId)));
    Assert.IsTrue(SameText(lRawSymbol.Kind, aSnapshot.TextOf(lSymbol.KindId)));
    Assert.IsTrue(SameText(lRawSymbol.OwnerName, aSnapshot.TextOf(lSymbol.OwnerNameId)));
    Assert.IsTrue(SameText(lRawSymbol.OwnerScopeId, aSnapshot.TextOf(lSymbol.OwnerScopeId)));
    Assert.IsTrue(SameText(lRawSymbol.SymbolId, aSnapshot.TextOf(lSymbol.SemanticSymbolId)));
    Assert.IsTrue(SameText(lRawSymbol.OwnerSymbolId, aSnapshot.TextOf(lSymbol.OwnerSymbolId)));
    Assert.IsTrue(SameText(lRawSymbol.RoutineName, aSnapshot.TextOf(lSymbol.RoutineNameId)));
    Assert.IsTrue(SameText(lRawSymbol.RoutineScopeId, aSnapshot.TextOf(lSymbol.RoutineScopeId)));
    Assert.IsTrue(SameText(lRawSymbol.SectionKind, aSnapshot.TextOf(lSymbol.SectionKindId)));
    if lRawSymbol.FileName = '' then
      Assert.AreEqual(0, Integer(lSymbol.FileId))
    else
      Assert.IsTrue(SameText(TPath.GetFullPath(lRawSymbol.FileName), aSnapshot.TextOf(lSymbol.FileId)));
    Assert.AreEqual(lRawSymbol.ExpansionId, aSnapshot.ExactTextOf(lSymbol.ExpansionId));
    Assert.AreEqual(lRawSymbol.OutputStartOffset, lSymbol.OutputStartOffset);
    Assert.AreEqual(lRawSymbol.OutputEndOffset, lSymbol.OutputEndOffset);
    Assert.AreEqual(lRawSymbol.Line, lSymbol.Line);
    Assert.AreEqual(lRawSymbol.Column, lSymbol.Column);
    Assert.AreEqual(lRawSymbol.EndLine, lSymbol.EndLine);
    Assert.AreEqual(lRawSymbol.EndColumn, lSymbol.EndColumn);
    Assert.AreEqual(lRawSymbol.Verified, lSymbol.Verified);
    if (lRawSymbol.FactKind = 'type-value-member') or
      ((lRawSymbol.FactKind = 'declaration') and
        ((lRawSymbol.Kind = 'routine') or SameText(lRawSymbol.Name, 'L') or SameText(lRawSymbol.Name, 'P'))) then
    begin
      Assert.AreEqual(cPhysicalProjectionNotProjected, lSymbol.ProjectionStatus);
      Assert.AreEqual(0, Integer(lSymbol.SnapshotSymbolId));
    end else begin
      Assert.AreEqual(cPhysicalProjectionLinked, lSymbol.ProjectionStatus);
      Assert.IsTrue(lSymbol.SnapshotSymbolId > 0);
      Assert.IsTrue(SameText(lRawSymbol.Name,
        aSnapshot.TextOf(lUnit.SymbolById(lSymbol.SnapshotSymbolId).NameId)));
    end;
  end;
  Assert.IsTrue(aModel.SourceObservations <> nil);
  Assert.AreEqual(aModel.SourceObservations.Count, lUnit.CapturedSourceCount);
  for i := 0 to aModel.SourceObservations.Count - 1 do
  begin
    lSource := aModel.SourceObservations.Items[i];
    Assert.IsTrue(aSnapshot.TryFindStringId(TPath.GetFullPath(lSource.FileName), lFileId));
    Assert.IsTrue(lUnit.TryFindCapturedSource(lFileId, lSourceFact));
    if lSource.Text = '' then
      Assert.AreEqual(cCapturedSourceEmpty, lSourceFact.Status)
    else
      Assert.AreEqual(cCapturedSourceText, lSourceFact.Status);
    Assert.AreEqual(lSource.Text, aSnapshot.ExactTextOf(lSourceFact.TextId));
  end;
  Assert.AreEqual(1, lUnit.VisibleUnitNameCount);
  Assert.IsTrue(SameText('SysUtils', aSnapshot.TextOf(lUnit.VisibleUnitNameByIndex(0))));
end;

end.
