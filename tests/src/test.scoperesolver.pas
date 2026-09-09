unit Test.ScopeResolver;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Model, DelphiSemantics.Resolve.ScopeResolver;

type
  [TestFixture]
  TScopeResolverTests = class
  private
    function ExtractSource(const aFileName, aSource: string): TDelphiSemanticUnitModel;
    function LoadModel: TDelphiSemanticUnitModel;
  public
    [Test]
    [TestCase('inline forward', '0')]
    [TestCase('next-line forward', '1')]
    [TestCase('split parameters', '2')]
    [TestCase('implemented comment control', '3')]
    [TestCase('external declaration', '4')]
    procedure PreservesOuterRoutineAfterNestedForward(const aCase: Integer);
    [Test]
    procedure HandlesClassMethodsAndNonBeginBlocks;
    [Test]
    procedure ResolvesNestedRoutineParentChainsFromIndex;
    [Test]
    procedure ScopeLineCleanerAvoidsRegexHotPath;
    [Test]
    procedure ScopeBlockScannerAvoidsRegexHotPath;
    [Test]
    procedure ScopeIndexAvoidsParentCopiesForTopLevelLines;
    [Test]
    procedure ScopeIndexUsesModelSourceTextWhenFileIsUnavailable;
    [Test]
    procedure ScopeIndexStopsAfterLastRequestedLine;
  end;

implementation

uses
  System.IOUtils, System.StrUtils, System.SysUtils,
  Winapi.Windows,
  maxLogic.IOUtils,
  Test.Support;

var
  GScopeResolverTempRoot: string;

function ScopeResolverTempPath(const aName: string): string;
var
  lGuid: TGUID;
  lGuidText: string;
begin
  if GScopeResolverTempRoot = '' then
  begin
    CreateGUID(lGuid);
    lGuidText := StringReplace(StringReplace(GUIDToString(lGuid), '{', '', [rfReplaceAll]), '}',
      '', [rfReplaceAll]);
    GScopeResolverTempRoot := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)),
      'scope-resolver-temp', 'run-' + GetCurrentProcessId.ToString + '-' + lGuidText]));
  end;
  TDirectory.CreateDirectory(GScopeResolverTempRoot);
  Result := TPath.Combine(GScopeResolverTempRoot, aName);
end;


function TScopeResolverTests.ExtractSource(const aFileName, aSource: string):
  TDelphiSemanticUnitModel;
var
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
begin
  lPath := ScopeResolverTempPath(aFileName);
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
  lOptions.SourceFileName := FixturePath('Resolver', 'Level2ResolverUnit.pas');
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

procedure TScopeResolverTests.ScopeIndexAvoidsParentCopiesForTopLevelLines;
var
  lBuildEnd: Integer;
  lBuildStart: Integer;
  lBuildText: string;
  lSourceFileName: string;
  lSourceText: string;
begin
  lSourceFileName := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..',
    '..', 'src', 'DelphiSemantics.Resolve.ScopeResolver.pas']));
  lSourceText := TFile.ReadAllText(lSourceFileName, TEncoding.UTF8);
  lBuildStart := Pos('class function TDelphiSemanticScopeResolver.BuildRoutineScopeIndex',
    lSourceText);
  lBuildEnd := PosEx('end.' + sLineBreak, lSourceText, lBuildStart);
  lBuildText := Copy(lSourceText, lBuildStart, lBuildEnd - lBuildStart);

  Assert.IsTrue(ContainsText(lBuildText, 'if lFrames.Count > 1 then'),
    'Scope index should allocate parent-name arrays only when a parent routine exists.');
  Assert.IsTrue(ContainsText(lBuildText, 'FrameParentNames(lFrames'),
    'Nested routine parent chains must still be materialized.');
end;

procedure TScopeResolverTests.ScopeIndexUsesModelSourceTextWhenFileIsUnavailable;
var
  lIndex: TDelphiSemanticRoutineScopeIndex;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := Default(TDelphiSemanticUnitModel);
  lModel.FileName := TPath.Combine(ExtractFilePath(ParamStr(0)),
    'missing-scope-source.pas');
  lModel.SourceText := 'unit SourceBackedScope;' + sLineBreak + 'interface' +
    sLineBreak + 'implementation' + sLineBreak + 'procedure Run;' + sLineBreak +
    'begin' + sLineBreak + '  if True then' + sLineBreak + '  begin' + sLineBreak +
    '    with Self do' + sLineBreak + '      Run;' + sLineBreak + '  end;' +
    sLineBreak + 'end;' + sLineBreak + 'end.';

  lIndex := TDelphiSemanticScopeResolver.BuildRoutineScopeIndex(lModel, [8]);

  Assert.AreEqual('Run', lIndex.RoutineNameForLine(8));
end;

procedure TScopeResolverTests.ScopeIndexStopsAfterLastRequestedLine;
var
  lBuildEnd: Integer;
  lBuildStart: Integer;
  lBuildText: string;
  lSourceFileName: string;
  lSourceText: string;
begin
  lSourceFileName := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..',
    '..', 'src', 'DelphiSemantics.Resolve.ScopeResolver.pas']));
  lSourceText := TFile.ReadAllText(lSourceFileName, TEncoding.UTF8);
  lBuildStart := Pos('class function TDelphiSemanticScopeResolver.BuildRoutineScopeIndex',
    lSourceText);
  lBuildEnd := PosEx('end.' + sLineBreak, lSourceText, lBuildStart);
  lBuildText := Copy(lSourceText, lBuildStart, lBuildEnd - lBuildStart);

  Assert.IsTrue(ContainsText(lBuildText, 'lMaxCaptureLine'),
    'Line-limited scope index builds should stop after the highest requested line.');
  Assert.IsTrue(ContainsText(lBuildText, 'Break'),
    'Line-limited scope index builds should break instead of scanning the whole file.');
end;

function NestedForwardSource(const aCase: Integer): string;
begin
  Result := TFile.ReadAllText(FixturePath('RemoveWithNestedForwardCapture',
    'NestedForwardCaptureUnit.pas'), TEncoding.UTF8);
  case aCase of
    1: Result := StringReplace(Result, '  procedure Touch; forward;' + sLineBreak,
      '  procedure Touch;' + sLineBreak + '  forward;', []);
    2:
      begin
        Result := StringReplace(Result, '  procedure Touch; forward;' + sLineBreak,
          '  procedure Touch(aFirst: Integer;' + sLineBreak +
          '    aSecond: Integer); forward;', []);
        Result := StringReplace(Result, '  procedure Touch;' + sLineBreak,
          '  procedure Touch(aFirst: Integer; aSecond: Integer);' + sLineBreak, []);
        Result := StringReplace(Result, 'Inc(lItem.Value);',
          'Inc(lItem.Value, aFirst + aSecond);', []);
        Result := StringReplace(Result, '  Touch;' + sLineBreak,
          '  Touch(1, 0);' + sLineBreak, []);
      end;
    3:
      begin
        Result := StringReplace(Result, '  procedure Touch; forward;',
          '  { An implemented routine follows. }', []);
        Result := StringReplace(Result, '  procedure Touch;' + sLineBreak,
          '  procedure Touch; { forward; }' + sLineBreak, []);
      end;
    4:
      begin
        Result := StringReplace(Result, '  procedure Touch; forward;',
          '  { The nested implementation follows. }', []);
        Result := StringReplace(Result, '  PItem = ^TItem;' + sLineBreak + sLineBreak,
          '  PItem = ^TItem;' + sLineBreak +
          'function ReadTick: UInt64; stdcall; external ''kernel32.dll'' name ''GetTickCount64'';' +
          sLineBreak, []);
      end;
  else
    if aCase <> 0 then
      raise Exception.Create('Unexpected nested forward test case.');
  end;
end;

procedure AssertNestedForwardReferenceScopes(const aModel: TDelphiSemanticUnitModel);
var
  lNestedScope: string;
  lOuterScope: string;
  lReference: TDelphiSemanticReference;
begin
  lNestedScope := '';
  lOuterScope := '';
  for lReference in aModel.References do
    if SameText(lReference.Name, 'lItem') then
    begin
      if lReference.Line = 24 then
      begin
        Assert.AreEqual('Touch', lReference.RoutineName);
        lNestedScope := lReference.RoutineScopeId;
      end else if lReference.Line = 35 then
      begin
        Assert.AreEqual('Observe', lReference.RoutineName);
        lOuterScope := lReference.RoutineScopeId;
      end;
    end;
  Assert.IsNotEmpty(lNestedScope);
  Assert.IsNotEmpty(lOuterScope);
  Assert.AreNotEqual(lNestedScope, lOuterScope);
end;

procedure TScopeResolverTests.PreservesOuterRoutineAfterNestedForward(const aCase: Integer);
var
  i: Integer;
  lBounded: TDelphiSemanticRoutineScopeIndex;
  lIndex: TDelphiSemanticRoutineScopeIndex;
  lModel: TDelphiSemanticUnitModel;
  lSource: string;
  lSourceModel: TDelphiSemanticUnitModel;
begin
  lSource := NestedForwardSource(aCase);
  lModel := ExtractSource('nested-forward-' + aCase.ToString + '.pas', lSource);
  lIndex := TDelphiSemanticScopeResolver.BuildRoutineScopeIndex(lModel);
  lSourceModel := Default(TDelphiSemanticUnitModel);
  lSourceModel.SourceText := lSource;
  lBounded := TDelphiSemanticScopeResolver.BuildRoutineScopeIndex(lSourceModel, [24, 30, 33, 35]);
  Assert.AreEqual('Touch', lIndex.RoutineNameForLine(24));
  Assert.AreEqual('Touch', lBounded.RoutineNameForLine(24));
  Assert.AreEqual(1, Integer(Length(lIndex.ParentRoutineNamesForLine('Touch', 24))));
  Assert.AreEqual('Observe', lIndex.ParentRoutineNamesForLine('Touch', 24)[0]);
  Assert.AreEqual(1, Integer(Length(lBounded.ParentRoutineNamesForLine('Touch', 24))));
  Assert.AreEqual('Observe', lBounded.ParentRoutineNamesForLine('Touch', 24)[0]);
  for i in [30, 33, 35] do
  begin
    Assert.AreEqual('Observe', lIndex.RoutineNameForLine(i), 'Full index line ' + i.ToString);
    Assert.AreEqual('Observe', lBounded.RoutineNameForLine(i), 'Bounded index line ' + i.ToString);
    Assert.AreEqual(0, Integer(Length(lIndex.ParentRoutineNamesForLine('Observe', i))));
    Assert.AreEqual(0, Integer(Length(lBounded.ParentRoutineNamesForLine('Observe', i))));
  end;
  AssertNestedForwardReferenceScopes(lModel);
end;

initialization
  TDUnitX.RegisterTestFixture(TScopeResolverTests);

end.
