unit DelphiSemantics.RemoveWithPlan.FinalRewrite;

interface

uses
  DelphiSemantics.RemoveWithPlan;

type
  TDelphiSemanticRemoveWithFinalRewriteSelectorDecisionInput = record
    SelectorText: string;
    QualifierText: string;
    Strategy: string;
    ReceiverType: string;
    TempName: string;
    DeclarationText: string;
    InitializationText: string;
    Reason: string;
    SemanticId: string;
  end;

function FinalStatementRewriteRecipe(
  const aStatement: TDelphiSemanticRemoveWithFinalStatement;
  const aDecisions:
    TArray<TDelphiSemanticRemoveWithFinalRewriteSelectorDecisionInput>):
  TDelphiSemanticRemoveWithRewriteRecipe;
procedure EnsureFinalStatementRewriteRecipe(
  var aStatement: TDelphiSemanticRemoveWithFinalStatement);
procedure ApplyFinalStatementRewriteRecipe(var aStatement:
  TDelphiSemanticRemoveWithFinalStatement;
  const aRecipe: TDelphiSemanticRemoveWithRewriteRecipe);
procedure SyncFinalStatementRewriteRecipe(
  var aStatement: TDelphiSemanticRemoveWithFinalStatement);
procedure AddFinalTextEdit(var aStatement: TDelphiSemanticRemoveWithFinalStatement;
  const aEdit: TDelphiSemanticRemoveWithFinalTextEdit; const aPrepend: Boolean);

implementation

uses
  System.SysUtils;

function FinalRewriteSelectorDecision(
  const aDecision: TDelphiSemanticRemoveWithFinalRewriteSelectorDecisionInput):
  TDelphiSemanticRemoveWithRewriteSelectorDecision;
begin
  Result := Default(TDelphiSemanticRemoveWithRewriteSelectorDecision);
  Result.SelectorText := aDecision.SelectorText;
  Result.QualifierText := aDecision.QualifierText;
  Result.Strategy := aDecision.Strategy;
  Result.ReceiverType := aDecision.ReceiverType;
  Result.TempName := aDecision.TempName;
  Result.DeclarationText := aDecision.DeclarationText;
  Result.InitializationText := aDecision.InitializationText;
  Result.Reason := aDecision.Reason;
  Result.SemanticId := aDecision.SemanticId;
end;

function FinalRewriteRuleId(const aStatement:
  TDelphiSemanticRemoveWithFinalStatement;
  const aDecisions:
    TArray<TDelphiSemanticRemoveWithFinalRewriteSelectorDecisionInput>): string;
var
  lDecision: TDelphiSemanticRemoveWithFinalRewriteSelectorDecisionInput;
begin
  if SameText(aStatement.Status, 'planned') then
  begin
    for lDecision in aDecisions do
      if SameText(lDecision.Reason, 'property-chain-direct-qualification') then
        Exit('source-backed-selector-chain');
    for lDecision in aDecisions do
      if lDecision.TempName <> '' then
        Exit(lDecision.Strategy);
    if Length(aDecisions) > 0 then
      Exit(aDecisions[0].Strategy);
    Exit('final-statement-render');
  end;

  if aStatement.Reason <> '' then
    Exit(aStatement.Reason);
  Result := aStatement.Status;
end;

function FinalRewriteRenderInstruction(
  const aStatement: TDelphiSemanticRemoveWithFinalStatement): string;
begin
  if SameText(aStatement.Status, 'planned') then
  begin
    if Length(aStatement.Edits) > 0 then
      Exit('render-final-edits');
    Exit('render-final-statement');
  end;
  Result := 'skip-final-statement';
end;

function FinalRewriteReplacementRange(
  const aStatement: TDelphiSemanticRemoveWithFinalStatement):
  TDelphiSemanticRemoveWithSourceRange;
var
  lEdit: TDelphiSemanticRemoveWithFinalTextEdit;
begin
  for lEdit in aStatement.Edits do
    if SameText(lEdit.Kind, 'replace-statement') then
      Exit(lEdit.Range);
  if Length(aStatement.Edits) > 0 then
    Exit(aStatement.Edits[0].Range);
  Result := aStatement.Range;
end;

function FinalStatementRewriteRecipe(
  const aStatement: TDelphiSemanticRemoveWithFinalStatement;
  const aDecisions:
    TArray<TDelphiSemanticRemoveWithFinalRewriteSelectorDecisionInput>):
  TDelphiSemanticRemoveWithRewriteRecipe;
var
  i: Integer;
begin
  Result := Default(TDelphiSemanticRemoveWithRewriteRecipe);
  Result.Status := aStatement.Status;
  Result.Reason := aStatement.Reason;
  Result.SafetyReason := aStatement.SafetyReason;
  Result.RuleId := FinalRewriteRuleId(aStatement, aDecisions);
  Result.Provenance := 'semantic-remove-with-final-planner';
  Result.RenderInstruction := FinalRewriteRenderInstruction(aStatement);
  Result.ReplacementRange := FinalRewriteReplacementRange(aStatement);
  Result.ReplacementText := aStatement.ReplacementText;
  SetLength(Result.SelectorDecisions, Length(aDecisions));
  for i := 0 to High(aDecisions) do
    Result.SelectorDecisions[i] := FinalRewriteSelectorDecision(aDecisions[i]);
  Result.TempDeclarations := Copy(aStatement.Temps);
  Result.TextEdits := Copy(aStatement.Edits);
end;

procedure EnsureFinalStatementRewriteRecipe(
  var aStatement: TDelphiSemanticRemoveWithFinalStatement);
begin
  if aStatement.RewriteRecipe.Status <> '' then
    Exit;
  if aStatement.Status = '' then
    Exit;
  aStatement.RewriteRecipe := FinalStatementRewriteRecipe(aStatement, []);
end;

procedure ApplyFinalStatementRewriteRecipe(var aStatement:
  TDelphiSemanticRemoveWithFinalStatement;
  const aRecipe: TDelphiSemanticRemoveWithRewriteRecipe);
begin
  aStatement.RewriteRecipe := aRecipe;
  aStatement.ReplacementText := aRecipe.ReplacementText;
  aStatement.Temps := Copy(aRecipe.TempDeclarations);
  aStatement.Edits := Copy(aRecipe.TextEdits);
end;

procedure SyncFinalStatementRewriteRecipe(
  var aStatement: TDelphiSemanticRemoveWithFinalStatement);
begin
  if aStatement.RewriteRecipe.Status = '' then
    Exit;
  aStatement.RewriteRecipe.Status := aStatement.Status;
  aStatement.RewriteRecipe.Reason := aStatement.Reason;
  aStatement.RewriteRecipe.SafetyReason := aStatement.SafetyReason;
  if aStatement.RewriteRecipe.RuleId = '' then
    aStatement.RewriteRecipe.RuleId := FinalRewriteRuleId(aStatement, []);
  if aStatement.RewriteRecipe.Provenance = '' then
    aStatement.RewriteRecipe.Provenance := 'semantic-remove-with-final-planner';
  aStatement.RewriteRecipe.RenderInstruction :=
    FinalRewriteRenderInstruction(aStatement);
  aStatement.RewriteRecipe.ReplacementRange :=
    FinalRewriteReplacementRange(aStatement);
  aStatement.RewriteRecipe.ReplacementText := aStatement.ReplacementText;
  aStatement.RewriteRecipe.TempDeclarations := Copy(aStatement.Temps);
  aStatement.RewriteRecipe.TextEdits := Copy(aStatement.Edits);
end;

procedure AddFinalTextEdit(var aStatement: TDelphiSemanticRemoveWithFinalStatement;
  const aEdit: TDelphiSemanticRemoveWithFinalTextEdit; const aPrepend: Boolean);
var
  i: Integer;
  lIndex: Integer;
begin
  if aPrepend then
  begin
    SetLength(aStatement.Edits, Length(aStatement.Edits) + 1);
    for i := High(aStatement.Edits) downto 1 do
      aStatement.Edits[i] := aStatement.Edits[i - 1];
    aStatement.Edits[0] := aEdit;
  end else
  begin
    lIndex := Length(aStatement.Edits);
    SetLength(aStatement.Edits, lIndex + 1);
    aStatement.Edits[lIndex] := aEdit;
  end;
  SyncFinalStatementRewriteRecipe(aStatement);
end;

end.
