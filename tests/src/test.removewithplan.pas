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
    procedure DtoParityHarnessReportsMissingFinalStatements;
    [Test]
    procedure DtoParityHarnessReportsUnexpectedFinalStatements;
    [Test]
    procedure FinalStatementDtoPreservesCandidateFields;
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

procedure TRemoveWithPlanTests.DtoParityHarnessReportsMissingFinalStatements;
var
  lExpectedEdit: TDelphiSemanticRemoveWithPlanParityEdit;
  lExpectedStatement: TDelphiSemanticRemoveWithPlanParityStatement;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lReport: TDelphiSemanticRemoveWithPlanParityReport;
begin
  lPlan := BuildPlan;
  Assert.IsTrue(Length(lPlan.Edits) > 0, 'Expected current candidate DTO edits for parity harness input.');

  lExpectedEdit := Default(TDelphiSemanticRemoveWithPlanParityEdit);
  lExpectedEdit.Kind := 'replace-statement';
  lExpectedEdit.FileName := lPlan.Edits[0].FileName;
  lExpectedEdit.StatementId := lPlan.Edits[0].StatementId;
  lExpectedEdit.Range := lPlan.Edits[0].Range;
  lExpectedEdit.Range.StartColumn := 1;
  lExpectedEdit.ReplacementText := 'lRecord.Value := 1;';

  lExpectedStatement := Default(TDelphiSemanticRemoveWithPlanParityStatement);
  lExpectedStatement.StatementId := lPlan.Edits[0].StatementId;
  lExpectedStatement.FileName := lPlan.Edits[0].FileName;
  lExpectedStatement.Status := 'planned';
  lExpectedStatement.Reason := 'current-dak-plan';
  lExpectedStatement.ReplacementText := lExpectedEdit.ReplacementText;
  lExpectedStatement.Edits := [lExpectedEdit];

  lReport := TDelphiSemanticRemoveWithPlanParity.Compare(lPlan, [lExpectedStatement]);

  Assert.AreEqual(2, lReport.MismatchCount, lReport.SummaryText);
  Assert.AreEqual('missing-final-statement', lReport.Mismatches[0].Kind);
  Assert.AreEqual(lExpectedStatement.StatementId, lReport.Mismatches[0].StatementId);
  Assert.IsTrue(ContainsText(lReport.SummaryText, lExpectedStatement.StatementId),
    'Expected mismatch report to include statement id.');
  Assert.IsTrue(ContainsText(lReport.SummaryText, ExtractFileName(lExpectedStatement.FileName)),
    'Expected mismatch report to include file.');
  Assert.IsTrue(ContainsText(lReport.SummaryText, 'status=planned'),
    'Expected mismatch report to include status.');
  Assert.IsTrue(ContainsText(lReport.SummaryText, 'reason=current-dak-plan'),
    'Expected mismatch report to include reason.');
  Assert.IsTrue(ContainsText(lReport.SummaryText, 'edit=replace-statement'),
    'Expected mismatch report to include edit kind.');
  Assert.IsTrue(ContainsText(lReport.SummaryText, 'range='),
    'Expected mismatch report to include edit range.');
  Assert.IsTrue(ContainsText(lReport.SummaryText, 'excerpt='),
    'Expected mismatch report to include replacement text excerpt.');
end;

procedure TRemoveWithPlanTests.DtoParityHarnessReportsUnexpectedFinalStatements;
var
  lFinalEdit: TDelphiSemanticRemoveWithFinalTextEdit;
  lFinalStatement: TDelphiSemanticRemoveWithFinalStatement;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lReport: TDelphiSemanticRemoveWithPlanParityReport;
begin
  lFinalEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
  lFinalEdit.Kind := 'replace-statement';
  lFinalEdit.FileName := FixturePath('ProjectWithBinding\ProjectWithUnit.pas');
  lFinalEdit.StatementId := 'with-extra';
  lFinalEdit.Range.StartLine := 10;
  lFinalEdit.Range.StartColumn := 1;
  lFinalEdit.Range.EndLine := 12;
  lFinalEdit.Range.EndColumn := 8;
  lFinalEdit.ReplacementText := 'lExtra.Value := 1;';

  lFinalStatement := Default(TDelphiSemanticRemoveWithFinalStatement);
  lFinalStatement.StatementId := lFinalEdit.StatementId;
  lFinalStatement.FileName := lFinalEdit.FileName;
  lFinalStatement.Status := 'planned';
  lFinalStatement.ReplacementText := lFinalEdit.ReplacementText;
  lFinalStatement.Edits := [lFinalEdit];

  lPlan := Default(TDelphiSemanticRemoveWithPlan);
  lPlan.Operation := 'remove-with';
  lPlan.Status := 'planned';
  lPlan.FinalStatements := [lFinalStatement];

  lReport := TDelphiSemanticRemoveWithPlanParity.Compare(lPlan, []);

  Assert.AreEqual(2, lReport.MismatchCount, lReport.SummaryText);
  Assert.AreEqual('unexpected-final-statement', lReport.Mismatches[0].Kind);
  Assert.AreEqual('with-extra', lReport.Mismatches[0].StatementId);
  Assert.AreEqual('unexpected-final-edit', lReport.Mismatches[1].Kind);
  Assert.IsTrue(ContainsText(lReport.SummaryText, 'statement=with-extra'),
    'Expected unexpected statement id in parity report.');
  Assert.IsTrue(ContainsText(lReport.SummaryText, 'edit=replace-statement'),
    'Expected unexpected edit kind in parity report.');
  Assert.IsTrue(ContainsText(lReport.SummaryText, 'range=10:1-12:8'),
    'Expected unexpected edit range in parity report.');
  Assert.IsTrue(ContainsText(lReport.SummaryText, 'excerpt='),
    'Expected unexpected edit replacement excerpt in parity report.');
end;

procedure TRemoveWithPlanTests.FinalStatementDtoPreservesCandidateFields;
var
  lCandidateEditCount: Integer;
  lExpectedStatement: TDelphiSemanticRemoveWithPlanParityStatement;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lPlannedEdit: TDelphiSemanticRemoveWithFinalTextEdit;
  lPlannedStatement: TDelphiSemanticRemoveWithFinalStatement;
  lReport: TDelphiSemanticRemoveWithPlanParityReport;
  lSkippedStatement: TDelphiSemanticRemoveWithFinalStatement;
  lTemp: TDelphiSemanticRemoveWithFinalTempDecision;
begin
  lPlan := BuildPlan;
  lCandidateEditCount := Length(lPlan.Edits);
  Assert.IsTrue(lCandidateEditCount > 0, 'Expected existing candidate edits to remain populated.');

  lTemp := Default(TDelphiSemanticRemoveWithFinalTempDecision);
  lTemp.SelectorText := 'lRecord';
  lTemp.QualifierText := 'lWithRecordPtr^';
  lTemp.Strategy := 'record-pointer-temp';
  lTemp.ReceiverType := 'TRecord';
  lTemp.TempName := 'lWithRecordPtr';
  lTemp.DeclarationText := 'lWithRecordPtr: ^TRecord;';
  lTemp.InitializationText := 'lWithRecordPtr := @lRecord;';
  lTemp.Reason := 'addressable-record';
  lTemp.SemanticId := lPlan.Edits[0].SemanticId;

  lPlannedEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
  lPlannedEdit.Kind := 'replace-statement';
  lPlannedEdit.FileName := lPlan.Edits[0].FileName;
  lPlannedEdit.StatementId := lPlan.Edits[0].StatementId;
  lPlannedEdit.Range := lPlan.Edits[0].Range;
  lPlannedEdit.Range.StartColumn := 1;
  lPlannedEdit.ReplacementText := 'lWithRecordPtr^.Value := 1;';
  lPlannedEdit.SemanticId := lPlan.Edits[0].SemanticId;
  lPlannedEdit.Verification.ExpectedFileHash := lPlan.Edits[0].ExpectedFileHash;
  lPlannedEdit.Verification.ExpectedSourceText := lPlan.Edits[0].ExpectedSourceText;
  lPlannedEdit.Verification.Range := lPlan.Edits[0].Range;

  lPlannedStatement := Default(TDelphiSemanticRemoveWithFinalStatement);
  lPlannedStatement.StatementId := lPlan.Edits[0].StatementId;
  lPlannedStatement.FileName := lPlan.Edits[0].FileName;
  lPlannedStatement.Status := 'planned';
  lPlannedStatement.Reason := 'dak-ready-final-dto';
  lPlannedStatement.ReplacementText := lPlannedEdit.ReplacementText;
  lPlannedStatement.Range := lPlan.Edits[0].Range;
  lPlannedStatement.SemanticId := lPlan.Edits[0].SemanticId;
  lPlannedStatement.ReferenceIds := lPlan.Edits[0].ReferenceIds;
  lPlannedStatement.Verification := lPlannedEdit.Verification;
  lPlannedStatement.Edits := [lPlannedEdit];
  lPlannedStatement.Temps := [lTemp];

  lSkippedStatement := Default(TDelphiSemanticRemoveWithFinalStatement);
  lSkippedStatement.StatementId := 'with-skipped';
  lSkippedStatement.FileName := lPlan.Edits[0].FileName;
  lSkippedStatement.Status := 'skipped';
  lSkippedStatement.Reason := 'selector-type-not-resolved';
  lSkippedStatement.SafetyReason := 'selector receiver type is unresolved';
  lSkippedStatement.SemanticId := 'semantic:with-skipped';
  lSkippedStatement.Verification.ExpectedFileHash := lPlan.Edits[0].ExpectedFileHash;

  lPlan.FinalStatements := [lPlannedStatement, lSkippedStatement];

  Assert.AreEqual(lCandidateEditCount, Length(lPlan.Edits),
    'Final statement DTO fields must not replace candidate Edits.');
  Assert.AreEqual('requires-dak-compatibility-adapter', lPlan.Edits[0].ApplyMode,
    'Existing candidate apply mode must remain backward compatible.');
  Assert.AreEqual(2, Length(lPlan.FinalStatements));
  Assert.AreEqual('planned', lPlan.FinalStatements[0].Status);
  Assert.AreEqual('skipped', lPlan.FinalStatements[1].Status);
  Assert.AreEqual('selector-type-not-resolved', lPlan.FinalStatements[1].Reason);
  Assert.AreEqual('lWithRecordPtr: ^TRecord;', lPlan.FinalStatements[0].Temps[0].DeclarationText);
  Assert.AreEqual(lPlan.Edits[0].ExpectedFileHash,
    lPlan.FinalStatements[0].Edits[0].Verification.ExpectedFileHash);
  Assert.AreEqual(lPlan.Edits[0].ReferenceIds[0], lPlan.FinalStatements[0].ReferenceIds[0]);

  lExpectedStatement := Default(TDelphiSemanticRemoveWithPlanParityStatement);
  lExpectedStatement.StatementId := lPlannedStatement.StatementId;
  lExpectedStatement.FileName := lPlannedStatement.FileName;
  lExpectedStatement.Status := lPlannedStatement.Status;
  lExpectedStatement.Reason := lPlannedStatement.Reason;
  lExpectedStatement.ReplacementText := lPlannedStatement.ReplacementText;
  SetLength(lExpectedStatement.Edits, 1);
  lExpectedStatement.Edits[0].Kind := lPlannedEdit.Kind;
  lExpectedStatement.Edits[0].FileName := lPlannedEdit.FileName;
  lExpectedStatement.Edits[0].StatementId := lPlannedEdit.StatementId;
  lExpectedStatement.Edits[0].Range := lPlannedEdit.Range;
  lExpectedStatement.Edits[0].ReplacementText := lPlannedEdit.ReplacementText;

  lReport := TDelphiSemanticRemoveWithPlanParity.Compare(lPlan, [lExpectedStatement]);
  Assert.AreEqual(1, lReport.MismatchCount, lReport.SummaryText);
  Assert.AreEqual('unexpected-final-statement', lReport.Mismatches[0].Kind);
  Assert.AreEqual('with-skipped', lReport.Mismatches[0].StatementId);
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
