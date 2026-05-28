unit Test.SemanticInvalidation;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Api;

type
  [TestFixture]
  TSemanticInvalidationTests = class
  private
    function BuildSession(const aProjectDir: string): TDelphiSemanticProjectSession;
    function CreateFixtureProject: string;
    function HasFile(const aFiles: TArray<string>; const aFileName: string): Boolean;
  public
    [Test]
    procedure PlansAffectedUnitsAndConservativeFallbacks;
  end;

implementation

uses
  System.IOUtils, System.SysUtils;

function TSemanticInvalidationTests.BuildSession(const aProjectDir: string):
  TDelphiSemanticProjectSession;
var
  lOptions: TDelphiSemanticApiOptions;
  lResult: TDelphiSemanticProjectSessionResult;
begin
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.Combine(aProjectDir, 'InvalidationProject.dproj');

  lResult := TDelphiSemanticApi.OpenProjectSession(lOptions);
  Assert.IsTrue(lResult.Success);
  Result := lResult.Session;
end;

function TSemanticInvalidationTests.CreateFixtureProject: string;
begin
  Result := TPath.Combine(ExtractFilePath(ParamStr(0)), 'semantic-invalidation-fixture');
  if TDirectory.Exists(Result) then
    TDirectory.Delete(Result, True);
  TDirectory.CreateDirectory(Result);

  TFile.WriteAllText(TPath.Combine(Result, 'InvalidationProject.dpr'),
    'program InvalidationProject;' + sLineBreak +
    sLineBreak +
    'uses' + sLineBreak +
    '  UnitA,' + sLineBreak +
    '  UnitB;' + sLineBreak +
    sLineBreak +
    'begin' + sLineBreak +
    'end.' + sLineBreak);

  TFile.WriteAllText(TPath.Combine(Result, 'UnitA.pas'),
    'unit UnitA;' + sLineBreak +
    sLineBreak +
    'interface' + sLineBreak +
    sLineBreak +
    'uses' + sLineBreak +
    '  UnitB;' + sLineBreak +
    sLineBreak +
    'implementation' + sLineBreak +
    sLineBreak +
    'end.' + sLineBreak);

  TFile.WriteAllText(TPath.Combine(Result, 'UnitB.pas'),
    'unit UnitB;' + sLineBreak +
    sLineBreak +
    'interface' + sLineBreak +
    sLineBreak +
    'type' + sLineBreak +
    '  TBaseRecord = record' + sLineBreak +
    '    Value: Integer;' + sLineBreak +
    '  end;' + sLineBreak +
    sLineBreak +
    'implementation' + sLineBreak +
    sLineBreak +
    '{$I Shared.inc}' + sLineBreak +
    sLineBreak +
    'end.' + sLineBreak);

  TFile.WriteAllText(TPath.Combine(Result, 'Shared.inc'),
    'const cSharedInvalidationValue = 1;' + sLineBreak);

  TFile.WriteAllText(TPath.Combine(Result, 'InvalidationProject.dproj'),
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' + sLineBreak +
    '  <PropertyGroup>' + sLineBreak +
    '    <ProjectGuid>{FA37B82E-B49C-4E52-8E4D-EE7A685B011D}</ProjectGuid>' + sLineBreak +
    '    <MainSource>InvalidationProject.dpr</MainSource>' + sLineBreak +
    '    <Config Condition="''$(Config)''==''''">Debug</Config>' + sLineBreak +
    '    <Platform Condition="''$(Platform)''==''''">Win32</Platform>' + sLineBreak +
    '  </PropertyGroup>' + sLineBreak +
    '  <ItemGroup>' + sLineBreak +
    '    <DCCReference Include="UnitA.pas"/>' + sLineBreak +
    '    <DCCReference Include="UnitB.pas"/>' + sLineBreak +
    '  </ItemGroup>' + sLineBreak +
    '</Project>' + sLineBreak);
end;

function TSemanticInvalidationTests.HasFile(const aFiles: TArray<string>;
  const aFileName: string): Boolean;
var
  lFileName: string;
begin
  for lFileName in aFiles do
    if SameText(TPath.GetFullPath(lFileName), TPath.GetFullPath(aFileName)) then
      Exit(True);

  Result := False;
end;

procedure TSemanticInvalidationTests.PlansAffectedUnitsAndConservativeFallbacks;
var
  lChange: TDelphiSemanticSessionChange;
  lPlan: TDelphiSemanticSessionInvalidationPlan;
  lProjectDir: string;
  lSession: TDelphiSemanticProjectSession;
  lUnitA: string;
  lUnitB: string;
begin
  lProjectDir := CreateFixtureProject;
  lUnitA := TPath.Combine(lProjectDir, 'UnitA.pas');
  lUnitB := TPath.Combine(lProjectDir, 'UnitB.pas');
  lSession := BuildSession(lProjectDir);
  try
    lChange := Default(TDelphiSemanticSessionChange);
    lChange.FileName := lUnitB;
    lChange.ChangeKind := 'implementation';
    lPlan := lSession.PlanInvalidation([lChange]);
    Assert.IsFalse(lPlan.RequiresFullSessionRebuild);
    Assert.IsTrue(HasFile(lPlan.AffectedUnitFiles, lUnitB));
    Assert.IsFalse(HasFile(lPlan.AffectedUnitFiles, lUnitA));

    lChange.ChangeKind := 'interface';
    lPlan := lSession.PlanInvalidation([lChange]);
    Assert.IsFalse(lPlan.RequiresFullSessionRebuild);
    Assert.IsTrue(HasFile(lPlan.AffectedUnitFiles, lUnitB));
    Assert.IsTrue(HasFile(lPlan.AffectedUnitFiles, lUnitA));

    lChange.ChangeKind := 'type-ancestor';
    lPlan := lSession.PlanInvalidation([lChange]);
    Assert.IsTrue(lPlan.LookupMemoizationInvalidated);
    Assert.IsTrue(HasFile(lPlan.AffectedUnitFiles, lUnitA));

    lChange.FileName := TPath.Combine(lProjectDir, 'Shared.inc');
    lChange.ChangeKind := 'include';
    lPlan := lSession.PlanInvalidation([lChange]);
    Assert.IsTrue(lPlan.IncludeGraphInvalidated);
    Assert.IsTrue(HasFile(lPlan.AffectedUnitFiles, lUnitA));
    Assert.IsTrue(HasFile(lPlan.AffectedUnitFiles, lUnitB));

    lChange.FileName := TPath.Combine(lProjectDir, 'InvalidationProject.dproj');
    lChange.ChangeKind := 'context';
    lPlan := lSession.PlanInvalidation([lChange]);
    Assert.IsTrue(lPlan.ContextInvalidated);
    Assert.IsTrue(lPlan.RequiresFullSessionRebuild);

    TFile.Delete(lUnitB);
    lChange.FileName := lUnitB;
    lChange.ChangeKind := 'interface';
    lPlan := lSession.PlanInvalidation([lChange]);
    Assert.IsTrue(lPlan.RequiresFullSessionRebuild);
    Assert.IsTrue(HasFile(lPlan.AffectedUnitFiles, lUnitA));
  finally
    lSession.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TSemanticInvalidationTests);

end.
