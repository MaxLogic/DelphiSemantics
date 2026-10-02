unit Test.ScopeResolver;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Model, DelphiSemantics.Resolve, DelphiSemantics.Resolve.ScopeResolver,
  DelphiSemantics.WithBinding;

type
  [TestFixture]
  TScopeResolverTests = class
  private
    function ExtractSource(const aFileName, aSource: string): TDelphiSemanticUnitModel;
    function LoadModel: TDelphiSemanticUnitModel;
  public
    [Test]
    [TestCase('different types', 'False')]
    [TestCase('same type distinct scopes', 'True')]
    procedure ResumedOverloadLocalsAreAmbiguous(const aSameType: Boolean);
    [Test]
    procedure ResumedDeclarationsRequireRoutineContext;
    [Test]
    [TestCase('TA current', '0')]
    [TestCase('TA parent', '1')]
    [TestCase('TB current', '2')]
    [TestCase('TB parent', '3')]
    procedure ResumedLocalsKeepQualifiedOwnership(const aCase: Integer);
    [Test]
    procedure ResumedLocalBeatsCurrentMemberFallback;
    [Test]
    [TestCase('full scope index', 'False')]
    [TestCase('bounded scope index', 'True')]
    procedure QualifiedMethodParentsResolveCapturedLocals(const aBounded: Boolean);
    [Test]
    procedure QualifiedMethodSiblingVarsDoNotEscapeFallback;
    [Test]
    procedure QualifiedMethodIndexedVarsRemainUnitScoped;
    [Test]
    procedure QualifiedMethodParentsKeepWithReceiverOwners;
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

const
  cQualifiedMethodScopeSource =
    'unit QualifiedMethodScopeUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TDataA = record' + sLineBreak +
    '    Count: Integer;' + sLineBreak +
    '  end;' + sLineBreak +
    '  TDataB = record' + sLineBreak +
    '    Count: Integer;' + sLineBreak +
    '  end;' + sLineBreak +
    '  TA = class' + sLineBreak +
    '    FData: TDataA;' + sLineBreak +
    '    procedure Run;' + sLineBreak +
    '  end;' + sLineBreak +
    '  TB = class' + sLineBreak +
    '    FData: TDataB;' + sLineBreak +
    '    procedure Run;' + sLineBreak +
    '  end;' + sLineBreak +
    'var' + sLineBreak +
    '  gVisible: Integer;' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure TA.Run;' + sLineBreak +
    'const' + sLineBreak +
    '  cKept = 1;' + sLineBreak +
    'type' + sLineBreak +
    '  TKept = (keOne, keTwo);' + sLineBreak +
    'var' + sLineBreak +
    '  lCaptured: Integer;' + sLineBreak +
    '  lOnlyA: Integer;' + sLineBreak +
    '  procedure Inner;' + sLineBreak +
    '  begin' + sLineBreak +
    '    with FData do' + sLineBreak +
    '      Count := lCaptured;' + sLineBreak +
    '  end;' + sLineBreak +
    'begin' + sLineBreak +
    '  lOnlyA := cKept;' + sLineBreak +
    '  lCaptured := lOnlyA;' + sLineBreak +
    '  Inner;' + sLineBreak +
    'end;' + sLineBreak +
    'procedure TB.Run;' + sLineBreak +
    'var' + sLineBreak +
    '  lCaptured: string;' + sLineBreak +
    '  procedure Inner;' + sLineBreak +
    '  begin' + sLineBreak +
    '    with FData do' + sLineBreak +
    '      Count := Length(lCaptured);' + sLineBreak +
    '  end;' + sLineBreak +
    'begin' + sLineBreak +
    '  lCaptured := ''B'';' + sLineBreak +
    '  Inner;' + sLineBreak +
    'end;' + sLineBreak +
    'end.';

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

  Assert.AreEqual('TRunner.Run', lIndex.RoutineNameForLine(19));
  Assert.AreEqual(0, Integer(Length(lIndex.ParentRoutineNamesForLine('TRunner.Run', 19))));
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

function QualifiedConstructorScopeSource: string;
begin
  Result := StringReplace(cQualifiedMethodScopeSource, 'procedure Run;', 'constructor Run;', [rfReplaceAll]);
  Result := StringReplace(Result, 'procedure TA.Run;', 'constructor TA.Run;', []);
  Result := StringReplace(Result, 'procedure TB.Run;', 'constructor TB.Run;', []);
end;

function QualifiedMethodContext(const aIndex: TDelphiSemanticRoutineScopeIndex;
  const aLine: Integer): TDelphiSemanticResolveContext;
begin
  Result := Default(TDelphiSemanticResolveContext);
  Result.RoutineName := aIndex.RoutineNameForLine(aLine);
  Result.ParentRoutineNames := aIndex.ParentRoutineNamesForLine(Result.RoutineName, aLine);
  Result.SectionKind := 'implementation';
  Result.ConformanceLevel := 3;
end;

procedure TScopeResolverTests.QualifiedMethodParentsResolveCapturedLocals(const aBounded: Boolean);
var
  lContext: TDelphiSemanticResolveContext;
  lIndex: TDelphiSemanticRoutineScopeIndex;
  lModel: TDelphiSemanticUnitModel;
  lResult: TDelphiSemanticResolveResult;
begin
  lModel := ExtractSource('qualified-captures-' + BoolToStr(aBounded, True) + '.pas',
    cQualifiedMethodScopeSource);
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  if aBounded then
    lIndex := TDelphiSemanticScopeResolver.BuildRoutineScopeIndex(lModel, [32, 45])
  else
    lIndex := TDelphiSemanticScopeResolver.BuildRoutineScopeIndex(lModel);
  // T-260: declarations must not rescue missing qualified lexical ownership.
  lModel.Declarations := nil;
  lContext := QualifiedMethodContext(lIndex, 32);
  Assert.AreEqual('Inner', lContext.RoutineName);
  Assert.AreEqual(1, Integer(Length(lContext.ParentRoutineNames)));
  Assert.AreEqual('TA.Run', lContext.ParentRoutineNames[0]);
  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'lCaptured');
  Assert.IsTrue(lResult.Found, lResult.Reason);
  Assert.AreEqual('local', lResult.Kind);
  Assert.AreEqual('TA.Run', lResult.OwnerName);
  Assert.AreEqual('Integer', lResult.TypeName);
  Assert.AreEqual(27, lResult.Line);
  Assert.AreEqual(3, lResult.Column);

  lContext := QualifiedMethodContext(lIndex, 45);
  Assert.AreEqual('Inner', lContext.RoutineName);
  Assert.AreEqual(1, Integer(Length(lContext.ParentRoutineNames)));
  Assert.AreEqual('TB.Run', lContext.ParentRoutineNames[0]);
  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'lCaptured');
  Assert.IsTrue(lResult.Found, lResult.Reason);
  Assert.AreEqual('local', lResult.Kind);
  Assert.AreEqual('TB.Run', lResult.OwnerName);
  Assert.AreEqual('string', lResult.TypeName);
  Assert.AreEqual(41, lResult.Line);
  Assert.AreEqual(3, lResult.Column);
end;

procedure TScopeResolverTests.QualifiedMethodSiblingVarsDoNotEscapeFallback;
var
  lContext: TDelphiSemanticResolveContext;
  lDeclaration: TDelphiSemanticDeclaration;
  lFoundDeclaration: Boolean;
  lIndex: TDelphiSemanticRoutineScopeIndex;
  lModel: TDelphiSemanticUnitModel;
  lResult: TDelphiSemanticResolveResult;
begin
  lModel := ExtractSource('qualified-sibling-fallback.pas', QualifiedConstructorScopeSource);
  lFoundDeclaration := False;
  for lDeclaration in lModel.Declarations do
    if SameText(lDeclaration.Name, 'lOnlyA') then
    begin
      lFoundDeclaration := True;
      Assert.AreEqual('var', lDeclaration.Kind);
      Assert.AreEqual('routine', lDeclaration.ScopeKind);
    end;
  Assert.IsTrue(lFoundDeclaration, 'Retain the actual declaration that previously leaked');
  lIndex := TDelphiSemanticScopeResolver.BuildRoutineScopeIndex(lModel);
  lContext := QualifiedMethodContext(lIndex, 45);
  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'lOnlyA');
  Assert.IsFalse(lResult.Found, 'TA.Run local must not leak into TB.Run.Inner');
  Assert.AreEqual('NAME_NOT_FOUND', lResult.ReasonCode);

  lContext := QualifiedMethodContext(lIndex, 32);
  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'lOnlyA');
  Assert.IsTrue(lResult.Found);
  Assert.AreEqual('local', lResult.Kind);
  Assert.AreEqual('TA.Run', lResult.OwnerName);
  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'gVisible');
  Assert.IsTrue(lResult.Found);
  Assert.AreEqual('var', lResult.Kind);
  // This task preserves the existing const/type/enum fallback, including local declarations.
  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'cKept');
  Assert.IsTrue(lResult.Found);
  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'TKept');
  Assert.IsTrue(lResult.Found);
  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'keOne');
  Assert.IsTrue(lResult.Found);
  Assert.AreEqual('enum-value', lResult.Kind);
end;

procedure TScopeResolverTests.QualifiedMethodIndexedVarsRemainUnitScoped;
var
  lContext: TDelphiSemanticResolveContext;
  lEmptyModel: TDelphiSemanticUnitModel;
  lModel: TDelphiSemanticUnitModel;
  lResult: TDelphiSemanticResolveResult;
begin
  lModel := ExtractSource('qualified-indexed-fallback.pas', QualifiedConstructorScopeSource);
  lEmptyModel := Default(TDelphiSemanticUnitModel);
  lContext := Default(TDelphiSemanticResolveContext);
  lContext.SectionKind := 'implementation';
  lContext.ConformanceLevel := 3;
  lContext.IndexedUnitModels := [lModel];
  lResult := TDelphiSemanticResolver.ResolveName(lEmptyModel, lContext, 'lOnlyA');
  Assert.IsFalse(lResult.Found);
  lResult := TDelphiSemanticResolver.ResolveName(lEmptyModel, lContext, 'gVisible');
  Assert.IsTrue(lResult.Found);
  Assert.AreEqual('var', lResult.Kind);
  Assert.AreEqual('QualifiedMethodScopeUnit', lResult.OwnerName);
end;

procedure TScopeResolverTests.QualifiedMethodParentsKeepWithReceiverOwners;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := ExtractSource('qualified-with-parent.pas', cQualifiedMethodScopeSource);
  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  Assert.AreEqual(2, Integer(Length(lBindings)));
  Assert.AreEqual(31, lBindings[0].Line);
  Assert.AreEqual(44, lBindings[1].Line);
  Assert.AreEqual('Inner', lBindings[0].RoutineName);
  Assert.AreEqual('Inner', lBindings[1].RoutineName);
  Assert.AreEqual(1, Integer(Length(lBindings[0].Selectors)));
  Assert.AreEqual(1, Integer(Length(lBindings[1].Selectors)));
  Assert.AreEqual('resolved', lBindings[0].Selectors[0].Status);
  Assert.AreEqual('resolved', lBindings[1].Selectors[0].Status);
  Assert.AreEqual('TDataA', lBindings[0].Selectors[0].TypeName);
  Assert.AreEqual('TDataB', lBindings[1].Selectors[0].TypeName);
end;

function ResumedLocalScopeSource: string;
begin
  Result :=
    'unit ResumedLocalUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TData = record' + sLineBreak +
    '    lLate: Boolean;' + sLineBreak +
    '  end;' + sLineBreak +
    '  TA = class' + sLineBreak +
    '    class procedure Run;' + sLineBreak +
    '  end;' + sLineBreak +
    '  TB = class' + sLineBreak +
    '    class procedure Run;' + sLineBreak +
    '  end;' + sLineBreak +
    'implementation' + sLineBreak +
    'class procedure TA.Run;' + sLineBreak +
    '  procedure Before;' + sLineBreak +
    '  begin' + sLineBreak +
    '  end;' + sLineBreak +
    'var' + sLineBreak +
    '  lLate: Integer;' + sLineBreak +
    '  lOnlyA: Integer;' + sLineBreak +
    '  procedure Observe;' + sLineBreak +
    '  begin' + sLineBreak +
    '    lLate := lLate;' + sLineBreak +
    '  end;' + sLineBreak +
    'begin' + sLineBreak +
    '  lLate := 1;' + sLineBreak +
    '  Observe;' + sLineBreak +
    'end;' + sLineBreak +
    'class procedure TB.Run;' + sLineBreak +
    '  procedure Before;' + sLineBreak +
    '  begin' + sLineBreak +
    '  end;' + sLineBreak +
    'var' + sLineBreak +
    '  lLate: string;' + sLineBreak +
    '  procedure Observe;' + sLineBreak +
    '  begin' + sLineBreak +
    '    lLate := lLate;' + sLineBreak +
    '  end;' + sLineBreak +
    'begin' + sLineBreak +
    '  lLate := ''B'';' + sLineBreak +
    '  Observe;' + sLineBreak +
    'end;' + sLineBreak +
    'end.';
end;

procedure AssertResumedDeclaration(const aModel: TDelphiSemanticUnitModel;
  const aOwner, aTypeName: string; const aLine: Integer);
var
  lDeclaration: TDelphiSemanticDeclaration;
  lFound: Boolean;
begin
  lFound := False;
  for lDeclaration in aModel.Declarations do
    if SameText(lDeclaration.Name, 'lLate') and (lDeclaration.Line = aLine) then
    begin
      lFound := True;
      Assert.AreEqual('routine', lDeclaration.ScopeKind);
      Assert.AreEqual(aOwner, lDeclaration.OwnerName);
      Assert.AreEqual('var', lDeclaration.Kind);
      Assert.AreEqual(aTypeName, lDeclaration.TypeName);
      Assert.AreEqual(3, lDeclaration.Column);
      Assert.IsNotEmpty(lDeclaration.OwnerScopeId);
    end;
  Assert.IsTrue(lFound, 'Expected actual resumed declaration at ' + aLine.ToString);
end;

procedure TScopeResolverTests.ResumedLocalsKeepQualifiedOwnership(const aCase: Integer);
var
  lContext: TDelphiSemanticResolveContext;
  lDeclarationLine: Integer;
  lModel: TDelphiSemanticUnitModel;
  lOwner: string;
  lQueryLine: Integer;
  lResult: TDelphiSemanticResolveResult;
  lTypeName: string;
begin
  lModel := ExtractSource('resumed-locals-' + aCase.ToString + '.pas', ResumedLocalScopeSource);
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  AssertResumedDeclaration(lModel, 'TA.Run', 'Integer', 19);
  AssertResumedDeclaration(lModel, 'TB.Run', 'string', 34);
  if aCase < 2 then
  begin
    lOwner := 'TA.Run';
    lTypeName := 'Integer';
    lDeclarationLine := 19;
    if aCase = 0 then
      lQueryLine := 26
    else
      lQueryLine := 23;
  end else
  begin
    lOwner := 'TB.Run';
    lTypeName := 'string';
    lDeclarationLine := 34;
    if aCase = 2 then
      lQueryLine := 40
    else
      lQueryLine := 37;
  end;
  lContext := QualifiedMethodContext(
    TDelphiSemanticScopeResolver.BuildRoutineScopeIndex(lModel, [lQueryLine]), lQueryLine);
  if Odd(aCase) then
  begin
    Assert.AreEqual('Observe', lContext.RoutineName);
    Assert.AreEqual(1, Integer(Length(lContext.ParentRoutineNames)));
    Assert.AreEqual(lOwner, lContext.ParentRoutineNames[0]);
  end else
    Assert.AreEqual(lOwner, lContext.RoutineName);
  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'lLate');
  Assert.IsTrue(lResult.Found, lResult.Reason);
  Assert.AreEqual('local', lResult.Kind);
  Assert.AreEqual(lOwner, lResult.OwnerName);
  Assert.AreEqual(lTypeName, lResult.TypeName);
  Assert.AreEqual(lDeclarationLine, lResult.Line);
  Assert.AreEqual(3, lResult.Column);
  if aCase >= 2 then
  begin
    lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'lOnlyA');
    Assert.IsFalse(lResult.Found, 'Resumed TA.Run local must not leak into TB.Run');
  end;
end;

procedure TScopeResolverTests.ResumedLocalBeatsCurrentMemberFallback;
var
  lContext: TDelphiSemanticResolveContext;
  lIndex: TDelphiSemanticRoutineScopeIndex;
  lModel: TDelphiSemanticUnitModel;
  lResult: TDelphiSemanticResolveResult;
begin
  lModel := ExtractSource('resumed-local-member.pas', ResumedLocalScopeSource);
  lIndex := TDelphiSemanticScopeResolver.BuildRoutineScopeIndex(lModel);
  lContext := QualifiedMethodContext(lIndex, 26);
  // Exercise lexical-before-current-member precedence; this is not a with receiver.
  lContext.CurrentTypeName := 'TData';
  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'lLate');
  Assert.IsTrue(lResult.Found);
  Assert.AreEqual('local', lResult.Kind);
  Assert.AreEqual('Integer', lResult.TypeName);
  Assert.AreEqual('TA.Run', lResult.OwnerName);
  Assert.AreEqual(19, lResult.Line);
end;

function ResumedOverloadScopeSource: string;
begin
  Result :=
    'unit ResumedOverloadUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TData = record' + sLineBreak +
    '    lLate: Boolean;' + sLineBreak +
    '  end;' + sLineBreak +
    '  TA = class' + sLineBreak +
    '    class procedure Run(aValue: Integer); overload;' + sLineBreak +
    '    class procedure Run(aValue: string); overload;' + sLineBreak +
    '  end;' + sLineBreak +
    'implementation' + sLineBreak +
    'class procedure TA.Run(aValue: Integer);' + sLineBreak +
    '  procedure Before;' + sLineBreak +
    '  begin' + sLineBreak +
    '  end;' + sLineBreak +
    'var' + sLineBreak +
    '  lLate: Integer;' + sLineBreak +
    'begin' + sLineBreak +
    '  lLate := aValue;' + sLineBreak +
    'end;' + sLineBreak +
    'class procedure TA.Run(aValue: string);' + sLineBreak +
    '  procedure Before;' + sLineBreak +
    '  begin' + sLineBreak +
    '  end;' + sLineBreak +
    'var' + sLineBreak +
    '  lLate: string;' + sLineBreak +
    'begin' + sLineBreak +
    '  lLate := aValue;' + sLineBreak +
    'end;' + sLineBreak +
    'end.';
end;

procedure AssertResumedOverloadScopeIdentity(const aModel: TDelphiSemanticUnitModel);
var
  lDeclaration: TDelphiSemanticDeclaration;
  lFirstScope: string;
  lLocal: TDelphiSemanticLocal;
  lLocalScopes: string;
begin
  lFirstScope := '';
  for lDeclaration in aModel.Declarations do
    if SameText(lDeclaration.Name, 'lLate') and (lDeclaration.Line = 17) then
      lFirstScope := lDeclaration.OwnerScopeId;
  Assert.IsNotEmpty(lFirstScope);
  for lDeclaration in aModel.Declarations do
    if SameText(lDeclaration.Name, 'lLate') and (lDeclaration.Line = 26) then
      Assert.AreNotEqual(lFirstScope, lDeclaration.OwnerScopeId);
  // DS-653: the var section resumed after a nested routine is extracted as a local of each
  // overload; the declarations keep covering the fallback when locals are absent.
  lLocalScopes := '';
  for lLocal in aModel.Locals do
    if SameText(lLocal.Name, 'lLate') then
      lLocalScopes := lLocalScopes + lLocal.Line.ToString + '=' +
        BoolToStr(lLocal.RoutineScopeId = lFirstScope, True) + ' ';
  Assert.AreEqual('17=True 26=False ', lLocalScopes);
end;

procedure TScopeResolverTests.ResumedOverloadLocalsAreAmbiguous(const aSameType: Boolean);
var
  lContext: TDelphiSemanticResolveContext;
  lIndex: TDelphiSemanticRoutineScopeIndex;
  lModel: TDelphiSemanticUnitModel;
  lResult: TDelphiSemanticResolveResult;
  lSecondType: string;
  lSource: string;
  lWithLocals: Boolean;
begin
  lSource := ResumedOverloadScopeSource;
  lSecondType := 'string';
  if aSameType then
  begin
    lSource := StringReplace(lSource, 'lLate: string;', 'lLate: Integer;', []);
    lSource := StringReplace(lSource, 'lLate := aValue;', 'lLate := 1;', [rfReplaceAll]);
    lSecondType := 'Integer';
  end;
  lModel := ExtractSource('resumed-overload-' + BoolToStr(aSameType, True) + '.pas', lSource);
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  AssertResumedDeclaration(lModel, 'TA.Run', 'Integer', 17);
  AssertResumedDeclaration(lModel, 'TA.Run', lSecondType, 26);
  AssertResumedOverloadScopeIdentity(lModel);
  for lWithLocals := True downto False do
  begin
    // Without extracted locals the resolver falls back to the routine-scoped declarations.
    if not lWithLocals then
      lModel.Locals := nil;
    lIndex := TDelphiSemanticScopeResolver.BuildRoutineScopeIndex(lModel);
    lContext := QualifiedMethodContext(lIndex, 19);
    Assert.AreEqual('TA.Run', lContext.RoutineName);
    // Case-insensitive exact owner matching must still detect both overload scopes.
    lContext.RoutineName := 'ta.run';
    lContext.CurrentTypeName := 'TData';
    lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'LLATE');
    Assert.AreEqual('ambiguous', lResult.Status,
      'Distinct overload declarations must block competing current-member fallback; locals: ' +
      BoolToStr(lWithLocals, True));
    Assert.IsFalse(lResult.Found);
    Assert.AreNotEqual('field', lResult.Kind);
  end;
end;

procedure TScopeResolverTests.ResumedDeclarationsRequireRoutineContext;
var
  lContext: TDelphiSemanticResolveContext;
  lModel: TDelphiSemanticUnitModel;
  lResult: TDelphiSemanticResolveResult;
begin
  lModel := ExtractSource('resumed-no-routine.pas', ResumedOverloadScopeSource);
  AssertResumedDeclaration(lModel, 'TA.Run', 'Integer', 17);
  lContext := Default(TDelphiSemanticResolveContext);
  lContext.SectionKind := 'implementation';
  lContext.ConformanceLevel := 3;
  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'lLate');
  Assert.IsFalse(lResult.Found);
  Assert.AreEqual('NAME_NOT_FOUND', lResult.ReasonCode);
end;

initialization
  TDUnitX.RegisterTestFixture(TScopeResolverTests);

end.
