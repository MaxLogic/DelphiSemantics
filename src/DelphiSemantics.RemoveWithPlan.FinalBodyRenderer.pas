unit DelphiSemantics.RemoveWithPlan.FinalBodyRenderer;

interface

uses
  DelphiSemantics.SourceContext, DelphiSemantics.WithBinding;

type
  TFinalBodyRendererRange = record
    StartLine: Integer;
    StartColumn: Integer;
    EndLine: Integer;
    EndColumn: Integer;
  end;

  TFinalBodyRendererSelectorDecision = record
    SelectorText: string;
    QualifierText: string;
    Strategy: string;
    ReceiverType: string;
    TempName: string;
    DeclarationText: string;
    InitializationText: string;
    Reason: string;
  end;

  TFinalBodyRendererRequest = record
    Binding: TDelphiSemanticWithBinding;
    BodyText: string;
    OriginalRange: TFinalBodyRendererRange;
    ReplacementRange: TFinalBodyRendererRange;
    TempDecisions: TArray<TFinalBodyRendererSelectorDecision>;
    ControlledStatement: Boolean;
    TrimmedBeforeOuterElse: Boolean;
    UseArchitectureStableRoutineEndTrim: Boolean;
  end;

function BuildFinalReplacementText(const aRequest: TFinalBodyRendererRequest;
  const aLineCache: TDelphiSemanticSourceContextCache; out aReplacementText: string;
  out aReplacementRange: TFinalBodyRendererRange; out aReason: string): Boolean;

implementation

uses
  System.Math, System.StrUtils, System.SysUtils;

function IndentText(const aColumn: Integer): string;
begin
  Result := StringOfChar(' ', Max(0, aColumn - 1));
end;

function IsSimplePointerDereferenceSelector(const aText: string): Boolean;
var
  i: Integer;
  lBaseText: string;
begin
  Result := False;
  if not EndsText('^', Trim(aText)) then
    Exit;
  lBaseText := Copy(Trim(aText), 1, Length(Trim(aText)) - 1);
  if lBaseText = '' then
    Exit;
  for i := 1 to Length(lBaseText) do
    if not CharInSet(lBaseText[i], ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
      Exit;
  Result := True;
end;

function BuildTempInitializationText(
  const aDecisions: TArray<TFinalBodyRendererSelectorDecision>;
  const aIndentColumn: Integer): string;
var
  lDecision: TFinalBodyRendererSelectorDecision;
begin
  Result := '';
  for lDecision in aDecisions do
  begin
    if lDecision.InitializationText <> '' then
      Result := Result + IndentText(aIndentColumn) + lDecision.InitializationText +
        sLineBreak;
  end;
end;

function TrimTrailingEnclosingRoutineEndOriginal(var aText: string): Boolean;
var
  lBeforeLastLine: string;
  lLastBreak: Integer;
  lLastLine: string;
  lPreviousBreak: Integer;
  lPreviousLine: string;
  lText: string;
begin
  Result := False;
  lText := aText;
  while EndsText(sLineBreak, lText) do
    Delete(lText, Length(lText) - Length(sLineBreak) + 1, Length(sLineBreak));
  while (lText <> '') and CharInSet(lText[Length(lText)], [#10, #13]) do
    Delete(lText, Length(lText), 1);
  if EndsText(sLineBreak + 'END;', lText) then
  begin
    lBeforeLastLine := Copy(lText, 1,
      Length(lText) - Length(sLineBreak + 'END;'));
    lPreviousBreak := LastDelimiter(#10#13, lBeforeLastLine);
    if lPreviousBreak > 0 then
      lPreviousLine := Copy(lBeforeLastLine, lPreviousBreak + 1, MaxInt)
    else
      lPreviousLine := lBeforeLastLine;
    if SameText(Trim(lPreviousLine), 'end') then
    begin
      aText := lBeforeLastLine + sLineBreak;
      Exit(True);
    end;
  end;
  lLastBreak := LastDelimiter(#10#13, lText);
  if lLastBreak <= 0 then
    Exit;
  lLastLine := Copy(lText, lLastBreak + 1, MaxInt);
  if SameText(Trim(lLastLine), 'end;') then
  begin
    lBeforeLastLine := Copy(lText, 1, lLastBreak - 1);
    while EndsText(sLineBreak, lBeforeLastLine) do
      Delete(lBeforeLastLine, Length(lBeforeLastLine) - Length(sLineBreak) + 1,
        Length(sLineBreak));
    while (lBeforeLastLine <> '') and
      CharInSet(lBeforeLastLine[Length(lBeforeLastLine)], [#10, #13]) do
      Delete(lBeforeLastLine, Length(lBeforeLastLine), 1);
    lPreviousBreak := LastDelimiter(#10#13, lBeforeLastLine);
    if lPreviousBreak > 0 then
      lPreviousLine := Copy(lBeforeLastLine, lPreviousBreak + 1, MaxInt)
    else
      lPreviousLine := lBeforeLastLine;
    if SameText(Trim(lPreviousLine), 'end') then
    begin
      aText := lBeforeLastLine + sLineBreak;
      Exit(True);
    end;
  end;
end;

function TrimTrailingEnclosingRoutineEndStable(var aText: string;
  const aBindingColumn: Integer): Boolean;
var
  lBeforeLastLine: string;
  lLastBreak: Integer;
  lLastLine: string;
  lPreviousBreak: Integer;
  lPreviousLine: string;
  lText: string;
begin
  Result := False;
  lText := aText;
  while EndsText(sLineBreak, lText) do
    Delete(lText, Length(lText) - Length(sLineBreak) + 1, Length(sLineBreak));
  while (lText <> '') and CharInSet(lText[Length(lText)], [#10, #13]) do
    Delete(lText, Length(lText), 1);
  lLastBreak := Length(lText);
  while (lLastBreak > 0) and
    (not CharInSet(lText[lLastBreak], [#10, #13])) do
    Dec(lLastBreak);
  if lLastBreak <= 0 then
    Exit;

  lLastLine := Copy(lText, lLastBreak + 1, MaxInt);
  if SameText(Trim(lLastLine), 'end;') and
    (Length(lLastLine) - Length(TrimLeft(lLastLine)) + 1 < aBindingColumn) then
  begin
    lBeforeLastLine := Copy(lText, 1, lLastBreak - 1);
    while EndsText(sLineBreak, lBeforeLastLine) do
      Delete(lBeforeLastLine, Length(lBeforeLastLine) - Length(sLineBreak) + 1,
        Length(sLineBreak));
    while (lBeforeLastLine <> '') and CharInSet(lBeforeLastLine[Length(lBeforeLastLine)],
      [#10, #13]) do
      Delete(lBeforeLastLine, Length(lBeforeLastLine), 1);
    lPreviousBreak := Length(lBeforeLastLine);
    while (lPreviousBreak > 0) and
      (not CharInSet(lBeforeLastLine[lPreviousBreak], [#10, #13])) do
      Dec(lPreviousBreak);
    if lPreviousBreak > 0 then
      lPreviousLine := Copy(lBeforeLastLine, lPreviousBreak + 1, MaxInt)
    else
      lPreviousLine := lBeforeLastLine;
    if SameText(Trim(lPreviousLine), 'end') then
    begin
      aText := lBeforeLastLine + sLineBreak;
      Exit(True);
    end;
  end;
end;

function TrimTrailingEnclosingRoutineEnd(var aText: string;
  const aBindingColumn: Integer;
  const aUseArchitectureStableTrim: Boolean): Boolean;
begin
  if aUseArchitectureStableTrim then
    Result := TrimTrailingEnclosingRoutineEndStable(aText, aBindingColumn)
  else
    Result := TrimTrailingEnclosingRoutineEndOriginal(aText);
end;

procedure RemoveTrailingSemicolon(var aText: string);
var
  lIndex: Integer;
begin
  lIndex := Length(aText);
  while (lIndex > 0) and CharInSet(aText[lIndex], [#9, ' ', #10, #13]) do
    Dec(lIndex);
  if (lIndex > 0) and (aText[lIndex] = ';') then
    Delete(aText, lIndex, 1);
end;

function BuildFinalReplacementText(const aRequest: TFinalBodyRendererRequest;
  const aLineCache: TDelphiSemanticSourceContextCache; out aReplacementText: string;
  out aReplacementRange: TFinalBodyRendererRange; out aReason: string): Boolean;
var
  lBinding: TDelphiSemanticWithBinding;
  lHasTempInitialization: Boolean;
  lIndentColumn: Integer;
  lLines: TArray<string>;
  lLineText: string;
  lNeedsControlledWrapper: Boolean;
  lPreviousLineIndex: Integer;
  lStatementIndent: string;
  lTempDecision: TFinalBodyRendererSelectorDecision;
  lTempText: string;
  lControlledStatement: Boolean;
begin
  Result := False;
  aReplacementText := '';
  aReplacementRange := aRequest.ReplacementRange;
  aReason := '';
  lBinding := aRequest.Binding;
  lControlledStatement := aRequest.ControlledStatement;

  if aLineCache.TryGetValue(lBinding.FileName, lLines) then
  begin
    for lPreviousLineIndex := lBinding.Line - 1 downto 1 do
    begin
      lLineText := Trim(lLines[lPreviousLineIndex - 1]);
      if (lLineText = '') or StartsText('//', lLineText) then
        Continue;
      if SameText(lLineText, 'initialization') or SameText(lLineText, 'finalization') then
      begin
        aReason := 'controlled-with-statement';
        Exit(False);
      end;
      lControlledStatement := EndsText(' then', LowerCase(lLineText)) or
        SameText(lLineText, 'then') or EndsText(' do', LowerCase(lLineText)) or
        SameText(lLineText, 'do') or EndsText(' else', LowerCase(lLineText)) or
        SameText(lLineText, 'else') or EndsText(':', lLineText);
      Break;
    end;
  end;

  lHasTempInitialization := False;
  for lTempDecision in aRequest.TempDecisions do
  begin
    if lTempDecision.InitializationText <> '' then
    begin
      lHasTempInitialization := True;
      Break;
    end;
  end;
  if lControlledStatement and
    (lHasTempInitialization or
    (not StartsText('begin', LowerCase(Trim(aRequest.BodyText))))) then
    lIndentColumn := lBinding.Column + 2
  else
    lIndentColumn := lBinding.Column;
  lTempText := BuildTempInitializationText(aRequest.TempDecisions, lIndentColumn);
  if lControlledStatement and lHasTempInitialization and
    StartsText('begin', LowerCase(TrimLeft(aRequest.BodyText))) then
    aReplacementText := IndentText(lIndentColumn) + TrimLeft(aRequest.BodyText)
  else if ContainsText(lBinding.SelectorText, '^') then
    aReplacementText := IndentText(lIndentColumn) + TrimLeft(aRequest.BodyText)
  else if (aRequest.BodyText <> '') and CharInSet(aRequest.BodyText[1], [#9, ' ']) then
    aReplacementText := aRequest.BodyText
  else
    aReplacementText := IndentText(lIndentColumn) + aRequest.BodyText;
  aReplacementText := lTempText + aReplacementText;
  lNeedsControlledWrapper := lControlledStatement and
    ((lTempText <> '') or (not StartsText('begin', LowerCase(Trim(aRequest.BodyText)))));
  if lNeedsControlledWrapper then
  begin
    lStatementIndent := IndentText(lBinding.Column);
    aReplacementText := lStatementIndent + 'begin' + sLineBreak +
      aReplacementText + sLineBreak + lStatementIndent + 'end;';
  end;
  if (not lNeedsControlledWrapper) and
    ((lTempText <> '') or (lControlledStatement and
    StartsText('begin', LowerCase(Trim(aRequest.BodyText))))) and
    TrimTrailingEnclosingRoutineEnd(aReplacementText, lBinding.Column,
    aRequest.UseArchitectureStableRoutineEndTrim) then
  begin
    aReplacementRange.EndColumn := 1;
    if lTempText = '' then
    begin
      while EndsText(sLineBreak, aReplacementText) do
        Delete(aReplacementText, Length(aReplacementText) - Length(sLineBreak) + 1,
          Length(sLineBreak));
      while (aReplacementText <> '') and
        CharInSet(aReplacementText[Length(aReplacementText)], [#10, #13]) do
        Delete(aReplacementText, Length(aReplacementText), 1);
      aReplacementText := aReplacementText + sLineBreak + ';';
    end;
  end;
  if (not lNeedsControlledWrapper) and (lTempText = '') and
    (not IsSimplePointerDereferenceSelector(lBinding.SelectorText)) and
    (not ((Pos('[', lBinding.SelectorText) > 0) and
    ContainsText(lBinding.SelectorText, '^'))) and
    TrimTrailingEnclosingRoutineEnd(aReplacementText, lBinding.Column,
    aRequest.UseArchitectureStableRoutineEndTrim) then
  begin
    if lBinding.Column > 2 then
      aReplacementRange.EndColumn := lBinding.Column - 2
    else
      aReplacementRange.EndColumn := 1;
    aReplacementText := aReplacementText + IndentText(aReplacementRange.EndColumn);
  end;
  if (not lNeedsControlledWrapper) and (lTempText = '') and
    (lBinding.Column > 3) and
    EndsText(sLineBreak + IndentText(lBinding.Column - 2) + 'END;',
    aReplacementText) then
  begin
    aReplacementRange.EndColumn := lBinding.Column - 2;
    Delete(aReplacementText, Length(aReplacementText) -
      Length(sLineBreak + IndentText(aReplacementRange.EndColumn) + 'END;') + 1,
      Length(sLineBreak + IndentText(aReplacementRange.EndColumn) + 'END;'));
    aReplacementText := aReplacementText + sLineBreak +
      IndentText(aReplacementRange.EndColumn);
  end;
  if aRequest.TrimmedBeforeOuterElse then
    RemoveTrailingSemicolon(aReplacementText);
  Result := True;
end;

end.
