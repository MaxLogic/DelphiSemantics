unit DelphiSemantics.RemoveWithPlan;

interface

uses
  DelphiSemantics.WithBinding;

type
  TDelphiSemanticRemoveWithSourceRange = record
    StartLine: Integer;
    StartColumn: Integer;
    EndLine: Integer;
    EndColumn: Integer;
  end;

  TDelphiSemanticRemoveWithVerification = record
    Kind: string;
    Description: string;
  end;

  TDelphiSemanticRemoveWithEdit = record
    Kind: string;
    FileName: string;
    StatementId: string;
    ExpectedFileHash: string;
    ExpectedSourceText: string;
    Range: TDelphiSemanticRemoveWithSourceRange;
    ReplacementText: string;
    ApplyMode: string;
    SemanticReason: string;
    SemanticId: string;
    ReferenceIds: TArray<string>;
  end;

  TDelphiSemanticRemoveWithSkippedStatement = record
    FileName: string;
    StatementId: string;
    Range: TDelphiSemanticRemoveWithSourceRange;
    Reason: string;
    SafetyReason: string;
    SemanticId: string;
  end;

  TDelphiSemanticRemoveWithPlan = record
    Operation: string;
    Status: string;
    ContextFingerprint: string;
    BaselineSemanticModelVersion: string;
    Diagnostic: string;
    RequiredVerification: TArray<TDelphiSemanticRemoveWithVerification>;
    Edits: TArray<TDelphiSemanticRemoveWithEdit>;
    SkippedStatements: TArray<TDelphiSemanticRemoveWithSkippedStatement>;
  end;

  TDelphiSemanticRemoveWithPlanner = record
  public
    class function Plan(const aFacts: TDelphiSemanticProjectWithBindingFacts):
      TDelphiSemanticRemoveWithPlan; static;
  end;

implementation

uses
  System.Generics.Collections, System.Hash, System.IOUtils, System.SysUtils;

function BindingRange(const aBinding: TDelphiSemanticWithBinding):
  TDelphiSemanticRemoveWithSourceRange;
begin
  Result.StartLine := aBinding.Line;
  Result.StartColumn := aBinding.Column;
  Result.EndLine := aBinding.EndLine;
  Result.EndColumn := aBinding.EndColumn;
end;

function SourceFileHash(const aFileName: string): string;
begin
  if not TFile.Exists(aFileName) then
    Exit('');

  Result := THashSHA2.GetHashStringFromFile(aFileName);
end;

function SourceTextForRange(const aFileName: string;
  const aRange: TDelphiSemanticRemoveWithSourceRange): string;
var
  lBuilder: TStringBuilder;
  lEndColumn: Integer;
  lLine: string;
  lLineIndex: Integer;
  lLines: TArray<string>;
  lStartColumn: Integer;
begin
  Result := '';
  if (aRange.StartLine <= 0) or (aRange.EndLine <= 0) or
    (not TFile.Exists(aFileName)) then
    Exit;

  lLines := TFile.ReadAllLines(aFileName);
  if (aRange.StartLine > Length(lLines)) or (aRange.EndLine > Length(lLines)) then
    Exit;

  lBuilder := TStringBuilder.Create;
  try
    for lLineIndex := aRange.StartLine to aRange.EndLine do
    begin
      lLine := lLines[lLineIndex - 1];
      lStartColumn := 1;
      if lLineIndex = aRange.StartLine then
        lStartColumn := aRange.StartColumn;
      lEndColumn := Length(lLine) + 1;
      if lLineIndex = aRange.EndLine then
        lEndColumn := aRange.EndColumn;
      if lStartColumn < 1 then
        lStartColumn := 1;
      if lEndColumn < lStartColumn then
        lEndColumn := lStartColumn;
      if lEndColumn > Length(lLine) then
        lEndColumn := Length(lLine);
      if lStartColumn <= Length(lLine) then
        lBuilder.Append(Copy(lLine, lStartColumn, lEndColumn - lStartColumn + 1));
      if lLineIndex < aRange.EndLine then
        lBuilder.Append(sLineBreak);
    end;
    Result := lBuilder.ToString;
  finally
    lBuilder.Free;
  end;
end;

function ReferenceIdsForBinding(const aBinding: TDelphiSemanticWithBinding): TArray<string>;
var
  lIds: TList<string>;
  lReference: TDelphiSemanticBoundReference;
begin
  lIds := TList<string>.Create;
  try
    for lReference in aBinding.References do
      if lReference.SemanticId <> '' then
        lIds.Add(lReference.SemanticId);
    Result := lIds.ToArray;
  finally
    lIds.Free;
  end;
end;

procedure AddVerification(var aPlan: TDelphiSemanticRemoveWithPlan; const aKind,
  aDescription: string);
var
  lIndex: Integer;
begin
  lIndex := Length(aPlan.RequiredVerification);
  SetLength(aPlan.RequiredVerification, lIndex + 1);
  aPlan.RequiredVerification[lIndex].Kind := aKind;
  aPlan.RequiredVerification[lIndex].Description := aDescription;
end;

procedure AddEdit(var aPlan: TDelphiSemanticRemoveWithPlan;
  const aBinding: TDelphiSemanticWithBinding);
var
  lEdit: TDelphiSemanticRemoveWithEdit;
  lIndex: Integer;
begin
  lEdit := Default(TDelphiSemanticRemoveWithEdit);
  lEdit.Kind := 'remove-with-candidate';
  lEdit.FileName := aBinding.FileName;
  lEdit.StatementId := aBinding.SemanticId;
  lEdit.Range := BindingRange(aBinding);
  lEdit.ExpectedFileHash := SourceFileHash(aBinding.FileName);
  lEdit.ExpectedSourceText := SourceTextForRange(aBinding.FileName, lEdit.Range);
  lEdit.ReplacementText := lEdit.ExpectedSourceText;
  lEdit.ApplyMode := 'requires-dak-compatibility-adapter';
  lEdit.SemanticReason := 'semantic-with-binding-candidate';
  lEdit.SemanticId := aBinding.SemanticId;
  lEdit.ReferenceIds := ReferenceIdsForBinding(aBinding);

  lIndex := Length(aPlan.Edits);
  SetLength(aPlan.Edits, lIndex + 1);
  aPlan.Edits[lIndex] := lEdit;
end;

procedure AddSkippedStatement(var aPlan: TDelphiSemanticRemoveWithPlan;
  const aBinding: TDelphiSemanticWithBinding; const aReason,
  aSafetyReason: string);
var
  lIndex: Integer;
  lStatement: TDelphiSemanticRemoveWithSkippedStatement;
begin
  lStatement := Default(TDelphiSemanticRemoveWithSkippedStatement);
  lStatement.FileName := aBinding.FileName;
  lStatement.StatementId := aBinding.SemanticId;
  lStatement.Range := BindingRange(aBinding);
  lStatement.Reason := aReason;
  lStatement.SafetyReason := aSafetyReason;
  lStatement.SemanticId := aBinding.SemanticId;

  lIndex := Length(aPlan.SkippedStatements);
  SetLength(aPlan.SkippedStatements, lIndex + 1);
  aPlan.SkippedStatements[lIndex] := lStatement;
end;

function HasStableSourceRange(const aBinding: TDelphiSemanticWithBinding): Boolean;
begin
  Result := (Trim(aBinding.FileName) <> '') and TFile.Exists(aBinding.FileName) and
    (aBinding.Line > 0) and (aBinding.Column > 0) and (aBinding.EndLine >= aBinding.Line) and
    (aBinding.EndColumn > 0);
end;

class function TDelphiSemanticRemoveWithPlanner.Plan(
  const aFacts: TDelphiSemanticProjectWithBindingFacts): TDelphiSemanticRemoveWithPlan;
var
  lBinding: TDelphiSemanticWithBinding;
begin
  Result := Default(TDelphiSemanticRemoveWithPlan);
  Result.Operation := 'remove-with';
  Result.Status := 'planned';
  Result.ContextFingerprint := aFacts.ContextFingerprint;
  Result.BaselineSemanticModelVersion := 'project-with-binding-v1';

  AddVerification(Result, 'baseline-compile',
    'Compile the project before source-changing apply.');
  AddVerification(Result, 'context-fingerprint',
    'Apply only when the semantic context fingerprint still matches.');
  AddVerification(Result, 'source-range',
    'Apply only when expected file hashes and source ranges still match.');
  AddVerification(Result, 'post-edit-compile',
    'Compile the project after source-changing apply.');
  AddVerification(Result, 'rollback-on-failure',
    'Rollback edited files when post-edit verification fails.');

  if Result.ContextFingerprint = '' then
  begin
    Result.Status := 'blocked';
    Result.Diagnostic := 'Missing semantic context fingerprint.';
    Exit;
  end;

  for lBinding in aFacts.Bindings do
  begin
    if HasStableSourceRange(lBinding) then
      AddEdit(Result, lBinding)
    else
      AddSkippedStatement(Result, lBinding, 'SOURCE_RANGE_UNAVAILABLE',
        'stable source file, hash, and source range are required');
  end;
end;

end.
