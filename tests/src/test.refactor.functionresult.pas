unit Test.Refactor.FunctionResult;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Api,
  DelphiSemantics.Cache,
  DelphiSemantics.CompilerProfile,
  DelphiSemantics.Model,
  DelphiSemantics.Query,
  DelphiSemantics.Refactor,
  DelphiSemantics.Snapshot;

type
  [TestFixture]
  TFunctionResultRefactorTests = class
  private
    function LoadContext: TDelphiSemanticSymbolQueryContext;
    function LoadSnapshotContext(out aSnapshot: TDelphiProjectSnapshot):
      TDelphiSemanticSymbolQueryContext;
  public
    [Test]
    procedure PlansFunctionNameResultReplacementInsideEnclosingFunction;
    [Test]
    procedure PlansFunctionNameResultReplacementAfterNestedRoutine;
    [Test]
    procedure PlansFunctionNameResultReplacementAfterTryFinallyBlock;
    [Test]
    procedure SkipsWithScopedSameTextField;
    [Test]
    procedure PlansFunctionNameResultReplacementFromSnapshotContext;
    [Test]
    procedure ApiFacadePlansFunctionNameResultReplacement;
  end;

implementation

uses
  System.Generics.Collections, System.IOUtils, System.StrUtils, System.SysUtils,
  maxLogic.IOUtils,
  Test.Support;


function TFunctionResultRefactorTests.LoadContext: TDelphiSemanticSymbolQueryContext;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModelOptions: TDelphiSemanticModelOptions;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.CompilerProfileName := 'Delphi-12-Function-Result-v1';
  lCache := TDelphiSemanticUnitCache.Create(lCacheOptions);
  try
    lModelOptions := Default(TDelphiSemanticModelOptions);
    lModelOptions.SourceFileName := FixturePath('FunctionResult', 'FunctionResultUnit.pas');
    lModelOptions.ProjectContextApplied := True;
    Result.UnitModel := lCache.GetOrExtractUnitModel(lModelOptions);
    Result.CompilerProfile := Default(TDelphiSemanticCompilerProfile);
    Result.IndexedUnitModels := [];
    Result.IndexedUnitSourceKinds := [];
    Result.CacheMetrics := lCache.Metrics;
  finally
    lCache.Free;
  end;
end;

function TFunctionResultRefactorTests.LoadSnapshotContext(
  out aSnapshot: TDelphiProjectSnapshot): TDelphiSemanticSymbolQueryContext;
var
  lBuilder: TDelphiProjectSnapshotBuilder;
  lContext: TDelphiSemanticSymbolQueryContext;
  lRoutine: TDelphiSemanticRoutine;
  lSymbol: TSemanticSymbolFact;
  lUnit: TUnitSnapshot;
  lWith: TSemanticWithStatementFact;
  lWithStatement: TDelphiSemanticWithStatement;
begin
  aSnapshot := nil;
  lContext := LoadContext;
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  try
    lUnit := TUnitSnapshot.Create(1, lBuilder.Strings.Intern(lContext.UnitModel.FileName),
      lBuilder.Strings.Intern(lContext.UnitModel.UnitName));
    try
      for lRoutine in lContext.UnitModel.Routines do
      begin
        lSymbol := Default(TSemanticSymbolFact);
        lSymbol.NameId := lBuilder.Strings.Intern(lRoutine.Name);
        lSymbol.OwnerTypeId := lBuilder.Strings.Intern(lRoutine.OwnerName);
        lSymbol.TypeId := lBuilder.Strings.Intern(lRoutine.ReturnType);
        lSymbol.RoutineId := lBuilder.Strings.Intern(lRoutine.Name);
        lSymbol.KindId := lBuilder.Strings.Intern('routine');
        lSymbol.SectionKindId := lBuilder.Strings.Intern(lRoutine.SectionKind);
        lSymbol.SourceKindId := lBuilder.Strings.Intern('project-source');
        lSymbol.SignatureId := lBuilder.Strings.Intern(lRoutine.Signature);
        lSymbol.Line := lRoutine.Line;
        lSymbol.Column := lRoutine.Column;
        lSymbol.EndLine := lRoutine.Line;
        lSymbol.EndColumn := lRoutine.Column + Length(lRoutine.Name) - 1;
        lUnit.AddSymbol(lSymbol);
      end;

      for lWithStatement in lContext.UnitModel.WithStatements do
      begin
        lWith := Default(TSemanticWithStatementFact);
        lWith.SelectorStartLine := lWithStatement.Line;
        lWith.SelectorStartColumn := lWithStatement.Column;
        lWith.BodyStartLine := lWithStatement.BodyLine;
        lWith.BodyStartColumn := lWithStatement.BodyColumn;
        lWith.BodyEndLine := lWithStatement.BodyEndLine;
        lWith.BodyEndColumn := lWithStatement.BodyEndColumn;
        lUnit.AddWithStatement(lWith);
      end;

      lBuilder.AddUnit(lUnit);
      lUnit := nil;
    finally
      lUnit.Free;
    end;

    aSnapshot := lBuilder.Build;
  finally
    lBuilder.Free;
  end;

  Result := Default(TDelphiSemanticSymbolQueryContext);
  Result.ProjectSnapshot := BorrowProjectSnapshot(aSnapshot);
end;

procedure TFunctionResultRefactorTests.ApiFacadePlansFunctionNameResultReplacement;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lPlan: DelphiSemantics.Api.TDelphiSemanticRenamePlan;
begin
  lContext := LoadContext;

  lPlan := TDelphiSemanticApi.PlanFunctionResultRefactorAtPosition(lContext,
    FixturePath('FunctionResult', 'FunctionResultUnit.pas'), 23, 3);

  Assert.AreEqual('planned', lPlan.Status, lPlan.Diagnostic);
  Assert.AreEqual(4, Integer(Length(lPlan.Edits)));
end;

procedure TFunctionResultRefactorTests.PlansFunctionNameResultReplacementInsideEnclosingFunction;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lEdit: TDelphiSemanticTextEdit;
  lLine23Count: Integer;
  lLine25Count: Integer;
  lLine26Count: Integer;
  lPlan: TDelphiSemanticRenamePlan;
begin
  lLine23Count := 0;
  lLine25Count := 0;
  lLine26Count := 0;
  lContext := LoadContext;

  lPlan := TDelphiSemanticRenamePlanner.PlanFunctionResultRefactorAtPosition(lContext,
    FixturePath('FunctionResult', 'FunctionResultUnit.pas'), 23, 3);

  Assert.AreEqual('planned', lPlan.Status, lPlan.Diagnostic);
  Assert.AreEqual(4, Integer(Length(lPlan.Edits)));
  for lEdit in lPlan.Edits do
  begin
    Assert.AreEqual('Result', lEdit.NewText);
    Assert.IsTrue(ContainsText(lEdit.FileName, 'FunctionResultUnit.pas'));
    case lEdit.StartLine of
      23:
      begin
        Assert.AreEqual(3, lEdit.StartColumn);
        Inc(lLine23Count);
      end;
      25:
      begin
        Assert.IsTrue((lEdit.StartColumn = 5) or (lEdit.StartColumn = 20),
          'Expected assignment and read positions on line 25.');
        Inc(lLine25Count);
      end;
      26:
      begin
        Assert.AreEqual(13, lEdit.StartColumn);
        Inc(lLine26Count);
      end;
      13, 21, 27, 28, 29, 30, 68:
        Assert.Fail('Function-result refactor rewrote declaration, call, string, comment, or other function.');
    else
      Assert.Fail('Unexpected function-result edit line: ' + IntToStr(lEdit.StartLine));
    end;
  end;

  Assert.AreEqual(1, lLine23Count, 'Expected first implicit result assignment.');
  Assert.AreEqual(2, lLine25Count, 'Expected assignment and read on the second implicit result line.');
  Assert.AreEqual(1, lLine26Count, 'Expected implicit result read.');
end;

procedure TFunctionResultRefactorTests.PlansFunctionNameResultReplacementFromSnapshotContext;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lPlan: TDelphiSemanticRenamePlan;
  lRequestedFileName: string;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lSnapshot := nil;
  lContext := LoadSnapshotContext(lSnapshot);
  try
    lRequestedFileName := FixturePath('FunctionResult', 'FunctionResultUnit.pas');
    lPlan := TDelphiSemanticRenamePlanner.PlanFunctionResultRefactorAtPosition(lContext,
      lRequestedFileName, 23, 3);

    Assert.AreEqual('planned', lPlan.Status, lPlan.Diagnostic);
    Assert.AreEqual(4, Integer(Length(lPlan.Edits)));
  finally
    lContext.ProjectSnapshot := nil;
    lSnapshot.Free;
  end;
end;

procedure TFunctionResultRefactorTests.PlansFunctionNameResultReplacementAfterTryFinallyBlock;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lEdit: TDelphiSemanticTextEdit;
  lLine45Count: Integer;
  lLine47Count: Integer;
  lLine49Count: Integer;
  lLine51Count: Integer;
  lPlan: TDelphiSemanticRenamePlan;
begin
  lLine45Count := 0;
  lLine47Count := 0;
  lLine49Count := 0;
  lLine51Count := 0;
  lContext := LoadContext;

  lPlan := TDelphiSemanticRenamePlanner.PlanFunctionResultRefactorAtPosition(lContext,
    FixturePath('FunctionResult', 'FunctionResultUnit.pas'), 45, 3);

  Assert.AreEqual('planned', lPlan.Status, lPlan.Diagnostic);
  Assert.AreEqual(7, Integer(Length(lPlan.Edits)));
  for lEdit in lPlan.Edits do
  begin
    Assert.AreEqual('Result', lEdit.NewText);
    case lEdit.StartLine of
      45:
      begin
        Assert.AreEqual(3, lEdit.StartColumn);
        Inc(lLine45Count);
      end;
      47:
      begin
        Assert.IsTrue((lEdit.StartColumn = 5) or (lEdit.StartColumn = 30));
        Inc(lLine47Count);
      end;
      49:
      begin
        Assert.IsTrue((lEdit.StartColumn = 5) or (lEdit.StartColumn = 30));
        Inc(lLine49Count);
      end;
      51:
      begin
        Assert.IsTrue((lEdit.StartColumn = 3) or (lEdit.StartColumn = 28),
          'Expected edit after try/finally block end.');
        Inc(lLine51Count);
      end;
    else
      Assert.Fail('Unexpected try/finally function-result edit line: ' + IntToStr(lEdit.StartLine));
    end;
  end;

  Assert.AreEqual(1, lLine45Count);
  Assert.AreEqual(2, lLine47Count);
  Assert.AreEqual(2, lLine49Count);
  Assert.AreEqual(2, lLine51Count);
end;

procedure TFunctionResultRefactorTests.PlansFunctionNameResultReplacementAfterNestedRoutine;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lEdit: TDelphiSemanticTextEdit;
  lLine39Count: Integer;
  lLine40Count: Integer;
  lPlan: TDelphiSemanticRenamePlan;
begin
  lLine39Count := 0;
  lLine40Count := 0;
  lContext := LoadContext;

  lPlan := TDelphiSemanticRenamePlanner.PlanFunctionResultRefactorAtPosition(lContext,
    FixturePath('FunctionResult', 'FunctionResultUnit.pas'), 39, 3);

  Assert.AreEqual('planned', lPlan.Status, lPlan.Diagnostic);
  Assert.AreEqual(3, Integer(Length(lPlan.Edits)));
  for lEdit in lPlan.Edits do
  begin
    Assert.AreEqual('Result', lEdit.NewText);
    case lEdit.StartLine of
      36:
        Assert.Fail('Nested helper function result must not be rewritten.');
      39:
      begin
        Assert.AreEqual(3, lEdit.StartColumn);
        Inc(lLine39Count);
      end;
      40:
      begin
        Assert.IsTrue((lEdit.StartColumn = 3) or (lEdit.StartColumn = 24),
          'Expected assignment and read positions after nested routine.');
        Inc(lLine40Count);
      end;
    else
      Assert.Fail('Unexpected nested function-result edit line: ' + IntToStr(lEdit.StartLine));
    end;
  end;

  Assert.AreEqual(1, lLine39Count, 'Expected outer result assignment after nested routine.');
  Assert.AreEqual(2, lLine40Count, 'Expected outer result assignment and read after nested routine.');
end;

procedure TFunctionResultRefactorTests.SkipsWithScopedSameTextField;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lEdit: TDelphiSemanticTextEdit;
  lFoundAfterWith: Boolean;
  lFoundBeforeWith: Boolean;
  lPlan: TDelphiSemanticRenamePlan;
begin
  lFoundAfterWith := False;
  lFoundBeforeWith := False;
  lContext := LoadContext;

  lPlan := TDelphiSemanticRenamePlanner.PlanFunctionResultRefactorAtPosition(lContext,
    FixturePath('FunctionResult', 'FunctionResultUnit.pas'), 58, 3);

  Assert.AreEqual('planned', lPlan.Status, lPlan.Diagnostic);
  Assert.AreEqual(3, Integer(Length(lPlan.Edits)));
  for lEdit in lPlan.Edits do
  begin
    if lEdit.StartLine = 61 then
      Assert.Fail('With-scoped same-text field must not be rewritten.');
    if (lEdit.StartLine = 58) and (lEdit.StartColumn = 3) then
      lFoundBeforeWith := True;
    if (lEdit.StartLine = 63) and ((lEdit.StartColumn = 3) or (lEdit.StartColumn = 22)) then
      lFoundAfterWith := True;
  end;

  Assert.IsTrue(lFoundBeforeWith, 'Expected result assignment before with block.');
  Assert.IsTrue(lFoundAfterWith, 'Expected result assignment/read after with block.');

  lPlan := TDelphiSemanticRenamePlanner.PlanFunctionResultRefactorAtPosition(lContext,
    FixturePath('FunctionResult', 'FunctionResultUnit.pas'), 61, 5);
  Assert.AreEqual('blocked', lPlan.Status, 'With-scoped same-text field must not trigger refactor.');
end;

initialization
  TDUnitX.RegisterTestFixture(TFunctionResultRefactorTests);

end.
