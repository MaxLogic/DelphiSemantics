unit Test.SemanticGraph;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Model, DelphiSemantics.ProjectContext, DelphiSemantics.SemanticGraph;

type
  [TestFixture]
  TSemanticGraphTests = class
  private
    function ProjectInfo: TDelphiSemanticProjectInfo;
    function SymbolModel(const aUnitName, aFileName: string): TDelphiSemanticUnitModel;
  public
    [Category('Fast')]
    [Test]
    procedure ProjectAndUnitIdsAreStableForSameContextAndSources;
    [Category('Fast')]
    [Test]
    procedure UnitDtosExposeOriginalSourceRanges;
    [Category('Fast')]
    [Test]
    procedure UnitDtosAreReturnedAsCopies;
    [Category('Fast')]
    [Test]
    procedure CanonicalImportsPreserveSpellingAmbiguityAndBuildContext;
    [Test]
    procedure ProjectSessionBuildMetricsReportGraphCounts;
  end;

implementation

uses
  System.IOUtils, System.SysUtils,
  maxLogic.IOUtils,
  DelphiSemantics.ProjectSession,
  Test.Support;


function TSemanticGraphTests.ProjectInfo: TDelphiSemanticProjectInfo;
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

function TSemanticGraphTests.SymbolModel(const aUnitName, aFileName: string):
  TDelphiSemanticUnitModel;
begin
  Result := Default(TDelphiSemanticUnitModel);
  Result.Success := True;
  Result.UnitName := aUnitName;
  Result.FileName := aFileName;
  SetLength(Result.Declarations, 1);
  Result.Declarations[0].Name := 'TGraphRecord';
  Result.Declarations[0].Kind := 'type';
  Result.Declarations[0].Line := 2;
  Result.Declarations[0].Column := 3;
  Result.Declarations[0].Offset := 10;
  Result.Declarations[0].EndOffset := 23;
end;

procedure TSemanticGraphTests.ProjectAndUnitIdsAreStableForSameContextAndSources;
var
  lFirst: TDelphiSemanticSemanticGraph;
  lProject: TDelphiSemanticProjectInfo;
  lSecond: TDelphiSemanticSemanticGraph;
begin
  lProject := ProjectInfo;
  lFirst := TDelphiSemanticSemanticGraphBuilder.Build(lProject, [
    SymbolModel('BasicProject', lProject.MainSourceFileName)]);
  try
    lSecond := TDelphiSemanticSemanticGraphBuilder.Build(lProject, [
      SymbolModel('BasicProject', lProject.MainSourceFileName)]);
    try
      Assert.AreEqual(lFirst.ProjectId.Value, lSecond.ProjectId.Value);
      Assert.AreEqual(lFirst.Units[0].Id.Value, lSecond.Units[0].Id.Value);
    finally
      lSecond.Free;
    end;
  finally
    lFirst.Free;
  end;
end;

procedure TSemanticGraphTests.UnitDtosExposeOriginalSourceRanges;
var
  lGraph: TDelphiSemanticSemanticGraph;
  lProject: TDelphiSemanticProjectInfo;
  lUnit: TDelphiSemanticGraphUnit;
begin
  lProject := ProjectInfo;
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(lProject, [
    SymbolModel('BasicProject', lProject.MainSourceFileName)]);
  try
    Assert.IsTrue(lGraph.FindUnitByName('BasicProject', lUnit));
    Assert.AreEqual(lProject.MainSourceFileName, lUnit.SourceRange.FileName);
    Assert.AreEqual(0, lUnit.SourceRange.Line);
    Assert.AreEqual(0, lUnit.SourceRange.Column);
  finally
    lGraph.Free;
  end;
end;

procedure TSemanticGraphTests.UnitDtosAreReturnedAsCopies;
var
  lGraph: TDelphiSemanticSemanticGraph;
  lProject: TDelphiSemanticProjectInfo;
  lUnit: TDelphiSemanticGraphUnit;
  lUnits: TArray<TDelphiSemanticGraphUnit>;
begin
  lProject := ProjectInfo;
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(lProject, [
    SymbolModel('BasicProject', lProject.MainSourceFileName)]);
  try
    lUnits := lGraph.Units;
    lUnits[0].UnitName := 'MutatedUnit';

    Assert.IsTrue(lGraph.FindUnitByName('BasicProject', lUnit));
    Assert.AreEqual('BasicProject', lUnit.UnitName);
  finally
    lGraph.Free;
  end;
end;

procedure TSemanticGraphTests.CanonicalImportsPreserveSpellingAmbiguityAndBuildContext;
var
  lGraph: TDelphiSemanticSemanticGraph;
  lImporter, lAlpha, lBeta, lDuplicate: TDelphiSemanticUnitModel;
  lProject: TDelphiSemanticProjectInfo;

  procedure CheckImports(const aModels: TArray<TDelphiSemanticUnitModel>;
    const aExpectedAlias: string);
  var
    lUnit: TDelphiSemanticGraphUnit;
  begin
    lGraph := TDelphiSemanticSemanticGraphBuilder.Build(lProject, aModels);
    try
      Assert.IsTrue(lGraph.FindUnitByName('Importer', lUnit));
      Assert.AreEqual<Integer>(4, Length(lUnit.InterfaceImports));
      Assert.AreEqual('Unindexed', lUnit.InterfaceImports[0]);
      Assert.AreEqual('unindexed', lUnit.InterfaceImports[1]);
      Assert.AreEqual(aExpectedAlias, lUnit.InterfaceImports[2]);
      Assert.AreEqual(aExpectedAlias, lUnit.InterfaceImports[3]);
    finally
      lGraph.Free;
    end;
  end;

begin
  lProject := ProjectInfo;
  lImporter := SymbolModel('Importer', 'Importer.pas');
  lImporter.DependencyFacts.Known := True;
  lImporter.DependencyFacts.InterfaceImports := ['Unindexed', 'unindexed', 'AliasUnit', 'AliasUnit'];
  lAlpha := SymbolModel('Alpha', 'Alpha.pas');
  lBeta := SymbolModel('Beta', 'Beta.pas');
  lProject.UnitAliases := ['AliasUnit=Alpha'];
  CheckImports([lImporter, lAlpha, lBeta], 'Alpha');
  lProject.UnitAliases := ['AliasUnit=Beta'];
  CheckImports([lImporter, lAlpha, lBeta], 'Beta');
  lDuplicate := SymbolModel('Beta', 'OtherBeta.pas');
  CheckImports([lImporter, lAlpha, lBeta, lDuplicate], 'AliasUnit');
  CheckImports([lImporter, lAlpha, lBeta], 'Beta');
end;

procedure TSemanticGraphTests.ProjectSessionBuildMetricsReportGraphCounts;
var
  lGraphResult: TDelphiSemanticSemanticGraphBuildResult;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := FixturePath('ProjectContext\Basic\BasicProject.dproj');
  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lGraphResult := lResult.Session.BuildSemanticGraphResult;
    try
      Assert.AreEqual(1, lGraphResult.Metrics.UnitCount);
      Assert.AreEqual(0, lGraphResult.Metrics.SymbolCount);
      Assert.IsTrue(lGraphResult.Metrics.BuildMilliseconds >= 0);
      Assert.AreEqual(lGraphResult.Graph.Metrics.UnitCount, lGraphResult.Metrics.UnitCount);
    finally
      lGraphResult.Graph.Free;
    end;
  finally
    lResult.Session.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TSemanticGraphTests);

end.
