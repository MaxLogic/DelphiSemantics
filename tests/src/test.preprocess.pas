unit Test.Preprocess;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Preprocess;

type
  [TestFixture]
  TPreprocessTests = class
  private
    function HasDiagnostic(const aResult: TDelphiSemanticPreprocessResult;
      const aCode: string): Boolean;
    function HasRegion(const aResult: TDelphiSemanticPreprocessResult; const aLine: Integer;
      const aActive: Boolean): Boolean;
  public
    [Test]
    procedure ActiveDefinesSelectExpectedConditionalRegions;
    [Test]
    procedure DefineAndUndefDirectivesAffectLaterRegions;
    [Test]
    procedure IncludesResolveFromSearchPathsAndAffectGraphHash;
    [Test]
    procedure IncludeHashUsesLoadedIncludeText;
    [Test]
    procedure IncludeCyclesProduceDeterministicDiagnostic;
    [Test]
    procedure MalformedConditionalStackProducesDiagnostics;
    [Test]
    procedure ConditionalDirectivesAllowTrailingComments;
    [Test]
    procedure ConditionalDirectivesAllowLegacyMultilineCloseBrace;
    [Test]
    procedure CompilerSwitchDirectivesDoNotFailPreprocessing;
    [Test]
    procedure DirectivesInsideLineCommentsAreIgnored;
    [Test]
    [TestCase('Brace text inside block comment', '0')]
    [TestCase('Parenthesized text inside brace comment', '1')]
    [TestCase('Directive text inside escaped string', '2')]
    procedure DirectiveLookalikesPreserveSource(const aCase: Integer);
    [Test]
    [TestCase('Parenthesized comment', '0')]
    [TestCase('Brace comment', '1')]
    procedure CommentSlashesDoNotHideFollowingDirective(const aCase: Integer);
    [Test]
    procedure InlineConditionalDirectivesCloseOnSameLine;
    [Test]
    procedure Linux64ProjectConditionalsUseTargetDefines;
    [Test]
    procedure UnsupportedConditionalElseBranchStaysInactive;
    [Test]
    procedure UnsupportedConditionalDirectiveProducesDiagnostic;
  end;

implementation

uses
  System.IOUtils, System.SysUtils,
  Winapi.Windows,
  maxLogic.IOUtils,
  DelphiSemantics.ProjectContext,
  Test.Support;

function PreprocessTempRoot(const aName: string): string;
var
  lGuid: TGUID;
  lGuidText: string;
begin
  CreateGUID(lGuid);
  lGuidText := StringReplace(StringReplace(GUIDToString(lGuid), '{', '', [rfReplaceAll]), '}', '',
    [rfReplaceAll]);
  Result := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), 'preprocess-temp',
    'run-' + GetCurrentProcessId.ToString + '-' + lGuidText, aName]));
  TDirectory.CreateDirectory(Result);
end;


function TPreprocessTests.HasDiagnostic(const aResult: TDelphiSemanticPreprocessResult;
  const aCode: string): Boolean;
var
  lDiagnostic: TDelphiSemanticPreprocessDiagnostic;
begin
  for lDiagnostic in aResult.Diagnostics do
    if SameText(lDiagnostic.Code, aCode) then
      Exit(True);

  Result := False;
end;

function TPreprocessTests.HasRegion(const aResult: TDelphiSemanticPreprocessResult;
  const aLine: Integer; const aActive: Boolean): Boolean;
var
  lRegion: TDelphiSemanticSourceRegion;
begin
  for lRegion in aResult.Regions do
    if (lRegion.StartLine <= aLine) and (lRegion.EndLine >= aLine) and
      (lRegion.Active = aActive) then
      Exit(True);

  Result := False;
end;

procedure TPreprocessTests.ActiveDefinesSelectExpectedConditionalRegions;
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lResult: TDelphiSemanticPreprocessResult;
begin
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := FixturePath('Preprocess', 'ConditionalUnit.pas');
  lOptions.Defines := ['ACTIVE_FEATURE'];

  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);

  Assert.IsTrue(lResult.Success);
  Assert.IsTrue(Pos('TActiveType', lResult.OutputText) > 0);
  Assert.IsTrue(Pos('TIfNDefType', lResult.OutputText) > 0);
  Assert.IsTrue(Pos('TIfDefinedType', lResult.OutputText) > 0);
  Assert.IsFalse(Pos('TInactiveType', lResult.OutputText) > 0);
  Assert.IsFalse(Pos('TElseIfType', lResult.OutputText) > 0);
  Assert.IsTrue(HasRegion(lResult, 6, True), 'active IFDEF branch region');
  Assert.IsTrue(HasRegion(lResult, 8, False), 'inactive ELSE branch region');
end;

procedure TPreprocessTests.DefineAndUndefDirectivesAffectLaterRegions;
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lResult: TDelphiSemanticPreprocessResult;
begin
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := FixturePath('Preprocess', 'DefineUndefUnit.pas');

  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);

  Assert.IsTrue(lResult.Success);
  Assert.IsTrue(Pos('TDefinedType', lResult.OutputText) > 0);
  Assert.IsFalse(Pos('TUndefinedType', lResult.OutputText) > 0);
end;

procedure TPreprocessTests.IncludesResolveFromSearchPathsAndAffectGraphHash;
var
  lFirst: TDelphiSemanticPreprocessResult;
  lOptions: TDelphiSemanticPreprocessOptions;
  lSecond: TDelphiSemanticPreprocessResult;
  lTempDir: string;
begin
  lTempDir := PreprocessTempRoot('includes');
  TFile.WriteAllText(TPath.Combine(lTempDir, 'Dynamic.inc'), 'type TFirstInclude = class end;',
    TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(lTempDir, 'DynamicIncludeUnit.pas'),
    'unit DynamicIncludeUnit;' + sLineBreak +
    'interface' + sLineBreak +
    '{$I Dynamic.inc}' + sLineBreak +
    'implementation' + sLineBreak +
    'end.', TEncoding.UTF8);

  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := TPath.Combine(lTempDir, 'DynamicIncludeUnit.pas');
  lOptions.SearchPaths := [lTempDir];

  lFirst := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);
  TFile.WriteAllText(TPath.Combine(lTempDir, 'Dynamic.inc'), 'type TSecondInclude = class end;',
    TEncoding.UTF8);
  lSecond := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);

  Assert.IsTrue(lFirst.Success);
  Assert.IsTrue(lSecond.Success);
  Assert.AreEqual(1, Integer(Length(lFirst.Includes)));
  Assert.IsTrue(Pos('TFirstInclude', lFirst.OutputText) > 0);
  Assert.IsTrue(Pos('TSecondInclude', lSecond.OutputText) > 0);
  Assert.AreNotEqual(lFirst.IncludeGraphHash, lSecond.IncludeGraphHash);
end;

procedure TPreprocessTests.IncludeHashUsesLoadedIncludeText;
var
  lSource: string;
begin
  lSource := ReadRepoSource('src\DelphiSemantics.Preprocess.pas');

  Assert.IsFalse(Pos('CalculateTextHash(TFile.ReadAllText', lSource) > 0,
    'Include content hash must use the text already loaded for include processing.');
  Assert.IsFalse(Pos('ProcessSourceFile(lIncludeFileName', lSource) > 0,
    'Include processing should not call the file-loading entry point after hashing.');
  Assert.IsFalse(Pos('TFile.ReadAllText', lSource) > 0,
    'Preprocessor file reads should use the shared source loader.');
  Assert.IsTrue(Pos('TSourceTextCache', lSource) > 0,
    'Preprocessor should keep a pass-scoped source text cache.');
  Assert.IsTrue(Pos('TSourceTextCache.Create(TFastCaseAwareComparer.OrdinalIgnoreCase)',
    lSource) > 0, 'Preprocessor source text cache should use path-casing tolerant keys.');
  Assert.IsTrue(Pos('TDelphiSemanticSourceLoader.LoadFile', lSource) > 0,
    'Preprocessor source reads should route through the shared source loader.');
end;

procedure TPreprocessTests.IncludeCyclesProduceDeterministicDiagnostic;
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lResult: TDelphiSemanticPreprocessResult;
  lTempDir: string;
begin
  lTempDir := PreprocessTempRoot('cycles');
  TFile.WriteAllText(TPath.Combine(lTempDir, 'CycleUnit.pas'),
    'unit CycleUnit;' + sLineBreak +
    'interface' + sLineBreak +
    '{$I Cycle.inc}' + sLineBreak +
    'implementation' + sLineBreak +
    'end.', TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(lTempDir, 'Cycle.inc'), '{$I Cycle.inc}',
    TEncoding.UTF8);

  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := TPath.Combine(lTempDir, 'CycleUnit.pas');
  lOptions.SearchPaths := [lTempDir];

  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);

  Assert.IsFalse(lResult.Success);
  Assert.IsTrue(HasDiagnostic(lResult, 'INCLUDE_CYCLE'));
end;

procedure TPreprocessTests.MalformedConditionalStackProducesDiagnostics;
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lResult: TDelphiSemanticPreprocessResult;
begin
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := FixturePath('Preprocess', 'MalformedConditionalUnit.pas');

  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);

  Assert.IsFalse(lResult.Success);
  Assert.IsTrue(HasDiagnostic(lResult, 'UNMATCHED_PREPROCESS_DIRECTIVE'));
  Assert.IsTrue(HasDiagnostic(lResult, 'UNTERMINATED_PREPROCESS_CONDITIONAL'));
end;

procedure TPreprocessTests.ConditionalDirectivesAllowTrailingComments;
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lResult: TDelphiSemanticPreprocessResult;
begin
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := FixturePath('Preprocess', 'TrailingCommentConditionalUnit.pas');
  lOptions.Defines := ['ACTIVE_FEATURE'];

  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);

  Assert.IsTrue(lResult.Success);
  Assert.IsTrue(Pos('TActiveTrailingType', lResult.OutputText) > 0);
  Assert.IsFalse(Pos('TInactiveTrailingType', lResult.OutputText) > 0);
  Assert.IsTrue(Pos('TElseTrailingType', lResult.OutputText) > 0);
end;

procedure TPreprocessTests.ConditionalDirectivesAllowLegacyMultilineCloseBrace;
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lResult: TDelphiSemanticPreprocessResult;
begin
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := FixturePath('Preprocess', 'LegacyMultilineCloseBraceUnit.pas');

  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);

  Assert.IsTrue(lResult.Success);
  Assert.IsTrue(Pos('TAfterLegacyCloseBrace', lResult.OutputText) > 0);
  Assert.IsFalse(HasDiagnostic(lResult, 'UNTERMINATED_PREPROCESS_CONDITIONAL'));
end;

procedure TPreprocessTests.CompilerSwitchDirectivesDoNotFailPreprocessing;
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lResult: TDelphiSemanticPreprocessResult;
begin
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := FixturePath('Preprocess', 'CompilerSwitchUnit.pas');

  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);

  Assert.IsTrue(lResult.Success);
  Assert.IsTrue(Pos('TAfterCompilerSwitch', lResult.OutputText) > 0);
  Assert.IsFalse(HasDiagnostic(lResult, 'UNSUPPORTED_PREPROCESS_DIRECTIVE'));
end;

procedure TPreprocessTests.DirectivesInsideLineCommentsAreIgnored;
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lPath: string;
  lResult: TDelphiSemanticPreprocessResult;
  lRoot: string;
begin
  lRoot := PreprocessTempRoot('line-comment-directive');
  lPath := TPath.Combine(lRoot, 'LineCommentDirectiveUnit.pas');
  TFile.WriteAllText(lPath,
    'unit LineCommentDirectiveUnit;' + sLineBreak +
    'interface' + sLineBreak +
    '/// Documentation mentioning {$IFDEF FPC} must stay a comment.' +
    sLineBreak + 'implementation' + sLineBreak +
    'end.', TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := lPath;

  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);

  Assert.IsTrue(lResult.Success);
  Assert.IsTrue(Pos('implementation', lResult.OutputText) > 0);
  Assert.IsFalse(HasDiagnostic(lResult, 'UNTERMINATED_PREPROCESS_CONDITIONAL'));
end;

procedure TPreprocessTests.DirectiveLookalikesPreserveSource(const aCase: Integer);
const
  cExamples: array[0..2] of string = (
    '(* Example' + sLineBreak + '{$J+}' + sLineBreak + '*)',
    '{ Example' + sLineBreak + '(*$J+*)' + sLineBreak + '}',
    'const TextValue = ''It''''s {$J+} and (*$J+*)'';');
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lResult: TDelphiSemanticPreprocessResult;
  lSource: string;
begin
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := TPath.Combine(PreprocessTempRoot('directive-lookalikes'),
    'DirectiveLookalikes.pas');
  lSource := 'unit DirectiveLookalikes;' + sLineBreak + 'interface' +
    sLineBreak + '{$J-}' + sLineBreak + cExamples[aCase] + sLineBreak +
    'const ReadOnlyValue: Integer = 1;' + sLineBreak + 'implementation' +
    sLineBreak + 'end.' + sLineBreak;
  TFile.WriteAllText(lOptions.SourceFileName, lSource, TEncoding.UTF8);
  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);
  Assert.IsTrue(lResult.Success);
  Assert.AreEqual(lSource, lResult.OutputText,
    'Inactive directive-shaped text must remain byte-position-equivalent source.');
end;

procedure TPreprocessTests.CommentSlashesDoNotHideFollowingDirective(const aCase: Integer);
const
  cComments: array[0..1] of string = ('(* // *)', '{ // }');
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lResult: TDelphiSemanticPreprocessResult;
begin
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := TPath.Combine(PreprocessTempRoot('comment-before-directive'),
    'CommentBeforeDirective.pas');
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit CommentBeforeDirective;' + sLineBreak + 'interface' + sLineBreak +
    cComments[aCase] + ' {$IFDEF NEVER_DEFINED}' + sLineBreak +
    'const HiddenValue = 1;' + sLineBreak + '{$ENDIF}' + sLineBreak +
    'const VisibleValue = 2;' + sLineBreak + 'implementation' + sLineBreak +
    'end.', TEncoding.UTF8);
  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);
  Assert.IsTrue(lResult.Success, 'Comment text must not hide the active conditional directive.');
  Assert.IsFalse(Pos('HiddenValue', lResult.OutputText) > 0);
  Assert.IsTrue(Pos('VisibleValue', lResult.OutputText) > 0);
end;

procedure TPreprocessTests.InlineConditionalDirectivesCloseOnSameLine;
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lResult: TDelphiSemanticPreprocessResult;
begin
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := FixturePath('Preprocess', 'InlineConditionalUnit.pas');

  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);

  Assert.IsTrue(lResult.Success);
  Assert.IsTrue(Pos('TAfterInlineConditional', lResult.OutputText) > 0);
  Assert.IsFalse(HasDiagnostic(lResult, 'UNTERMINATED_PREPROCESS_CONDITIONAL'));
end;

procedure TPreprocessTests.Linux64ProjectConditionalsUseTargetDefines;
var
  lContextOptions: TDelphiSemanticOptions;
  lContext: TDelphiSemanticContextResult;
  lOptions: TDelphiSemanticPreprocessOptions;
  lResult: TDelphiSemanticPreprocessResult;
begin
  lContextOptions := Default(TDelphiSemanticOptions);
  lContextOptions.Configuration := 'Debug';
  lContextOptions.Platform := 'Linux64';
  lContextOptions.DelphiVersion := '23.0';

  lContext := TDelphiSemanticProject.Load(
    FixturePath('ProjectContext', 'MsBuild\MsBuildProject.dproj'), lContextOptions);
  Assert.IsTrue(lContext.Success);

  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := FixturePath('Preprocess', 'ConditionalUnit.pas');
  lOptions.SourceText :=
    'unit TargetPlatformConditionalUnit;' + sLineBreak +
    'interface' + sLineBreak +
    '{$IFDEF LINUX}' + sLineBreak +
    'type TLinuxTargetBranch = class end;' + sLineBreak +
    '{$ENDIF}' + sLineBreak +
    '{$IF DEFINED(POSIX) and DEFINED(CPUX64)}' + sLineBreak +
    'type TPosixCpuX64Branch = class end;' + sLineBreak +
    '{$ENDIF}' + sLineBreak +
    '{$IFDEF MSWINDOWS}' + sLineBreak +
    'type TWindowsHostBranch = class end;' + sLineBreak +
    '{$ENDIF}' + sLineBreak +
    '{$IFDEF WIN32}' + sLineBreak +
    'type TWin32HostBranch = class end;' + sLineBreak +
    '{$ENDIF}' + sLineBreak +
    'implementation' + sLineBreak +
    'end.';
  lOptions.Defines := lContext.Project.Defines;

  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);

  Assert.IsTrue(lResult.Success);
  Assert.IsTrue(Pos('TLinuxTargetBranch', lResult.OutputText) > 0);
  Assert.IsTrue(Pos('TPosixCpuX64Branch', lResult.OutputText) > 0);
  Assert.IsFalse(Pos('TWindowsHostBranch', lResult.OutputText) > 0);
  Assert.IsFalse(Pos('TWin32HostBranch', lResult.OutputText) > 0);
end;

procedure TPreprocessTests.UnsupportedConditionalElseBranchStaysInactive;
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lResult: TDelphiSemanticPreprocessResult;
begin
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := FixturePath('Preprocess', 'UnsupportedElseUnit.pas');

  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);

  Assert.IsFalse(lResult.Success);
  Assert.IsTrue(HasDiagnostic(lResult, 'UNSUPPORTED_PREPROCESS_DIRECTIVE'));
  Assert.IsFalse(Pos('TUnsupportedIfElseType', lResult.OutputText) > 0);
  Assert.IsFalse(Pos('TUnsupportedIfOptElseType', lResult.OutputText) > 0);
end;

procedure TPreprocessTests.UnsupportedConditionalDirectiveProducesDiagnostic;
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lResult: TDelphiSemanticPreprocessResult;
begin
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := FixturePath('Preprocess', 'UnsupportedDirectiveUnit.pas');

  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);

  Assert.IsFalse(lResult.Success);
  Assert.IsTrue(HasDiagnostic(lResult, 'UNSUPPORTED_PREPROCESS_DIRECTIVE'));
  Assert.IsFalse(Pos('TUnsupportedActiveType', lResult.OutputText) > 0);
end;

initialization
  TDUnitX.RegisterTestFixture(TPreprocessTests);

end.
