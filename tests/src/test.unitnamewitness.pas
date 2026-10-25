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
    [Test]
    procedure ProjectSourceCannotProveAbsence;
    [TestCase('Project include only', 'project')]
    [TestCase('Two SDK include candidates', 'ambiguous')]
    [TestCase('Nested root fallback', 'nested')]
    [TestCase('Parent escapes source', 'escape')]
    procedure SdkIncludesStayInsideInstallation(const aShape: string);
    [TestCase('Installed Windows aliases', 'windows')]
    [TestCase('Default/project conflict', 'conflict')]
    [TestCase('Project conflict', 'project-conflict')]
    [TestCase('Exact duplicate', 'duplicate')]
    [TestCase('Alias key and target', 'extra')]
    [TestCase('Missing targets', 'missing')]
    [TestCase('Malformed targets', 'malformed')]
    [TestCase('Other platform', 'other')]
    procedure DefaultAliasesRespectPlatformAndUncertainty(const aShape: string);
    [Test]
    procedure SdkSourceWithoutDcuCannotProveAbsence;
    [TestCase('Same physical candidate', 'False')]
    [TestCase('Different physical candidates', 'True')]
    procedure ScopedAliasCandidatesUsePhysicalIdentity(const aExtraFile: Boolean);
    [Test]
    procedure TokensAreCaseInsensitiveAndIncludeEscapedIdentifiers;
    [Test]
    procedure SourceAndIncludeBytesInvalidateIdentity;
    [Test]
    procedure IncludesAreFollowedAndCyclesTerminate;
    [TestCase('Pascal shadow', 'pas')]
    [TestCase('DCU shadow', 'dcu')]
    procedure DuplicateLookupDirectoriesAreUnknown(const aExtension: string);
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
    [Category('DS719Review2')]
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
    [Category('DS719Review2')]
    procedure IncludeDirectiveGrammar(const aDirective, aExpected: string);
    [TestCase('INCLUDE plus brace', 'brace')]
    [TestCase('INCLUDE plus parentheses', 'paren')]
    [Category('DS719Review2')]
    procedure PlusIncludeContentChangesIdentity(const aForm: string);
    [Test]
    [Category('DS719Review2')]
    procedure ProfileFileCandidatesChangeWitnessIdentity;
    [TestCase('SDK pair', 'pair')]
    [TestCase('SDK pair plus project source', 'project-source')]
    [TestCase('SDK pair plus second SDK source', 'second-sdk-source')]
    [TestCase('SDK pair plus external DCU', 'external-dcu')]
    [TestCase('SDK pair plus other installation DCU', 'other-installation')]
    [TestCase('SDK DCU without source', 'dcu-only')]
    [Category('DS719Pairing')]
    procedure SdkPairingDoesNotHideExtraCandidates(const aShape: string);

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

    [TestCase('Missing', 'no-source')]
    [TestCase('Dcu', 'dcu-only')]
    [TestCase('WrongHeader', 'unit-name-mismatch')]
    [TestCase('MissingInclude', 'include-unresolved')]
    [TestCase('DuplicateRtl', 'ambiguous-source')]
    procedure UnknownSourcesCannotProveAbsence(const aReason: string);
  end;

implementation

uses
  System.IOUtils, System.StrUtils, System.SysUtils,
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

procedure TUnitNameWitnessTests.ProfileFileCandidatesChangeWitnessIdentity;
var
  lOptions: TDelphiSemanticOptions;
  lContext: TDelphiSemanticContextResult;
  lFirst, lSecond: IDelphiSemanticUnitNameWitness;
begin
  WriteSource('P.dproj', '<Project><PropertyGroup><Platform>Win64</Platform></PropertyGroup></Project>');
  WriteSource('profile.proj', '<Project><PropertyGroup><DelphiLibraryPath>' +
    TPath.Combine(fRoot, '..\..\profile') + '</DelphiLibraryPath><DelphiBrowsingPath />' +
    '</PropertyGroup></Project>');
  WriteSource('..\..\profile\U.dcu', 'compiled unit');
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.DelphiVersion := '23.0';
  lOptions.Platform := 'Win64';
  lOptions.EnvOptionsPath := TPath.Combine(fRoot, 'profile.proj');
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
    WriteSource('P.dproj', '<Project><PropertyGroup><Platform>Win64</Platform></PropertyGroup></Project>');
    WriteSource('profile.proj', '<Project><PropertyGroup><DelphiLibraryPath />' +
      '<DelphiBrowsingPath />' + lPaths + '</PropertyGroup></Project>');
    lOptions := Default(TDelphiSemanticOptions);
    lOptions.DelphiVersion := '23.0';
    lOptions.Platform := 'Win64';
    lOptions.EnvOptionsPath := TPath.Combine(fRoot, 'profile.proj');
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
    WriteSource('P.dproj', '<Project><PropertyGroup><Platform>Win64</Platform></PropertyGroup></Project>');
    lProperties := '<DelphiLibraryPath /><DelphiBrowsingPath /><LANGDIR>' + aLanguage +
      '</LANGDIR><' + aProperty + '>' + lPath + '</' + aProperty + '>';
    WriteSource('profile.proj', '<Project><PropertyGroup>' + lProperties + '</PropertyGroup></Project>');
    lOptions := Default(TDelphiSemanticOptions);
    lOptions.DelphiVersion := '23.0';
    lOptions.Platform := 'Win64';
    lOptions.EnvOptionsPath := TPath.Combine(fRoot, 'profile.proj');
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
