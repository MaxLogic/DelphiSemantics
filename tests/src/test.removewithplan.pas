unit Test.RemoveWithPlan;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Api;

type
  [TestFixture]
  TRemoveWithPlanTests = class
  private
    function FixturePath(const aRelativePath: string): string;
    function BuildPlan: TDelphiSemanticRemoveWithPlan;
  public
    [Test]
    procedure PlansDeterministicDryRunDtoWithVerificationAndProvenance;
    [Test]
    procedure PlannerCachesSourceTextAndHashesPerFile;
  end;

implementation

uses
  System.IOUtils, System.StrUtils, System.SysUtils;

function TRemoveWithPlanTests.FixturePath(const aRelativePath: string): string;
begin
  Result := TPath.GetFullPath(TPath.Combine(
    TPath.Combine(ExtractFilePath(ParamStr(0)), '..\fixtures'), aRelativePath));
end;

function TRemoveWithPlanTests.BuildPlan: TDelphiSemanticRemoveWithPlan;
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOptions: TDelphiSemanticApiOptions;
begin
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := FixturePath('ProjectWithBinding\ProjectWithBinding.dproj');
  lFacts := TDelphiSemanticApi.BuildProjectWithBindingFacts(lOptions);
  Result := TDelphiSemanticApi.PlanRemoveWith(lFacts);
end;

procedure TRemoveWithPlanTests.PlansDeterministicDryRunDtoWithVerificationAndProvenance;
var
  lAfterBytes: TBytes;
  lBeforeBytes: TBytes;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lSecondPlan: TDelphiSemanticRemoveWithPlan;
  lSkippedFacts: TDelphiSemanticProjectWithBindingFacts;
  lSkippedPlan: TDelphiSemanticRemoveWithPlan;
  lUnitPath: string;
  i: Integer;
begin
  lUnitPath := FixturePath('ProjectWithBinding\ProjectWithUnit.pas');
  lBeforeBytes := TFile.ReadAllBytes(lUnitPath);

  lPlan := BuildPlan;
  lSecondPlan := BuildPlan;

  Assert.AreEqual('remove-with', lPlan.Operation);
  Assert.AreEqual('planned', lPlan.Status, lPlan.Diagnostic);
  Assert.IsNotEmpty(lPlan.ContextFingerprint);
  Assert.AreEqual('project-with-binding-v1', lPlan.BaselineSemanticModelVersion);
  Assert.IsTrue(Length(lPlan.RequiredVerification) >= 5,
    'Expected compile, context, source, post-compile, and rollback verification requirements.');
  Assert.IsTrue(Length(lPlan.Edits) > 0, 'Expected at least one planned semantic remove-with edit.');
  Assert.IsNotEmpty(lPlan.Edits[0].ExpectedFileHash);
  Assert.IsNotEmpty(lPlan.Edits[0].ExpectedSourceText);
  Assert.AreEqual('with lRecord do' + sLineBreak + '    Value := 1;', lPlan.Edits[0].ExpectedSourceText);
  Assert.AreEqual(lPlan.Edits[0].ExpectedSourceText, lPlan.Edits[0].ReplacementText);
  Assert.AreEqual('requires-dak-compatibility-adapter', lPlan.Edits[0].ApplyMode);
  Assert.IsNotEmpty(lPlan.Edits[0].SemanticId);
  Assert.IsTrue(Length(lPlan.Edits[0].ReferenceIds) > 0,
    'Expected semantic references to justify the edit.');
  Assert.AreEqual(lPlan.ContextFingerprint, lSecondPlan.ContextFingerprint);
  Assert.AreEqual(Length(lPlan.Edits), Length(lSecondPlan.Edits));
  Assert.AreEqual(lPlan.Edits[0].ExpectedFileHash, lSecondPlan.Edits[0].ExpectedFileHash);
  Assert.AreEqual(lPlan.Edits[0].ExpectedSourceText, lSecondPlan.Edits[0].ExpectedSourceText);

  lAfterBytes := TFile.ReadAllBytes(lUnitPath);
  Assert.AreEqual(Length(lBeforeBytes), Length(lAfterBytes), 'Plan mode must not write source files.');
  for i := 0 to High(lBeforeBytes) do
    Assert.AreEqual(lBeforeBytes[i], lAfterBytes[i], 'Plan mode must preserve source bytes.');

  lSkippedFacts := Default(TDelphiSemanticProjectWithBindingFacts);
  lSkippedFacts.ContextFingerprint := 'skipped-plan-context';
  SetLength(lSkippedFacts.Bindings, 1);
  lSkippedFacts.Bindings[0].SemanticId := 'with:skipped';
  lSkippedFacts.Bindings[0].Status := 'skipped';
  lSkippedFacts.Bindings[0].SkipReason := 'UNRESOLVED_REFERENCE';
  lSkippedPlan := TDelphiSemanticApi.PlanRemoveWith(lSkippedFacts);
  Assert.AreEqual(0, Length(lSkippedPlan.Edits));
  Assert.AreEqual(1, Length(lSkippedPlan.SkippedStatements));
  Assert.AreEqual('SOURCE_RANGE_UNAVAILABLE', lSkippedPlan.SkippedStatements[0].Reason);
  Assert.AreEqual('stable source file, hash, and source range are required',
    lSkippedPlan.SkippedStatements[0].SafetyReason);
end;

procedure TRemoveWithPlanTests.PlannerCachesSourceTextAndHashesPerFile;
var
  lSourceText: string;
begin
  lSourceText := TFile.ReadAllText(TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)),
    '..\..\src\DelphiSemantics.RemoveWithPlan.pas')), TEncoding.UTF8);

  Assert.IsTrue(ContainsText(lSourceText, 'TDictionary<string, TArray<string>>'),
    'remove-with plan DTO should cache source lines per file while building edits');
  Assert.IsTrue(ContainsText(lSourceText, 'TDictionary<string, string>'),
    'remove-with plan DTO should cache source hashes per file while building edits');
end;

initialization
  TDUnitX.RegisterTestFixture(TRemoveWithPlanTests);

end.
