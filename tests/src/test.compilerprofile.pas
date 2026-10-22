unit Test.CompilerProfile;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TCompilerProfileTests = class
  public
    [Test]
    [Category('DS742')]
    procedure CompatibilityRecordMembersMatchInstalledSource;
    [Test]
    procedure ProfileBuildersShareIntrinsicSeedContract;
    [Test]
    procedure RtlSourceRootProjectionUsesUnitModelSemantics;
    [Test]
    procedure RtlSourceRootProjectionStripsAssignedEnumValues;
    [Test]
    procedure RtlSourceRootProjectionHidesImplementationSymbols;
    [Test]
    procedure RecursiveRtlDuplicateBasenamesChooseSortedPath;
  end;

implementation

uses
  System.Classes, System.IOUtils, System.StrUtils, System.SysUtils,
  Winapi.Windows,
  AutoFree, maxLogic.IOUtils,
  DelphiSemantics.Cache, DelphiSemantics.CompilerProfile, DelphiSemantics.Model,
  DelphiSemantics.Resolve,
  Test.Support;

function CompilerProfileTempRoot: string;
begin
  Result := CreateTestTempRoot('compiler-profile-temp');
  TDirectory.CreateDirectory(Result);
end;

procedure TCompilerProfileTests.CompatibilityRecordMembersMatchInstalledSource;
var
  g: TGarbos;
  lActual, lExpected: TStringList;
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModel: TDelphiSemanticUnitModel;
  lNames: TArray<string>;
  lPlatform, lRoot, lSourceRoot, lName: string;
  lProfile: TDelphiSemanticCompilerProfile;
  lMember: TDelphiSemanticMember;
  lCount: Integer;
begin
  lRoot := CompilerProfileTempRoot;
  lSourceRoot := TDelphiSemanticCompilerProfileBuilder.ResolveRtlSourceRoot('23.0', '');
  Assert.IsTrue(TDirectory.Exists(lSourceRoot), 'The installed RTL source is required.');
  Assert.IsTrue(TDelphiSemanticCompilerProfileBuilder.CompatibilityRecordMemberNames('TSearchRec', lNames));
  GC(lActual, TStringList.Create, g);
  GC(lExpected, TStringList.Create, g);
  lActual.Sorted := True;
  lActual.Duplicates := dupIgnore;
  lExpected.Sorted := True;
  lExpected.Duplicates := dupIgnore;
  for lName in lNames do
    lExpected.Add(LowerCase(lName));
  for lPlatform in ['Win32', 'Win64', 'Linux64', 'OSX64'] do
  begin
    lCacheOptions := Default(TDelphiSemanticCacheOptions);
    lCacheOptions.SqliteCacheFileName := TPath.Combine(lRoot, lPlatform + '.sqlite');
    GC(lCache, TDelphiSemanticUnitCache.Create(lCacheOptions), g);
    lProfile := TDelphiSemanticCompilerProfileBuilder.ProfileForTargetFromRtlSourceRoot(lCache,
      'DS742-installed-search-record', '23.0', lPlatform, lSourceRoot, ['System.SysUtils']);
    lCount := 0;
    for lModel in lProfile.RtlSourceUnitModels do
      for lMember in lModel.Members do
        if SameText(lMember.OwnerName, 'TSearchRec') then
        begin
          Inc(lCount);
          lActual.Add(LowerCase(lMember.Name));
        end;
    Assert.IsTrue(lCount > 0, lPlatform + ' must contribute parsed TSearchRec members.');
  end;
  Assert.AreEqual(lExpected.Text, lActual.Text,
    'The absence-only witness must cover the installed four-platform member union.');
end;

function CompilerProfileFixtureRoot(const aName: string): string;
begin
  Result := FixturePath('CompilerProfile', aName);
end;

function FindProfileDeclaration(const aModel: TDelphiSemanticUnitModel; const aName,
  aKind: string; out aDeclaration: TDelphiSemanticDeclaration): Boolean;
var
  lDeclaration: TDelphiSemanticDeclaration;
begin
  for lDeclaration in aModel.Declarations do
  begin
    if SameText(lDeclaration.Name, aName) and SameText(lDeclaration.Kind, aKind) then
    begin
      aDeclaration := lDeclaration;
      Exit(True);
    end;
  end;

  aDeclaration := Default(TDelphiSemanticDeclaration);
  Result := False;
end;

function FindProfileMember(const aModel: TDelphiSemanticUnitModel; const aOwnerName,
  aName: string; out aMember: TDelphiSemanticMember): Boolean;
var
  lMember: TDelphiSemanticMember;
begin
  for lMember in aModel.Members do
  begin
    if SameText(lMember.OwnerName, aOwnerName) and SameText(lMember.Name, aName) then
    begin
      aMember := lMember;
      Exit(True);
    end;
  end;

  aMember := Default(TDelphiSemanticMember);
  Result := False;
end;

function CountProfileMembers(const aModel: TDelphiSemanticUnitModel; const aOwnerName,
  aName: string): Integer;
var
  lMember: TDelphiSemanticMember;
begin
  Result := 0;
  for lMember in aModel.Members do
    if SameText(lMember.OwnerName, aOwnerName) and SameText(lMember.Name, aName) then
      Inc(Result);
end;

function CountProfileRoutines(const aModel: TDelphiSemanticUnitModel; const aName: string):
  Integer;
var
  lRoutine: TDelphiSemanticRoutine;
begin
  Result := 0;
  for lRoutine in aModel.Routines do
    if SameText(lRoutine.Name, aName) then
      Inc(Result);
end;

function LoadSemanticRtlProfile: TDelphiSemanticCompilerProfile;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.CompilerProfileName := 'Delphi-12-RTL-Projection';
  lCache := TDelphiSemanticUnitCache.Create(lCacheOptions);
  try
    Result := TDelphiSemanticCompilerProfileBuilder.ProfileForTargetFromRtlSourceRoot(lCache,
      'Delphi-12-RTL-Projection', '23.0', 'Win32',
      CompilerProfileFixtureRoot('RtlProjection'), ['SemanticRtl']);
  finally
    lCache.Free;
  end;
end;

function ProfileHasIntrinsic(const aProfile: TDelphiSemanticCompilerProfile;
  const aName, aKind: string): Boolean;
var
  lIntrinsic: TDelphiSemanticIntrinsicSymbol;
begin
  Result := False;
  for lIntrinsic in aProfile.IntrinsicSymbols do
  begin
    if SameText(lIntrinsic.Name, aName) and SameText(lIntrinsic.Kind, aKind) then
      Exit(True);
  end;
end;

procedure AssertSharedIntrinsicSeed(const aExpected, aActual: TDelphiSemanticCompilerProfile;
  const aActualLabel: string);
var
  lExpected: TDelphiSemanticIntrinsicSymbol;
begin
  Assert.AreEqual(aExpected.IntrinsicSeedVersion, aActual.IntrinsicSeedVersion,
    aActualLabel + ' seed version drifted.');
  Assert.AreEqual(Integer(Length(aExpected.IntrinsicSymbols)),
    Integer(Length(aActual.IntrinsicSymbols)), aActualLabel + ' intrinsic count drifted.');

  for lExpected in aExpected.IntrinsicSymbols do
  begin
    Assert.IsTrue(ProfileHasIntrinsic(aActual, lExpected.Name, lExpected.Kind),
      aActualLabel + ' missing intrinsic ' + lExpected.Kind + ':' + lExpected.Name);
  end;
end;

procedure TCompilerProfileTests.ProfileBuildersShareIntrinsicSeedContract;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lCachedProfile: TDelphiSemanticCompilerProfile;
  lDefaultProfile: TDelphiSemanticCompilerProfile;
  lTargetProfile: TDelphiSemanticCompilerProfile;
begin
  lDefaultProfile := TDelphiSemanticCompilerProfileBuilder.DefaultProfile(
    'Delphi-12-Win32-Debug');
  lTargetProfile := TDelphiSemanticCompilerProfileBuilder.ProfileForTarget(
    'Delphi-12-Win32-Debug', '23.0', 'Win32', 'C:\rtl\source');

  Assert.AreEqual('delphi-intrinsics-v2', lTargetProfile.IntrinsicSeedVersion);
  Assert.IsTrue(Length(lTargetProfile.IntrinsicSymbols) >= 47);
  Assert.IsTrue(ProfileHasIntrinsic(lTargetProfile, 'NativeUInt', 'intrinsic-type'));
  Assert.IsTrue(ProfileHasIntrinsic(lTargetProfile, 'Random', 'intrinsic-routine'));

  AssertSharedIntrinsicSeed(lTargetProfile, lDefaultProfile, 'DefaultProfile');

  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCache := TDelphiSemanticUnitCache.Create(lCacheOptions);
  try
    lCachedProfile := TDelphiSemanticCompilerProfileBuilder.FromCachedSources(lCache, []);
  finally
    lCache.Free;
  end;

  AssertSharedIntrinsicSeed(lTargetProfile, lCachedProfile, 'FromCachedSources');
end;

procedure TCompilerProfileTests.RtlSourceRootProjectionUsesUnitModelSemantics;
var
  lDeclaration: TDelphiSemanticDeclaration;
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
  lProfile: TDelphiSemanticCompilerProfile;
begin
  lProfile := LoadSemanticRtlProfile;

  Assert.AreEqual(1, Integer(Length(lProfile.RtlSourceUnitModels)));
  lModel := lProfile.RtlSourceUnitModels[0];
  Assert.IsTrue(lModel.Success, 'Expected RTL projection unit model to succeed.');
  Assert.AreEqual('System.SemanticRtl', lModel.UnitName);

  Assert.IsTrue(FindProfileDeclaration(lModel, 'TRtlRecord', 'type', lDeclaration),
    'Expected record declaration.');
  Assert.AreEqual('record', lDeclaration.TypeName);
  Assert.IsTrue(FindProfileDeclaration(lModel, 'TRtlRecordHelper', 'type', lDeclaration),
    'Expected record helper declaration.');
  Assert.AreEqual('TRtlRecord', lDeclaration.HelperTargetName);
  Assert.IsTrue(FindProfileDeclaration(lModel, 'TRtlClassHelper', 'type', lDeclaration),
    'Expected class helper declaration.');
  Assert.AreEqual('TRtlChild', lDeclaration.HelperTargetName);
  Assert.IsTrue(FindProfileDeclaration(lModel, 'TRtlForward', 'type', lDeclaration),
    'Expected forward class declaration.');
  Assert.IsTrue(FindProfileDeclaration(lModel, 'reOne', 'enum-value', lDeclaration),
    'Expected enum value declaration.');
  Assert.IsTrue(FindProfileDeclaration(lModel, 'reAssigned', 'enum-value', lDeclaration),
    'Expected assigned enum value declaration.');
  Assert.IsTrue(FindProfileDeclaration(lModel, 'rceTwo', 'enum-value', lDeclaration),
    'Expected commented multiline enum value declaration.');
  Assert.IsTrue(FindProfileDeclaration(lModel, 'RtlPlainConst', 'const', lDeclaration),
    'Expected const declaration.');
  Assert.IsTrue(FindProfileDeclaration(lModel, 'RtlTypedConst', 'typed-const', lDeclaration),
    'Expected typed const declaration.');
  Assert.IsTrue(FindProfileDeclaration(lModel, 'rsRtlMessage', 'resourcestring',
    lDeclaration), 'Expected resourcestring declaration.');
  Assert.IsTrue(FindProfileDeclaration(lModel, 'RtlGlobal', 'var', lDeclaration),
    'Expected var declaration.');
  Assert.IsTrue(FindProfileDeclaration(lModel, 'RtlThreadGlobal', 'threadvar',
    lDeclaration), 'Expected threadvar declaration.');

  Assert.IsTrue(FindProfileMember(lModel, 'TRtlChild', 'Items', lMember),
    'Expected indexed default property member.');
  Assert.AreEqual('property', lMember.Kind);
  Assert.AreEqual('string', lMember.TypeName);
  Assert.IsTrue(lMember.IsIndexed, 'Expected indexed property metadata.');
  Assert.IsTrue(lMember.IsDefault, 'Expected default property metadata.');

  Assert.AreEqual(1, CountProfileMembers(lModel, 'TRtlLifecycle', 'Create'),
    'Expected instance constructor member projection.');
  Assert.AreEqual(1, CountProfileMembers(lModel, 'TRtlLifecycle', 'Destroy'),
    'Expected instance destructor member projection.');
  Assert.AreEqual(1, CountProfileMembers(lModel, 'TRtlClassLifecycle', 'Create'),
    'Expected class constructor member projection.');
  Assert.AreEqual(1, CountProfileMembers(lModel, 'TRtlClassLifecycle', 'Destroy'),
    'Expected class destructor member projection.');

  Assert.AreEqual(2, CountProfileRoutines(lModel, 'RtlOverloaded'));
  Assert.IsTrue(CountProfileRoutines(lModel, 'RtlProjectValue') > 0,
    'Expected top-level RTL routine projection.');
end;

procedure TCompilerProfileTests.RtlSourceRootProjectionStripsAssignedEnumValues;
var
  lDeclaration: TDelphiSemanticDeclaration;
  lModel: TDelphiSemanticUnitModel;
  lProfile: TDelphiSemanticCompilerProfile;
begin
  lProfile := LoadSemanticRtlProfile;
  Assert.AreEqual(1, Integer(Length(lProfile.RtlSourceUnitModels)));
  lModel := lProfile.RtlSourceUnitModels[0];

  Assert.IsTrue(FindProfileDeclaration(lModel, 'reAssigned', 'enum-value', lDeclaration),
    'Expected assigned enum member to publish only the identifier.');
  Assert.AreEqual('TRtlEnum', lDeclaration.TypeName);
  Assert.IsFalse(FindProfileDeclaration(lModel, 'reAssigned = 7', 'enum-value', lDeclaration),
    'Assigned enum member value text must not become the semantic name.');
  Assert.IsFalse(FindProfileDeclaration(lModel, '// comment rceTwo', 'enum-value',
    lDeclaration), 'Line-comment text must not become part of a multiline enum value name.');
end;

procedure TCompilerProfileTests.RtlSourceRootProjectionHidesImplementationSymbols;
var
  lContext: TDelphiSemanticResolveContext;
  lDeclaration: TDelphiSemanticDeclaration;
  lModel: TDelphiSemanticUnitModel;
  lProfile: TDelphiSemanticCompilerProfile;
  lResult: TDelphiSemanticResolveResult;
  lSourceModel: TDelphiSemanticUnitModel;
begin
  lProfile := LoadSemanticRtlProfile;
  Assert.AreEqual(1, Integer(Length(lProfile.RtlSourceUnitModels)));
  lModel := lProfile.RtlSourceUnitModels[0];

  Assert.IsFalse(FindProfileDeclaration(lModel, 'TImplementationOnly', 'type', lDeclaration));
  Assert.IsFalse(FindProfileDeclaration(lModel, 'ImplementationOnlyConst', 'const',
    lDeclaration));
  Assert.IsFalse(FindProfileDeclaration(lModel, 'ImplementationOnlyGlobal', 'var',
    lDeclaration));
  Assert.IsFalse(FindProfileDeclaration(lModel, 'ImplementationOnlyRoutine', 'routine',
    lDeclaration));
  Assert.AreEqual(0, CountProfileRoutines(lModel, 'ImplementationOnlyRoutine'));
  Assert.IsFalse(ContainsText(lModel.SourceText, 'ImplementationOnlyRoutine'),
    'Interface-only RTL projection must not expose implementation source text.');

  lSourceModel := Default(TDelphiSemanticUnitModel);
  lContext := Default(TDelphiSemanticResolveContext);
  lContext.ConformanceLevel := 3;
  lContext.IntrinsicSymbols := lProfile.IntrinsicSymbols;
  lContext.IndexedUnitModels := lProfile.RtlSourceUnitModels;

  lResult := TDelphiSemanticResolver.ResolveName(lSourceModel, lContext,
    'TImplementationOnly');

  Assert.IsFalse(lResult.Found, 'Implementation-only RTL type must not resolve externally.');
end;

procedure TCompilerProfileTests.RecursiveRtlDuplicateBasenamesChooseSortedPath;
var
  lFirstRoot: string;
  lFiles: TArray<string>;
  lMixedFirstRoot: string;
  lMixedSecondRoot: string;
  lRtlRoot: string;
  lSecondRoot: string;
begin
  lRtlRoot := TPath.Combine(CompilerProfileTempRoot, 'fake-duplicate-rtl-source');

  lFirstRoot := CombinePath([lRtlRoot, 'rtl', 'aaa']);
  lSecondRoot := CombinePath([lRtlRoot, 'rtl', 'zzz']);
  TDirectory.CreateDirectory(lSecondRoot);
  TDirectory.CreateDirectory(lFirstRoot);

  TFile.WriteAllText(TPath.Combine(lSecondRoot, 'DuplicateRtl.pas'),
    'unit DuplicateRtl; interface implementation end.', TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(lFirstRoot, 'DuplicateRtl.pas'),
    'unit DuplicateRtl; interface implementation end.', TEncoding.UTF8);

  lFiles := TDelphiSemanticCompilerProfileBuilder.DiscoverRtlSourceFiles(lRtlRoot,
    ['DuplicateRtl']);

  Assert.AreEqual(1, Integer(Length(lFiles)), 'Expected one deterministic duplicate-basename result.');
  Assert.AreEqual(TPath.GetFullPath(TPath.Combine(lFirstRoot, 'DuplicateRtl.pas')), lFiles[0],
    'Duplicate recursive RTL basenames must choose the sorted normalized path.');

  lMixedFirstRoot := CombinePath([lRtlRoot, 'rtl', 'bbb']);
  lMixedSecondRoot := CombinePath([lRtlRoot, 'rtl', 'ccc']);
  TDirectory.CreateDirectory(lMixedSecondRoot);
  TDirectory.CreateDirectory(lMixedFirstRoot);
  TFile.WriteAllText(TPath.Combine(lMixedSecondRoot, 'CaseRtl.pas'),
    'unit CaseRtl; interface implementation end.', TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(lMixedFirstRoot, 'casertl.pas'),
    'unit CaseRtl; interface implementation end.', TEncoding.UTF8);

  lFiles := TDelphiSemanticCompilerProfileBuilder.DiscoverRtlSourceFiles(lRtlRoot,
    ['CaseRtl']);

  Assert.AreEqual(1, Integer(Length(lFiles)), 'Expected case-insensitive duplicate basename result.');
  Assert.AreEqual(TPath.GetFullPath(TPath.Combine(lMixedFirstRoot, 'casertl.pas')), lFiles[0],
    'Case-insensitive duplicate recursive RTL basenames must use the ordinal sorted first path.');
end;

initialization
  TDUnitX.RegisterTestFixture(TCompilerProfileTests);

end.
