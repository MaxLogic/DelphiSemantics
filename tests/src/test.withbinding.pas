unit Test.WithBinding;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.ProjectSession, DelphiSemantics.WithBinding;

type
  [TestFixture]
  TProjectWithBindingTests = class
  private
    function FixturePath(const aRelativePath: string): string;
    function BindingByUnit(const aFacts: TDelphiSemanticProjectWithBindingFacts;
      const aUnitName: string): TDelphiSemanticWithBinding;
    function HasBindingForUnit(const aFacts: TDelphiSemanticProjectWithBindingFacts;
      const aUnitName: string): Boolean;
    function HasProjectSymbol(const aFacts: TDelphiSemanticProjectWithBindingFacts;
      const aName, aSymbolClass: string): Boolean;
    function HasProjectSymbolSource(const aFacts: TDelphiSemanticProjectWithBindingFacts;
      const aName, aSymbolClass, aSourceKind: string): Boolean;
    function HasReference(const aBinding: TDelphiSemanticWithBinding; const aName,
      aClassification: string): Boolean;
  public
    [Test]
    procedure ProjectSessionBuildsProjectLevelWithBindingFacts;
    [Test]
    procedure ProjectSessionCanSkipGraphForRangeMappedWithBindingFacts;
    [Test]
    procedure ProjectSessionIncludesExplicitAdditionalSourceFiles;
    [Test]
    procedure ProjectSessionLimitsBodyAnalysisToRequestedSourceFiles;
    [Test]
    procedure BindingReferenceCacheUsesStatementPrefix;
  end;

implementation

uses
  System.IOUtils, System.StrUtils, System.SysUtils,
  DelphiSemantics.ProjectContext;

function TProjectWithBindingTests.FixturePath(const aRelativePath: string): string;
begin
  Result := TPath.GetFullPath(TPath.Combine(
    TPath.Combine(ExtractFilePath(ParamStr(0)), '..\fixtures'),
    aRelativePath));
end;

function TProjectWithBindingTests.BindingByUnit(
  const aFacts: TDelphiSemanticProjectWithBindingFacts;
  const aUnitName: string): TDelphiSemanticWithBinding;
var
  lBinding: TDelphiSemanticWithBinding;
begin
  for lBinding in aFacts.Bindings do
    if SameText(lBinding.UnitName, aUnitName) then
      Exit(lBinding);

  Assert.Fail('Missing binding for unit ' + aUnitName);
  Result := Default(TDelphiSemanticWithBinding);
end;

function TProjectWithBindingTests.HasReference(const aBinding: TDelphiSemanticWithBinding;
  const aName, aClassification: string): Boolean;
var
  lReference: TDelphiSemanticBoundReference;
begin
  for lReference in aBinding.References do
    if SameText(lReference.Name, aName) and SameText(lReference.Classification,
      aClassification) then
      Exit(lReference.SemanticId <> '');

  Result := False;
end;

function TProjectWithBindingTests.HasBindingForUnit(
  const aFacts: TDelphiSemanticProjectWithBindingFacts; const aUnitName: string): Boolean;
var
  lBinding: TDelphiSemanticWithBinding;
begin
  for lBinding in aFacts.Bindings do
    if SameText(lBinding.UnitName, aUnitName) then
      Exit(True);

  Result := False;
end;

function TProjectWithBindingTests.HasProjectSymbol(
  const aFacts: TDelphiSemanticProjectWithBindingFacts; const aName,
  aSymbolClass: string): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  for lSymbol in aFacts.Symbols do
    if SameText(lSymbol.Name, aName) and SameText(lSymbol.SymbolClass, aSymbolClass) then
      Exit(True);

  Result := False;
end;

function TProjectWithBindingTests.HasProjectSymbolSource(
  const aFacts: TDelphiSemanticProjectWithBindingFacts; const aName,
  aSymbolClass, aSourceKind: string): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  for lSymbol in aFacts.Symbols do
    if SameText(lSymbol.Name, aName) and SameText(lSymbol.SymbolClass, aSymbolClass) and
      SameText(lSymbol.SourceOwnerType, aSourceKind) then
      Exit(True);

  Result := False;
end;

procedure TProjectWithBindingTests.ProjectSessionBuildsProjectLevelWithBindingFacts;
var
  lProgramBinding: TDelphiSemanticWithBinding;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
  lUnitBinding: TDelphiSemanticWithBinding;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := FixturePath('ProjectWithBinding\ProjectWithBinding.dproj');

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lFacts := lResult.Session.BuildWithBindingFacts;

    Assert.AreEqual(lResult.Session.Project.ContextFingerprint, lFacts.ContextFingerprint);
    Assert.IsTrue(lFacts.Metrics.SemanticGraphUsed);
    Assert.IsFalse(lFacts.Metrics.BuildUnitIndexUsed);
    Assert.IsTrue(lFacts.Metrics.ModelExtractionMilliseconds >= 0);
    Assert.AreEqual(2, lFacts.Metrics.UnitCount);
    Assert.AreEqual(2, lFacts.Metrics.BindingCount);
    Assert.AreEqual(2, Length(lFacts.Bindings));
    Assert.IsTrue(Length(lFacts.Symbols) > 0,
      'Expected project facts to carry reusable semantic inventory symbols.');
    Assert.IsTrue(HasProjectSymbol(lFacts, 'ProjectWithUnit', 'unit'));
    Assert.IsTrue(HasProjectSymbol(lFacts, 'TProjectWithRecord', 'declaration'));
    Assert.IsTrue(HasProjectSymbol(lFacts, 'Value', 'member'));
    Assert.IsTrue(HasProjectSymbolSource(lFacts, 'SizeOf', 'routine', 'compiler-intrinsic'));
    Assert.IsTrue(HasProjectSymbolSource(lFacts, 'Push', 'routine', 'rtl-source'));
    Assert.IsTrue(HasProjectSymbolSource(lFacts, 'TSearchRec', 'type-member', 'rtl-source'));
    Assert.IsFalse(HasBindingForUnit(lFacts, 'UnreferencedWithUnit'),
      'Unreferenced .pas files in the project directory must not be scanned as project units.');

    lProgramBinding := BindingByUnit(lFacts, 'ProjectWithBinding');
    Assert.IsNotEmpty(lProgramBinding.SemanticId);
    Assert.AreEqual('with-binding:project-session', lProgramBinding.Provenance);
    Assert.IsFalse(lProgramBinding.HasScopedDeclaration);
    Assert.IsTrue(HasReference(lProgramBinding, 'Value', 'member'));

    lUnitBinding := BindingByUnit(lFacts, 'ProjectWithUnit');
    Assert.IsTrue(HasReference(lUnitBinding, 'Count', 'member'));
    Assert.IsNotEmpty(lUnitBinding.References[0].SemanticId);
    Assert.AreNotEqual(lUnitBinding.SemanticId, lUnitBinding.References[0].SemanticId);
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectWithBindingTests.ProjectSessionCanSkipGraphForRangeMappedWithBindingFacts;
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOptions: TDelphiSemanticOptions;
  lProgramBinding: TDelphiSemanticWithBinding;
  lResult: TDelphiSemanticProjectSessionResult;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := FixturePath('ProjectWithBinding\ProjectWithBinding.dproj');
  lOptions.SkipWithBindingSemanticGraph := True;

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lFacts := lResult.Session.BuildWithBindingFacts;

    Assert.IsFalse(lFacts.Metrics.SemanticGraphUsed);
    Assert.AreEqual(2, lFacts.Metrics.BindingCount);
    lProgramBinding := BindingByUnit(lFacts, 'ProjectWithBinding');
    Assert.AreEqual('with-binding:model', lProgramBinding.Provenance);
    Assert.IsNotEmpty(lProgramBinding.SemanticId);
    Assert.IsTrue(HasReference(lProgramBinding, 'Value', 'member'));
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectWithBindingTests.ProjectSessionIncludesExplicitAdditionalSourceFiles;
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := FixturePath('ProjectWithBinding\ProjectWithBinding.dproj');
  lOptions.AdditionalSourceFileNames := [
    FixturePath('ProjectWithBinding\UnreferencedWithUnit.pas')];

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lFacts := lResult.Session.BuildWithBindingFacts;

    Assert.IsTrue(HasBindingForUnit(lFacts, 'UnreferencedWithUnit'),
      'Explicit additional source files must participate in project semantic facts.');
    Assert.IsTrue(HasProjectSymbol(lFacts, 'TUnreferencedRecord', 'declaration'),
      'Explicit additional source files must contribute semantic inventory symbols.');
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectWithBindingTests.ProjectSessionLimitsBodyAnalysisToRequestedSourceFiles;
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := FixturePath('ProjectWithBinding\ProjectWithBinding.dproj');
  lOptions.AdditionalSourceFileNames := [
    FixturePath('ProjectWithBinding\UnreferencedWithUnit.pas')];
  lOptions.BodyAnalysisSourceFileNames := [
    FixturePath('ProjectWithBinding\ProjectWithBinding.dpr'),
    FixturePath('ProjectWithBinding\ProjectWithUnit.pas')];

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lFacts := lResult.Session.BuildWithBindingFacts;

    Assert.IsFalse(HasBindingForUnit(lFacts, 'UnreferencedWithUnit'),
      'Sources outside the body-analysis set must not contribute with bindings.');
    Assert.IsTrue(HasProjectSymbol(lFacts, 'TUnreferencedRecord', 'declaration'),
      'Sources outside the body-analysis set must still contribute declarations.');
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectWithBindingTests.BindingReferenceCacheUsesStatementPrefix;
var
  lSourceText: string;
begin
  lSourceText := TFile.ReadAllText(TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)),
    '..\..\src\DelphiSemantics.WithBinding.pas')), TEncoding.UTF8);

  Assert.IsTrue(ContainsText(lSourceText, 'BoundReferenceCachePrefix'),
    'binding should build the shared reference-cache key prefix once per statement');
  Assert.IsTrue(ContainsText(lSourceText, 'ResolveNameCachePrefix'),
    'binding should build the shared resolver-cache key prefix once per statement');
end;

initialization
  TDUnitX.RegisterTestFixture(TProjectWithBindingTests);

end.
