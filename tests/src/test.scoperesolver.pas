unit Test.ScopeResolver;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Model, DelphiSemantics.Resolve.ScopeResolver;

type
  [TestFixture]
  TScopeResolverTests = class
  private
    function FixturePath(const aFileName: string): string;
    function ExtractSource(const aFileName, aSource: string): TDelphiSemanticUnitModel;
    function LoadModel: TDelphiSemanticUnitModel;
  public
    [Test]
    procedure HandlesClassMethodsAndNonBeginBlocks;
    [Test]
    procedure ResolvesNestedRoutineParentChainsFromIndex;
  end;

implementation

uses
  System.IOUtils, System.SysUtils,
  maxLogic.IOUtils;

function TScopeResolverTests.FixturePath(const aFileName: string): string;
begin
  Result := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..', 'fixtures',
    'Resolver', aFileName]));
end;

function TScopeResolverTests.ExtractSource(const aFileName, aSource: string):
  TDelphiSemanticUnitModel;
var
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
begin
  lPath := TPath.Combine(ExtractFilePath(ParamStr(0)), aFileName);
  TFile.WriteAllText(lPath, aSource);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  Result := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(Result.Success);
end;

function TScopeResolverTests.LoadModel: TDelphiSemanticUnitModel;
var
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('Level2ResolverUnit.pas');
  lOptions.ProjectContextApplied := True;
  Result := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(Result.Success);
end;

procedure TScopeResolverTests.ResolvesNestedRoutineParentChainsFromIndex;
var
  lIndex: TDelphiSemanticRoutineScopeIndex;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;
  lIndex := TDelphiSemanticScopeResolver.BuildRoutineScopeIndex(lModel);

  Assert.AreEqual('InnerScope', lIndex.RoutineNameForLine(55));
  Assert.AreEqual(1, Length(lIndex.ParentRoutineNamesForLine('InnerScope', 55)));
  Assert.AreEqual('OuterScope', lIndex.ParentRoutineNamesForLine('InnerScope', 55)[0]);
end;

procedure TScopeResolverTests.HandlesClassMethodsAndNonBeginBlocks;
var
  lIndex: TDelphiSemanticRoutineScopeIndex;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := ExtractSource('scope-resolver-class-method.pas',
    'unit ScopeResolverClassMethod;' + sLineBreak + 'interface' + sLineBreak + 'type' +
    sLineBreak + '  TRunner = class' + sLineBreak +
    '    class procedure Run;' + sLineBreak + '  end;' + sLineBreak + 'implementation' +
    sLineBreak + 'class procedure TRunner.Run;' + sLineBreak + 'begin' + sLineBreak +
    '  try' + sLineBreak + '    if True then' + sLineBreak + '      begin' + sLineBreak +
    '      end;' + sLineBreak + '  finally' + sLineBreak + '  end;' + sLineBreak +
    '  repeat' + sLineBreak + '  until True;' + sLineBreak + '  with Self do' + sLineBreak +
    '    Run;' + sLineBreak + 'end;' + sLineBreak + 'end.');
  lIndex := TDelphiSemanticScopeResolver.BuildRoutineScopeIndex(lModel);

  Assert.AreEqual('Run', lIndex.RoutineNameForLine(19));
  Assert.AreEqual(0, Length(lIndex.ParentRoutineNamesForLine('Run', 19)));
end;

initialization
  TDUnitX.RegisterTestFixture(TScopeResolverTests);

end.
