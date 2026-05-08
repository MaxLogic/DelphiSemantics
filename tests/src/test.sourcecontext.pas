unit Test.SourceContext;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.ProjectContext,
  DelphiSemantics.SourceContext;

type
  [TestFixture]
  TSourceContextTests = class
  private
    function FixturePath(const aFolder, aFileName: string): string;
    function LoadProject(const aFileName: string): TDelphiSemanticProjectInfo;
  public
    [Test]
    procedure AbsolutePathSourceContextResolves;
    [Test]
    procedure ProjectRelativeSourceContextResolves;
    [Test]
    procedure ProjectRelativeSourceContextPrefersProjectLookupOverCurrentDirectoryShadow;
    [Test]
    procedure SearchPathSourceContextResolves;
    [Test]
    procedure MissingSourceContextFileReturnsFalse;
    [Test]
    procedure ParseFindingLocationExtractsColumn;
    [Test]
    procedure SourceContextCandidateUsesTokenAtColumn;
    [Test]
    procedure SourceContextCandidateUsesTokenWhenColumnPointsAfterIdentifier;
    [Test]
    procedure SourceContextCandidateReturnsFalseForMalformedPathToken;
    [Test]
    procedure SourceContextCandidateUsesFirstIdentifierWithoutColumn;
    [Test]
    procedure SourceContextCandidateFallsBackToEnclosingSymbol;
    [Test]
    procedure SourceContextCandidateReturnsFalseWithoutReasonableCandidate;
  end;

implementation

uses
  System.IOUtils, System.SysUtils,
  maxLogic.IOUtils;

function TSourceContextTests.FixturePath(const aFolder, aFileName: string): string;
begin
  Result := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..', 'fixtures',
    aFolder, aFileName]));
end;

function TSourceContextTests.LoadProject(const aFileName: string): TDelphiSemanticProjectInfo;
var
  lResult: TDelphiSemanticContextResult;
begin
  lResult := TDelphiSemanticProject.Load(aFileName);
  Assert.IsTrue(lResult.Success);
  Result := lResult.Project;
end;

procedure TSourceContextTests.AbsolutePathSourceContextResolves;
var
  lContext: TDelphiSemanticSourceContextSnippet;
  lError: string;
  lProject: TDelphiSemanticProjectInfo;
  lProjectFileName: string;
begin
  lProjectFileName := FixturePath('SourceContext', 'ProjectRelativeUnit.pas');
  lProject := LoadProject(FixturePath('SourceContext', 'SourceContextFixture.dproj'));

  Assert.IsTrue(TDelphiSemanticSourceContext.TryResolve(lProject, lProjectFileName, 7, 1,
    lContext, lError), lError);
  Assert.AreEqual(TPath.GetFullPath(lProjectFileName), lContext.FileName);
  Assert.IsTrue(Pos('ProjectRelativeValue := 1;', String.Join(sLineBreak, lContext.Lines)) > 0);
end;

procedure TSourceContextTests.ProjectRelativeSourceContextResolves;
var
  lContext: TDelphiSemanticSourceContextSnippet;
  lError: string;
  lProject: TDelphiSemanticProjectInfo;
begin
  lProject := LoadProject(FixturePath('SourceContext', 'SourceContextFixture.dproj'));

  Assert.IsTrue(TDelphiSemanticSourceContext.TryResolve(lProject, 'ProjectRelativeUnit.pas', 7,
    1, lContext, lError), lError);
  Assert.AreEqual(FixturePath('SourceContext', 'ProjectRelativeUnit.pas'), lContext.FileName);
end;

procedure TSourceContextTests.ProjectRelativeSourceContextPrefersProjectLookupOverCurrentDirectoryShadow;
var
  lContext: TDelphiSemanticSourceContextSnippet;
  lCurrentDir: string;
  lError: string;
  lProject: TDelphiSemanticProjectInfo;
  lShadowDir: string;
  lShadowFileName: string;
begin
  lProject := LoadProject(FixturePath('SourceContext', 'SourceContextFixture.dproj'));
  lShadowDir := TPath.Combine(ExtractFilePath(ParamStr(0)), 'source-context-shadow');
  if TDirectory.Exists(lShadowDir) then
    TDirectory.Delete(lShadowDir, True);
  TDirectory.CreateDirectory(lShadowDir);
  lShadowFileName := TPath.Combine(lShadowDir, 'ProjectRelativeUnit.pas');
  TFile.WriteAllText(lShadowFileName,
    'unit ProjectRelativeUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'implementation' + sLineBreak +
    'begin' + sLineBreak +
    '  ShadowValue := 1;' + sLineBreak +
    'end.', TEncoding.UTF8);

  lCurrentDir := GetCurrentDir;
  try
    SetCurrentDir(lShadowDir);
    Assert.IsTrue(TDelphiSemanticSourceContext.TryResolve(lProject, 'ProjectRelativeUnit.pas',
      7, 1, lContext, lError), lError);
  finally
    SetCurrentDir(lCurrentDir);
  end;

  Assert.AreEqual(FixturePath('SourceContext', 'ProjectRelativeUnit.pas'), lContext.FileName);
  Assert.IsTrue(Pos('ProjectRelativeValue := 1;', String.Join(sLineBreak, lContext.Lines)) > 0);
end;

procedure TSourceContextTests.SearchPathSourceContextResolves;
var
  lContext: TDelphiSemanticSourceContextSnippet;
  lError: string;
  lProject: TDelphiSemanticProjectInfo;
begin
  lProject := LoadProject(FixturePath('SourceContext', 'SourceContextFixture.dproj'));

  Assert.IsTrue(TDelphiSemanticSourceContext.TryResolve(lProject, 'SearchHitUnit.pas', 7, 1,
    lContext, lError), lError);
  Assert.AreEqual(TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..', 'fixtures',
    'SourceContext', 'lib', 'SearchHitUnit.pas'])), lContext.FileName);
end;

procedure TSourceContextTests.MissingSourceContextFileReturnsFalse;
var
  lContext: TDelphiSemanticSourceContextSnippet;
  lError: string;
  lProject: TDelphiSemanticProjectInfo;
begin
  lProject := LoadProject(FixturePath('SourceContext', 'SourceContextFixture.dproj'));

  Assert.IsFalse(TDelphiSemanticSourceContext.TryResolve(lProject, 'MissingUnit.pas', 7, 1,
    lContext, lError));
  Assert.IsTrue(Pos('Could not resolve source file', lError) > 0);
end;

procedure TSourceContextTests.ParseFindingLocationExtractsColumn;
var
  lColumn: Integer;
  lFileToken: string;
  lLine: Integer;
begin
  Assert.IsTrue(TDelphiSemanticSourceContext.TryParseFindingLocationWithColumn(
    'TokenUnit.pas(7,5): error E2003: Undeclared identifier: ''MissingIdentifier''',
    lFileToken, lLine, lColumn));
  Assert.AreEqual('TokenUnit.pas', lFileToken);
  Assert.AreEqual(7, lLine);
  Assert.AreEqual(5, lColumn);
end;

procedure TSourceContextTests.SourceContextCandidateUsesTokenAtColumn;
var
  lContext: TDelphiSemanticSourceContextSnippet;
  lEnclosingSymbol: string;
  lError: string;
  lProject: TDelphiSemanticProjectInfo;
  lToken: string;
begin
  lProject := LoadProject(FixturePath('SourceContext', 'SourceContextCandidateFixture.dproj'));

  Assert.IsTrue(TDelphiSemanticSourceContext.TryResolveCandidate(lProject,
    'TokenUnit.pas(7,5): error E2003: Undeclared identifier', 1, lContext, lToken,
    lEnclosingSymbol, lError), lError);
  Assert.AreEqual('MissingIdentifier', lToken);
  Assert.AreEqual('', lEnclosingSymbol);
  Assert.AreEqual(FixturePath('SourceContext', 'TokenUnit.pas'), lContext.FileName);
  Assert.AreEqual(7, lContext.TargetLine);
end;

procedure TSourceContextTests.SourceContextCandidateUsesTokenWhenColumnPointsAfterIdentifier;
var
  lContext: TDelphiSemanticSourceContextSnippet;
  lEnclosingSymbol: string;
  lError: string;
  lProject: TDelphiSemanticProjectInfo;
  lToken: string;
begin
  lProject := LoadProject(FixturePath('SourceContext', 'SourceContextCandidateFixture.dproj'));

  Assert.IsTrue(TDelphiSemanticSourceContext.TryResolveCandidate(lProject,
    'TokenUnit.pas(7,22): error E2003: Undeclared identifier', 1, lContext, lToken,
    lEnclosingSymbol, lError), lError);
  Assert.AreEqual('MissingIdentifier', lToken);
end;

procedure TSourceContextTests.SourceContextCandidateReturnsFalseForMalformedPathToken;
var
  lContext: TDelphiSemanticSourceContextSnippet;
  lEnclosingSymbol: string;
  lError: string;
  lProject: TDelphiSemanticProjectInfo;
  lToken: string;
begin
  lProject := LoadProject(FixturePath('SourceContext', 'SourceContextCandidateFixture.dproj'));

  Assert.IsFalse(TDelphiSemanticSourceContext.TryResolveCandidate(lProject,
    'Bad'#0'Path.pas(7,5): error E2003: Undeclared identifier', 1, lContext, lToken,
    lEnclosingSymbol, lError));
  Assert.IsTrue(Pos('source file', LowerCase(lError)) > 0, lError);
end;

procedure TSourceContextTests.SourceContextCandidateUsesFirstIdentifierWithoutColumn;
var
  lContext: TDelphiSemanticSourceContextSnippet;
  lEnclosingSymbol: string;
  lError: string;
  lProject: TDelphiSemanticProjectInfo;
  lToken: string;
begin
  lProject := LoadProject(FixturePath('SourceContext', 'SourceContextCandidateFixture.dproj'));

  Assert.IsTrue(TDelphiSemanticSourceContext.TryResolveCandidate(lProject,
    'TokenUnit.pas(7): error E2003: Undeclared identifier', 1, lContext, lToken,
    lEnclosingSymbol, lError), lError);
  Assert.AreEqual('MissingIdentifier', lToken);
  Assert.AreEqual('', lEnclosingSymbol);
end;

procedure TSourceContextTests.SourceContextCandidateFallsBackToEnclosingSymbol;
var
  lContext: TDelphiSemanticSourceContextSnippet;
  lEnclosingSymbol: string;
  lError: string;
  lProject: TDelphiSemanticProjectInfo;
  lToken: string;
begin
  lProject := LoadProject(FixturePath('SourceContext', 'SourceContextCandidateFixture.dproj'));

  Assert.IsTrue(TDelphiSemanticSourceContext.TryResolveCandidate(lProject,
    'SymbolUnit.pas(7,3): error E2029: Record not allowed here', 3, lContext, lToken,
    lEnclosingSymbol, lError), lError);
  Assert.AreEqual('', lToken);
  Assert.AreEqual('Trigger', lEnclosingSymbol);
  Assert.AreEqual(FixturePath('SourceContext', 'SymbolUnit.pas'), lContext.FileName);
  Assert.AreEqual(7, lContext.TargetLine);
end;

procedure TSourceContextTests.SourceContextCandidateReturnsFalseWithoutReasonableCandidate;
var
  lContext: TDelphiSemanticSourceContextSnippet;
  lEnclosingSymbol: string;
  lError: string;
  lProject: TDelphiSemanticProjectInfo;
  lToken: string;
begin
  lProject := LoadProject(FixturePath('SourceContext', 'SourceContextCandidateFixture.dproj'));

  Assert.IsFalse(TDelphiSemanticSourceContext.TryResolveCandidate(lProject,
    'NoCandidateUnit.pas(3,1): error E2010: Syntax error', 1, lContext, lToken,
    lEnclosingSymbol, lError));
  Assert.IsTrue(Pos('candidate', LowerCase(lError)) > 0, lError);
end;

initialization
  TDUnitX.RegisterTestFixture(TSourceContextTests);

end.
