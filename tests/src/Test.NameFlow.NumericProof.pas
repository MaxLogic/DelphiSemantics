unit Test.NameFlow.NumericProof;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TNameFlowNumericProofTests = class
  public
    [TestCase('verified Integer', 'Integer,0')]
    [TestCase('string positive control', 'string,1')]
    [TestCase('unverified type', 'UnknownNumber,1')]
    [Test] procedure PhysicalOperandTypeProof(const aType: string; const aExpected: Integer);
  end;

implementation

uses
  System.IOUtils, System.SysUtils,
  DelphiSemantics.Model, DelphiSemantics.Query, DelphiSemantics.Snapshot,
  DelphiSemantics.Snapshot.Builder, DelphiSemantics.Snapshot.PositionResolver,
  DelphiSemantics.Symbols, DelphiSemantics.Usage, DelphiSemantics.WithBinding,
  Test.Support;

procedure TNameFlowNumericProofTests.PhysicalOperandTypeProof(const aType: string; const aExpected: Integer);
var
  lRoot, lFile, lSource: string;
  lOptions: TDelphiSemanticModelOptions;
  lModel: TDelphiSemanticUnitModel;
  lSnapshot: TDelphiProjectSnapshot;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lContext: TDelphiSemanticSymbolQueryContext;
  lSymbol: TDelphiSemanticIndexedSymbol;
  lResolution: TDelphiSemanticSnapshotPositionResolution;
  lGap: TDelphiSemanticUsage;
  lCount: Integer;
begin
  lRoot := CreateTestTempRoot('numeric-physical-proof-temp');
  lFile := TPath.Combine(lRoot, 'NumericProbe.pas');
  TFile.WriteAllText(TPath.Combine(lRoot, 'flags.inc'), '{$DEFINE HAS_FLAG}', TEncoding.ASCII);
  lSource := 'unit NumericProbe;'#13#10'interface'#13#10'{$I flags.inc}'#13#10 +
    'procedure Soundex;'#13#10'implementation'#13#10'procedure Soundex;'#13#10 +
    'var'#13#10'  lCount: ' + aType + ';'#13#10'begin'#13#10'  lCount := 3;'#13#10 +
    '  lCount := lCount + 1;'#13#10'end;'#13#10'end.';
  TFile.WriteAllText(lFile, lSource, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lFile;
  lOptions.SearchPaths := [lRoot];
  lOptions.DefineEvidenceComplete := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success, 'The fixture must parse successfully.');
  lSnapshot := BuildProjectSnapshotFromModels([lModel],
    Default(TDelphiSemanticProjectWithBindingFacts), Default(TDelphiSnapshotBuildOptions), lMetrics);
  lContext := Default(TDelphiSemanticSymbolQueryContext);
  try
    Assert.IsTrue(TryResolveSnapshotPosition(lSnapshot, lFile, 11, 13, 'lCount', lResolution));
    Assert.AreEqual('snapshot-physical-position-match', lResolution.Status);
    Assert.IsTrue(lResolution.SymbolFound);
    Assert.IsFalse(lResolution.ReferenceFound, 'Exercise the DS-692 symbol-only physical path.');
    lContext.ProjectSnapshot := BorrowProjectSnapshot(lSnapshot);
    lSymbol := Default(TDelphiSemanticIndexedSymbol);
    lSymbol.Name := 'Soundex';
    lSymbol.Kind := 'routine';
    lSymbol.UnitName := 'NumericProbe';
    lSymbol.FileName := lFile;
    lCount := 0;
    for lGap in TDelphiSemanticUsageFinder.PossibleImportGaps(lContext, lSymbol, ['Soundex', 'RenamedSoundex']) do
      if lGap.Reason = 'string-constant-value-unproved' then
        Inc(lCount);
    Assert.AreEqual(aExpected, lCount, 'Only verified non-string operand types may remove a witness.');
  finally
    lContext.ProjectSnapshot := nil;
    lSnapshot.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TNameFlowNumericProofTests);

end.
