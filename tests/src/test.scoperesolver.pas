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
    [Test]
    procedure ScopeLineCleanerAvoidsRegexHotPath;
    [Test]
    procedure ScopeBlockScannerAvoidsRegexHotPath;
  end;

implementation

uses
  System.IOUtils, System.StrUtils, System.SysUtils,
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
  Assert.AreEqual(1, Integer(Length(lIndex.ParentRoutineNamesForLine('InnerScope', 55))));
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
  Assert.AreEqual(0, Integer(Length(lIndex.ParentRoutineNamesForLine('Run', 19))));
end;

procedure TScopeResolverTests.ScopeLineCleanerAvoidsRegexHotPath;
var
  lCleanerEnd: Integer;
  lCleanerStart: Integer;
  lCleanerText: string;
  lSourceFileName: string;
  lSourceText: string;
begin
  lSourceFileName := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..',
    '..', 'src', 'DelphiSemantics.Resolve.ScopeResolver.pas']));
  lSourceText := TFile.ReadAllText(lSourceFileName, TEncoding.UTF8);
  lCleanerStart := Pos('function CleanSourceLine', lSourceText);
  lCleanerEnd := Pos('function TDelphiSemanticRoutineScopeIndex.ParentRoutineNamesForLine',
    lSourceText);
  lCleanerText := Copy(lSourceText, lCleanerStart, lCleanerEnd - lCleanerStart);

  Assert.IsFalse(ContainsText(lCleanerText, 'TRegEx.Replace'),
    'Scope-index line cleanup must not allocate regex replacements for every source line.');
  Assert.IsTrue(ContainsText(lCleanerText, 'lInString'),
    'Scope-index line cleanup must use a simple string/comment scanner.');
end;

procedure TScopeResolverTests.ScopeBlockScannerAvoidsRegexHotPath;
var
  lBlockEnd: Integer;
  lBlockStart: Integer;
  lBlockText: string;
  lClosedBlockEnd: Integer;
  lClosedBlockStart: Integer;
  lClosedBlockText: string;
  lSourceFileName: string;
  lSourceText: string;
begin
  lSourceFileName := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..',
    '..', 'src', 'DelphiSemantics.Resolve.ScopeResolver.pas']));
  lSourceText := TFile.ReadAllText(lSourceFileName, TEncoding.UTF8);
  lClosedBlockStart := Pos('function LineStartsEndClosedBlock', lSourceText);
  lClosedBlockEnd := Pos('function FrameParentNames', lSourceText);
  lClosedBlockText := Copy(lSourceText, lClosedBlockStart, lClosedBlockEnd -
    lClosedBlockStart);
  lBlockStart := Pos('procedure ApplyBlockTokens', lSourceText);
  lBlockEnd := Pos('function CleanSourceLine', lSourceText);
  lBlockText := Copy(lSourceText, lBlockStart, lBlockEnd - lBlockStart);

  Assert.IsFalse(ContainsText(lClosedBlockText, 'TRegEx'),
    'Scope closed-block detection must not run regex per source line.');
  Assert.IsTrue(ContainsText(lClosedBlockText, 'ContainsScopeWord(lText, ''of'')'),
    'Scope case-block detection must require standalone "of".');
  Assert.IsFalse(ContainsText(lBlockText, 'TRegEx'),
    'Scope begin/end token scanning must not run regex per source line.');
  Assert.IsTrue(ContainsText(lBlockText, 'ReadScopeToken'),
    'Scope begin/end token scanning must use the simple token reader.');
end;

initialization
  TDUnitX.RegisterTestFixture(TScopeResolverTests);

end.
