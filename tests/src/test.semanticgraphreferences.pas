unit Test.SemanticGraphReferences;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Model, DelphiSemantics.ProjectContext, DelphiSemantics.SemanticGraph;

type
  [TestFixture]
  TSemanticGraphReferenceTests = class
  private
    function FixturePath(const aRelativePath: string): string;
    function ProjectInfo: TDelphiSemanticProjectInfo;
    function UnitModel: TDelphiSemanticUnitModel;
  public
    [Test]
    procedure GraphStoresReferencesAndWithStatementsWithStableIds;
    [Test]
    procedure ReferenceAndWithIdsIgnorePrecedingUnits;
    [Test]
    procedure ReferenceAndWithDtosExposeSourceRangesAndNames;
  end;

implementation

uses
  System.IOUtils, System.SysUtils,
  maxLogic.IOUtils;

function TSemanticGraphReferenceTests.FixturePath(const aRelativePath: string): string;
begin
  Result := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..', 'fixtures',
    aRelativePath]));
end;

function TSemanticGraphReferenceTests.ProjectInfo: TDelphiSemanticProjectInfo;
var
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticContextResult;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := FixturePath('ProjectContext\Basic\BasicProject.dproj');
  lResult := TDelphiSemanticProject.Load(lOptions.ProjectPath, lOptions);
  Assert.IsTrue(lResult.Success);
  Result := lResult.Project;
end;

function TSemanticGraphReferenceTests.UnitModel: TDelphiSemanticUnitModel;
begin
  Result := Default(TDelphiSemanticUnitModel);
  Result.Success := True;
  Result.UnitName := 'GraphReferencesUnit';
  Result.FileName := FixturePath('ProjectContext\Basic\BasicProject.dpr');

  SetLength(Result.References, 1);
  Result.References[0].Name := 'TGraphRecord';
  Result.References[0].RoutineName := 'RunGraph';
  Result.References[0].Role := 'type-reference';
  Result.References[0].SectionKind := 'implementation';
  Result.References[0].Line := 12;
  Result.References[0].Column := 7;
  Result.References[0].Offset := 120;
  Result.References[0].EndOffset := 132;
  Result.References[0].EndLine := 12;
  Result.References[0].EndColumn := 19;

  SetLength(Result.WithStatements, 1);
  Result.WithStatements[0].SelectorText := 'lRecord';
  Result.WithStatements[0].SelectorCount := 1;
  Result.WithStatements[0].Line := 20;
  Result.WithStatements[0].Column := 3;
  Result.WithStatements[0].EndLine := 22;
  Result.WithStatements[0].EndColumn := 7;
  Result.WithStatements[0].BodyLine := 21;
  Result.WithStatements[0].BodyColumn := 5;
  Result.WithStatements[0].BodyEndLine := 22;
  Result.WithStatements[0].BodyEndColumn := 7;
end;

procedure TSemanticGraphReferenceTests.GraphStoresReferencesAndWithStatementsWithStableIds;
var
  lFirst: TDelphiSemanticSemanticGraph;
  lSecond: TDelphiSemanticSemanticGraph;
begin
  lFirst := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [UnitModel]);
  try
    lSecond := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [UnitModel]);
    try
      Assert.AreEqual(1, Length(lFirst.References));
      Assert.AreEqual(1, Length(lFirst.WithStatements));
      Assert.AreEqual(1, lFirst.Metrics.ReferenceCount);
      Assert.AreEqual(1, lFirst.Metrics.WithStatementCount);
      Assert.AreEqual(lFirst.References[0].Id.Value, lSecond.References[0].Id.Value);
      Assert.AreEqual(lFirst.WithStatements[0].Id.Value, lSecond.WithStatements[0].Id.Value);
    finally
      lSecond.Free;
    end;
  finally
    lFirst.Free;
  end;
end;

procedure TSemanticGraphReferenceTests.ReferenceAndWithIdsIgnorePrecedingUnits;
var
  lBaseline: TDelphiSemanticSemanticGraph;
  lOther: TDelphiSemanticUnitModel;
  lWithPrecedingUnit: TDelphiSemanticSemanticGraph;
begin
  lOther := UnitModel;
  lOther.UnitName := 'OtherGraphReferencesUnit';
  lOther.References[0].Name := 'OtherType';
  lOther.WithStatements[0].SelectorText := 'lOtherRecord';

  lBaseline := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [UnitModel]);
  try
    lWithPrecedingUnit := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lOther, UnitModel]);
    try
      Assert.AreEqual(lBaseline.References[0].Id.Value,
        lWithPrecedingUnit.References[1].Id.Value);
      Assert.AreEqual(lBaseline.WithStatements[0].Id.Value,
        lWithPrecedingUnit.WithStatements[1].Id.Value);
    finally
      lWithPrecedingUnit.Free;
    end;
  finally
    lBaseline.Free;
  end;
end;

procedure TSemanticGraphReferenceTests.ReferenceAndWithDtosExposeSourceRangesAndNames;
var
  lGraph: TDelphiSemanticSemanticGraph;
begin
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [UnitModel]);
  try
    Assert.AreEqual('TGraphRecord', lGraph.References[0].Name);
    Assert.AreEqual(12, lGraph.References[0].SourceRange.Line);
    Assert.AreEqual(19, lGraph.References[0].SourceRange.EndColumn);
    Assert.AreEqual('lRecord', lGraph.WithStatements[0].SelectorText);
    Assert.AreEqual(20, lGraph.WithStatements[0].SourceRange.Line);
    Assert.AreEqual(22, lGraph.WithStatements[0].SourceRange.EndLine);
    Assert.AreEqual(21, lGraph.WithStatements[0].BodyRange.Line);
  finally
    lGraph.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TSemanticGraphReferenceTests);

end.
