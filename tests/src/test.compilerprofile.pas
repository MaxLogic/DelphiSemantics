unit Test.CompilerProfile;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TCompilerProfileTests = class
  public
    [Test]
    procedure RecursiveRtlDuplicateBasenamesChooseSortedPath;
  end;

implementation

uses
  System.IOUtils, System.SysUtils,
  Winapi.Windows,
  maxLogic.IOUtils,
  DelphiSemantics.CompilerProfile;

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
