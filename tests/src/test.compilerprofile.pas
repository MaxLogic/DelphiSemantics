unit Test.CompilerProfile;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TCompilerProfileTests = class
  public
    [Test]
    procedure ProfileBuildersShareIntrinsicSeedContract;
    [Test]
    procedure RecursiveRtlDuplicateBasenamesChooseSortedPath;
  end;

implementation

uses
  System.IOUtils, System.SysUtils,
  Winapi.Windows,
  maxLogic.IOUtils,
  DelphiSemantics.Cache, DelphiSemantics.CompilerProfile;

function CompilerProfileTempRoot: string;
var
  lGuid: TGUID;
  lGuidText: string;
begin
  CreateGUID(lGuid);
  lGuidText := StringReplace(StringReplace(GUIDToString(lGuid), '{', '', [rfReplaceAll]), '}', '',
    [rfReplaceAll]);
  Result := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), 'compiler-profile-temp',
    'run-' + GetCurrentProcessId.ToString + '-' + lGuidText]));
  TDirectory.CreateDirectory(Result);
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

  Assert.AreEqual('delphi-intrinsics-v1', lTargetProfile.IntrinsicSeedVersion);
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
