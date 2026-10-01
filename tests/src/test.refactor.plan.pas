unit Test.Refactor.Plan;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Refactor.Plan;

type
  [TestFixture]
  [Category('RefactoringLightApply')]
  TRefactoringPlanTests = class
  private
    function Context: TSemanticPlanContext;
    function Sources(const aText: string = 'alpha beta'): TArray<TSemanticPlanSource>;
    function Edit(const aStart, aFinish: Integer; const aExpected: string): TSemanticPlanEdit;
    procedure AssertRejected(const aSources: TArray<TSemanticPlanSource>;
      const aEdits: TArray<TSemanticPlanEdit>; const aCode: string);
  public
    [Test] procedure OwnsOriginalFactsAndHalfOpenEdits;
    [Test] procedure RejectsOutOfLineColumn;
    [Test] procedure RejectsSplitSurrogate;
    [Test] procedure RejectsMismatchedExpectedText;
    [Test] procedure RejectsOverlapAndDuplicateInsertion;
    [Test] procedure RejectsInsertionAtReplacementEnd;
    [Test] procedure SupportsMultilineAndEofInsertion;
    [Test] procedure StatusControlsApplicableEdits;
    [Test] procedure DetectsChangedContextAndManifest;
    [Test] procedure ConstructorRejectsInvalidCompleteAndNoChange;
  end;

implementation

uses
  AutoFree;

function TRefactoringPlanTests.Context: TSemanticPlanContext;
begin
  Result.ProjectIdentity := 'project-hash';
  Result.CompilerIdentity := 'compiler-hash';
  Result.ModelVersion := 'model-v1';
  Result.ConfigurationFingerprint := 'Debug-Win64-context-hash';
end;

function TRefactoringPlanTests.Sources(const aText: string): TArray<TSemanticPlanSource>;
begin
  SetLength(Result, 1);
  Result[0].FileName := 'C:\owned\UnitA.pas';
  Result[0].ContentHash := 'observed-content-hash';
  Result[0].IncludeGraphHash := 'observed-include-hash';
  Result[0].OriginalText := aText;
end;

function TRefactoringPlanTests.Edit(const aStart, aFinish: Integer;
  const aExpected: string): TSemanticPlanEdit;
begin
  Result := Default(TSemanticPlanEdit);
  Result.FileName := 'C:\owned\UnitA.pas';
  Result.StartLine := 1;
  Result.StartColumn := aStart;
  Result.EndLine := 1;
  Result.EndColumn := aFinish;
  Result.ExpectedText := aExpected;
  Result.ReplacementText := 'gamma';
end;

procedure TRefactoringPlanTests.AssertRejected(const aSources: TArray<TSemanticPlanSource>;
  const aEdits: TArray<TSemanticPlanEdit>; const aCode: string);
var
  g: TGarbos;
  lPlan: TSemanticRefactoringPlan;
  lError: string;
  lAccepted: Boolean;
begin
  g := Default(TGarbos);
  lAccepted := TSemanticRefactoringPlan.TryCreate(Context, TSemanticPlanStatus.Complete,
    '', aSources, aEdits, lPlan, lError);
  GC(lPlan, g);
  Assert.IsFalse(lAccepted);
  Assert.IsNull(lPlan);
  Assert.AreEqual(aCode, lError);
end;

procedure TRefactoringPlanTests.OwnsOriginalFactsAndHalfOpenEdits;
var
  g: TGarbos;
  lPlan: TSemanticRefactoringPlan;
  lSources: TArray<TSemanticPlanSource>;
  lEdits: TArray<TSemanticPlanEdit>;
  lCopy: TSemanticPlanSource;
  lError: string;
begin
  g := Default(TGarbos);
  lSources := Sources;
  lEdits := [Edit(1, 6, 'alpha')];
  Assert.IsTrue(TSemanticRefactoringPlan.TryCreate(Context, TSemanticPlanStatus.Complete,
    '', lSources, lEdits, lPlan, lError), lError);
  GC(lPlan, g);
  lSources[0].OriginalText := 'changed';
  lEdits[0].ReplacementText := 'changed';
  lCopy := lPlan.Sources[0];
  lCopy.OriginalText := 'also changed';
  Assert.AreEqual('alpha beta', lPlan.Sources[0].OriginalText);
  Assert.AreEqual('gamma', lPlan.Edits[0].ReplacementText);
  Assert.AreEqual(1, lPlan.EditCount);
  Assert.AreEqual(1, lPlan.SourceCount);
end;

procedure TRefactoringPlanTests.RejectsOutOfLineColumn;
begin
  AssertRejected(Sources('a'#13#10'b'), [Edit(1, 4, 'a'#13#10)], 'plan.invalid-range');
  AssertRejected(Sources, [Edit(0, 2, 'a')], 'plan.invalid-range');
  AssertRejected(Sources, [Edit(6, 1, '')], 'plan.invalid-range');
end;

procedure TRefactoringPlanTests.RejectsSplitSurrogate;
begin
  AssertRejected(Sources('a'#$D83D#$DE00'b'), [Edit(2, 3, #$D83D)], 'plan.invalid-range');
end;

procedure TRefactoringPlanTests.RejectsMismatchedExpectedText;
begin
  AssertRejected(Sources, [Edit(1, 6, 'ALPHA')], 'plan.expected-text-mismatch');
end;

procedure TRefactoringPlanTests.RejectsOverlapAndDuplicateInsertion;
begin
  AssertRejected(Sources, [Edit(1, 6, 'alpha'), Edit(2, 3, 'l')], 'plan.overlapping-edits');
  AssertRejected(Sources, [Edit(1, 1, ''), Edit(1, 1, '')], 'plan.overlapping-edits');
  AssertRejected(Sources, [Edit(1, 6, 'alpha'), Edit(3, 3, '')], 'plan.overlapping-edits');
end;

procedure TRefactoringPlanTests.SupportsMultilineAndEofInsertion;
var
  g: TGarbos;
  lPlan: TSemanticRefactoringPlan;
  lEdit: TSemanticPlanEdit;
  lError: string;
begin
  g := Default(TGarbos);
  lEdit := Edit(1, 2, 'a'#13#10'b');
  lEdit.EndLine := 2;
  Assert.IsTrue(TSemanticRefactoringPlan.TryCreate(Context, TSemanticPlanStatus.Complete,
    '', Sources('a'#13#10'b'), [lEdit], lPlan, lError), lError);
  GC(lPlan, g);
  Assert.IsTrue(TSemanticRefactoringPlan.TryCreate(Context, TSemanticPlanStatus.Complete,
    '', Sources, [Edit(11, 11, '')], lPlan, lError), lError);
  GC(lPlan, g);
end;

procedure TRefactoringPlanTests.RejectsInsertionAtReplacementEnd;
begin
  AssertRejected(Sources, [Edit(1, 6, 'alpha'), Edit(6, 6, '')], 'plan.overlapping-edits');
end;

procedure TRefactoringPlanTests.StatusControlsApplicableEdits;
var
  g: TGarbos;
  lPlan: TSemanticRefactoringPlan;
  lStatus: TSemanticPlanStatus;
  lError: string;
begin
  g := Default(TGarbos);
  for lStatus in [TSemanticPlanStatus.NoChange, TSemanticPlanStatus.Incomplete,
    TSemanticPlanStatus.Blocked] do
  begin
    Assert.IsTrue(TSemanticRefactoringPlan.TryCreate(Context, lStatus, 'reason', Sources,
      [], lPlan, lError), lError);
    GC(lPlan, g);
    Assert.AreEqual(0, lPlan.EditCount);
    Assert.IsFalse(TSemanticRefactoringPlan.TryCreate(Context, lStatus, 'reason', Sources,
      [Edit(1, 6, 'alpha')], lPlan, lError));
    Assert.IsNull(lPlan);
    Assert.AreEqual('plan.status-edits-mismatch', lError);
  end;
end;

procedure TRefactoringPlanTests.DetectsChangedContextAndManifest;
var
  g: TGarbos;
  lPlan: TSemanticRefactoringPlan;
  lContext: TSemanticPlanContext;
  lSources: TArray<TSemanticPlanSource>;
  lError: string;
begin
  g := Default(TGarbos);
  lSources := Sources;
  Assert.IsTrue(TSemanticRefactoringPlan.TryCreate(Context, TSemanticPlanStatus.Complete,
    '', lSources, [Edit(1, 6, 'alpha')], lPlan, lError), lError);
  GC(lPlan, g);
  Assert.IsTrue(lPlan.MatchesObservations(Context, lSources, lError), lError);
  lContext := Context;
  lContext.ConfigurationFingerprint := 'changed';
  Assert.IsFalse(lPlan.MatchesObservations(lContext, lSources, lError));
  Assert.AreEqual('plan.stale-context', lError);
  lSources[0].IncludeGraphHash := 'changed';
  Assert.IsFalse(lPlan.MatchesObservations(Context, lSources, lError));
  Assert.AreEqual('plan.stale-source', lError);
  Assert.IsFalse(lPlan.MatchesObservations(Context, [], lError));
  Assert.AreEqual('plan.stale-manifest', lError);
end;

procedure TRefactoringPlanTests.ConstructorRejectsInvalidCompleteAndNoChange;
var
  lStatus: TSemanticPlanStatus;
begin
  for lStatus in [TSemanticPlanStatus.Complete, TSemanticPlanStatus.NoChange] do
    Assert.WillRaise(
      procedure
      var
        lPlan: TSemanticRefactoringPlan;
      begin
        if lStatus = TSemanticPlanStatus.Complete then
          lPlan := TSemanticRefactoringPlan.Create(Context, lStatus, '', Sources, [])
        else
          lPlan := TSemanticRefactoringPlan.Create(Context, lStatus, '', Sources,
            [Edit(1, 6, 'alpha')]);
        lPlan.Free;
      end, ESemanticPlanValidation);
end;

initialization
  TDUnitX.RegisterTestFixture(TRefactoringPlanTests);

end.
