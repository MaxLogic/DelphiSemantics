unit Test.NameFlow.Containment;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TNameFlowContainmentTests = class
  public
    [Test] procedure MissingFactsRefuse;
    [Test] procedure RaiseObservesClassNames;
    [Test] procedure RaiseDoesNotObserveRecordNames;
    [Test] procedure UnboundExecutableCallRefuses;
    [Test] procedure ConstantBindingUsesNearestDeclaration;
  end;

implementation

uses
  System.IOUtils, System.SysUtils,
  DelphiSemantics.Model,
  DelphiSemantics.NameConsumers, DelphiSemantics.NameFlow.Containment,
  DelphiSemantics.NameFlow.Facts, DelphiSemantics.Snapshot,
  DelphiSemantics.Snapshot.Builder, DelphiSemantics.Snapshot.PositionResolver,
  DelphiSemantics.WithBinding,
  Test.Support;

procedure TNameFlowContainmentTests.ConstantBindingUsesNearestDeclaration;
const
  cSource = 'unit UCertified;'#13#10'interface'#13#10'procedure Touch;'#13#10 +
    'implementation'#13#10'uses UNames;'#13#10'const cPre = ''Co'';'#13#10 +
    'procedure Touch;'#13#10'var Name: string;'#13#10'begin'#13#10 +
    '  Name := cPre + ''unt'';'#13#10'end;'#13#10'end.';
var
  lRoot, lFile: string;
  lOptions: TDelphiSemanticModelOptions;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lSnapshot: TDelphiProjectSnapshot;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lBoundUnit: TUnitSnapshot;
  lBoundSymbol: TSemanticSymbolFact;
begin
  lRoot := CreateTestTempRoot('nameflow-constant-temp');
  lFile := TPath.Combine(lRoot, 'UCertified.pas');
  TFile.WriteAllText(lFile, cSource, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'UNames.pas'),
    'unit UNames;'#13#10'interface'#13#10'const cPre = ''Xo'';'#13#10 +
    'implementation'#13#10'end.', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lFile;
  lOptions.SearchPaths := [lRoot];
  SetLength(lModels, 2);
  lModels[0] := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'UNames.pas');
  lModels[1] := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  lSnapshot := BuildProjectSnapshotFromModels(lModels,
    Default(TDelphiSemanticProjectWithBindingFacts), Default(TDelphiSnapshotBuildOptions), lMetrics);
  try
    Assert.IsTrue(TryBindNameFlowConstant(lSnapshot, lFile, 'cPre', 10, 11, lBoundUnit, lBoundSymbol));
    Assert.AreEqual(lFile, lSnapshot.TextOf(lBoundUnit.FileNameId));
    Assert.AreEqual(6, lBoundSymbol.Line,
      'The active local Co declaration wins over imported Xo');
  finally
    lSnapshot.Free;
  end;
end;

function SnapshotWithNode(const aKind: TDelphiNameFlowNodeKind;
  const aSyntax, aName: string): TDelphiProjectSnapshot;
var
  lBuilder: TDelphiProjectSnapshotBuilder;
  lUnit: TUnitSnapshot;
  lNode: TDelphiNameFlowNode;
begin
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  try
    lUnit := TUnitSnapshot.Create(1, lBuilder.Strings.Intern('unit.pas'),
      lBuilder.Strings.Intern('Unit1'), lBuilder.ExactStrings.Intern('begin Opaque(); end.'));
    lNode := Default(TDelphiNameFlowNode);
    lNode.Id := 1;
    lNode.Kind := aKind;
    lNode.SyntaxKind := aSyntax;
    lNode.Name := aName;
    lNode.FileName := 'unit.pas';
    lNode.Line := 1;
    lNode.Column := 7;
    lNode.SpanKnown := True;
    lNode.ActivityKnown := True;
    lUnit.SetNameFlowFactsJsonId(lBuilder.ExactStrings.Intern(NameFlowFactsToJson(
      CreateNameFlowFacts([lNode], True, True, ''))));
    lBuilder.AddUnit(lUnit);
    Result := lBuilder.Build;
  finally
    lBuilder.Free;
  end;
end;

procedure TNameFlowContainmentTests.MissingFactsRefuse;
var
  lReport: TNameFlowAnalysis;
begin
  lReport := AnalyzeNameFlowSnapshot(nil, TNameEffectTargetKind.Member, nil);
  Assert.AreEqual(1, Integer(Length(lReport.Gaps)));
  Assert.AreEqual('runtime-name-flow-coverage-unproved', lReport.Gaps[0].Reason);
end;

procedure TNameFlowContainmentTests.RaiseObservesClassNames;
var
  lSnapshot: TDelphiProjectSnapshot;
  lReport: TNameFlowAnalysis;
begin
  lSnapshot := SnapshotWithNode(TDelphiNameFlowNodeKind.RaiseValue, 'raise', '');
  try
    lReport := AnalyzeNameFlowSnapshot(lSnapshot, TNameEffectTargetKind.ClassType, nil);
    Assert.AreEqual(1, lReport.Statistics.LanguageRoots);
    Assert.AreEqual('runtime-name-metadata-consumer', lReport.Gaps[0].Reason);
  finally
    lSnapshot.Free;
  end;
end;

procedure TNameFlowContainmentTests.RaiseDoesNotObserveRecordNames;
var
  lSnapshot: TDelphiProjectSnapshot;
  lReport: TNameFlowAnalysis;
begin
  lSnapshot := SnapshotWithNode(TDelphiNameFlowNodeKind.RaiseValue, 'raise', '');
  try
    lReport := AnalyzeNameFlowSnapshot(lSnapshot, TNameEffectTargetKind.OtherType, nil);
    Assert.AreEqual(0, Integer(Length(lReport.Gaps)));
  finally
    lSnapshot.Free;
  end;
end;

procedure TNameFlowContainmentTests.UnboundExecutableCallRefuses;
var
  lSnapshot: TDelphiProjectSnapshot;
  lReport: TNameFlowAnalysis;
begin
  lSnapshot := SnapshotWithNode(TDelphiNameFlowNodeKind.Call, 'call', 'Opaque');
  try
    lReport := AnalyzeNameFlowSnapshot(lSnapshot, TNameEffectTargetKind.Member, nil);
    Assert.AreEqual(1, lReport.Statistics.UnboundCalls);
    Assert.AreEqual('runtime-name-call-effect-unproved', lReport.Gaps[0].Reason);
  finally
    lSnapshot.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TNameFlowContainmentTests);

end.
