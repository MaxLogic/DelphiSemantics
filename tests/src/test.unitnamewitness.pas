unit Test.UnitNameWitness;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Model, DelphiSemantics.ProjectContext,
  DelphiSemantics.Resolve.UnitNameWitness;

type
  [TestFixture]
  TUnitNameWitnessTests = class
  private
    fRoot: string;
    fProject: TDelphiSemanticProjectInfo;
    fModels: TArray<TDelphiSemanticUnitModel>;
    function Witness(const aRtlRoot: string = ''): IDelphiSemanticUnitNameWitness;
    procedure WriteSource(const aRelativeName, aText: string);
  public
    [Setup]
    procedure Setup;
    [Category('Fast')]
    [Test]
    procedure BoundedLookupMatchesFullEnumeration;
    [TestCase('Empty', '0')]
    [TestCase('One', '1')]
    [TestCase('Tiny', '32')]
    [TestCase('Boundary', '33')]
    [TestCase('Large', '1463')]
    procedure DirectoryListingCharacterization(const aNameCount: Integer);
    [Test]
    procedure LargeNameSetsAvoidNativeProbes;
    [TestCase('Removed source', 'remove')]
    [TestCase('Changed source bytes', 'edit')]
    [TestCase('Added candidate after listing', 'add')]
    procedure DirectoryChangesBetweenListingAndUse(const aShape: string);
    [Category('Fast')]
    [Test]
    procedure ComparerClassLookupMatchesFullEnumeration;
    [Category('Fast')]
    [Test]
    procedure ChangedProfilePathGetsFreshScan;
    [Category('Fast')]
    [Test]
    procedure DirectoryInventoryNoticesAddedAndRemovedCandidates;
    [Category('Fast')]
    [Test]
    procedure ProjectSourceCannotProveAbsence;
    [Category('Fast')]
    [TestCase('Project include only', 'project')]
    [TestCase('Two SDK include candidates', 'ambiguous')]
    [TestCase('Nested root fallback', 'nested')]
    [TestCase('Parent escapes source', 'escape')]
    procedure SdkIncludesStayInsideInstallation(const aShape: string);
    [Category('Fast')]
    [TestCase('Installed Windows aliases', 'windows')]
    [TestCase('Default/project conflict', 'conflict')]
    [TestCase('Project conflict', 'project-conflict')]
    [TestCase('Exact duplicate', 'duplicate')]
    [TestCase('Alias key and target', 'extra')]
    [TestCase('Missing targets', 'missing')]
    [TestCase('Malformed targets', 'malformed')]
    [TestCase('Other platform', 'other')]
    procedure DefaultAliasesRespectPlatformAndUncertainty(const aShape: string);
    [Category('Fast')]
    [Test]
    procedure SdkSourceWithoutDcuCannotProveAbsence;
    [Category('Fast')]
    [TestCase('Same physical candidate', 'False')]
    [TestCase('Different physical candidates', 'True')]
    procedure ScopedAliasCandidatesUsePhysicalIdentity(const aExtraFile: Boolean);
    [Category('Fast')]
    [Test]
    procedure TokensAreCaseInsensitiveAndIncludeEscapedIdentifiers;
    [Category('Fast')]
    [Test]
    procedure SourceAndIncludeBytesInvalidateIdentity;
    [Category('Fast')]
    [Test]
    procedure IncludesAreFollowedAndCyclesTerminate;
    [Category('Fast')]
    [TestCase('Pascal shadow', 'pas')]
    [TestCase('DCU shadow', 'dcu')]
    procedure DuplicateLookupDirectoriesAreUnknown(const aExtension: string);
    [Category('Fast')]
    [TestCase('I tab', 'I,tab,brace')]
    [TestCase('INCLUDE tab', 'INCLUDE,tab,brace')]
    [TestCase('Parenthesis I tab', 'I,tab,paren')]
    [TestCase('Parenthesis INCLUDE newline', 'INCLUDE,newline,paren')]
    [TestCase('I newline', 'I,newline,brace')]
    procedure DirectiveWhitespaceFollowsIncludes(const aSpelling, aWhitespace, aForm: string);
    [TestCase('RTL plus reference source', 'rtl')]
    [TestCase('Colocated DCU plus source', 'colocated')]
    [TestCase('Library Pascal', 'library-pas')]
    [TestCase('Library DCU', 'library-dcu')]
    [TestCase('Browsing Pascal', 'browsing-pas')]
    [TestCase('Browsing DCU', 'browsing-dcu')]
    [Category('DS719Review2,Fast')]
    procedure CandidateLocationUnionCannotProveAbsence(const aShape: string);
    [TestCase('INCLUDE plus', 'INCLUDE+names.inc,+names.inc')]
    [TestCase('INCLUDE minus', 'INCLUDE-names.inc,-names.inc')]
    [TestCase('INCLUDE spaced plus', 'INCLUDE +names.inc,+names.inc')]
    [TestCase('I spaced plus', 'I +names.inc,+names.inc')]
    [TestCase('I plus switch', 'I+,')]
    [TestCase('I minus switch', 'I-,')]
    [TestCase('I plus trailing argument switch', 'I+ x,')]
    [TestCase('I plus adjacent argument switch', 'I+x,')]
    [TestCase('Known non-include BOOLEVAL', 'BOOLEVAL OFF,')]
    [TestCase('Known non-include LONGSTRINGS', 'LONGSTRINGS ON,')]
    [TestCase('Known non-include TYPEDADDRESS', 'TYPEDADDRESS OFF,')]
    [TestCase('Known non-include EXTENDEDSYNTAX', 'EXTENDEDSYNTAX ON,')]
    [TestCase('Known non-include ALIGN', 'ALIGN 8,')]
    [TestCase('Known non-include ZEROBASEDSTRINGS', 'ZEROBASEDSTRINGS OFF,')]
    [TestCase('Known non-include HINTS', 'HINTS ON,')]
    [TestCase('Outside include scope INLINE', 'INLINE value,')]
    [TestCase('Outside include scope IOCHECKS', 'IOCHECKS value,')]
    [TestCase('Outside include scope IMPORTEDDATA', 'IMPORTEDDATA value,')]
    [TestCase('Outside include scope IMPLICITBUILD', 'IMPLICITBUILD value,')]
    [TestCase('Outside include scope IMAGEBASE', 'IMAGEBASE value,')]
    [TestCase('Outside include scope WEAKPACKAGEUNIT', 'WEAKPACKAGEUNIT value,')]
    [TestCase('Outside include scope STACKFRAMES', 'STACKFRAMES value,')]
    [TestCase('Outside include scope OPTIMIZATION', 'OPTIMIZATION value,')]
    [TestCase('Outside include scope EXCESSPRECISION', 'EXCESSPRECISION value,')]
    [TestCase('Missing INCLUDE filename', 'INCLUDE,<include-unclassified>')]
    [TestCase('Other directive name', 'INCLUDEX names.inc,')]
    [Category('DS719Review2,Fast')]
    procedure IncludeDirectiveGrammar(const aDirective, aExpected: string);
    [TestCase('INCLUDE plus brace', 'brace')]
    [TestCase('INCLUDE plus parentheses', 'paren')]
    [Category('DS719Review2,Fast')]
    procedure PlusIncludeContentChangesIdentity(const aForm: string);
    [Test]
    [Category('DS719Review2')]
    procedure ProfileFileCandidatesChangeWitnessIdentity;
    [Test]
    procedure CallerSearchPathsJoinWitnessCandidates;
    [Test]
    procedure DcpOnlyUnitStaysUnknown;
    [TestCase('Active runtime packages', 'true')]
    [TestCase('Dormant IDE package list', 'false')]
    procedure RuntimePackagesCannotProveSdkAbsence(const aEnabled: Boolean);
    [TestCase('SDK pair', 'pair')]
    [TestCase('SDK pair plus project source', 'project-source')]
    [TestCase('SDK pair plus second SDK source', 'second-sdk-source')]
    [TestCase('SDK pair plus external DCU', 'external-dcu')]
    [TestCase('SDK pair plus other installation DCU', 'other-installation')]
    [TestCase('SDK DCU without source', 'dcu-only')]
    [Category('DS719Pairing,Fast')]
    procedure SdkPairingDoesNotHideExtraCandidates(const aShape: string);

    [Category('Fast')]
    [TestCase('String', 'string')]
    [TestCase('Line comment', 'line')]
    [TestCase('Brace comment', 'brace')]
    [TestCase('Parenthesis comment', 'paren')]
    [TestCase('Multiline string', 'multiline')]
    [TestCase('Include-like string unknown', 'uncertain')]
    procedure EveryDirectiveOpenerIsConsidered(const aShape: string);
    [TestCase('Project debug path', 'project')]
    [TestCase('EnvOptions debug path', 'profile')]
    procedure DebugDcuPathsAreCandidateLocations(const aOrigin: string);
    [TestCase('Project translated library', 'project,DelphiTranslatedLibraryPath,DE')]
    [TestCase('Project translated debug', 'project,DelphiTranslatedDebugLibraryPath,DE')]
    [TestCase('EnvOptions translated library', 'profile,DelphiTranslatedLibraryPath,DE')]
    [TestCase('EnvOptions translated debug', 'profile,DelphiTranslatedDebugLibraryPath,DE')]
    [TestCase('Project empty LANGDIR', 'project,DelphiTranslatedDebugLibraryPath,')]
    [TestCase('EnvOptions empty LANGDIR', 'profile,DelphiTranslatedDebugLibraryPath,')]
    procedure TranslatedPathsRequireLanguage(const aOrigin, aProperty, aLanguage: string);

    [Category('Fast')]
    [TestCase('Missing', 'no-source')]
    [TestCase('Dcu', 'dcu-only')]
    [TestCase('WrongHeader', 'unit-name-mismatch')]
    [TestCase('MissingInclude', 'include-unresolved')]
    [TestCase('DuplicateRtl', 'ambiguous-source')]
    procedure UnknownSourcesCannotProveAbsence(const aReason: string);
  end;

implementation

uses
  System.Classes, System.IOUtils, System.StrUtils, System.SysUtils,
  Winapi.Windows,
  MaxLogic.StrUtils,
  DelphiSemantics.Preprocess, Test.Support;

procedure TUnitNameWitnessTests.Setup;
begin
  // A4: grammar/token controls use an SDK pair; arbitrary project sources stay unknown.
  fRoot := TPath.Combine(CreateTestTempRoot('unit-name-witness-temp'), 'sdk\source');
  TDirectory.CreateDirectory(fRoot);
  fProject := Default(TDelphiSemanticProjectInfo);
  fProject.SearchPaths := [fRoot];
  SetLength(fModels, 1);
  fModels[0] := Default(TDelphiSemanticUnitModel);
  fModels[0].UnitName := 'Consumer';
  fModels[0].Success := True;
  fModels[0].ScopeModelStatus := 'ast';
  fModels[0].DependencyFacts.Known := True;
  fModels[0].DependencyFacts.InterfaceImports := ['U'];
  WriteSource('U.pas', 'unit U; interface type TOther = Integer; implementation end.');
  WriteSource('..\lib\win64\release\U.dcu', 'SDK unit');
end;

procedure TUnitNameWitnessTests.WriteSource(const aRelativeName, aText: string);
var
  lPath: string;
begin
  lPath := TPath.Combine(fRoot, aRelativeName);
  TDirectory.CreateDirectory(ExtractFilePath(lPath));
  TFile.WriteAllText(lPath, aText, TEncoding.UTF8);
end;

function TUnitNameWitnessTests.Witness(const aRtlRoot: string): IDelphiSemanticUnitNameWitness;
var
  lProject: TDelphiSemanticProjectInfo;
  lRoot: string;
begin
  lProject := fProject;
  lRoot := aRtlRoot;
  if lRoot = '' then
  begin
    lRoot := fRoot;
    lProject.SearchPaths := lProject.SearchPaths +
      [TPath.Combine(TPath.GetDirectoryName(fRoot), 'lib\win64\release')];
  end;
  Result := TDelphiSemanticUnitNameWitnessBuilder.Build(lProject, fModels, lRoot);
end;

// Match Test.SourceContext: permit developer-mode links without elevation.
function CreateWitnessDirectoryLink(const aLink, aTarget: PWideChar;
  const aFlags: DWORD): ByteBool; stdcall; external kernel32 name 'CreateSymbolicLinkW';

procedure TUnitNameWitnessTests.BoundedLookupMatchesFullEnumeration;
var
  lFull, lBounded: IDelphiSemanticUnitNameWitness;
  lExpected, lActual: TArray<string>;
  lBase, lFirstRoot, lSecondRoot, lSdkRoot, lLink, lName, lToken: string;
  lSeed, i: Integer;
begin
  // Exhaustive 5-bit layout matrix, deterministic seed range 0..31.
  // Compare ordered candidate lists as well as complete identity/verdicts.
  fModels[0].DependencyFacts.InterfaceImports := ['U', 'Missing', 'Mixed', 'Unit.One', 'I', 'S'];
  for lSeed := 0 to 31 do
  begin
    lBase := 'generated-' + IntToStr(lSeed);
    lFirstRoot := TPath.Combine(fRoot, lBase + '\first');
    lSecondRoot := TPath.Combine(fRoot, lBase + '\second');
    lSdkRoot := TPath.Combine(fRoot, lBase + '\sdk\source');
    TDirectory.CreateDirectory(lFirstRoot);
    TDirectory.CreateDirectory(lSecondRoot);
    TDirectory.CreateDirectory(lSdkRoot);
    WriteSource(lBase + '\first\mIxEd.PaS', 'unit Mixed; interface type TOne = Integer; implementation end.');
    WriteSource(lBase + '\first\Unit.One.DcU', 'DCU');
    WriteSource(lBase + '\first\' + #$0131 + '.pas', 'unit I; interface implementation end.');
    WriteSource(lBase + '\first\' + #$017F + '.dcu', 'Unicode case folding');
    WriteSource(lBase + '\first\U.pas.bak', 'lookalike');
    WriteSource(lBase + '\first\U.pasmore', '8.3 alias lookalike');
    TDirectory.CreateDirectory(TPath.Combine(lFirstRoot, 'Missing.pas'));
    WriteSource(lBase + '\first\nested\Missing.pas', 'unit Missing; interface implementation end.');
    if lSeed and 1 <> 0 then
      WriteSource(lBase + '\first\U.pas', 'unit U; interface implementation end.');
    if lSeed and 2 <> 0 then
      WriteSource(lBase + '\second\U.dcu', 'duplicate');
    if lSeed and 4 <> 0 then
      WriteSource(lBase + '\sdk\source\nested\U.pas', 'unit U; interface type TSdk = Integer; implementation end.');
    fProject.SearchPaths := [lFirstRoot, lSecondRoot];
    if lSeed and 8 <> 0 then
      fProject.SearchPaths := [lSecondRoot, lFirstRoot, lSecondRoot];
    fProject.Properties := nil;
    if lSeed and 16 <> 0 then
    begin
      SetLength(fProject.Properties, 1);
      fProject.Properties[0].Name := 'DSWitnessProfileKnown';
      fProject.Properties[0].Value := 'False';
    end;
    lLink := TPath.Combine(lSdkRoot, 'linked');
    Assert.IsTrue(CreateWitnessDirectoryLink(PWideChar(lLink), PWideChar(lFirstRoot), $1 or $2),
      'Directory link creation: ' + SysErrorMessage(GetLastError));
    try
      // The original recursive RTL walk follows this directory reparse point.
      lFull := TDelphiSemanticUnitNameWitnessBuilder.BuildForTest(
        fProject, fModels, lSdkRoot, True, lExpected);
      lBounded := TDelphiSemanticUnitNameWitnessBuilder.BuildForTest(
        fProject, fModels, lSdkRoot, False, lActual);
      Assert.AreEqual(Length(lExpected), Length(lActual), 'Candidate count seed ' + IntToStr(lSeed));
      for i := 0 to High(lExpected) do
        Assert.AreEqual(lExpected[i], lActual[i], 'Candidate ordering seed ' + IntToStr(lSeed));
      Assert.AreEqual(lFull.IdentityText, lBounded.IdentityText, 'Identity seed ' + IntToStr(lSeed));
      for lName in ['U', 'Missing', 'Mixed', 'Unit.One', 'I', 'S'] do
        for lToken in ['Absent', 'TOne', 'TSdk'] do
          Assert.AreEqual(lFull.MayDeclare(lName, lToken), lBounded.MayDeclare(lName, lToken),
            'Verdict seed ' + IntToStr(lSeed) + ' ' + lName + '.' + lToken);
    finally
      Assert.IsTrue(RemoveDir(lLink), 'Remove generated directory link');
    end;
  end;
end;


procedure TUnitNameWitnessTests.DirectoryListingCharacterization(const aNameCount: Integer);
var
  lReference, lActual: IDelphiSemanticUnitNameWitness;
  lExpected, lCandidates: TArray<string>;
  lFirst, lSecond, lName: string;
  lQueries, lFallbacks, i: Integer;
begin
  lFirst := TPath.Combine(fRoot, 'first');
  lSecond := TPath.Combine(fRoot, 'second');
  TDirectory.CreateDirectory(lFirst);
  TDirectory.CreateDirectory(lSecond);
  WriteSource('first\mIxEd.PaS', 'unit Mixed; interface implementation end.');
  WriteSource('first\Mixed.DcU', 'DCU');
  WriteSource('first\Mixed.pasmore', 'not a Pascal source');
  WriteSource('first\Unit.One.DCU', 'DCU');
  WriteSource('second\Mixed.pas', 'unit Mixed; interface implementation end.');
  TDirectory.CreateDirectory(TPath.Combine(lFirst, 'Missing.pas'));
  WriteSource('first\nested\Missing.pas', 'unit Missing; interface implementation end.');
  fProject.SearchPaths := [lFirst, lSecond, lFirst, TPath.Combine(fRoot, 'missing-directory')];
  SetLength(fProject.Properties, 2);
  fProject.Properties[0].Name := 'DelphiBrowsingPath';
  fProject.Properties[0].Value := lSecond;
  fProject.Properties[1].Name := 'DelphiDebugDCUPath';
  fProject.Properties[1].Value := lFirst;
  SetLength(fModels[0].DependencyFacts.InterfaceImports, aNameCount);
  for i := 0 to aNameCount - 1 do
    fModels[0].DependencyFacts.InterfaceImports[i] := 'Missing' + IntToStr(i);
  if aNameCount > 0 then
    fModels[0].DependencyFacts.InterfaceImports[0] := 'Mixed';
  if aNameCount > 1 then
    fModels[0].DependencyFacts.InterfaceImports[1] := 'Unit.One';
  lReference := TDelphiSemanticUnitNameWitnessBuilder.BuildForTest(
    fProject, fModels, '', True, lExpected);
  lActual := TDelphiSemanticUnitNameWitnessBuilder.BuildForTest(
    fProject, fModels, '', False, lCandidates, lQueries, lFallbacks);
  Assert.AreEqual(string.Join(#10, lExpected), string.Join(#10, lCandidates),
    'Complete ordered witness candidate index');
  Assert.AreEqual(lReference.IdentityText, lActual.IdentityText, 'Complete witness identity');
  for lName in fModels[0].DependencyFacts.InterfaceImports do
    Assert.AreEqual(lReference.MayDeclare(lName, 'Absent'), lActual.MayDeclare(lName, 'Absent'), lName);
end;

procedure TUnitNameWitnessTests.LargeNameSetsAvoidNativeProbes;
var
  lWitness: IDelphiSemanticUnitNameWitness;
  lCandidates, lListings: TArray<string>;
  lOptions: TWitnessLookupTestOptions;
  lQueries, lFallbacks, i: Integer;
begin
  fProject.SearchPaths := [fRoot, fRoot];
  SetLength(fProject.Properties, 2);
  fProject.Properties[0].Name := 'DelphiBrowsingPath';
  fProject.Properties[0].Value := fRoot;
  fProject.Properties[1].Name := 'DelphiDebugDCUPath';
  fProject.Properties[1].Value := fRoot;
  lOptions := Default(TWitnessLookupTestOptions);
  lOptions.CaptureDirectoryListings := True;
  SetLength(fModels[0].DependencyFacts.InterfaceImports, 1463);
  for i := 0 to 1462 do
    fModels[0].DependencyFacts.InterfaceImports[i] := 'Needed' + IntToStr(i);
  lWitness := TDelphiSemanticUnitNameWitnessBuilder.BuildForTest(
    fProject, fModels, '', False, lOptions, lCandidates, lListings, lQueries, lFallbacks);
  Assert.IsNotNull(lWitness);
  Assert.AreEqual(0, lQueries, 'Large name sets must use a directory inventory');
  Assert.AreEqual<NativeInt>(1, Length(lListings), 'Search, browsing and debug roots share one listing');
  Assert.AreEqual(fRoot, lListings[0]);
end;

procedure TUnitNameWitnessTests.DirectoryChangesBetweenListingAndUse(const aShape: string);
var
  lReference, lActual: IDelphiSemanticUnitNameWitness;
  lExpected, lCandidates, lNativeQueries: TArray<string>;
  lOptions: TWitnessLookupTestOptions;
  lQueries, lFallbacks, i: Integer;
begin
  fProject.SearchPaths := [fRoot, TPath.Combine(fRoot, '..\lib\win64\release')];
  SetLength(fModels[0].DependencyFacts.InterfaceImports, 1463);
  fModels[0].DependencyFacts.InterfaceImports[0] := 'U';
  for i := 1 to 1462 do
    fModels[0].DependencyFacts.InterfaceImports[i] := 'Missing' + IntToStr(i);
  lOptions := Default(TWitnessLookupTestOptions);
  lOptions.BeforeEntries :=
    procedure
    begin
      if aShape = 'remove' then
        TFile.Delete(TPath.Combine(fRoot, 'U.pas'))
      else if aShape = 'edit' then
        WriteSource('U.pas', 'unit U; interface type TChanged = Integer; implementation end.')
      else
        WriteSource('new\U.pas', 'unit U; interface implementation end.');
    end;
  lReference := TDelphiSemanticUnitNameWitnessBuilder.BuildForTest(
    fProject, fModels, fRoot, True, lOptions, lExpected, lNativeQueries, lQueries, lFallbacks);
  WriteSource('U.pas', 'unit U; interface type TOther = Integer; implementation end.');
  if aShape = 'add' then
    TFile.Delete(TPath.Combine(fRoot, 'new\U.pas'));
  lActual := TDelphiSemanticUnitNameWitnessBuilder.BuildForTest(
    fProject, fModels, fRoot, False, lOptions, lCandidates, lNativeQueries, lQueries, lFallbacks);
  Assert.AreEqual(string.Join(#10, lExpected), string.Join(#10, lCandidates), 'Listed index');
  Assert.AreEqual(lReference.IdentityText, lActual.IdentityText, 'Read-time identity after drift');
  Assert.AreEqual(lReference.MayDeclare('U', 'Absent'), lActual.MayDeclare('U', 'Absent'));
  Assert.AreEqual(lReference.MayDeclare('U', 'TChanged'), lActual.MayDeclare('U', 'TChanged'));
  Assert.AreEqual(aShape = 'remove', lActual.MayDeclare('U', 'Absent'),
    'A vanished indexed source is unreadable; additions after listing belong to the next witness');
  if aShape = 'edit' then
    Assert.IsTrue(lActual.MayDeclare('U', 'TChanged'), 'Read the changed source bytes');
end;

function CompareWitnessLookup(const aDirectory, aNeededName: string;
  const aExpectBounded: Boolean; const aLines: TStrings;
  const aForcedPreimages: string = ''; const aLookupError: Cardinal = 0): Integer;
var
  lProject: TDelphiSemanticProjectInfo;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lFull, lBounded: IDelphiSemanticUnitNameWitness;
  lExpected, lActual, lNativeQueries: TArray<string>;
  lOptions: TWitnessLookupTestOptions;
  lQuery: string;
  lQueries, lFallbacks, i: Integer;
  lEqual: Boolean;
begin
  lProject := Default(TDelphiSemanticProjectInfo);
  lProject.SearchPaths := [aDirectory];
  SetLength(lModels, 1);
  lModels[0] := Default(TDelphiSemanticUnitModel);
  lModels[0].UnitName := 'Consumer';
  lModels[0].Success := True;
  lModels[0].ScopeModelStatus := 'ast';
  lModels[0].DependencyFacts.Known := True;
  lModels[0].DependencyFacts.InterfaceImports := [aNeededName];
  lFull := TDelphiSemanticUnitNameWitnessBuilder.BuildForTest(
    lProject, lModels, '', True, lExpected);
  lOptions := Default(TWitnessLookupTestOptions);
  lOptions.CaptureNativeQueries := True;
  lOptions.ForcedPreimages := aForcedPreimages;
  lOptions.LookupErrorDirectory := aDirectory;
  lOptions.LookupError := aLookupError;
  lBounded := TDelphiSemanticUnitNameWitnessBuilder.BuildForTest(
    lProject, lModels, '', False, lOptions, lActual, lNativeQueries, lQueries, lFallbacks);
  lEqual := Length(lExpected) = Length(lActual);
  if lEqual then
    for i := 0 to High(lExpected) do
      lEqual := lEqual and (lExpected[i] = lActual[i]);
  lEqual := lEqual and (lFull.IdentityText = lBounded.IdentityText) and
    (lFull.MayDeclare(aNeededName, 'Absent') = lBounded.MayDeclare(aNeededName, 'Absent')) and
    (lFull.MayDeclare(aNeededName, 'TOne') = lBounded.MayDeclare(aNeededName, 'TOne'));
  Result := 0;
  if not lEqual or (aExpectBounded <> (lQueries > 0)) then
    Result := 1;
  if Length(lNativeQueries) <> lQueries then
    Result := 1;
  if (aLookupError <> 0) and (lFallbacks = 0) then
    Result := 1;
  if (aForcedPreimages = 'S') and aExpectBounded then
    for lQuery in lNativeQueries do
      if Pos('?ample', ExtractFileName(lQuery)) <> 1 then
        Result := 1;
  for lQuery in lNativeQueries do
    aLines.Add('native-query=' + lQuery);
  aLines.Add('lookup-fallbacks=' + IntToStr(lFallbacks));
  aLines.Add(Format('case=%s needed=%s expected=%d actual=%d bounded=%d expect-bounded=%s equal=%s failures=%d',
    [aDirectory, aNeededName, Length(lExpected), Length(lActual), lQueries,
    BoolToStr(aExpectBounded, True), BoolToStr(lEqual, True), Result]));
  if not lEqual then
  begin
    for i := 0 to High(lExpected) do
      aLines.Add('  expected=' + lExpected[i]);
    for i := 0 to High(lActual) do
      aLines.Add('  actual=' + lActual[i]);
    aLines.Add('  expected-identity=' + lFull.IdentityText);
    aLines.Add('  actual-identity=' + lBounded.IdentityText);
  end;
end;

procedure TUnitNameWitnessTests.ComparerClassLookupMatchesFullEnumeration;
var
  lBase, lDirectory, lName, lNeeded, lFileName, lReceipt: string;
  lLines: TStringList;
  lFailures, lCases, lCode, lAscii, lPosition, lLength: Integer;
  lCharacter: Char;
begin
  // The caller can repeat the identical generator on independently owned NTFS/ReFS roots.
  lBase := GetEnvironmentVariable('DS768_DIFFERENTIAL_ROOT');
  if lBase = '' then
    lBase := TPath.Combine(fRoot, 'comparer-class');
  TDirectory.CreateDirectory(lBase);
  lReceipt := TPath.Combine(lBase, 'differential-receipt.txt');
  lLines := TStringList.Create;
  try
    lLines.Add('BMP range=U+0000..U+FFFF comparer=TFastCaseAwareComparer.OrdinalIgnoreCase');
    lFailures := 0;
    lCases := 0;
    for lCode := 0 to High(Word) do
      for lAscii := Ord('A') to Ord('Z') do
        if TFastCaseAwareComparer.OrdinalIgnoreCase.Equals(string(Char(lCode)), string(Char(lAscii))) then
        begin
          lLines.Add(Format('preimage=U+%.4X ASCII=%s', [lCode, string(Char(lAscii))]));
          for lPosition := 0 to 2 do
          begin
            lNeeded := 'AsciiUnit';
            lName := lNeeded;
            Insert(string(Char(lAscii)), lNeeded, 1 + lPosition * 4);
            Insert(string(Char(lCode)), lName, 1 + lPosition * 4);
            lDirectory := TPath.Combine(lBase, Format('fold-%.4X-%d', [lCode, lPosition]));
            TDirectory.CreateDirectory(lDirectory);
            TFile.WriteAllText(TPath.Combine(lDirectory, lName + '.dcu'), 'DCU');
            Inc(lFailures, CompareWitnessLookup(lDirectory, lNeeded, True, lLines));
            Inc(lCases);
            // Reverse direction in a separate layout, containing the ASCII spelling.
            lDirectory := lDirectory + '-reverse';
            TDirectory.CreateDirectory(lDirectory);
            TFile.WriteAllText(TPath.Combine(lDirectory, lNeeded + '.dcu'), 'DCU');
            Inc(lFailures, CompareWitnessLookup(lDirectory, lName, lCode < 128, lLines));
            Inc(lCases);
          end;
          // The RTL extension matcher is part of the reference contract too.
          for lCharacter in ['p', 'a', 's', 'd', 'c', 'u'] do
            if TFastCaseAwareComparer.OrdinalIgnoreCase.Equals(string(Char(lCode)), string(lCharacter)) then
            begin
              lName := 'AsciiUnit.pas';
              if CharInSet(lCharacter, ['d', 'c', 'u']) then
                lName := 'AsciiUnit.dcu';
              lName := StringReplace(lName, string(lCharacter), string(Char(lCode)), []);
              lDirectory := TPath.Combine(lBase, Format('extension-%.4X', [lCode]));
              TDirectory.CreateDirectory(lDirectory);
              TFile.WriteAllText(TPath.Combine(lDirectory, lName), 'DCU');
              Inc(lFailures, CompareWitnessLookup(lDirectory, 'AsciiUnit', True, lLines));
              Inc(lCases);
            end;
        end;
    for lCharacter in string(#$00C4 + #$03A9 + #$0131 + #$017F + #$212A) do
    begin
      lNeeded := 'Unit' + lCharacter;
      lDirectory := TPath.Combine(lBase, 'non-ascii-' + IntToHex(Ord(lCharacter), 4));
      TDirectory.CreateDirectory(lDirectory);
      TFile.WriteAllText(TPath.Combine(lDirectory, lNeeded + '.pas'),
        'unit ' + lNeeded + '; interface implementation end.', TEncoding.UTF8);
      Inc(lFailures, CompareWitnessLookup(lDirectory, lNeeded, False, lLines));
      Inc(lCases);
    end;
    // Both hits and misses must enter the native path on local supported volumes.
    lDirectory := TPath.Combine(lBase, 'ascii');
    TDirectory.CreateDirectory(lDirectory);
    TFile.WriteAllText(TPath.Combine(lDirectory, 'AsciiUnit.dcu'), 'DCU');
    Inc(lFailures, CompareWitnessLookup(lDirectory, 'AsciiUnit', True, lLines));
    Inc(lFailures, CompareWitnessLookup(lDirectory, 'Absent', True, lLines));
    Inc(lCases, 2);
    for lNeeded in ['Unit-Name', 'Unit?Name', '', '.Unit', 'Unit..Name'] do
    begin
      Inc(lFailures, CompareWitnessLookup(lDirectory, lNeeded, False, lLines));
      Inc(lCases);
    end;
    // DOS device parsing applies before the first dot, including dotted units.
    for lNeeded in ['CON', 'PRN', 'AUX', 'NUL', 'Aux.Utils', 'com0', 'COM1', 'COM2',
      'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9', 'lpt0', 'LPT1', 'LPT2',
      'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9'] do
    begin
      Inc(lFailures, CompareWitnessLookup(lDirectory, lNeeded, False, lLines));
      Inc(lCases);
    end;
    for lLength := 257 to 261 do
    begin
      lNeeded := 'Vcl.Graphics';
      lDirectory := TPath.Combine(lBase, 'length-' + IntToStr(lLength));
      lDirectory := TPath.Combine(lDirectory,
        StringOfChar('x', lLength - Length(lDirectory) - Length(lNeeded) - 6));
      TDirectory.CreateDirectory(lDirectory);
      lFileName := TPath.Combine(lDirectory, lNeeded + '.dcu');
      Assert.AreEqual(lLength, Length(lFileName), 'Generator path length');
      TFile.WriteAllText('\\?\' + lFileName, 'DCU');
      Inc(lFailures, CompareWitnessLookup(lDirectory, lNeeded, lLength < MAX_PATH - 1, lLines));
      Inc(lCases);
    end;
    lDirectory := TPath.Combine(lBase, 'nonexistent');
    Inc(lFailures, CompareWitnessLookup(lDirectory, 'AsciiUnit', False, lLines));
    Inc(lCases);
    // Native errors are injected per instance: ACL privileges differ by session.
    // The reference still enumerates a real populated directory.
    lDirectory := TPath.Combine(lBase, 'lookup-error');
    TDirectory.CreateDirectory(lDirectory);
    TFile.WriteAllText(TPath.Combine(lDirectory, 'AsciiUnit.dcu'), 'DCU');
    Inc(lFailures, CompareWitnessLookup(lDirectory, 'AsciiUnit', True, lLines,
      '', ERROR_ACCESS_DENIED));
    Inc(lCases);
    // Exercise the actual mask/separator implementation even on hosts whose
    // comparer has no non-ASCII preimages. Capture the native query itself.
    TFile.WriteAllText(TPath.Combine(lDirectory, 'Sample.dcu'), 'DCU');
    TFile.WriteAllText(TPath.Combine(lDirectory, 'Xample.dcu'), 'must be filtered');
    Inc(lFailures, CompareWitnessLookup(lDirectory, 'Sample', True, lLines, 'S'));
    Inc(lFailures, CompareWitnessLookup(lDirectory, 'Sample', False, lLines, '.'));
    Inc(lCases, 2);
    lLines.Add(Format('cases=%d failures=%d', [lCases, lFailures]));
    lLines.SaveToFile(lReceipt, TEncoding.UTF8);
    Assert.AreEqual(0, lFailures, 'Differential mismatches; receipt: ' + lReceipt);
  finally
    // Preserve partial setup evidence as well as assertion failures.
    lLines.SaveToFile(lReceipt, TEncoding.UTF8);
    lLines.Free;
  end;
end;

procedure TUnitNameWitnessTests.ChangedProfilePathGetsFreshScan;
var
  lFirst, lUnchanged, lChanged, lRestored: IDelphiSemanticUnitNameWitness;
  lProfileRoot: string;
begin
  lFirst := Witness;
  Assert.IsFalse(lFirst.MayDeclare('U', 'Absent'), lFirst.IdentityText);
  lProfileRoot := TPath.Combine(fRoot, '..\..\profile');
  WriteSource('..\..\profile\U.dcu', 'A second physical candidate');
  lUnchanged := Witness;
  Assert.AreEqual(lFirst.IdentityText, lUnchanged.IdentityText,
    'The extra file is outside every current lookup root.');
  SetLength(fProject.Properties, 1);
  fProject.Properties[0].Name := 'DSWitnessProfilePaths';
  fProject.Properties[0].Value := lProfileRoot;
  lChanged := Witness;
  Assert.IsTrue(lChanged.MayDeclare('U', 'Absent'), lChanged.IdentityText);
  Assert.AreNotEqual(lFirst.IdentityText, lChanged.IdentityText);
  fProject.Properties := nil;
  lRestored := Witness;
  Assert.AreEqual(lFirst.IdentityText, lRestored.IdentityText);
  TFile.Delete(TPath.Combine(lProfileRoot, 'U.dcu'));
end;

procedure TUnitNameWitnessTests.DirectoryInventoryNoticesAddedAndRemovedCandidates;
var
  lFirst, lAdded, lRemoved: IDelphiSemanticUnitNameWitness;
begin
  lFirst := Witness;
  Assert.IsFalse(lFirst.MayDeclare('U', 'Absent'), 'Initial: ' + lFirst.IdentityText);
  WriteSource('nested\U.pas', 'unit U; interface implementation end.');
  lAdded := Witness;
  Assert.IsTrue(lAdded.MayDeclare('U', 'Absent'), 'The additional source is ambiguous.');
  Assert.IsTrue(Pos('ambiguous-source', lAdded.IdentityText) > 0, lAdded.IdentityText);
  TFile.Delete(TPath.Combine(fRoot, 'nested\U.pas'));
  lRemoved := Witness;
  Assert.IsFalse(lRemoved.MayDeclare('U', 'Absent'), 'Removed: ' + lRemoved.IdentityText);
  Assert.AreEqual(lFirst.IdentityText, lRemoved.IdentityText);
end;

procedure TUnitNameWitnessTests.ProjectSourceCannotProveAbsence;
var
  lWitness: IDelphiSemanticUnitNameWitness;
begin
  lWitness := TDelphiSemanticUnitNameWitnessBuilder.Build(fProject, fModels, '');
  Assert.IsTrue(lWitness.MayDeclare('U', 'Absent'), 'A4: unpaired project source is unknown');
end;

procedure TUnitNameWitnessTests.SdkSourceWithoutDcuCannotProveAbsence;
begin
  TFile.Delete(TPath.Combine(fRoot, 'U.pas'));
  WriteSource('sdk\source\U.pas', 'unit U; interface implementation end.');
  Assert.IsTrue(Witness(TPath.Combine(fRoot, 'sdk\source')).MayDeclare('U', 'Absent'));
end;

procedure TUnitNameWitnessTests.SdkIncludesStayInsideInstallation(const aShape: string);
var
  lWitness: IDelphiSemanticUnitNameWitness;
begin
  TFile.Delete(TPath.Combine(fRoot, 'U.pas'));
  WriteSource('sdk\lib\win64\release\U.dcu', 'SDK unit');
  WriteSource('sdk\source\data\U.pas', 'unit U; interface {$I sub/outer.inc} implementation end.');
  WriteSource('sdk\source\data\sub\outer.inc', '{$I names.inc}');
  fProject.SearchPaths := [fRoot, TPath.Combine(fRoot, 'sdk\lib\win64\release')];
  fProject.IncludePaths := [fRoot];
  WriteSource('names.inc', 'type TX = Integer;');
  if MatchText(aShape, ['nested', 'ambiguous']) then
    WriteSource('sdk\source\data\names.inc', 'type TX = Integer;');
  if aShape = 'ambiguous' then
    WriteSource('sdk\source\data\sub\names.inc', 'type TY = Integer;');
  if aShape = 'escape' then
  begin
    WriteSource('sdk\source\data\sub\outer.inc', '{$I ../../../outside.inc}');
    WriteSource('sdk\outside.inc', 'type TY = Integer;');
  end;
  lWitness := Witness(TPath.Combine(fRoot, 'sdk\source'));
  Assert.AreEqual(aShape <> 'nested', lWitness.MayDeclare('U', 'Absent'), lWitness.IdentityText);
  Assert.IsTrue(lWitness.MayDeclare('U', 'TX'), lWitness.IdentityText);
end;

procedure TUnitNameWitnessTests.DefaultAliasesRespectPlatformAndUncertainty(const aShape: string);
var
  lWitness: IDelphiSemanticUnitNameWitness;
  lRoot, lTarget: string;
begin
  TFile.Delete(TPath.Combine(fRoot, 'U.pas'));
  fModels[0].DependencyFacts.InterfaceImports := ['WinTypes'];
  fProject.Platform := 'Win64';
  fProject.SearchPaths := [TPath.Combine(fRoot, 'sdk\lib\win64\release')];
  if aShape = 'other' then
    fProject.Platform := 'Linux64';
  lTarget := 'Winapi.Windows';
  if aShape = 'conflict' then
  begin
    fProject.UnitAliases := ['WinTypes=Custom.Windows'];
    lTarget := 'Custom.Windows';
  end else if aShape = 'project-conflict' then
    fProject.UnitAliases := ['WinTypes=Winapi.Windows', 'WinTypes=Custom.Windows']
  else if aShape = 'duplicate' then
    fProject.UnitAliases := ['WinTypes=Winapi.Windows', 'WinTypes=Winapi.Windows']
  else if aShape = 'other' then
    lTarget := 'WinTypes';
  WriteSource('sdk\source\rtl\' + lTarget + '.pas',
    'unit ' + lTarget + '; interface implementation end.');
  WriteSource('sdk\lib\win64\release\' + lTarget + '.dcu', 'SDK unit');
  if aShape = 'extra' then
    WriteSource('sdk\source\rtl\WinTypes.pas', 'unit WinTypes; interface implementation end.');
  if aShape <> 'missing' then
    WriteSource('sdk\bin\CodeGear.Common.Targets',
      '<Project><PropertyGroup><cWin64Platform>Win64</cWin64Platform>' +
      '<UnitAliases>Generics.Collections=System.Generics.Collections</UnitAliases>' +
      '<UnitAliases Condition="''$(Platform)''==''$(cWin64Platform)''">' +
      '$(UnitAliases);WinTypes=Winapi.Windows</UnitAliases>' +
      '<UnitAliases Condition="''$(DCC_UnitAlias)''!=''''">$(DCC_UnitAlias)$(UnitAliases)</UnitAliases>' +
      '</PropertyGroup></Project>');
  if aShape = 'malformed' then
    WriteSource('sdk\bin\CodeGear.Common.Targets', '<Project>');
  lRoot := TPath.Combine(fRoot, 'sdk\source');
  lWitness := Witness(lRoot);
  Assert.AreEqual(MatchText(aShape, ['missing', 'malformed', 'extra', 'conflict', 'project-conflict']),
    lWitness.MayDeclare('WinTypes', 'Absent'), lWitness.IdentityText);
end;

procedure TUnitNameWitnessTests.ScopedAliasCandidatesUsePhysicalIdentity(const aExtraFile: Boolean);
var
  lWitness: IDelphiSemanticUnitNameWitness;
begin
  TFile.Delete(TPath.Combine(fRoot, 'U.pas'));
  fModels[0].DependencyFacts.InterfaceImports := ['Generics.Collections'];
  fProject.UnitScopeNames := ['System'];
  fProject.UnitAliases := ['Generics.Collections=System.Generics.Collections'];
  WriteSource('..\bin\CodeGear.Common.Targets',
    '<Project><PropertyGroup><UnitAliases>' +
    'Generics.Collections=System.Generics.Collections</UnitAliases></PropertyGroup></Project>');
  WriteSource('System.Generics.Collections.pas',
    'unit System.Generics.Collections; interface implementation end.');
  WriteSource('..\lib\win64\release\System.Generics.Collections.dcu', 'SDK unit');
  if aExtraFile then
    WriteSource('Generics.Collections.pas',
      'unit Generics.Collections; interface type TX = Integer; implementation end.');
  lWitness := Witness;
  Assert.AreEqual(aExtraFile, lWitness.MayDeclare('Generics.Collections', 'Absent'),
    lWitness.IdentityText);
end;

procedure TUnitNameWitnessTests.TokensAreCaseInsensitiveAndIncludeEscapedIdentifiers;
var
  lWitness: IDelphiSemanticUnitNameWitness;
begin
  WriteSource('U.pas', 'unit U; interface type &Escaped = Integer; ' +
    '// comment TX'#13#10 + 'implementation const S = ''TStringToken''; end.');
  lWitness := Witness;
  Assert.IsFalse(lWitness.MayDeclare('U', 'Absent'));
  Assert.IsTrue(lWitness.MayDeclare('u', 'escaped'));
  Assert.IsTrue(lWitness.MayDeclare('U', 'tx'));
  Assert.IsTrue(lWitness.MayDeclare('U', 'TStringToken'));
  Assert.IsTrue(lWitness.MayDeclare('Missing', 'Absent'));
  Assert.IsTrue(lWitness.MayDeclare('<imports-unproved>', 'Absent'));
  Assert.IsTrue(lWitness.MayDeclare('U', 'A.B'));
end;

procedure TUnitNameWitnessTests.SourceAndIncludeBytesInvalidateIdentity;
var
  lFirst, lSecond: IDelphiSemanticUnitNameWitness;
begin
  WriteSource('U.pas', 'unit U; interface {$I names.inc} implementation end.');
  WriteSource('names.inc', 'type TOther = Integer;');
  lFirst := Witness;
  Assert.IsFalse(lFirst.MayDeclare('U', 'Absent'));
  lSecond := Witness;
  Assert.AreEqual(lFirst.IdentityText, lSecond.IdentityText);
  WriteSource('names.inc', 'type TOther = Integer; ');
  lSecond := Witness;
  Assert.AreNotEqual(lFirst.IdentityText, lSecond.IdentityText);
  lFirst := lSecond;
  WriteSource('U.pas', 'unit U; interface {$I names.inc} implementation end. ');
  lSecond := Witness;
  Assert.AreNotEqual(lFirst.IdentityText, lSecond.IdentityText);
end;

procedure TUnitNameWitnessTests.IncludesAreFollowedAndCyclesTerminate;
var
  lWitness: IDelphiSemanticUnitNameWitness;
begin
  WriteSource('U.pas', 'unit U; interface (*$INCLUDE ''a.inc''*) implementation end.');
  WriteSource('a.inc', '{$I b.inc} type FromA = Integer;');
  WriteSource('b.inc', '{$I a.inc} type FromB = Integer;');
  lWitness := Witness;
  Assert.IsFalse(lWitness.MayDeclare('U', 'Absent'));
  Assert.IsTrue(lWitness.MayDeclare('U', 'FromA'));
  Assert.IsTrue(lWitness.MayDeclare('U', 'FromB'));
end;

procedure TUnitNameWitnessTests.UnknownSourcesCannotProveAbsence(const aReason: string);
var
  lWitness: IDelphiSemanticUnitNameWitness;
  lRtlRoot: string;
begin
  // Each case first exercises a real absence proof; an always-unknown stub must fail.
  Assert.IsFalse(Witness.MayDeclare('U', 'Absent'));
  lRtlRoot := '';
  if aReason = 'no-source' then
    TFile.Delete(TPath.Combine(TPath.GetDirectoryName(fRoot), 'lib\win64\release\U.dcu'));
  if aReason = 'unit-name-mismatch' then
    WriteSource('U.pas', 'unit WrongName; interface implementation end.')
  else if aReason = 'include-unresolved' then
    WriteSource('U.pas', 'unit U; interface // {$I missing.inc}'#13#10 + 'implementation end.')
  else begin
    TFile.Delete(TPath.Combine(fRoot, 'U.pas'));
    if aReason = 'dcu-only' then
      WriteSource('U.dcu', 'not a source file')
    else if aReason = 'ambiguous-source' then
    begin
      WriteSource('rtl\one\U.pas', 'unit U; interface implementation end.');
      WriteSource('rtl\two\U.pas', 'unit U; interface implementation end.');
      lRtlRoot := TPath.Combine(fRoot, 'rtl');
    end;
  end;
  lWitness := Witness(lRtlRoot);
  Assert.IsTrue(lWitness.MayDeclare('U', 'Absent'));
  Assert.IsTrue(lWitness.IdentityText.Contains('|unknown|' + aReason), lWitness.IdentityText);
end;

procedure TUnitNameWitnessTests.DuplicateLookupDirectoriesAreUnknown(const aExtension: string);
var
  lWitness: IDelphiSemanticUnitNameWitness;
begin
  Assert.IsFalse(Witness.MayDeclare('U', 'TX'));
  WriteSource('lib\U.' + aExtension, 'unit U; interface type TX = Integer; implementation end.');
  fProject.SearchPaths := [fRoot, TPath.Combine(fRoot, 'lib'), fRoot];
  lWitness := Witness;
  Assert.IsTrue(lWitness.MayDeclare('U', 'TX'));
  Assert.IsTrue(lWitness.IdentityText.Contains('|unknown|ambiguous-source'), lWitness.IdentityText);
end;

procedure TUnitNameWitnessTests.DirectiveWhitespaceFollowsIncludes(
  const aSpelling, aWhitespace, aForm: string);
var
  lDirective, lSpace: string;
  lFirst, lSecond: IDelphiSemanticUnitNameWitness;
begin
  lSpace := #9;
  if aWhitespace = 'newline' then
    lSpace := #13#10;
  lDirective := '{$' + aSpelling + lSpace + 'names.inc}';
  if aForm = 'paren' then
    lDirective := '(*$' + aSpelling + lSpace + 'names.inc*)';
  WriteSource('U.pas', 'unit U; interface ' + lDirective + ' implementation end.');
  WriteSource('names.inc', 'type TX = Integer;');
  lFirst := Witness;
  Assert.IsTrue(lFirst.MayDeclare('U', 'TX'));
  Assert.IsFalse(lFirst.MayDeclare('U', 'Absent'));
  Assert.IsTrue(lFirst.IdentityText.Contains('witness-include=U|'), lFirst.IdentityText);
  WriteSource('names.inc', 'type TY = Integer;');
  lSecond := Witness;
  Assert.AreNotEqual(lFirst.IdentityText, lSecond.IdentityText);
  Assert.IsFalse(lSecond.MayDeclare('U', 'TX'));
end;

procedure TUnitNameWitnessTests.CandidateLocationUnionCannotProveAbsence(const aShape: string);
var
  lWitness: IDelphiSemanticUnitNameWitness;
  lRtlRoot, lPropertyName, lExtension: string;
begin
  Assert.IsFalse(Witness.MayDeclare('U', 'TX'));
  lRtlRoot := '';
  if aShape = 'rtl' then
  begin
    WriteSource('rtl\U.pas', 'unit U; interface type TX = Integer; implementation end.');
    lRtlRoot := TPath.Combine(fRoot, 'rtl');
  end else if aShape = 'colocated' then
    WriteSource('U.dcu', 'compiled unit')
  else begin
    lPropertyName := 'DelphiLibraryPath';
    if aShape.StartsWith('browsing') then
      lPropertyName := 'DelphiBrowsingPath';
    lExtension := 'pas';
    if aShape.EndsWith('dcu') then
      lExtension := 'dcu';
    WriteSource('..\..\profile\U.' + lExtension, 'unit U; interface type TX = Integer; implementation end.');
    SetLength(fProject.Properties, 1);
    fProject.Properties[0].Name := lPropertyName;
    fProject.Properties[0].Value := TPath.Combine(fRoot, '..\..\profile');
  end;
  lWitness := Witness(lRtlRoot);
  Assert.IsTrue(lWitness.MayDeclare('U', 'TX'), aShape);
  Assert.IsTrue(lWitness.IdentityText.Contains('|unknown|ambiguous-source'), lWitness.IdentityText);
end;

procedure TUnitNameWitnessTests.IncludeDirectiveGrammar(const aDirective, aExpected: string);
begin
  Assert.AreEqual(aExpected,
    TDelphiSemanticPreprocessor.IncludeArgumentFromDirective(aDirective));
  if aExpected = '' then
  begin
    WriteSource('U.pas', 'unit U; interface {$' + aDirective + '} implementation end.');
    Assert.IsFalse(Witness.MayDeclare('U', 'Absent'), aDirective);
  end;
end;

procedure TUnitNameWitnessTests.PlusIncludeContentChangesIdentity(const aForm: string);
var
  lFirst, lSecond: IDelphiSemanticUnitNameWitness;
  lDirective: string;
begin
  lDirective := '{$INCLUDE+names.inc}';
  if aForm = 'paren' then
    lDirective := '(*$INCLUDE+names.inc*)';
  WriteSource('U.pas', 'unit U; interface ' + lDirective + ' implementation end.');
  WriteSource('+names.inc', 'type TX = Integer;');
  lFirst := Witness;
  Assert.IsTrue(lFirst.MayDeclare('U', 'TX'));
  Assert.IsFalse(lFirst.MayDeclare('U', 'Absent'));
  Assert.IsTrue(lFirst.IdentityText.Contains('witness-include=U|'), lFirst.IdentityText);
  WriteSource('+names.inc', 'type TY = Integer;');
  lSecond := Witness;
  Assert.AreNotEqual(lFirst.IdentityText, lSecond.IdentityText);
  Assert.IsFalse(lSecond.MayDeclare('U', 'TX'));
end;

procedure TUnitNameWitnessTests.CallerSearchPathsJoinWitnessCandidates;
var
  lOptions: TDelphiSemanticOptions;
  lContext: TDelphiSemanticContextResult;
  lWitness: IDelphiSemanticUnitNameWitness;
begin
  WriteSource('P.dpr', 'program P; begin end.');
  WriteSource('P.dproj', '<Project><PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup></Project>');
  WriteSource('thirdlib\U.dcu', 'command-line-only candidate');
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.SearchPaths := [TPath.Combine(fRoot, 'thirdlib'),
    TPath.Combine(fRoot, '..\lib\win64\release')];
  lContext := TDelphiSemanticProject.Load(TPath.Combine(fRoot, 'P.dproj'), lOptions);
  Assert.IsTrue(lContext.Success);
  lWitness := TDelphiSemanticUnitNameWitnessBuilder.Build(lContext.Project, fModels, fRoot);
  Assert.IsTrue(lWitness.MayDeclare('U', 'Absent'), lWitness.IdentityText);
  Assert.IsTrue(lWitness.IdentityText.Contains('|unknown|ambiguous-source'), lWitness.IdentityText);
end;

procedure TUnitNameWitnessTests.DcpOnlyUnitStaysUnknown;
var
  lWitness: IDelphiSemanticUnitNameWitness;
begin
  fModels[0].DependencyFacts.InterfaceImports := ['PackageUnit'];
  WriteSource('thirdlib\CustomPackage.dcp', 'package contains PackageUnit');
  fProject.SearchPaths := [TPath.Combine(fRoot, 'thirdlib')];
  lWitness := Witness;
  Assert.IsTrue(lWitness.MayDeclare('PackageUnit', 'TX'), lWitness.IdentityText);
end;

procedure TUnitNameWitnessTests.RuntimePackagesCannotProveSdkAbsence(const aEnabled: Boolean);
var
  lWitness: IDelphiSemanticUnitNameWitness;
begin
  SetLength(fProject.Properties, 2);
  fProject.Properties[0].Name := 'DCC_UsePackage';
  fProject.Properties[0].Value := 'CustomPackage';
  fProject.Properties[1].Name := 'DCC_EnabledPackages';
  fProject.Properties[1].Value := BoolToStr(aEnabled, True);
  lWitness := Witness;
  Assert.AreEqual(aEnabled, lWitness.MayDeclare('U', 'Absent'), lWitness.IdentityText);
end;

procedure TUnitNameWitnessTests.ProfileFileCandidatesChangeWitnessIdentity;
var
  lOptions: TDelphiSemanticOptions;
  lContext: TDelphiSemanticContextResult;
  lFirst, lSecond: IDelphiSemanticUnitNameWitness;
begin
  WriteSource('P.dproj', '<Project><PropertyGroup><Platform>Win64</Platform>' +
    '<BDSUSERDIR /><BDSCOMMONDIR /></PropertyGroup></Project>');
  WriteSource('profile.proj', '<Project><PropertyGroup><DelphiLibraryPath>' +
    TPath.Combine(fRoot, '..\..\profile') + '</DelphiLibraryPath><DelphiBrowsingPath />' +
    '</PropertyGroup></Project>');
  WriteSource('..\..\profile\U.dcu', 'compiled unit');
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.DelphiVersion := '23.0';
  lOptions.Platform := 'Win64';
  lOptions.EnvOptionsPath := TPath.Combine(fRoot, 'profile.proj');
  lOptions.ProfileInputs := TIsolatedProfileInputs.Create;
  lContext := TDelphiSemanticProject.Load(TPath.Combine(fRoot, 'P.dproj'), lOptions);
  Assert.IsTrue(lContext.Success);
  lContext.Project.SearchPaths := lContext.Project.SearchPaths +
    [TPath.Combine(TPath.GetDirectoryName(fRoot), 'lib\win64\release')];
  lFirst := TDelphiSemanticUnitNameWitnessBuilder.Build(lContext.Project, fModels, fRoot);
  Assert.IsTrue(lFirst.MayDeclare('U', 'TX'));
  Assert.IsTrue(lFirst.IdentityText.Contains('|unknown|ambiguous-source'), lFirst.IdentityText);
  WriteSource('profile.proj', '<Project><PropertyGroup><DelphiLibraryPath />' +
    '<DelphiBrowsingPath /></PropertyGroup></Project>');
  lContext := TDelphiSemanticProject.Load(TPath.Combine(fRoot, 'P.dproj'), lOptions);
  Assert.IsTrue(lContext.Success);
  lContext.Project.SearchPaths := lContext.Project.SearchPaths +
    [TPath.Combine(TPath.GetDirectoryName(fRoot), 'lib\win64\release')];
  lSecond := TDelphiSemanticUnitNameWitnessBuilder.Build(lContext.Project, fModels, fRoot);
  Assert.IsFalse(lSecond.MayDeclare('U', 'TX'));
  Assert.AreNotEqual(lFirst.IdentityText, lSecond.IdentityText);
end;

procedure TUnitNameWitnessTests.SdkPairingDoesNotHideExtraCandidates(const aShape: string);
var
  lRoot, lLibrary: string;
  lWitness: IDelphiSemanticUnitNameWitness;
begin
  TFile.Delete(TPath.Combine(fRoot, 'U.pas'));
  WriteSource('sdk\lib\win64\release\U.dcu', 'compiled SDK unit');
  WriteSource('sdk\source\data\U.pas', 'unit U; interface implementation end.');
  lRoot := TPath.Combine(fRoot, 'sdk\source');
  SetLength(fProject.Properties, 1);
  fProject.Properties[0].Name := 'DelphiLibraryPath';
  fProject.Properties[0].Value := TPath.Combine(fRoot, 'sdk\lib\win64\release');
  Assert.IsFalse(Witness(lRoot).MayDeclare('U', 'Absent'), 'Paired readable control: ' + aShape);
  if aShape = 'dcu-only' then
    TFile.Delete(TPath.Combine(fRoot, 'sdk\source\data\U.pas'));
  if aShape = 'project-source' then
    WriteSource('U.pas', 'unit U; interface implementation end.');
  if aShape = 'second-sdk-source' then
    WriteSource('sdk\source\other\U.pas', 'unit U; interface implementation end.');
  if aShape = 'external-dcu' then
    WriteSource('U.dcu', 'compiled project unit');
  if aShape = 'other-installation' then
    WriteSource('sdk2\lib\win64\release\U.dcu', 'compiled other SDK unit');
  lRoot := TPath.Combine(fRoot, 'sdk\source');
  lLibrary := TPath.Combine(fRoot, 'sdk\lib\win64\release');
  if aShape = 'other-installation' then
    lLibrary := lLibrary + ';' + TPath.Combine(fRoot, 'sdk2\lib\win64\release');
  SetLength(fProject.Properties, 1);
  fProject.Properties[0].Name := 'DelphiLibraryPath';
  fProject.Properties[0].Value := lLibrary;
  lWitness := Witness(lRoot);
  Assert.AreEqual(aShape <> 'pair', lWitness.MayDeclare('U', 'Absent'), aShape);
  var lPairing: IDelphiSemanticSdkUnitPairing;
  Assert.IsTrue(Supports(lWitness, IDelphiSemanticSdkUnitPairing, lPairing));
  Assert.AreEqual(aShape = 'pair', lPairing.IsSdkPaired('U'),
    'DS-719 2.10: helper exemption requires the same conservative SDK pairing.');
  if aShape = 'pair' then
    Assert.IsTrue(lWitness.IdentityText.Contains('witness=U|'), lWitness.IdentityText)
  else
    Assert.IsTrue(lWitness.IdentityText.Contains('|unknown|'), lWitness.IdentityText);
end;

procedure TUnitNameWitnessTests.EveryDirectiveOpenerIsConsidered(const aShape: string);
var
  lPrefix, lInclude: string;
  lFirst, lSecond: IDelphiSemanticUnitNameWitness;
begin
  lPrefix := 'const Marker = ''{$notinclude'';';
  lInclude := '{$I names.inc}';
  if aShape = 'line' then
    lPrefix := '// {$notinclude'
  else if aShape = 'brace' then
  begin
    lPrefix := '{ (*$notinclude }';
    lInclude := '(*$I names.inc*)';
  end else if aShape = 'paren' then
    lPrefix := '(* {$notinclude *)'
  else if aShape = 'multiline' then
    lPrefix := 'const Marker = ' + StringOfChar('''', 3) + #13#10 +
      '  {$notinclude' + #13#10 + '  ' + StringOfChar('''', 3) + ';'
  else if aShape = 'uncertain' then
    lPrefix := 'const Marker = ''{$I missing.inc'';';
  WriteSource('U.pas', 'unit U; interface ' + lPrefix + #13#10 +
    lInclude + ' implementation end.');
  WriteSource('names.inc', 'type TX = Integer;');
  lFirst := Witness;
  Assert.IsTrue(lFirst.MayDeclare('U', 'TX'), aShape);
  if aShape <> 'uncertain' then
  begin
    Assert.IsFalse(lFirst.MayDeclare('U', 'Absent'), aShape);
    WriteSource('names.inc', 'type TY = Integer;');
    lSecond := Witness;
    Assert.AreNotEqual(lFirst.IdentityText, lSecond.IdentityText, aShape);
    Assert.IsFalse(lSecond.MayDeclare('U', 'TX'), aShape);
  end;
end;

procedure TUnitNameWitnessTests.DebugDcuPathsAreCandidateLocations(const aOrigin: string);
var
  lOptions: TDelphiSemanticOptions;
  lContext: TDelphiSemanticContextResult;
  lWitness: IDelphiSemanticUnitNameWitness;
  lPaths: string;
begin
  WriteSource('..\..\dbg\U.dcu', 'compiled debug unit');
  lPaths := '<DelphiDebugDCUPath>' + TPath.Combine(fRoot, '..\..\dbg') + '</DelphiDebugDCUPath>';
  if aOrigin = 'project' then
  begin
    SetLength(fProject.Properties, 1);
    fProject.Properties[0].Name := 'DelphiDebugDCUPath';
    fProject.Properties[0].Value := TPath.Combine(fRoot, '..\..\dbg');
  end else begin
    WriteSource('P.dproj', '<Project><PropertyGroup><Platform>Win64</Platform>' +
      '<BDSUSERDIR /><BDSCOMMONDIR /></PropertyGroup></Project>');
    WriteSource('profile.proj', '<Project><PropertyGroup><DelphiLibraryPath />' +
      '<DelphiBrowsingPath />' + lPaths + '</PropertyGroup></Project>');
    lOptions := Default(TDelphiSemanticOptions);
    lOptions.DelphiVersion := '23.0';
    lOptions.Platform := 'Win64';
    lOptions.EnvOptionsPath := TPath.Combine(fRoot, 'profile.proj');
    lOptions.ProfileInputs := TIsolatedProfileInputs.Create;
    lContext := TDelphiSemanticProject.Load(TPath.Combine(fRoot, 'P.dproj'), lOptions);
    Assert.IsTrue(lContext.Success);
    fProject.Properties := lContext.Project.Properties;
  end;
  lWitness := Witness;
  Assert.IsTrue(lWitness.MayDeclare('U', 'TX'), aOrigin);
  Assert.IsTrue(lWitness.IdentityText.Contains('|unknown|ambiguous-source'), lWitness.IdentityText);
end;

procedure TUnitNameWitnessTests.TranslatedPathsRequireLanguage(
  const aOrigin, aProperty, aLanguage: string);
var
  lOptions: TDelphiSemanticOptions;
  lContext: TDelphiSemanticContextResult;
  lWitness: IDelphiSemanticUnitNameWitness;
  lPath, lProperties: string;
begin
  WriteSource('..\..\translated\U.dcu', 'compiled translated unit');
  lPath := TPath.Combine(fRoot, '..\..\translated');
  if aLanguage = '' then
    lPath := '$(UnresolvedTranslation)';
  if aOrigin = 'project' then
  begin
    SetLength(fProject.Properties, 2);
    fProject.Properties[0].Name := aProperty;
    fProject.Properties[0].Value := lPath;
    fProject.Properties[1].Name := 'LANGDIR';
    fProject.Properties[1].Value := aLanguage;
  end else begin
    WriteSource('P.dproj', '<Project><PropertyGroup><Platform>Win64</Platform>' +
      '<BDSUSERDIR /><BDSCOMMONDIR /></PropertyGroup></Project>');
    lProperties := '<DelphiLibraryPath /><DelphiBrowsingPath /><LANGDIR>' + aLanguage +
      '</LANGDIR><' + aProperty + '>' + lPath + '</' + aProperty + '>';
    WriteSource('profile.proj', '<Project><PropertyGroup>' + lProperties + '</PropertyGroup></Project>');
    lOptions := Default(TDelphiSemanticOptions);
    lOptions.DelphiVersion := '23.0';
    lOptions.Platform := 'Win64';
    lOptions.EnvOptionsPath := TPath.Combine(fRoot, 'profile.proj');
    lOptions.ProfileInputs := TIsolatedProfileInputs.Create;
    lContext := TDelphiSemanticProject.Load(TPath.Combine(fRoot, 'P.dproj'), lOptions);
    Assert.IsTrue(lContext.Success);
    fProject.Properties := lContext.Project.Properties;
  end;
  lWitness := Witness;
  Assert.AreEqual(aLanguage <> '', lWitness.MayDeclare('U', 'TX'), lWitness.IdentityText);
end;

initialization
  TDUnitX.RegisterTestFixture(TUnitNameWitnessTests);

end.
