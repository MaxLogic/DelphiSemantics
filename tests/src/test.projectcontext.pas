unit Test.ProjectContext;

interface

uses
  DUnitX.TestFramework, DelphiSemantics.ProjectContext;

type
  TProfileDirectoryMatrixAttribute = class(CustomTestCaseSourceAttribute)
  protected
    function GetCaseInfoArray: TestCaseInfoArray; override;
  end;

  [TestFixture]
  TProjectContextTests = class
  private
    function ContainsPath(const aItems: TArray<string>; const aExpectedPath: string): Boolean;
    function ContextEvidenceTempPath(const aName: string): string;
    function DiagnosticSummary(const aResult: TDelphiSemanticContextResult): string;
    function HasDiagnostic(const aResult: TDelphiSemanticContextResult;
      const aCode: string): Boolean;
    function FindContextEvidenceInput(
      const aObservations: IDelphiSemanticProjectContextObservations;
      const aFileName: string; out aObservation: TDelphiSemanticProjectContextObservation): Boolean;
    procedure WriteUtf8Bytes(const aFileName, aText: string);
  public
    [Test]
    [Category('Fast')]
    [TProfileDirectoryMatrix]
    procedure FinalProfileInputsMatchGeneratedOracle(const aCaseId: Integer);
    [Test]
    [Category('Fast')]
    [TestCase('Derived 23', 'derived,23.0')]
    [TestCase('Derived 37', 'derived,37.0')]
    [TestCase('Environment wins', 'environment,23.0')]
    [TestCase('Registry wins', 'registry,23.0')]
    [TestCase('Native option wins', 'native,23.0')]
    [TestCase('Project wins', 'project,23.0')]
    procedure ProfileDirectoriesRespectInputPrecedence(const aOrigin, aVersion: string);
    [Test]
    [Category('Fast')]
    procedure UnavailableProfileFolderFailsClosed;
    [Test]
    [Category('Fast')]
    [TestCase('Native', 'native')]
    [TestCase('Environment', 'environment')]
    [TestCase('Registry', 'registry')]
    [TestCase('Project', 'project')]
    procedure ExplicitProfileIdentityMatchesBase641e4a3(const aOrigin: string);
    [Test]
    [Category('Fast')]
    [TestCase('Native empty', 'native,True')]
    [TestCase('Native absent', 'native,False')]
    [TestCase('Environment empty', 'environment,True')]
    [TestCase('Environment absent', 'environment,False')]
    [TestCase('Registry empty', 'registry,True')]
    [TestCase('Registry absent', 'registry,False')]
    [TestCase('Project empty', 'project,True')]
    [TestCase('Project absent', 'project,False')]
    procedure EmptyProfileDirectoryKeepsPrecedence(const aOrigin: string; const aPresent: Boolean);
    [Test]
    [Category('Fast')]
    [TestCase('Both overridden', 'both')]
    [TestCase('One fallback remains', 'one')]
    [TestCase('Both explicitly empty', 'empty')]
    procedure ProjectOverridesDiscardObsoleteFolderErrors(const aOverride: string);

    [Category('Fast')]
    [Test]
    procedure DprojResolvesBasicMetadata;
    [Category('Fast')]
    [Test]
    procedure DprResolvesThroughSiblingDproj;
    [Category('Fast')]
    [Test]
    procedure StaleDccReferenceResolvesThroughSearchPath;
    [Category('Fast')]
    [Test]
    procedure MissingProjectReturnsDeterministicDiagnostic;
    [Test]
    [Category('RefactoringLightContextEvidence,Fast')]
    procedure ProjectAndOptionBytesAndConfigurationAreObserved;
    [Test]
    [Category('RefactoringLightContextEvidence,Fast')]
    procedure AppearingHigherPriorityCandidateChangesSearchEvidence;
    [Test]
    [Category('RefactoringLightContextEvidence,Fast')]
    procedure AppearingConditionPathChangesContextEvidence;
    [Test]
    [Category('RefactoringLightContextEvidence,Fast')]
    procedure DuplicateImportedPathsReconcileDeterministically;
    [Test]
    [Category('RefactoringLightContextEvidence,Fast')]
    procedure OwnedContextEvidenceSurvivesSessionDisposal;
    [Test]
    [Category('RefactoringLightContextEvidence,Fast')]
    procedure PersistedSnapshotWithoutCoProducedEvidenceIsNonCertifying;
    [Test]
    [Category('RefactoringLightContext,Fast')]
    procedure BoundPlanBindsOperationConfigurationScopeAndIncludeManifest;
    [Test]
    [Category('RefactoringLightProjectContext,Fast')]
    procedure InstalledDelphiTargetsDoNotReportUnusedBuildMacros;
    [Test]
    [Category('RefactoringLightProjectContext,Fast')]
    procedure ExplicitSelfReferentialSearchPathRemainsEffective;
    [Test]
    [Category('RefactoringLightProjectContext,Fast')]
    procedure MissingFrameworkTypeInImportedTargetReportsSourceMacro;
    [Test]
    [Category('RefactoringLightProjectContext,Fast')]
    procedure ExplicitOptionalTargetPropertiesArePreserved;
    [Test]
    [Category('RefactoringLightProjectContext,Fast')]
    procedure EmptyExistsConditionIsFalse;
    [Test]
    [Category('RefactoringLightProjectContext,Fast')]
    procedure UnresolvedSourceSearchPathStillReportsMacro;
    [Test]
    [Category('RefactoringLightProjectContext,Fast')]
    procedure UnresolvedBuildPropertyFlowStillReportsMacro;
    [Test]
    [Category('RefactoringLightProjectContext,Fast')]
    procedure UnresolvedConditionOnSemanticPropertyStillReportsMacro;
    [Test]
    [Category('RefactoringLightProjectContext,Fast')]
    procedure UnresolvedBuildConditionFlowStillReportsMacro;
    [Test]
    [Category('RefactoringLightProjectContext,Fast')]
    [TestCase('Package list', 'DCC_UsePackage')]
    [TestCase('Package enable', 'UsePackages')]
    [TestCase('DCC package enable', 'DCC_EnabledPackages')]
    [TestCase('Package override', '_UsePackage')]
    [TestCase('Raw switches', 'DCC_AdditionalSwitches')]
    procedure UnresolvedLinkPropertyReportsMacro(const aProperty: string);
    [Test]
    [Category('RefactoringLightProjectContext,Fast')]
    [TestCase('Package list', 'DCC_UsePackage')]
    [TestCase('Package enable', 'UsePackages')]
    [TestCase('DCC package enable', 'DCC_EnabledPackages')]
    [TestCase('Package override', '_UsePackage')]
    [TestCase('Raw switches', 'DCC_AdditionalSwitches')]
    procedure UnresolvedLinkConditionReportsMacro(const aProperty: string);
    [Test]
    [Category('RefactoringLightProjectContext,Fast')]
    [TestCase('Package list', 'DCC_UsePackage')]
    [TestCase('Package enable', 'UsePackages')]
    [TestCase('DCC package enable', 'DCC_EnabledPackages')]
    [TestCase('Package override', '_UsePackage')]
    [TestCase('Raw switches', 'DCC_AdditionalSwitches')]
    procedure LinkPropertyChangesContextIdentity(const aProperty: string);
    [Test]
    [Category('RefactoringLightProjectContext,Fast')]
    [TestCase('Package list', 'DCC_UsePackage')]
    [TestCase('Package enable', 'UsePackages')]
    [TestCase('DCC package enable', 'DCC_EnabledPackages')]
    [TestCase('Package override', '_UsePackage')]
    [TestCase('Raw switches', 'DCC_AdditionalSwitches')]
    procedure FirstSelfReferenceUsesEmptyLinkDefault(const aProperty: string);
  end;

implementation

uses
  System.Classes, System.Hash, System.IOUtils, System.Rtti, System.SysUtils,
  DelphiSemantics.Cache, DelphiSemantics.CompilerProfile, DelphiSemantics.ProjectSession,
  DelphiSemantics.Query, DelphiSemantics.Refactor.Binding, DelphiSemantics.Refactor.Plan,
  DelphiSemantics.SemanticGraph, DelphiSemantics.Snapshot, DelphiSemantics.Snapshot.ContextEvidence,
  DelphiSemantics.Source, Test.Support;

const
  // Increasing precedence for these fixtures: project properties precede the
  // explicit import, and the witness profile file is evaluated after both.
  cMatrixSources: array[0..5] of string = ('registry', 'environment', 'native',
    'project', 'import', 'profile');
  cMatrixNames: array[0..1] of string = ('BDSUSERDIR', 'BDSCOMMONDIR');
  cMatrixSuffixes: array[0..1] of string = ('\MatrixUserSentinel', '\MatrixCommonSentinel');
  cMatrixStates: array[0..3] of string = ('literal', 'macro', 'empty', 'absent');
  cMatrixSourceLabels: array[0..5] of string = ('BDS registry', 'environment',
    'native option', 'project property', 'project property', 'project property');
  cMatrixSingleCount = 6 * 4 * 4 * 2;
  cMatrixCrossCount = 15 * 2 * 2 * 2;

type
  TProfileMatrixScenario = record
    States: array[0..5, 0..1] of Integer;
    FolderFailure: Boolean;
  end;

  TProfileMatrixExpected = record
    Present: Boolean;
    Value: string;
    Source: string;
  end;

function ProfileMatrixScenario(const aCaseId: Integer): TProfileMatrixScenario;
var
  lSource, lDirectory, lHigher, lLower, lPair, lCross: Integer;
begin
  Result := Default(TProfileMatrixScenario);
  for lSource := 0 to 5 do
    for lDirectory := 0 to 1 do
      Result.States[lSource, lDirectory] := 3;
  Result.FolderFailure := Odd(aCaseId);
  if aCaseId < cMatrixSingleCount then
  begin
    lSource := aCaseId div 32;
    Result.States[lSource, 0] := (aCaseId div 8) mod 4;
    Result.States[lSource, 1] := (aCaseId div 2) mod 4;
    Exit;
  end;
  lCross := aCaseId - cMatrixSingleCount;
  lDirectory := (lCross div 4) mod 2;
  // Keep the other directory explicit so it cannot mask target precedence.
  Result.States[2, 1 - lDirectory] := 0;
  lPair := 0;
  for lHigher := 1 to 5 do
    for lLower := 0 to lHigher - 1 do
    begin
      if lPair = lCross div 8 then
      begin
        Result.States[lLower, lDirectory] := 0;
        Result.States[lHigher, lDirectory] := 2 + (lCross div 2) mod 2;
        Exit;
      end;
      Inc(lPair);
    end;
  Assert.Fail('Invalid generated profile matrix case');
end;

function ProfileMatrixRawValue(const aState, aDirectory: Integer): string;
const
  cLiteral: array[0..1] of string = ('Z:\Matrix\LiteralUser', 'Z:\Matrix\LiteralCommon');
  cMacro: array[0..1] of string = ('$(MatrixRoot)\MacroUser', '$(MatrixRoot)\MacroCommon');
begin
  case aState of
    0: Result := cLiteral[aDirectory];
    1: Result := cMacro[aDirectory];
  else
    Result := '';
  end;
end;

function ProfileMatrixProperties(const aScenario: TProfileMatrixScenario;
  const aSource: Integer): TArray<TDelphiSemanticProperty>;
var
  lDirectory, lIndex: Integer;
begin
  Result := nil;
  for lDirectory := 0 to 1 do
    if aScenario.States[aSource, lDirectory] <> 3 then
    begin
      lIndex := Length(Result);
      SetLength(Result, lIndex + 1);
      Result[lIndex].Name := cMatrixNames[lDirectory];
      Result[lIndex].Value := ProfileMatrixRawValue(aScenario.States[aSource, lDirectory], lDirectory);
    end;
end;

function ProfileMatrixXml(const aScenario: TProfileMatrixScenario;
  const aSource: Integer): string;
var
  lProperty: TDelphiSemanticProperty;
begin
  Result := '<Project><PropertyGroup>';
  for lProperty in ProfileMatrixProperties(aScenario, aSource) do
    Result := Result + '<' + lProperty.Name + '>' + lProperty.Value + '</' + lProperty.Name + '>';
  Result := Result + '</PropertyGroup></Project>';
end;

function ProfileMatrixOptions(const aScenario: TProfileMatrixScenario): TDelphiSemanticOptions;
var
  lInputs: TIsolatedProfileInputs;
  lRoot, lProjectXml: string;
  lValues: TArray<TDelphiSemanticProperty>;
begin
  Result := Default(TDelphiSemanticOptions);
  lRoot := CreateTestTempRoot('profile-matrix-temp');
  Result.ProjectPath := TPath.Combine(lRoot, 'Matrix.dproj');
  Result.EnvOptionsPath := TPath.Combine(lRoot, 'Profile.proj');
  Result.Platform := 'Win64';
  Result.DelphiVersion := '23.0';
  lInputs := TIsolatedProfileInputs.Create;
  Result.ProfileInputs := lInputs;
  lInputs.Documents := 'Z:\DocumentsUser';
  lInputs.PublicDocuments := 'Z:\DocumentsCommon';
  lInputs.FailKnownFolder := aScenario.FolderFailure;
  lInputs.RegistryEnvironment := ProfileMatrixProperties(aScenario, 0);
  lInputs.Environment := ProfileMatrixProperties(aScenario, 1);
  SetLength(lInputs.RegistryLibrary, 2);
  lInputs.RegistryLibrary[0].Name := 'Search Path';
  lInputs.RegistryLibrary[0].Value := '$(BDSUSERDIR)' + cMatrixSuffixes[0] +
    ';$(BDSCOMMONDIR)' + cMatrixSuffixes[1];
  lInputs.RegistryLibrary[1].Name := 'Browsing Path';
  SetLength(lValues, 1);
  lValues[0].Name := 'MatrixRoot';
  lValues[0].Value := 'Z:\Matrix';
  Result.EnvironmentVariables := lValues + ProfileMatrixProperties(aScenario, 2);
  lProjectXml := ProfileMatrixXml(aScenario, 3).Replace('</Project>',
    '<Import Project="Matrix.props"/></Project>');
  TFile.WriteAllText(Result.ProjectPath, lProjectXml, TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Matrix.props'), ProfileMatrixXml(aScenario, 4), TEncoding.UTF8);
  TFile.WriteAllText(Result.EnvOptionsPath, ProfileMatrixXml(aScenario, 5), TEncoding.UTF8);
end;

function ProfileMatrixExpected(const aScenario: TProfileMatrixScenario;
  const aDirectory: Integer): TProfileMatrixExpected;
const
  cDefaults: array[0..1] of string = ('Z:\DocumentsUser\Embarcadero\Studio\23.0',
    'Z:\DocumentsCommon\Embarcadero\Studio\23.0');
var
  lSource: Integer;
begin
  // Oracle: select the last present input, including empty. It never reads or
  // models the implementation's fallback error markers or clearing operations.
  Result := Default(TProfileMatrixExpected);
  for lSource := 5 downto 0 do
    if aScenario.States[lSource, aDirectory] <> 3 then
    begin
      Result.Present := True;
      Result.Value := ProfileMatrixRawValue(aScenario.States[lSource, aDirectory], aDirectory).
        Replace('$(MatrixRoot)', 'Z:\Matrix');
      Result.Source := cMatrixSourceLabels[lSource];
      Exit;
    end;
  Result.Present := not aScenario.FolderFailure;
  if Result.Present then
  begin
    Result.Value := cDefaults[aDirectory];
    Result.Source := 'derived default';
  end;
  // Missing properties expand to empty text, but remain unavailable inputs.
end;

procedure AssertProfileMatrixDirectory(const aScenario: TProfileMatrixScenario;
  const aResult: TDelphiSemanticContextResult; const aDirectory: Integer);
var
  lExpected: TProfileMatrixExpected;
  lPath: string;
  lSourceCount, lUnavailableCount, lPathCount: Integer;
  lDiagnostic: TDelphiSemanticDiagnostic;
begin
  lExpected := ProfileMatrixExpected(aScenario, aDirectory);
  lSourceCount := 0;
  lUnavailableCount := 0;
  lPathCount := 0;
  for lPath in aResult.Project.PropertyValue('DSWitnessProfilePaths').Split([';']) do
    if lPath.EndsWith(cMatrixSuffixes[aDirectory]) then
    begin
      Inc(lPathCount);
      Assert.AreEqual(lExpected.Value + cMatrixSuffixes[aDirectory], lPath,
        'Final effective value of ' + cMatrixNames[aDirectory]);
    end;
  Assert.AreEqual(1, lPathCount, 'Exactly one effective path for each directory');
  for lDiagnostic in aResult.Diagnostics do
  begin
    if (lDiagnostic.Code = 'PROFILE_DIRECTORY_SOURCE') and
      lDiagnostic.Message.StartsWith(cMatrixNames[aDirectory] + '=') then
    begin
      Inc(lSourceCount);
      Assert.AreEqual(cMatrixNames[aDirectory] + '=' + lExpected.Value +
        ' (' + lExpected.Source + ')', lDiagnostic.Message, 'Final source and effective value');
    end;
    if (lDiagnostic.Code = 'PROFILE_DIRECTORY_UNAVAILABLE') and
      lDiagnostic.Message.StartsWith(cMatrixNames[aDirectory] + ':') then
      Inc(lUnavailableCount);
  end;
  Assert.AreEqual<Integer>(Ord(lExpected.Present), lSourceCount, 'Final source diagnostic: ' + cMatrixNames[aDirectory]);
  Assert.AreEqual<Integer>(Ord(not lExpected.Present), lUnavailableCount,
    'Final unavailable diagnostic: ' + cMatrixNames[aDirectory]);
end;

function TProfileDirectoryMatrixAttribute.GetCaseInfoArray: TestCaseInfoArray;
var
  lIndex: Integer;
begin
  SetLength(Result, cMatrixSingleCount + cMatrixCrossCount);
  for lIndex := 0 to High(Result) do
  begin
    if lIndex < cMatrixSingleCount then
      Result[lIndex].Name := Format('Single.%s.User_%s.Common_%s.FolderFail_%s',
        [cMatrixSources[lIndex div 32], cMatrixStates[(lIndex div 8) mod 4],
         cMatrixStates[(lIndex div 2) mod 4], BoolToStr(Odd(lIndex), True)])
    else
      Result[lIndex].Name := Format('Cross.%d.FolderFail_%s',
        [lIndex - cMatrixSingleCount, BoolToStr(Odd(lIndex), True)]);
    Result[lIndex].Values := [TValue.From<Integer>(lIndex)];
  end;
end;

procedure TProjectContextTests.FinalProfileInputsMatchGeneratedOracle(const aCaseId: Integer);
var
  lScenario: TProfileMatrixScenario;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticContextResult;
  lUser, lCommon: TProfileMatrixExpected;
  lDiagnostic: TDelphiSemanticDiagnostic;
begin
  lScenario := ProfileMatrixScenario(aCaseId);
  lOptions := ProfileMatrixOptions(lScenario);
  lResult := TDelphiSemanticProject.Load(lOptions.ProjectPath, lOptions);
  Assert.IsTrue(lResult.Success);
  lUser := ProfileMatrixExpected(lScenario, 0);
  lCommon := ProfileMatrixExpected(lScenario, 1);
  Assert.AreEqual(BoolToStr(lUser.Present and lCommon.Present, True),
    lResult.Project.PropertyValue('DSWitnessProfileKnown'), 'Final witness state, case ' + IntToStr(aCaseId));
  AssertProfileMatrixDirectory(lScenario, lResult, 0);
  AssertProfileMatrixDirectory(lScenario, lResult, 1);
  for lDiagnostic in lResult.Diagnostics do
    Assert.IsTrue((lDiagnostic.Code = 'PROFILE_DIRECTORY_SOURCE') or
      (lDiagnostic.Code = 'PROFILE_DIRECTORY_UNAVAILABLE'), 'Unexpected diagnostic: ' + lDiagnostic.Code);
end;

// Frozen fingerprint serializer from base 641e4a3; compatibility oracle for DS770-S1.
procedure Base641e4a3AppendFingerprintItem(const aBuilder: TStringBuilder; const aName, aValue: string);
begin
  aBuilder.Append(aName);
  aBuilder.Append('=');
  aBuilder.AppendLine(aValue);
end;

function Base641e4a3CanonicalFingerprintText(const aValue: string): string;
begin
  Result := LowerCase(Trim(aValue));
end;

procedure Base641e4a3AppendFingerprintItems(const aBuilder: TStringBuilder; const aName: string;
  const aItems: TArray<string>; const aItemsArePaths: Boolean);
var
  lItem: string;
  lValue: string;
begin
  aBuilder.Append(aName);
  aBuilder.Append('=');
  for lItem in aItems do
  begin
    if aItemsArePaths then
      lValue := TDelphiSemanticCacheIdentityBuilder.CanonicalPath(lItem)
    else
      lValue := Base641e4a3CanonicalFingerprintText(lItem);
    if lValue <> '' then
    begin
      aBuilder.Append(lValue);
      aBuilder.Append('|');
    end;
  end;
  aBuilder.AppendLine;
end;

function Base641e4a3BuildContextFingerprint(const aProject: TDelphiSemanticProjectInfo;
  const aOptions: TDelphiSemanticOptions; const aRootAbsenceFingerprint: string): string;
var
  lBuilder: TStringBuilder;
  lContext: TDelphiSemanticCacheIdentityContext;
  lProjectIdentity: TDelphiSemanticProjectCacheIdentity;
  lPropertyName: string;
begin
  lContext := Default(TDelphiSemanticCacheIdentityContext);
  lContext.SchemaVersion := 'project-context-fingerprint-v3';
  lContext.ProjectPath := aProject.ProjectFileName;
  lContext.Configuration := aProject.Configuration;
  lContext.Platform := aProject.Platform;
  lContext.DelphiVersion := aOptions.DelphiVersion;
  lContext.Defines := aProject.Defines;
  lContext.SearchPaths := aProject.SourceLookupPaths;
  lContext.UnitScopes := aProject.UnitScopeNames;
  lContext.UnitAliases := aProject.UnitAliases;
  lProjectIdentity := TDelphiSemanticCacheIdentityBuilder.BuildProjectIdentity(lContext);

  lBuilder := TStringBuilder.Create;
  try
    Base641e4a3AppendFingerprintItem(lBuilder, 'projectIdentity', lProjectIdentity.ProjectKey);
    Base641e4a3AppendFingerprintItem(lBuilder, 'main',
      TDelphiSemanticCacheIdentityBuilder.CanonicalPath(aProject.MainSourceFileName));
    Base641e4a3AppendFingerprintItem(lBuilder, 'rsvars',
      TDelphiSemanticCacheIdentityBuilder.CanonicalPath(aOptions.RsVarsPath));
    Base641e4a3AppendFingerprintItem(lBuilder, 'envoptions',
      TDelphiSemanticCacheIdentityBuilder.CanonicalPath(aOptions.EnvOptionsPath));
    Base641e4a3AppendFingerprintItem(lBuilder, 'compilerProfile',
      Base641e4a3CanonicalFingerprintText(aProject.CompilerProfileName));
    if aOptions.ImplicitRootMemberAbsence <> nil then
      Base641e4a3AppendFingerprintItem(lBuilder, 'implicitRootMemberAbsence',
        aRootAbsenceFingerprint);
    Base641e4a3AppendFingerprintItems(lBuilder, 'includePaths', aProject.IncludePaths, True);
    Base641e4a3AppendFingerprintItems(lBuilder, 'references', aProject.ReferenceDirectories, True);
    Base641e4a3AppendFingerprintItems(lBuilder, 'sourceFiles', aProject.SourceFileNames, True);
    // Hash raw switch values without case folding or delimiter ambiguity.
    for lPropertyName in cDelphiSemanticCompilerLinkPropertyNames do
      Base641e4a3AppendFingerprintItem(lBuilder, lPropertyName,
        THashSHA2.GetHashString(aProject.PropertyValue(lPropertyName)));
    Result := THashSHA2.GetHashString(lBuilder.ToString);
  finally
    lBuilder.Free;
  end;
end;

procedure TProjectContextTests.ExplicitProfileIdentityMatchesBase641e4a3(const aOrigin: string);
var
  lFileName, lProperties: string;
  lInputs: TIsolatedProfileInputs;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticContextResult;
  lBaseProject: TDelphiSemanticProjectInfo;
  lGraph, lBaseGraph: TDelphiSemanticSemanticGraph;
  lValues: TArray<TDelphiSemanticProperty>;
begin
  lFileName := TPath.Combine(CreateTestTempRoot('profile-identity-temp'), 'P.dproj');
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win64';
  lOptions.DelphiVersion := '23.0';
  lInputs := TIsolatedProfileInputs.Create;
  lOptions.ProfileInputs := lInputs;
  lInputs.FailKnownFolder := True;
  SetLength(lValues, 2);
  lValues[0].Name := 'BDSUSERDIR';
  lValues[0].Value := 'Z:\ExplicitUser';
  lValues[1].Name := 'BDSCOMMONDIR';
  lValues[1].Value := 'Z:\ExplicitCommon';
  lProperties := '';
  if aOrigin = 'native' then
    lOptions.EnvironmentVariables := lValues
  else if aOrigin = 'environment' then
    lInputs.Environment := lValues
  else if aOrigin = 'registry' then
    lInputs.RegistryEnvironment := lValues
  else
    lProperties := '<BDSUSERDIR>Z:\ExplicitUser</BDSUSERDIR>' +
      '<BDSCOMMONDIR>Z:\ExplicitCommon</BDSCOMMONDIR>';
  WriteUtf8Bytes(lFileName, '<Project><PropertyGroup>' + lProperties +
    '</PropertyGroup></Project>');
  lResult := TDelphiSemanticProject.Load(lFileName, lOptions);
  Assert.IsTrue(lResult.Success);
  lBaseProject := lResult.Project;
  lBaseProject.ContextFingerprint := Base641e4a3BuildContextFingerprint(lBaseProject, lOptions, '');
  Assert.AreEqual(lBaseProject.ContextFingerprint, lResult.Project.ContextFingerprint,
    'Explicit profiles preserve the byte contract at base 641e4a3.');
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(lResult.Project, nil);
  try
    lBaseGraph := TDelphiSemanticSemanticGraphBuilder.Build(lBaseProject, nil);
    try
      Assert.AreEqual(lBaseGraph.ProjectId.Value, lGraph.ProjectId.Value);
    finally
      lBaseGraph.Free;
    end;
  finally
    lGraph.Free;
  end;
end;

procedure TProjectContextTests.EmptyProfileDirectoryKeepsPrecedence(
  const aOrigin: string; const aPresent: Boolean);
var
  lFileName, lProperties, lExpected, lSource, lName: string;
  lInputs: TIsolatedProfileInputs;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticContextResult;
  lEmpty, lLower: TArray<TDelphiSemanticProperty>;
begin
  lFileName := TPath.Combine(CreateTestTempRoot('profile-empty-temp'), 'P.dproj');
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.DelphiVersion := '23.0';
  lInputs := TIsolatedProfileInputs.Create;
  lOptions.ProfileInputs := lInputs;
  lInputs.Documents := 'Z:\Documents';
  lInputs.PublicDocuments := lInputs.Documents;
  SetLength(lLower, 2);
  lLower[0].Name := 'BDSUSERDIR';
  lLower[0].Value := 'Z:\Lower';
  lLower[1].Name := 'BDSCOMMONDIR';
  lLower[1].Value := lLower[0].Value;
  if aPresent then
  begin
    lEmpty := Copy(lLower);
    lEmpty[0].Value := '';
    lEmpty[1].Value := '';
  end;
  lProperties := '';
  lExpected := 'Z:\Lower';
  if aOrigin = 'registry' then
  begin
    lInputs.RegistryEnvironment := lEmpty;
    lExpected := 'Z:\Documents\Embarcadero\Studio\23.0';
    lSource := 'derived default';
  end else if aOrigin = 'environment' then
  begin
    lInputs.RegistryEnvironment := lLower;
    lInputs.Environment := lEmpty;
    lSource := 'BDS registry';
  end else if aOrigin = 'native' then
  begin
    lInputs.Environment := lLower;
    lOptions.EnvironmentVariables := lEmpty;
    lSource := 'environment';
  end else begin
    lOptions.EnvironmentVariables := lLower;
    lSource := 'native option';
    if aPresent then
      lProperties := '<BDSUSERDIR></BDSUSERDIR><BDSCOMMONDIR></BDSCOMMONDIR>';
  end;
  if aPresent then
  begin
    lExpected := '';
    if aOrigin = 'registry' then
      lSource := 'BDS registry'
    else if aOrigin = 'native' then
      lSource := 'native option'
    else if aOrigin = 'project' then
      lSource := 'project property'
    else
      lSource := 'environment';
  end;
  WriteUtf8Bytes(lFileName, '<Project><PropertyGroup>' + lProperties +
    '</PropertyGroup></Project>');
  lResult := TDelphiSemanticProject.Load(lFileName, lOptions);
  Assert.IsTrue(lResult.Success);
  for lName in ['BDSUSERDIR', 'BDSCOMMONDIR'] do
  begin
    Assert.AreEqual(lExpected, lResult.Project.PropertyValue(lName), lName);
    Assert.AreEqual(lSource, lResult.Project.PropertyValue(lName + 'Source'), lName);
  end;
end;

procedure TProjectContextTests.ProjectOverridesDiscardObsoleteFolderErrors(const aOverride: string);
var
  lFileName, lProperties: string;
  lInputs: TIsolatedProfileInputs;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticContextResult;
begin
  lFileName := TPath.Combine(CreateTestTempRoot('profile-override-temp'), 'P.dproj');
  lOptions := Default(TDelphiSemanticOptions);
  lInputs := TIsolatedProfileInputs.Create;
  lOptions.ProfileInputs := lInputs;
  lInputs.FailKnownFolder := True;
  SetLength(lInputs.RegistryLibrary, 2);
  lInputs.RegistryLibrary[0].Name := 'Search Path';
  lInputs.RegistryLibrary[1].Name := 'Browsing Path';
  lProperties := '<BDSUSERDIR>Z:\ProjectUser</BDSUSERDIR>';
  if aOverride = 'both' then
    lProperties := lProperties + '<BDSCOMMONDIR>Z:\ProjectCommon</BDSCOMMONDIR>'
  else if aOverride = 'empty' then
    lProperties := '<BDSUSERDIR></BDSUSERDIR><BDSCOMMONDIR></BDSCOMMONDIR>';
  WriteUtf8Bytes(lFileName, '<Project><PropertyGroup>' + lProperties +
    '</PropertyGroup></Project>');
  lResult := TDelphiSemanticProject.Load(lFileName, lOptions);
  Assert.IsTrue(lResult.Success);
  if aOverride = 'one' then
  begin
    Assert.AreEqual('False', lResult.Project.PropertyValue('DSWitnessProfileKnown'));
    Assert.IsTrue(HasDiagnostic(lResult, 'PROFILE_DIRECTORY_UNAVAILABLE'));
  end else begin
    Assert.AreEqual('True', lResult.Project.PropertyValue('DSWitnessProfileKnown'),
      lResult.Project.PropertyValue('DSWitnessProfileError'));
    Assert.IsFalse(HasDiagnostic(lResult, 'PROFILE_DIRECTORY_UNAVAILABLE'), DiagnosticSummary(lResult));
    Assert.AreEqual('', lResult.Project.PropertyValue('DSWitnessProfileError'));
  end;
end;

procedure TProjectContextTests.UnavailableProfileFolderFailsClosed;
var
  lFileName: string;
  lInputs: TIsolatedProfileInputs;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticContextResult;
begin
  lFileName := TPath.Combine(CreateTestTempRoot('profile-failure-temp'), 'P.dproj');
  WriteUtf8Bytes(lFileName, '<Project />');
  lOptions := Default(TDelphiSemanticOptions);
  lInputs := TIsolatedProfileInputs.Create;
  lOptions.ProfileInputs := lInputs;
  lInputs.FailKnownFolder := True;
  try
    lResult := TDelphiSemanticProject.Load(lFileName, lOptions);
  except
    on E: Exception do
      Assert.Fail('Expected an unproved profile diagnostic, got exception: ' + E.Message);
  end;
  Assert.IsTrue(lResult.Success);
  Assert.AreEqual('False', lResult.Project.PropertyValue('DSWitnessProfileKnown'));
  Assert.IsTrue(lResult.Project.PropertyValue('DSWitnessProfileError').Contains('known folder unavailable'));
  Assert.IsTrue(HasDiagnostic(lResult, 'PROFILE_DIRECTORY_UNAVAILABLE'), DiagnosticSummary(lResult));
end;

procedure TProjectContextTests.ProfileDirectoriesRespectInputPrecedence(
  const aOrigin, aVersion: string);
var
  lRoot, lFileName, lExpectedUser, lExpectedCommon, lProperties, lSource: string;
  lInputs: TIsolatedProfileInputs;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticContextResult;
  lValues: TArray<TDelphiSemanticProperty>;
begin
  lFileName := TPath.Combine(CreateTestTempRoot('profile-directories-temp'), 'ProfileDirectories.dproj');
  lRoot := TPath.GetDirectoryName(lFileName);
  lInputs := TIsolatedProfileInputs.Create;
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProfileInputs := lInputs;
  lOptions.DelphiVersion := aVersion;
  lOptions.Platform := 'Win64';
  lInputs.Documents := TPath.Combine(lRoot, 'User Documents');
  lInputs.PublicDocuments := TPath.Combine(lRoot, 'Public Documents');
  lExpectedUser := TPath.Combine(lInputs.Documents, 'Embarcadero\Studio\' + aVersion);
  lExpectedCommon := TPath.Combine(lInputs.PublicDocuments, 'Embarcadero\Studio\' + aVersion);
  lSource := 'derived default';
  SetLength(lInputs.RegistryLibrary, 2);
  lInputs.RegistryLibrary[0].Name := 'Search Path';
  lInputs.RegistryLibrary[0].Value := '$(BDSUSERDIR)\Imports;$(BDSCOMMONDIR)\Dcp';
  lInputs.RegistryLibrary[1].Name := 'Browsing Path';
  SetLength(lValues, 2);
  lValues[0].Name := 'BDSUSERDIR';
  lValues[0].Value := TPath.Combine(lRoot, 'ExplicitUser');
  lValues[1].Name := 'BDSCOMMONDIR';
  lValues[1].Value := TPath.Combine(lRoot, 'ExplicitCommon');
  lProperties := '';
  if aOrigin <> 'derived' then
  begin
    lExpectedUser := lValues[0].Value;
    lExpectedCommon := lValues[1].Value;
    if aOrigin = 'registry' then
    begin
      lInputs.RegistryEnvironment := Copy(lValues);
      lSource := 'BDS registry';
    end else if aOrigin = 'environment' then
    begin
      lInputs.RegistryEnvironment := Copy(lValues);
      lInputs.RegistryEnvironment[0].Value := 'Z:\LosingRegistryUser';
      lInputs.RegistryEnvironment[1].Value := 'Z:\LosingRegistryCommon';
      lInputs.Environment := Copy(lValues);
      lSource := 'environment';
    end else begin
      lInputs.Environment := Copy(lValues);
      lInputs.Environment[0].Value := 'Z:\LosingEnvironmentUser';
      lInputs.Environment[1].Value := 'Z:\LosingEnvironmentCommon';
      lOptions.EnvironmentVariables := Copy(lValues);
      lSource := 'native option';
      if aOrigin = 'project' then
      begin
        lOptions.EnvironmentVariables[0].Value := 'Z:\LosingNativeUser';
        lOptions.EnvironmentVariables[1].Value := 'Z:\LosingNativeCommon';
        lProperties := '<BDSUSERDIR>' + lExpectedUser + '</BDSUSERDIR><BDSCOMMONDIR>' +
          lExpectedCommon + '</BDSCOMMONDIR>';
        lSource := 'project property';
      end;
    end;
  end;
  WriteUtf8Bytes(lFileName, '<Project><PropertyGroup>' + lProperties +
    '<DCC_UnitSearchPath>$(BDSUSERDIR)\Project;$(BDSCOMMONDIR)\Project</DCC_UnitSearchPath>' +
    '</PropertyGroup></Project>');
  lResult := TDelphiSemanticProject.Load(lFileName, lOptions);
  Assert.IsTrue(lResult.Success, DiagnosticSummary(lResult));
  Assert.AreEqual(lExpectedUser, lResult.Project.PropertyValue('BDSUSERDIR'));
  Assert.AreEqual(lExpectedCommon, lResult.Project.PropertyValue('BDSCOMMONDIR'));
  Assert.AreEqual('True', lResult.Project.PropertyValue('DSWitnessProfileKnown'),
    lResult.Project.PropertyValue('DSWitnessProfileError'));
  Assert.IsTrue(lResult.Project.PropertyValue('DSWitnessProfilePaths').Contains(lExpectedUser + '\Imports'));
  Assert.IsTrue(lResult.Project.PropertyValue('DSWitnessProfilePaths').Contains(lExpectedCommon + '\Dcp'));
  Assert.AreEqual(lSource, lResult.Project.PropertyValue('BDSUSERDIRSource'));
  Assert.AreEqual(lSource, lResult.Project.PropertyValue('BDSCOMMONDIRSource'));
  Assert.IsTrue(DiagnosticSummary(lResult).Contains(lSource), DiagnosticSummary(lResult));
  Assert.IsTrue(ContainsPath(lResult.Project.SearchPaths, lExpectedUser + '\Project'));
end;

procedure TProjectContextTests.UnresolvedLinkPropertyReportsMacro(const aProperty: string);
var
  lDprojFileName: string;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticContextResult;
begin
  lDprojFileName := ContextEvidenceTempPath('UnknownLink.dproj');
  WriteUtf8Bytes(lDprojFileName,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><' + aProperty + '>$(MissingLinkSetting)</' + aProperty +
    '></PropertyGroup></Project>');
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := lDprojFileName;
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win64';
  lResult := TDelphiSemanticProject.Load(lDprojFileName, lOptions);
  Assert.IsTrue(lResult.Success);
  Assert.IsTrue(HasDiagnostic(lResult, 'UNRESOLVED_MSBUILD_MACRO'),
    'Unknown compiler linking inputs must remain diagnosable: ' + aProperty);
end;

procedure TProjectContextTests.UnresolvedLinkConditionReportsMacro(const aProperty: string);
var
  lDprojFileName: string;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticContextResult;
begin
  lDprojFileName := ContextEvidenceTempPath('UnknownLinkCondition.dproj');
  WriteUtf8Bytes(lDprojFileName,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup Condition="''$(MissingLinkCondition)''==''enabled''">' +
    '<' + aProperty + '>true</' + aProperty + '></PropertyGroup></Project>');
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := lDprojFileName;
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win64';
  lResult := TDelphiSemanticProject.Load(lDprojFileName, lOptions);
  Assert.IsTrue(lResult.Success);
  Assert.IsTrue(HasDiagnostic(lResult, 'UNRESOLVED_MSBUILD_MACRO'),
    'Unknown conditions on linking inputs must remain diagnosable: ' + aProperty);
end;

procedure TProjectContextTests.LinkPropertyChangesContextIdentity(const aProperty: string);
var
  lDprojFileName: string;
  lOptions: TDelphiSemanticOptions;
  lBefore, lAfter: TDelphiSemanticContextResult;
  lFirstValue, lSecondValue: string;
begin
  lDprojFileName := ContextEvidenceTempPath('LinkIdentity.dproj');
  lFirstValue := 'true';
  lSecondValue := 'false';
  if aProperty = 'DCC_AdditionalSwitches' then
  begin
    lFirstValue := '-DFIRST';
    lSecondValue := '-DSECOND';
  end;
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := lDprojFileName;
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win64';
  WriteUtf8Bytes(lDprojFileName,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><' + aProperty + '>' + lFirstValue + '</' + aProperty +
    '></PropertyGroup></Project>');
  lBefore := TDelphiSemanticProject.Load(lDprojFileName, lOptions);
  WriteUtf8Bytes(lDprojFileName,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><' + aProperty + '>' + lSecondValue + '</' + aProperty +
    '></PropertyGroup></Project>');
  lAfter := TDelphiSemanticProject.Load(lDprojFileName, lOptions);
  Assert.IsTrue(lBefore.Success and lAfter.Success);
  Assert.AreEqual(lFirstValue, lBefore.Project.PropertyValue(aProperty));
  Assert.AreEqual(lSecondValue, lAfter.Project.PropertyValue(aProperty));
  Assert.AreNotEqual(lBefore.Project.ContextFingerprint, lAfter.Project.ContextFingerprint,
    'Effective compiler linking settings must distinguish semantic context: ' + aProperty);
end;

procedure TProjectContextTests.FirstSelfReferenceUsesEmptyLinkDefault(const aProperty: string);
var
  lDprojFileName: string;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticContextResult;
  lValue: string;
begin
  lDprojFileName := ContextEvidenceTempPath('SelfLink.dproj');
  lValue := 'true';
  if aProperty = 'DCC_AdditionalSwitches' then
    lValue := '-DFIRST';
  WriteUtf8Bytes(lDprojFileName,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><' + aProperty + '>' + lValue + '$(' + aProperty + ')</' +
    aProperty + '></PropertyGroup></Project>');
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := lDprojFileName;
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win64';
  lResult := TDelphiSemanticProject.Load(lDprojFileName, lOptions);
  Assert.IsTrue(lResult.Success);
  Assert.AreEqual(lValue, lResult.Project.PropertyValue(aProperty));
  Assert.IsFalse(HasDiagnostic(lResult, 'UNRESOLVED_MSBUILD_MACRO'),
    'An unset optional compiler property is empty in native MSBuild: ' + aProperty);
end;

function TProjectContextTests.ContextEvidenceTempPath(const aName: string): string;
begin
  Result := TPath.Combine(CreateTestTempRoot('context-evidence-temp'), aName);
end;

function TProjectContextTests.HasDiagnostic(const aResult: TDelphiSemanticContextResult;
  const aCode: string): Boolean;
var
  lDiagnostic: TDelphiSemanticDiagnostic;
begin
  for lDiagnostic in aResult.Diagnostics do
    if SameText(lDiagnostic.Code, aCode) then
      Exit(True);

  Result := False;
end;

function TProjectContextTests.DiagnosticSummary(
  const aResult: TDelphiSemanticContextResult): string;
var
  lDiagnostic: TDelphiSemanticDiagnostic;
begin
  Result := '';
  for lDiagnostic in aResult.Diagnostics do
  begin
    if Result <> '' then
      Result := Result + sLineBreak;
    Result := Result + lDiagnostic.Code + ' [' + lDiagnostic.FileName + '] ' +
      lDiagnostic.Message;
  end;
end;

function TProjectContextTests.FindContextEvidenceInput(
  const aObservations: IDelphiSemanticProjectContextObservations;
  const aFileName: string; out aObservation: TDelphiSemanticProjectContextObservation): Boolean;
var
  i: Integer;
  lCanonicalFileName: string;
  lObservation: TDelphiSemanticProjectContextObservation;
begin
  aObservation := Default(TDelphiSemanticProjectContextObservation);
  lCanonicalFileName := TPath.GetFullPath(aFileName);
  for i := 0 to aObservations.Count - 1 do
  begin
    lObservation := aObservations.Items[i];
    if (lObservation.Kind = TDelphiSemanticProjectContextObservationKind.pckoInput) and
      SameText(TPath.GetFullPath(lObservation.FileName), lCanonicalFileName) then
    begin
      aObservation := lObservation;
      Exit(True);
    end;
  end;

  Result := False;
end;

procedure TProjectContextTests.WriteUtf8Bytes(const aFileName, aText: string);
begin
  TDirectory.CreateDirectory(ExtractFilePath(aFileName));
  TFile.WriteAllBytes(aFileName, TEncoding.UTF8.GetBytes(aText));
end;

function TProjectContextTests.ContainsPath(const aItems: TArray<string>;
  const aExpectedPath: string): Boolean;
var
  lExpectedPath: string;
  lItem: string;
begin
  lExpectedPath := ExcludeTrailingPathDelimiter(TPath.GetFullPath(aExpectedPath));
  for lItem in aItems do
    if SameText(ExcludeTrailingPathDelimiter(TPath.GetFullPath(lItem)), lExpectedPath) then
      Exit(True);

  Result := False;
end;


procedure TProjectContextTests.DprojResolvesBasicMetadata;
var
  lResult: TDelphiSemanticContextResult;
begin
  lResult := TDelphiSemanticProject.Load(FixturePath('ProjectContext\Basic\BasicProject.dproj'));

  Assert.IsTrue(lResult.Success);
  Assert.AreEqual('BasicProject', lResult.Project.ProjectName);
  Assert.AreEqual('Release', lResult.Project.Configuration);
  Assert.AreEqual('Win64', lResult.Project.Platform);
  Assert.AreEqual(FixturePath('ProjectContext\Basic\BasicProject.dproj'), lResult.Project.ProjectFileName);
  Assert.AreEqual(FixturePath('ProjectContext\Basic\BasicProject.dpr'), lResult.Project.MainSourceFileName);
end;

procedure TProjectContextTests.StaleDccReferenceResolvesThroughSearchPath;
var
  lProjectDir: string;
  lResult: TDelphiSemanticContextResult;
begin
  lProjectDir := FixturePath('ProjectContext\DccReferenceFallback');
  lResult := TDelphiSemanticProject.Load(TPath.Combine(lProjectDir,
    'DccReferenceFallbackProject.dproj'));

  Assert.IsTrue(lResult.Success);
  Assert.IsTrue(ContainsPath(lResult.Project.ReferenceDirectories,
    TPath.Combine(lProjectDir, 'RealLib')), 'Expected fallback unit directory from search path.');
  Assert.IsFalse(ContainsPath(lResult.Project.ReferenceDirectories,
    TPath.Combine(lProjectDir, 'OldLocation')), 'Stale DCCReference directory must not be retained.');
end;

procedure TProjectContextTests.DprResolvesThroughSiblingDproj;
var
  lResult: TDelphiSemanticContextResult;
begin
  lResult := TDelphiSemanticProject.Load(FixturePath('ProjectContext\Basic\BasicProject.dpr'));

  Assert.IsTrue(lResult.Success);
  Assert.AreEqual(FixturePath('ProjectContext\Basic\BasicProject.dproj'), lResult.Project.ProjectFileName);
  Assert.AreEqual(FixturePath('ProjectContext\Basic\BasicProject.dpr'), lResult.Project.MainSourceFileName);
end;

procedure TProjectContextTests.MissingProjectReturnsDeterministicDiagnostic;
var
  lResult: TDelphiSemanticContextResult;
begin
  lResult := TDelphiSemanticProject.Load(FixturePath('ProjectContext\Missing\MissingProject.dproj'));

  Assert.IsFalse(lResult.Success);
  Assert.AreEqual(1, Integer(Length(lResult.Diagnostics)));
  Assert.AreEqual('PROJECT_FILE_NOT_FOUND', lResult.Diagnostics[0].Code);
end;

procedure TProjectContextTests.ProjectAndOptionBytesAndConfigurationAreObserved;
var
  lContextChanged: TDelphiSemanticContextResult;
  lContextDebug: TDelphiSemanticContextResult;
  lContextPlatformChanged: TDelphiSemanticContextResult;
  lDprojFileName: string;
  lDprojObservation: TDelphiSemanticProjectContextObservation;
  lDprojText: string;
  lOptionFileName: string;
  lOptionObservation: TDelphiSemanticProjectContextObservation;
  lOptionText: string;
  lOptions: TDelphiSemanticOptions;
  lRoot: string;
  lInitialFingerprint: string;
  lAfterOptionChangeFingerprint: string;
  lAfterProjectChangeFingerprint: string;
begin
  lDprojFileName := ContextEvidenceTempPath('ObservedProject.dproj');
  lRoot := ExtractFilePath(lDprojFileName);
  lOptionFileName := TPath.Combine(lRoot, 'Observed.optset');
  lDprojText := '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>ObservedProject.dpr</MainSource></PropertyGroup>' +
    '<Import Project="Observed.optset"/></Project>';
  lOptionText := '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><DCC_Define>OPTION_ONE</DCC_Define></PropertyGroup></Project>';
  WriteUtf8Bytes(lDprojFileName, lDprojText);
  WriteUtf8Bytes(lOptionFileName, lOptionText);

  lOptions := Default(TDelphiSemanticOptions);
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win64';
  lOptions.DelphiVersion := '37.0';
  lOptions.EnvironmentVariables := [];
  lOptions.ProjectPath := lDprojFileName;
  lContextDebug := TDelphiSemanticProject.Load(lDprojFileName, lOptions);
  Assert.IsTrue(lContextDebug.Success);
  Assert.IsNotNull(lContextDebug.Project.ContextObservations);
  Assert.IsTrue(FindContextEvidenceInput(lContextDebug.Project.ContextObservations,
    lDprojFileName, lDprojObservation));
  Assert.AreEqual(THashSHA2.GetHashStringFromFile(lDprojFileName), lDprojObservation.ContentHash);
  Assert.IsTrue(FindContextEvidenceInput(lContextDebug.Project.ContextObservations,
    lOptionFileName, lOptionObservation));
  Assert.AreEqual(THashSHA2.GetHashStringFromFile(lOptionFileName), lOptionObservation.ContentHash);
  lInitialFingerprint := lContextDebug.Project.ContextObservations.EvidenceFingerprint;
  Assert.AreNotEqual('', lContextDebug.Project.ContextObservations.ConfigurationIdentity);

  lOptionText := lOptionText.Replace('OPTION_ONE', 'OPTION_TWO');
  WriteUtf8Bytes(lOptionFileName, lOptionText);
  lContextChanged := TDelphiSemanticProject.Load(lDprojFileName, lOptions);
  Assert.IsTrue(lContextChanged.Success);
  lAfterOptionChangeFingerprint := lContextChanged.Project.ContextObservations.EvidenceFingerprint;
  Assert.AreNotEqual(lInitialFingerprint, lAfterOptionChangeFingerprint,
    'Changing imported option bytes must change the co-produced observation identity.');

  WriteUtf8Bytes(lDprojFileName, lDprojText.Replace('</Project>',
    '<!-- byte-only project edit --></Project>'));
  lContextChanged := TDelphiSemanticProject.Load(lDprojFileName, lOptions);
  Assert.IsTrue(lContextChanged.Success);
  lAfterProjectChangeFingerprint := lContextChanged.Project.ContextObservations.EvidenceFingerprint;
  Assert.AreNotEqual(lAfterOptionChangeFingerprint, lAfterProjectChangeFingerprint,
    'A raw project-file change must be retained even when evaluated properties are unchanged.');
  Assert.AreEqual(lContextDebug.Project.ContextObservations.ConfigurationIdentity,
    lContextChanged.Project.ContextObservations.ConfigurationIdentity);

  lOptions.Platform := 'Win32';
  lContextPlatformChanged := TDelphiSemanticProject.Load(lDprojFileName, lOptions);
  Assert.IsTrue(lContextPlatformChanged.Success);
  Assert.AreNotEqual(lContextChanged.Project.ContextObservations.ConfigurationIdentity,
    lContextPlatformChanged.Project.ContextObservations.ConfigurationIdentity,
    'The selected platform must be part of configuration identity.');
end;

procedure TProjectContextTests.AppearingHigherPriorityCandidateChangesSearchEvidence;
var
  i: Integer;
  lCandidate: TDelphiSemanticProjectContextObservation;
  lDprojFileName: string;
  lFallbackFileName: string;
  lHigherFileName: string;
  lInitialFingerprint: string;
  lInitialResult: TDelphiSemanticContextResult;
  lOptions: TDelphiSemanticOptions;
  lRoot: string;
  lUpdatedResult: TDelphiSemanticContextResult;
  lHigherSelected: Boolean;
  lFallbackSelected: Boolean;
begin
  lDprojFileName := ContextEvidenceTempPath('SearchProject.dproj');
  lRoot := ExtractFilePath(lDprojFileName);
  lHigherFileName := TPath.Combine(lRoot, 'Higher\Provider.pas');
  lFallbackFileName := TPath.Combine(lRoot, 'Fallback\Provider.pas');
  WriteUtf8Bytes(lFallbackFileName, 'unit Provider; interface implementation end.');
  WriteUtf8Bytes(lDprojFileName,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><DCC_UnitSearchPath>Higher;Fallback</DCC_UnitSearchPath></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="Provider.pas"/></ItemGroup></Project>');

  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := lDprojFileName;
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win64';
  lInitialResult := TDelphiSemanticProject.Load(lDprojFileName, lOptions);
  Assert.IsTrue(lInitialResult.Success);
  lInitialFingerprint := lInitialResult.Project.ContextObservations.EvidenceFingerprint;
  lHigherSelected := False;
  lFallbackSelected := False;
  for i := 0 to lInitialResult.Project.ContextObservations.Count - 1 do
  begin
    lCandidate := lInitialResult.Project.ContextObservations.Items[i];
    if (lCandidate.Kind = TDelphiSemanticProjectContextObservationKind.pckoSearchCandidate) and
      SameText(lCandidate.Role, 'dcc-reference-file') then
    begin
      if SameText(TPath.GetFullPath(lCandidate.FileName), TPath.GetFullPath(lHigherFileName)) then
        Assert.IsFalse(lCandidate.Exists, 'The higher-priority candidate starts absent.')
      else if SameText(TPath.GetFullPath(lCandidate.FileName),
        TPath.GetFullPath(lFallbackFileName)) then
      begin
        Assert.IsTrue(lCandidate.Exists);
        Assert.IsTrue(lCandidate.Selected);
        lFallbackSelected := True;
      end;
    end;
  end;
  Assert.IsTrue(lFallbackSelected, 'The existing fallback candidate must be selected.');

  WriteUtf8Bytes(lHigherFileName, 'unit Provider; interface implementation end.');
  lUpdatedResult := TDelphiSemanticProject.Load(lDprojFileName, lOptions);
  Assert.IsTrue(lUpdatedResult.Success);
  Assert.AreNotEqual(lInitialFingerprint,
    lUpdatedResult.Project.ContextObservations.EvidenceFingerprint,
    'A newly appearing earlier search candidate must change evidence.');
  for i := 0 to lUpdatedResult.Project.ContextObservations.Count - 1 do
  begin
    lCandidate := lUpdatedResult.Project.ContextObservations.Items[i];
    if (lCandidate.Kind = TDelphiSemanticProjectContextObservationKind.pckoSearchCandidate) and
      SameText(lCandidate.Role, 'dcc-reference-file') and
      SameText(TPath.GetFullPath(lCandidate.FileName), TPath.GetFullPath(lHigherFileName)) then
      lHigherSelected := lCandidate.Exists and lCandidate.Selected;
  end;
  Assert.IsTrue(lHigherSelected, 'The new higher-priority candidate must now be selected.');
end;

procedure TProjectContextTests.AppearingConditionPathChangesContextEvidence;
var
  i: Integer;
  lConditionPath: string;
  lDefine: string;
  lDprojFileName: string;
  lFeatureDefined: Boolean;
  lInitialFingerprint: string;
  lInitialResult: TDelphiSemanticContextResult;
  lObservation: TDelphiSemanticProjectContextObservation;
  lOptions: TDelphiSemanticOptions;
  lRoot: string;
  lUpdatedResult: TDelphiSemanticContextResult;
  lMissingConditionObserved: Boolean;
begin
  lDprojFileName := ContextEvidenceTempPath('ExistsProject.dproj');
  lRoot := ExtractFilePath(lDprojFileName);
  lConditionPath := TPath.Combine(lRoot, 'EnableFeature.flag');
  WriteUtf8Bytes(lDprojFileName,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><DCC_Define>BASE</DCC_Define></PropertyGroup>' +
    '<PropertyGroup Condition="Exists(''EnableFeature.flag'')">' +
    '<DCC_Define>$(DCC_Define);FEATURE</DCC_Define></PropertyGroup></Project>');
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := lDprojFileName;
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win64';
  lInitialResult := TDelphiSemanticProject.Load(lDprojFileName, lOptions);
  Assert.IsTrue(lInitialResult.Success);
  lInitialFingerprint := lInitialResult.Project.ContextObservations.EvidenceFingerprint;
  lMissingConditionObserved := False;
  for i := 0 to lInitialResult.Project.ContextObservations.Count - 1 do
  begin
    lObservation := lInitialResult.Project.ContextObservations.Items[i];
    if (lObservation.Kind = TDelphiSemanticProjectContextObservationKind.pckoPresence) and
      SameText(TPath.GetFullPath(lObservation.FileName), TPath.GetFullPath(lConditionPath)) then
    begin
      Assert.IsFalse(lObservation.Exists);
      lMissingConditionObserved := True;
    end;
  end;
  Assert.IsTrue(lMissingConditionObserved,
    'The absent path that controlled a project Condition must be recorded.');

  WriteUtf8Bytes(lConditionPath, 'present');
  lUpdatedResult := TDelphiSemanticProject.Load(lDprojFileName, lOptions);
  Assert.IsTrue(lUpdatedResult.Success);
  Assert.AreNotEqual(lInitialFingerprint,
    lUpdatedResult.Project.ContextObservations.EvidenceFingerprint);
  lFeatureDefined := False;
  for lDefine in lUpdatedResult.Project.Defines do
    if SameText(lDefine, 'FEATURE') then
      lFeatureDefined := True;
  Assert.IsTrue(lFeatureDefined);
end;

procedure TProjectContextTests.DuplicateImportedPathsReconcileDeterministically;
var
  i: Integer;
  lDprojFileName: string;
  lImportCount: Integer;
  lObservation: TDelphiSemanticProjectContextObservation;
  lOptionFileName: string;
  lOptions: TDelphiSemanticOptions;
  lSecondResult: TDelphiSemanticContextResult;
  lResult: TDelphiSemanticContextResult;
begin
  lDprojFileName := ContextEvidenceTempPath('DuplicateImportProject.dproj');
  lOptionFileName := TPath.Combine(ExtractFilePath(lDprojFileName), 'Common.optset');
  WriteUtf8Bytes(lOptionFileName,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><DCC_Define>COMMON</DCC_Define></PropertyGroup></Project>');
  WriteUtf8Bytes(lDprojFileName,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<Import Project="Common.optset"/><Import Project="COMMON.OPTSET"/></Project>');
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := lDprojFileName;
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win64';
  lResult := TDelphiSemanticProject.Load(lDprojFileName, lOptions);
  Assert.IsTrue(lResult.Success);
  lSecondResult := TDelphiSemanticProject.Load(lDprojFileName, lOptions);
  Assert.IsTrue(lSecondResult.Success);
  Assert.AreEqual(lResult.Project.ContextObservations.EvidenceFingerprint,
    lSecondResult.Project.ContextObservations.EvidenceFingerprint);
  lImportCount := 0;
  for i := 0 to lResult.Project.ContextObservations.Count - 1 do
  begin
    lObservation := lResult.Project.ContextObservations.Items[i];
    if (lObservation.Kind = TDelphiSemanticProjectContextObservationKind.pckoInput) and
      SameText(TPath.GetFullPath(lObservation.FileName), TPath.GetFullPath(lOptionFileName)) then
      Inc(lImportCount);
  end;
  Assert.AreEqual(1, lImportCount,
    'Repeated imports of one canonical path must reconcile to one deterministic input observation.');
end;

procedure TProjectContextTests.OwnedContextEvidenceSurvivesSessionDisposal;
var
  lCacheMetrics: TDelphiSemanticCacheMetrics;
  lEvidence: TDelphiSemanticContextEvidenceExtension;
  lExtension: TObject;
  lRetainedExtension: TObject;
  lExtractionMilliseconds: Int64;
  lFoundUnitModelEvidence: Boolean;
  lModelIndex: Integer;
  lOptions: TDelphiSemanticOptions;
  lOriginalSourceHash: string;
  lRetainedSourceHash: string;
  lRoot: string;
  lRetainedContext: TDelphiSemanticSymbolQueryContext;
  lSessionResult: TDelphiSemanticProjectSessionResult;
  lSnapshot: TDelphiProjectSnapshot;
  lUnitFileName: string;
begin
  lUnitFileName := ContextEvidenceTempPath('EvidenceUnit.pas');
  lRoot := ExtractFilePath(lUnitFileName);
  WriteUtf8Bytes(TPath.Combine(lRoot, 'EvidenceProject.dpr'),
    'program EvidenceProject;' + sLineBreak + 'uses EvidenceUnit in ''EvidenceUnit.pas'';' +
    sLineBreak + 'begin end.');
  WriteUtf8Bytes(lUnitFileName,
    'unit EvidenceUnit;' + sLineBreak + 'interface' + sLineBreak +
    'type TContextEvidence = Integer;' + sLineBreak + 'implementation' + sLineBreak + 'end.');
  WriteUtf8Bytes(TPath.Combine(lRoot, 'EvidenceProject.dproj'),
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>EvidenceProject.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="EvidenceUnit.pas"/></ItemGroup></Project>');
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := TPath.Combine(lRoot, 'EvidenceProject.dproj');
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win64';
  lOptions.SqliteCacheFileName := '';
  lSessionResult := TDelphiSemanticProjectSession.Open(lOptions);
  Assert.IsTrue(lSessionResult.Success);
  try
    lRetainedContext := lSessionResult.Session.BuildSnapshotSymbolQueryContext(
      lCacheMetrics, lExtractionMilliseconds);
    lSnapshot := lRetainedContext.ProjectSnapshot.Snapshot;
    Assert.IsTrue(lSnapshot.TryGetExtension(cDelphiSemanticContextEvidenceExtensionName,
      lExtension));
    Assert.IsTrue(lExtension is TDelphiSemanticContextEvidenceExtension);
    lEvidence := lExtension as TDelphiSemanticContextEvidenceExtension;
    Assert.IsTrue(lEvidence.HasCoProducedEvidence);
    lFoundUnitModelEvidence := False;
    lOriginalSourceHash := '';
    for lModelIndex := 0 to lEvidence.ModelCount - 1 do
    begin
      if SameText(TPath.GetFullPath(lEvidence.ModelEvidence[lModelIndex].SourceFileName),
        TPath.GetFullPath(lUnitFileName)) then
      begin
        lFoundUnitModelEvidence := True;
        lOriginalSourceHash := lEvidence.ModelEvidence[lModelIndex].RootSourceContentHash;
        Assert.AreNotEqual('', lOriginalSourceHash);
        Assert.IsTrue(lEvidence.ModelEvidence[lModelIndex].BodyAnalysisIncluded);
        Assert.IsTrue(lEvidence.ModelEvidence[lModelIndex].ReferenceExtractionIncluded);
        Break;
      end;
    end;
    Assert.IsTrue(lFoundUnitModelEvidence,
      'Per-root evidence remains grouped with its analyzed source identity.');
    lSessionResult.Session.Free;
    lSessionResult.Session := nil;
  finally
    lSessionResult.Session.Free;
  end;

  lSnapshot := lRetainedContext.ProjectSnapshot.Snapshot;
  Assert.IsTrue(lSnapshot.TryGetExtension(cDelphiSemanticContextEvidenceExtensionName,
    lRetainedExtension));
  lEvidence := lRetainedExtension as TDelphiSemanticContextEvidenceExtension;
  lRetainedSourceHash := '';
  for lModelIndex := 0 to lEvidence.ModelCount - 1 do
    if SameText(TPath.GetFullPath(lEvidence.ModelEvidence[lModelIndex].SourceFileName),
      TPath.GetFullPath(lUnitFileName)) then
    begin
      lRetainedSourceHash := lEvidence.ModelEvidence[lModelIndex].RootSourceContentHash;
      Break;
    end;
  Assert.AreEqual(lOriginalSourceHash, lRetainedSourceHash);
  Assert.IsTrue(lEvidence.HasCoProducedEvidence,
    'The copied query context retains co-produced evidence after session disposal; ' +
    'closed-world completeness remains for T-625.');
end;

procedure TProjectContextTests.PersistedSnapshotWithoutCoProducedEvidenceIsNonCertifying;
var
  lBoundPlan: TDelphiSemanticBoundPlanResult;
  lCacheFileName: string;
  lEdit: TSemanticPlanEdit;
  lExtension: TObject;
  lOptions: TDelphiSemanticOptions;
  lRoot: string;
  lRequest: TDelphiSemanticPlanBindingRequest;
  lSessionResult: TDelphiSemanticProjectSessionResult;
  lSnapshotResult: TDelphiSemanticProjectSnapshotBuildResult;
  lUnitFileName: string;
begin
  lUnitFileName := ContextEvidenceTempPath('CachedEvidenceUnit.pas');
  lRoot := ExtractFilePath(lUnitFileName);
  WriteUtf8Bytes(TPath.Combine(lRoot, 'CachedEvidenceProject.dpr'),
    'program CachedEvidenceProject;' + sLineBreak +
    'uses CachedEvidenceUnit in ''CachedEvidenceUnit.pas'';' + sLineBreak + 'begin end.');
  WriteUtf8Bytes(lUnitFileName,
    'unit CachedEvidenceUnit;' + sLineBreak + 'interface' + sLineBreak +
    'const CachedValue = 1;' + sLineBreak + 'implementation' + sLineBreak + 'end.');
  WriteUtf8Bytes(TPath.Combine(lRoot, 'CachedEvidenceProject.dproj'),
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>CachedEvidenceProject.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="CachedEvidenceUnit.pas"/></ItemGroup></Project>');
  lCacheFileName := TPath.Combine(lRoot, '.dak\semantic-cache.sqlite3');
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := TPath.Combine(lRoot, 'CachedEvidenceProject.dproj');
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win64';
  lOptions.SqliteCacheFileName := lCacheFileName;

  lSessionResult := TDelphiSemanticProjectSession.Open(lOptions);
  Assert.IsTrue(lSessionResult.Success);
  try
    lSnapshotResult := lSessionResult.Session.BuildSnapshotResult;
    try
      Assert.IsTrue(lSnapshotResult.Snapshot.TryGetExtension(
        cDelphiSemanticContextEvidenceExtensionName, lExtension));
      Assert.IsTrue(lExtension is TDelphiSemanticContextEvidenceExtension,
        'The first uncached build has a context evidence extension.');
    finally
      lSnapshotResult.Snapshot.Free;
    end;
  finally
    lSessionResult.Session.Free;
  end;

  lSessionResult := TDelphiSemanticProjectSession.Open(lOptions);
  Assert.IsTrue(lSessionResult.Success);
  try
    lSnapshotResult := lSessionResult.Session.BuildSnapshotResult;
    try
      Assert.AreEqual(1, lSnapshotResult.Metrics.SnapshotCacheFullHitCount,
        'The second build must exercise the persisted snapshot cache path.');
      Assert.IsFalse(lSnapshotResult.Snapshot.TryGetExtension(
        cDelphiSemanticContextEvidenceExtensionName, lExtension),
        'A persisted snapshot without co-produced evidence must remain non-certifying.');
       Assert.IsNull(lExtension);
       lRequest := Default(TDelphiSemanticPlanBindingRequest);
       lRequest.OperationIdentity := 'test.cached-snapshot';
       lRequest.Status := TSemanticPlanStatus.Complete;
       lEdit := Default(TSemanticPlanEdit);
       lEdit.FileName := TPath.GetFullPath(lUnitFileName);
       lEdit.StartLine := 3;
       lEdit.StartColumn := Pos('1;', 'const CachedValue = 1;');
       lEdit.EndLine := 3;
       lEdit.EndColumn := lEdit.StartColumn + 1;
       lEdit.ExpectedText := '1';
       lEdit.ReplacementText := '2';
       lRequest.Edits := [lEdit];
       lBoundPlan := TDelphiSemanticPlanBinder.Bind(lSnapshotResult.Snapshot, lRequest);
       try
         Assert.AreEqual(TSemanticPlanStatus.Incomplete, lBoundPlan.Status);
         Assert.AreEqual('binding.context-evidence-missing', lBoundPlan.Reason);
         Assert.IsNull(lBoundPlan.Plan,
           'A persisted legacy snapshot without co-produced evidence cannot bind a plan.');
       finally
         lBoundPlan.Free;
       end;
     finally
       lSnapshotResult.Snapshot.Free;
    end;
  finally
    lSessionResult.Session.Free;
  end;
end;

procedure TProjectContextTests.BoundPlanBindsOperationConfigurationScopeAndIncludeManifest;
var
  lBoundPlan: TDelphiSemanticBoundPlanResult;
  lBoundPlanAgain: TDelphiSemanticBoundPlanResult;
  lNegativeBoundPlan: TDelphiSemanticBoundPlanResult;
  lNegativeRequest: TDelphiSemanticPlanBindingRequest;
  lEdit: TSemanticPlanEdit;
  lEvidence: TDelphiSemanticContextEvidenceExtension;
  lExtension: TObject;
  lIncludeFileName: string;
  lIncludeGraphHash: string;
  lModelIndex: Integer;
  lUnitSourceIndex: Integer;
  lOptions: TDelphiSemanticOptions;
  lRequest: TDelphiSemanticPlanBindingRequest;
  lRoot: string;
  lScopeBoundPlan: TDelphiSemanticBoundPlanResult;
  lScopeEvidence: TDelphiSemanticContextEvidenceExtension;
  lScopeRequest: TDelphiSemanticPlanBindingRequest;
  lScopedExtension: TObject;
  lScopedRootFileName: string;
  lScopedSnapshotResult: TDelphiSemanticProjectSnapshotBuildResult;
  lSessionResult: TDelphiSemanticProjectSessionResult;
  lSnapshotResult: TDelphiSemanticProjectSnapshotBuildResult;
  lUnitFileName: string;
begin
  lBoundPlan := nil;
  lBoundPlanAgain := nil;
  lNegativeBoundPlan := nil;
  lScopeBoundPlan := nil;
  lUnitFileName := ContextEvidenceTempPath('BoundUnit.pas');
  lRoot := ExtractFilePath(lUnitFileName);
  lIncludeFileName := TPath.Combine(lRoot, 'Bound.inc');
  WriteUtf8Bytes(TPath.Combine(lRoot, 'BoundProject.dpr'),
    'program BoundProject;' + sLineBreak +
    'uses BoundUnit in ''BoundUnit.pas'';' + sLineBreak + 'begin end.');
  WriteUtf8Bytes(lUnitFileName,
    'unit BoundUnit;' + sLineBreak + 'interface' + sLineBreak +
    '{$I Bound.inc}' + sLineBreak + 'const BoundValue = 1;' + sLineBreak +
    'implementation' + sLineBreak + 'end.');
  WriteUtf8Bytes(lIncludeFileName, 'type TIncludedBound = Integer;');
  WriteUtf8Bytes(TPath.Combine(lRoot, 'BoundProject.dproj'),
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>BoundProject.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="BoundUnit.pas"/></ItemGroup></Project>');
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := TPath.Combine(lRoot, 'BoundProject.dproj');
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win64';
  lSessionResult := TDelphiSemanticProjectSession.Open(lOptions);
  Assert.IsTrue(lSessionResult.Success);
  try
    lSnapshotResult := lSessionResult.Session.BuildSnapshotResult;
    try
      Assert.IsTrue(lSnapshotResult.Snapshot.TryGetExtension(
        cDelphiSemanticContextEvidenceExtensionName, lExtension));
      lEvidence := lExtension as TDelphiSemanticContextEvidenceExtension;
      lRequest := Default(TDelphiSemanticPlanBindingRequest);
       lRequest.OperationIdentity := 'test.operation';
       lRequest.SelectedConfigurationIdentities := [
        lEvidence.ProjectConfigurationIdentity];
      lRequest.RequiredAnalysisKinds := [
        TSemanticPlanAnalysisKind.pakBodyAnalysis,
        TSemanticPlanAnalysisKind.pakReferenceExtraction];
      lRequest.Status := TSemanticPlanStatus.Complete;
      lEdit := Default(TSemanticPlanEdit);
      lEdit.FileName := TPath.GetFullPath(lUnitFileName);
      lEdit.StartLine := 4;
      lEdit.StartColumn := Pos('1;', 'const BoundValue = 1;');
      lEdit.EndLine := 4;
      lEdit.EndColumn := lEdit.StartColumn + 1;
      lEdit.ExpectedText := '1';
      lEdit.ReplacementText := '2';
      lRequest.Edits := [lEdit];

      lBoundPlan := TDelphiSemanticPlanBinder.Bind(lSnapshotResult.Snapshot, lRequest);
      Assert.AreEqual(TSemanticPlanStatus.Complete, lBoundPlan.Status);
      Assert.IsNotNull(lBoundPlan.Plan);
      Assert.AreEqual('test.operation', lBoundPlan.OperationIdentity);
      Assert.AreEqual(1, Integer(Length(lBoundPlan.SelectedConfigurationIdentities)));
      Assert.AreEqual(lEvidence.ProjectConfigurationIdentity,
        lBoundPlan.SelectedConfigurationIdentities[0]);
      Assert.AreEqual(Length(lEvidence.ExpectedRootFileNames),
        Length(lBoundPlan.ExpectedRootFileNames));
      Assert.AreEqual(Length(lEvidence.ExpectedRootFileNames),
        Length(lBoundPlan.AnalyzedRootFileNames));
      Assert.IsTrue(TSemanticPlanVerificationFact.pvSameIntentFeatureReplan in
        lBoundPlan.RequiredVerifications);

      lIncludeGraphHash := '';
      lUnitSourceIndex := -1;
      for lModelIndex := 0 to lBoundPlan.Plan.SourceCount - 1 do
        if SameText(TPath.GetFullPath(lBoundPlan.Plan.Sources[lModelIndex].FileName),
          TPath.GetFullPath(lUnitFileName)) then
        begin
          lIncludeGraphHash := lBoundPlan.Plan.Sources[lModelIndex].IncludeGraphHash;
          lUnitSourceIndex := lModelIndex;
        end;
      Assert.AreNotEqual('', lIncludeGraphHash,
        'The plan source retains a non-empty raw-byte include manifest.');
      Assert.IsTrue(lUnitSourceIndex >= 0);

      lBoundPlanAgain := TDelphiSemanticPlanBinder.Bind(lSnapshotResult.Snapshot, lRequest);
      Assert.IsTrue(lBoundPlanAgain.Status = TSemanticPlanStatus.Complete);
      Assert.AreEqual(lBoundPlan.ContextFingerprint, lBoundPlanAgain.ContextFingerprint,
        'Binding the same retained snapshot and scope is deterministic.');
      Assert.AreEqual(lIncludeGraphHash,
        lBoundPlanAgain.Plan.Sources[lUnitSourceIndex].IncludeGraphHash);

      lNegativeRequest := lRequest;
      lNegativeRequest.SelectedConfigurationIdentities := [
        lEvidence.ProjectConfigurationIdentity + '-not-observed'];
      lNegativeBoundPlan := TDelphiSemanticPlanBinder.Bind(
        lSnapshotResult.Snapshot, lNegativeRequest);
      Assert.AreEqual(TSemanticPlanStatus.Incomplete, lNegativeBoundPlan.Status);
      Assert.AreEqual('binding.configuration-not-observed', lNegativeBoundPlan.Reason);
      Assert.IsNull(lNegativeBoundPlan.Plan,
        'A caller-selected configuration not captured by the session cannot bind.');
      lNegativeBoundPlan.Free;
      lNegativeBoundPlan := nil;

      lNegativeRequest := lRequest;
      lNegativeRequest.RequiredAnalysisKinds := [];
      lNegativeBoundPlan := TDelphiSemanticPlanBinder.Bind(
        lSnapshotResult.Snapshot, lNegativeRequest);
      Assert.AreEqual(TSemanticPlanStatus.Incomplete, lNegativeBoundPlan.Status);
      Assert.AreEqual('binding.analysis-kind-required', lNegativeBoundPlan.Reason);
      Assert.IsNull(lNegativeBoundPlan.Plan,
        'A bound plan must name the semantic analysis kinds required by its operation.');
      lNegativeBoundPlan.Free;
      lNegativeBoundPlan := nil;

      lScopedSnapshotResult := lSessionResult.Session.BuildSnapshotResult([lUnitFileName]);
      try
        Assert.IsTrue(lScopedSnapshotResult.Snapshot.TryGetExtension(
          cDelphiSemanticContextEvidenceExtensionName, lScopedExtension));
        lScopeEvidence := lScopedExtension as TDelphiSemanticContextEvidenceExtension;
        lScopedRootFileName := '';
        for lModelIndex := 0 to lScopeEvidence.ModelCount - 1 do
          if not lScopeEvidence.ModelEvidence[lModelIndex].BodyAnalysisIncluded then
          begin
            lScopedRootFileName := lScopeEvidence.ModelEvidence[lModelIndex].SourceFileName;
            Break;
          end;
        Assert.AreNotEqual('', lScopedRootFileName,
          'The scoped extraction fixture leaves at least one project root unanalyzed.');
        lScopeRequest := lRequest;
        lScopeRequest.ScopeRootFileNames := [lScopedRootFileName];
        lScopeBoundPlan := TDelphiSemanticPlanBinder.Bind(
          lScopedSnapshotResult.Snapshot, lScopeRequest);
        Assert.AreEqual(TSemanticPlanStatus.Incomplete, lScopeBoundPlan.Status);
        Assert.AreEqual('binding.analysis-scope-incomplete', lScopeBoundPlan.Reason);
        Assert.IsNull(lScopeBoundPlan.Plan,
          'A root outside the extraction analysis scope cannot be bound.');
        lScopeBoundPlan.Free;
        lScopeBoundPlan := nil;

        lScopeRequest.ScopeRootFileNames := [lUnitFileName];
        lScopeBoundPlan := TDelphiSemanticPlanBinder.Bind(
          lScopedSnapshotResult.Snapshot, lScopeRequest);
        Assert.AreEqual(TSemanticPlanStatus.Complete, lScopeBoundPlan.Status);
        Assert.AreEqual(1, Integer(Length(lScopeBoundPlan.ScopeRootFileNames)));
        Assert.AreEqual(1, Integer(Length(lScopeBoundPlan.AnalyzedRootFileNames)));
        Assert.AreEqual(Length(lScopeEvidence.ExpectedRootFileNames),
          Length(lScopeBoundPlan.ExpectedRootFileNames));
        Assert.AreEqual(TPath.GetFullPath(lUnitFileName),
          TPath.GetFullPath(lScopeBoundPlan.AnalyzedRootFileNames[0]));
        Assert.IsTrue(Length(lScopeBoundPlan.ExpectedRootFileNames) >
          Length(lScopeBoundPlan.AnalyzedRootFileNames),
          'The result distinguishes subset analysis from project-wide coverage.');
      finally
        lScopeBoundPlan.Free;
        lScopedSnapshotResult.Snapshot.Free;
      end;
    finally
      lNegativeBoundPlan.Free;
      lBoundPlanAgain.Free;
      lBoundPlan.Free;
      lSnapshotResult.Snapshot.Free;
    end;
  finally
    lSessionResult.Session.Free;
  end;
end;

procedure TProjectContextTests.InstalledDelphiTargetsDoNotReportUnusedBuildMacros;
var
  lAppDataPath: string;
  lBdsRoot: string;
  lDprojFileName: string;
  lImportedTarget: TDelphiSemanticProjectContextObservation;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticContextResult;
  lTargetsFileName: string;
begin
  lBdsRoot := TDelphiSemanticCompilerProfileBuilder.ResolveBdsRoot('23.0', '');
  lTargetsFileName := TPath.Combine(lBdsRoot, 'Bin\CodeGear.Delphi.Targets');
  Assert.IsTrue(TFile.Exists(lTargetsFileName),
    'This test requires the installed Delphi 12 CodeGear targets.');

  lDprojFileName := ContextEvidenceTempPath('InstalledTargetsProject.dproj');
  lAppDataPath := TPath.Combine(ExtractFilePath(lDprojFileName), 'empty-appdata');
  TDirectory.CreateDirectory(lAppDataPath);
  WriteUtf8Bytes(lDprojFileName,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>InstalledTargetsProject.dpr</MainSource>' +
    '<Config>Debug</Config><Platform>Win64</Platform><FrameworkType>None</FrameworkType>' +
    '<DCC_Define>OWNED_DEFINE</DCC_Define>' +
    '<DCC_UnitSearchPath>OwnedUnits</DCC_UnitSearchPath></PropertyGroup>' +
    '<Import Project="$(BDS)\Bin\CodeGear.Delphi.Targets" ' +
    'Condition="Exists(''$(BDS)\Bin\CodeGear.Delphi.Targets'')"/></Project>');

  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := lDprojFileName;
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win64';
  lOptions.DelphiVersion := '23.0';
  SetLength(lOptions.EnvironmentVariables, 2);
  lOptions.EnvironmentVariables[0].Name := 'BDS';
  lOptions.EnvironmentVariables[0].Value := lBdsRoot;
  lOptions.EnvironmentVariables[1].Name := 'APPDATA';
  lOptions.EnvironmentVariables[1].Value := lAppDataPath;

  lResult := TDelphiSemanticProject.Load(lDprojFileName, lOptions);

  Assert.IsTrue(lResult.Success);
  Assert.AreEqual('OWNED_DEFINE', lResult.Project.PropertyValue('DCC_Define'));
  Assert.AreEqual('OwnedUnits', lResult.Project.PropertyValue('DCC_UnitSearchPath'));
  Assert.IsTrue(FindContextEvidenceInput(lResult.Project.ContextObservations,
    lTargetsFileName, lImportedTarget),
    'The real imported targets remain part of stale-context evidence.');
  Assert.IsFalse(HasDiagnostic(lResult, 'UNRESOLVED_MSBUILD_MACRO'),
    'Unconsumed build-only macros in installed targets must not block source context.' +
    sLineBreak + DiagnosticSummary(lResult));
end;

procedure TProjectContextTests.ExplicitSelfReferentialSearchPathRemainsEffective;
var
  lExpectedPath: string;
  lOptions: TDelphiSemanticOptions;
  lProjectPath: string;
  lResult: TDelphiSemanticContextResult;
  lSearchPath: string;
  lFoundPhysicalPath: Boolean;
begin
  lProjectPath := TPath.GetFullPath(TPath.Combine(
    ExtractFilePath(ParamStr(0)),
    '..\..\..\DelphiAiKit\tests\fixtures\test-projects\maxTdb\src\maxtdb.dproj'));
  lExpectedPath := PhysicalTestPath(TPath.GetFullPath(TPath.Combine(
    ExtractFilePath(ParamStr(0)),
    '..\..\..\DelphiAiKit\tests\fixtures\test-projects\semantic-isolated-t311\Foundation')));
  Assert.IsTrue(TFile.Exists(lProjectPath));
  Assert.IsTrue(TDirectory.Exists(lExpectedPath));

  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := lProjectPath;
  lOptions.Configuration := 'Release';
  lOptions.Platform := 'Win64';
  lOptions.DelphiVersion := '23.0';
  lResult := TDelphiSemanticProject.Load(lProjectPath, lOptions);

  Assert.IsTrue(lResult.Success);
  lFoundPhysicalPath := False;
  for lSearchPath in lResult.Project.SourceLookupPaths do
  begin
    if TDirectory.Exists(lSearchPath) and
      SameText(PhysicalTestPath(lSearchPath), lExpectedPath) then
    begin
      lFoundPhysicalPath := True;
      Break;
    end;
  end;
  Assert.IsTrue(lFoundPhysicalPath,
    'The explicit Foundation path must survive self-reference and imported targets. ' +
    'DCC_UnitSearchPath=' + lResult.Project.PropertyValue('DCC_UnitSearchPath'));
end;

procedure TProjectContextTests.MissingFrameworkTypeInImportedTargetReportsSourceMacro;
var
  lAppDataPath: string;
  lBdsRoot: string;
  lDprojFileName: string;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticContextResult;
  lTargetsFileName: string;
begin
  lBdsRoot := TDelphiSemanticCompilerProfileBuilder.ResolveBdsRoot('23.0', '');
  lTargetsFileName := TPath.Combine(lBdsRoot, 'Bin\CodeGear.Delphi.Targets');
  Assert.IsTrue(TFile.Exists(lTargetsFileName),
    'This test requires the installed Delphi 12 CodeGear targets.');

  lDprojFileName := ContextEvidenceTempPath('MissingFrameworkTypeProject.dproj');
  lAppDataPath := TPath.Combine(ExtractFilePath(lDprojFileName), 'empty-appdata');
  TDirectory.CreateDirectory(lAppDataPath);
  WriteUtf8Bytes(lDprojFileName,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>MissingFrameworkTypeProject.dpr</MainSource>' +
    '<Config>Debug</Config><Platform>Win64</Platform>' +
    '<DCC_Define>OWNED_DEFINE</DCC_Define></PropertyGroup>' +
    '<Import Project="$(BDS)\Bin\CodeGear.Delphi.Targets" ' +
    'Condition="Exists(''$(BDS)\Bin\CodeGear.Delphi.Targets'')"/></Project>');

  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := lDprojFileName;
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win64';
  lOptions.DelphiVersion := '23.0';
  SetLength(lOptions.EnvironmentVariables, 2);
  lOptions.EnvironmentVariables[0].Name := 'BDS';
  lOptions.EnvironmentVariables[0].Value := lBdsRoot;
  lOptions.EnvironmentVariables[1].Name := 'APPDATA';
  lOptions.EnvironmentVariables[1].Value := lAppDataPath;

  lResult := TDelphiSemanticProject.Load(lDprojFileName, lOptions);

  Assert.IsTrue(lResult.Success);
  Assert.IsTrue(HasDiagnostic(lResult, 'UNRESOLVED_MSBUILD_MACRO'),
    'An absent framework type controls compiler defines and must remain diagnosable.' +
    sLineBreak + DiagnosticSummary(lResult));
  Assert.IsTrue(Pos('FrameworkType', DiagnosticSummary(lResult)) > 0,
    'The diagnostic should identify the source-affecting FrameworkType macro.' +
    sLineBreak + DiagnosticSummary(lResult));
end;

procedure TProjectContextTests.ExplicitOptionalTargetPropertiesArePreserved;
var
  lAppDataPath: string;
  lBdsRoot: string;
  lDprojFileName: string;
  lGlobalOptionFile: string;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticContextResult;
  lTargetsFileName: string;
begin
  lBdsRoot := TDelphiSemanticCompilerProfileBuilder.ResolveBdsRoot('23.0', '');
  lTargetsFileName := TPath.Combine(lBdsRoot, 'Bin\CodeGear.Delphi.Targets');
  Assert.IsTrue(TFile.Exists(lTargetsFileName),
    'This test requires the installed Delphi 12 CodeGear targets.');

  lDprojFileName := ContextEvidenceTempPath('ExplicitOptionalTargetsProject.dproj');
  lAppDataPath := TPath.Combine(ExtractFilePath(lDprojFileName), 'empty-appdata');
  lGlobalOptionFile := TPath.Combine(ExtractFilePath(lDprojFileName),
    'explicit-global-options.optset');
  TDirectory.CreateDirectory(lAppDataPath);
  Assert.IsFalse(TFile.Exists(lGlobalOptionFile));
  WriteUtf8Bytes(lDprojFileName,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>ExplicitOptionalTargetsProject.dpr</MainSource>' +
    '<Config>Debug</Config><Platform>Win64</Platform><FrameworkType>None</FrameworkType>' +
    '<PlatformSDK>ExplicitSDK.profile</PlatformSDK>' +
    '<GlobalOptionFile>' + lGlobalOptionFile + '</GlobalOptionFile>' +
    '</PropertyGroup><Import Project="$(BDS)\Bin\CodeGear.Delphi.Targets" ' +
    'Condition="Exists(''$(BDS)\Bin\CodeGear.Delphi.Targets'')"/></Project>');

  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := lDprojFileName;
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win64';
  lOptions.DelphiVersion := '23.0';
  SetLength(lOptions.EnvironmentVariables, 2);
  lOptions.EnvironmentVariables[0].Name := 'BDS';
  lOptions.EnvironmentVariables[0].Value := lBdsRoot;
  lOptions.EnvironmentVariables[1].Name := 'APPDATA';
  lOptions.EnvironmentVariables[1].Value := lAppDataPath;

  lResult := TDelphiSemanticProject.Load(lDprojFileName, lOptions);

  Assert.IsTrue(lResult.Success);
  Assert.AreEqual('ExplicitSDK.profile', lResult.Project.PropertyValue('PlatformSDK'));
  Assert.AreEqual(lGlobalOptionFile, lResult.Project.PropertyValue('GlobalOptionFile'));
end;

procedure TProjectContextTests.EmptyExistsConditionIsFalse;
var
  lDprojFileName: string;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticContextResult;
begin
  lDprojFileName := ContextEvidenceTempPath('EmptyExistsConditionProject.dproj');
  WriteUtf8Bytes(lDprojFileName,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>EmptyExistsConditionProject.dpr</MainSource>' +
    '<Config>Debug</Config><Platform>Win64</Platform>' +
    '<DCC_Define Condition="Exists('''')">SHOULD_NOT_APPLY</DCC_Define>' +
    '</PropertyGroup></Project>');
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := lDprojFileName;
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win64';

  lResult := TDelphiSemanticProject.Load(lDprojFileName, lOptions);

  Assert.IsTrue(lResult.Success);
  Assert.AreEqual('', lResult.Project.PropertyValue('DCC_Define'),
    'An empty Exists path is not the project directory.');
end;

procedure TProjectContextTests.UnresolvedSourceSearchPathStillReportsMacro;
var
  lDprojFileName: string;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticContextResult;
begin
  lDprojFileName := ContextEvidenceTempPath('UnresolvedSourcePathProject.dproj');
  WriteUtf8Bytes(lDprojFileName,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>UnresolvedSourcePathProject.dpr</MainSource>' +
    '<DCC_UnitSearchPath>$(MissingSourceSearchPath)</DCC_UnitSearchPath>' +
    '</PropertyGroup></Project>');
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := lDprojFileName;
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win64';

  lResult := TDelphiSemanticProject.Load(lDprojFileName, lOptions);

  Assert.IsTrue(lResult.Success);
  Assert.IsTrue(HasDiagnostic(lResult, 'UNRESOLVED_MSBUILD_MACRO'),
    'An unknown value in a consumed compiler search path must remain diagnosable.');
end;

procedure TProjectContextTests.UnresolvedBuildPropertyFlowStillReportsMacro;
var
  lDprojFileName: string;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticContextResult;
begin
  lDprojFileName := ContextEvidenceTempPath('UnresolvedBuildPropertyFlowProject.dproj');
  WriteUtf8Bytes(lDprojFileName,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><OptionalBuildPath>$(MissingBuildPath)</OptionalBuildPath>' +
    '<DCC_UnitSearchPath>$(OptionalBuildPath)</DCC_UnitSearchPath></PropertyGroup></Project>');
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := lDprojFileName;
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win64';

  lResult := TDelphiSemanticProject.Load(lDprojFileName, lOptions);

  Assert.IsTrue(lResult.Success);
  Assert.IsTrue(HasDiagnostic(lResult, 'UNRESOLVED_MSBUILD_MACRO'),
    'A missing macro preserved through a build property must still block when consumed by search-path context.');
end;

procedure TProjectContextTests.UnresolvedConditionOnSemanticPropertyStillReportsMacro;
var
  lDprojFileName: string;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticContextResult;
begin
  lDprojFileName := ContextEvidenceTempPath('UnresolvedSemanticConditionProject.dproj');
  WriteUtf8Bytes(lDprojFileName,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup Condition="''$(MissingDefineCondition)''==''enabled''">' +
    '<DCC_Define>CONDITIONALLY_DEFINED</DCC_Define></PropertyGroup></Project>');
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := lDprojFileName;
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win64';

  lResult := TDelphiSemanticProject.Load(lDprojFileName, lOptions);

  Assert.IsTrue(lResult.Success);
  Assert.IsTrue(HasDiagnostic(lResult, 'UNRESOLVED_MSBUILD_MACRO'),
    'An unresolved condition controlling source-context defines must remain diagnosable.');
end;

procedure TProjectContextTests.UnresolvedBuildConditionFlowStillReportsMacro;
var
  lDprojFileName: string;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticContextResult;
begin
  lDprojFileName := ContextEvidenceTempPath('UnresolvedBuildConditionFlowProject.dproj');
  WriteUtf8Bytes(lDprojFileName,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup Condition="''$(MissingBuildCondition)''==''enabled''">' +
    '<OptionalBuildPath>ConditionallyPresent</OptionalBuildPath></PropertyGroup>' +
    '<PropertyGroup><DCC_UnitSearchPath>$(OptionalBuildPath)</DCC_UnitSearchPath></PropertyGroup>' +
    '</Project>');
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := lDprojFileName;
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win64';

  lResult := TDelphiSemanticProject.Load(lDprojFileName, lOptions);

  Assert.IsTrue(lResult.Success);
  Assert.IsTrue(HasDiagnostic(lResult, 'UNRESOLVED_MSBUILD_MACRO'),
    'An unknown condition on a build-only property must not be guessed if that property flows into semantic context.');
end;

initialization
  TDUnitX.RegisterTestFixture(TProjectContextTests);

end.
