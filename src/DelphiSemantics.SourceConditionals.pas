unit DelphiSemantics.SourceConditionals;

interface

type
  // Internal, source-coordinate activity evidence; no compiler values are inferred.
  TDelphiSemanticSourceActivity = (saInactive, saActive, saUnknown);

  TDelphiSemanticActivitySpan = record
    FileName: string;
    SourceText: string;
    StartOffset: Integer;
    EndOffset: Integer;
    Activity: TDelphiSemanticSourceActivity;
    // In-memory inclusion instance, shared with copied-source and line-origin evidence.
    ExpansionId: string;
  end;

  TDelphiSemanticSourceConditionals = record
  public
    class function ImportOrderUnknown(const aSource, aEvidence: string;
      const aIncludeFileNames, aImports: TArray<string>): Boolean; static;
    class function UnavailableActivity: string; static;
    class function EncodeActivity(const aSource, aFileName: string;
      const aSpans: TArray<TDelphiSemanticActivitySpan>): string; static;
    class function SourceForScan(const aSource, aEvidence: string): string; static;
    class function UnknownAtOffset(const aSource, aEvidence: string;
      const aOffset: Integer): Boolean; static;
    class function RangeIsKnownActive(const aSource, aEvidence: string;
      const aStartOffset, aEndOffset: Integer): Boolean; static;
    class function UnknownAtPosition(const aSource, aEvidence: string;
      const aLine, aColumn: Integer): Boolean; static;
    class function InsideInactiveNeverConditionalRegion(const aLines: TArray<string>;
      const aStartLine, aLine: Integer): Boolean; static;
    class function LineHasConditionalDirective(const aLineText: string): Boolean; overload; static;
    class function LineHasConditionalDirective(const aLines: TArray<string>;
      const aLine: Integer): Boolean; overload; static;
  end;

implementation

uses
  System.Classes, System.IOUtils, System.StrUtils, System.SysUtils,
  DelphiSemantics.Preprocess;

const
  // Stored in the existing exact-text pool. Plain evidence retains its original bytes.
  cActivityPrefix = #1'DS-ACTIVITY-1:';

class function TDelphiSemanticSourceConditionals.ImportOrderUnknown(
  const aSource, aEvidence: string;
  const aIncludeFileNames, aImports: TArray<string>): Boolean;
var
  lClauses, lIncludedClauses, lExpanded, lStates, lIncludedText: string;
  lFileName, lImportName, lImportToken: string;
  lHasUses, lIncludedUses, lKnown: Boolean;
  lExpandedIncludes, lStack: TStringList;

  function ResolveInclude(const aArgument, aDirectory: string; out aFileName: string): Boolean;
  var
    lCandidate, lExpected, lSuffix: string;
  begin
    aFileName := '';
    lSuffix := aArgument.Trim.Trim([#39, '"']).Replace('/', PathDelim);
    if lSuffix = '' then
      Exit(False);
    lExpected := '';
    if aDirectory <> '' then
      lExpected := TPath.GetFullPath(TPath.Combine(aDirectory, lSuffix));
    for lCandidate in aIncludeFileNames do
      if ((lExpected <> '') and SameText(lCandidate, lExpected)) or
        ((lExpected = '') and (SameText(lCandidate, lSuffix) or
          EndsText(PathDelim + lSuffix, lCandidate))) then
      begin
        if (aFileName <> '') and not SameText(aFileName, lCandidate) then
          Exit(False);
        aFileName := lCandidate;
      end;
    Result := aFileName <> '';
  end;

  function Expand(const aText, aActivity, aDirectory: string; const aIsInclude: Boolean;
    out aExpanded, aStates: string; out aKnown: Boolean): Boolean;
  var
    i, j, lStart, lCopied, lArgumentStart, lDirectiveEnd: Integer;
    lDirective, lConditional, lChildKnown, lResolved: Boolean;
    lToken, lArgument, lChildFile, lChildText, lChildExpanded, lChildStates: string;

    function States(const aFirst, aLength: Integer): string;
    begin
      if StartsStr(cActivityPrefix, aActivity) then
        Result := Copy(aActivity, Length(cActivityPrefix) + aFirst, aLength)
      else
        Result := StringOfChar('A', aLength);
    end;

  begin
    aExpanded := '';
    aStates := '';
    aKnown := True;
    if StartsStr(cActivityPrefix, aActivity) and
      (Length(aActivity) <> Length(cActivityPrefix) + Length(aText)) then
      Exit(False);
    lConditional := False;
    lCopied := 1;
    i := 1;
    while i <= Length(aText) do
    begin
      if aText[i] = #39 then
      begin
        Inc(i);
        while i <= Length(aText) do
        begin
          if aText[i] = #39 then
          begin
            Inc(i);
            if (i > Length(aText)) or (aText[i] <> #39) then
              Break;
          end;
          Inc(i);
        end;
      end else if (aText[i] = '/') and (i < Length(aText)) and (aText[i + 1] = '/') then
      begin
        while (i <= Length(aText)) and not CharInSet(aText[i], [#10, #13]) do
          Inc(i);
      end else if (aText[i] = '{') or ((aText[i] = '(') and
        (i < Length(aText)) and (aText[i + 1] = '*')) then
      begin
        lStart := i;
        if aText[i] = '{' then
          j := i + 1
        else
          j := i + 2;
        lDirective := (j <= Length(aText)) and (aText[j] = '$');
        if lDirective then
          Inc(j);
        while (j <= Length(aText)) and CharInSet(aText[j], [#9, ' ']) do
          Inc(j);
        i := j;
        while (j <= Length(aText)) and CharInSet(aText[j], ['A'..'Z', 'a'..'z']) do
          Inc(j);
        lToken := Copy(aText, i, j - i);
        lArgumentStart := i;
        i := j;
        if aText[lStart] = '{' then
        begin
          while (i <= Length(aText)) and (aText[i] <> '}') do
            Inc(i);
          lDirectiveEnd := i;
          if i <= Length(aText) then
            Inc(i);
        end else begin
          while (i < Length(aText)) and
            not ((aText[i] = '*') and (aText[i + 1] = ')')) do
            Inc(i);
          lDirectiveEnd := i;
          Inc(i, 2);
          if i > Length(aText) + 1 then
            i := Length(aText) + 1;
        end;
        if lDirective and MatchText(lToken, ['IF', 'IFDEF', 'IFNDEF', 'IFOPT', 'ELSE',
          'ELSEIF', 'ENDIF', 'IFEND', 'DEFINE', 'UNDEF']) then
          lConditional := True;
        lArgument := '';
        if lDirective then
          lArgument := TDelphiSemanticPreprocessor.IncludeArgumentFromDirective(
            Copy(aText, lArgumentStart, lDirectiveEnd - lArgumentStart));
        if lArgument <> '' then
        begin
          lResolved := ResolveInclude(lArgument, aDirectory, lChildFile) and
            (lStack.Count < 64) and (lStack.IndexOf(lChildFile) < 0);
          lChildExpanded := '';
          lChildStates := '';
          lChildKnown := False;
          if lResolved then
          begin
            lStack.Add(lChildFile);
            try
              try
                lChildText := TFile.ReadAllText(lChildFile);
                lResolved := Expand(lChildText, '', ExtractFilePath(lChildFile), True,
                  lChildExpanded, lChildStates, lChildKnown);
                if lResolved then
                  lExpandedIncludes.Add(lChildFile);
              except
                on E: EInOutError do
                  lResolved := False;
                on E: EFOpenError do
                  lResolved := False;
              end;
            finally
              lStack.Delete(lStack.Count - 1);
            end;
          end;
          aExpanded := aExpanded + Copy(aText, lCopied, lStart - lCopied);
          aStates := aStates + States(lCopied, lStart - lCopied);
          if not lResolved or not lChildKnown then
          begin
            // Keep the directive and its proven root activity at the original insertion point.
            aExpanded := aExpanded + Copy(aText, lStart, i - lStart);
            aStates := aStates + States(lStart, i - lStart);
            aKnown := False;
          end;
          aExpanded := aExpanded + lChildExpanded;
          if Pos('?', States(lStart, i - lStart)) > 0 then
            aStates := aStates + StringOfChar('?', Length(lChildExpanded))
          else
            aStates := aStates + lChildStates;
          lCopied := i;
        end;
      end else
        Inc(i);
    end;
    aExpanded := aExpanded + Copy(aText, lCopied, MaxInt);
    aStates := aStates + States(lCopied, Length(aText) - lCopied + 1);
    // This API has no per-include activity witness. A1a's fallback forbids conditional/define content.
    if aIsInclude and lConditional then
      aKnown := False;
    if aIsInclude and not aKnown then
      aStates := StringOfChar('?', Length(aExpanded));
    Result := True;
  end;

  function Scan(const aText, aActivity: string; out aClauses: string;
    out aHasUses: Boolean): Boolean;
  var
    i, j, lStart, lDirectiveStart, lDirectiveEnd: Integer;
    lClause, lDirective, lInclude: Boolean;
    lToken: string;

    function UnknownRange(const aFirst, aLast: Integer): Boolean;
    var
      k: Integer;
    begin
      for k := aFirst to aLast do
        if UnknownAtOffset(aText, aActivity, k) then
          Exit(True);
      Result := False;
    end;

  begin
    Result := False;
    aClauses := '';
    aHasUses := False;
    if StartsStr(cActivityPrefix, aActivity) and
      (Length(aActivity) <> Length(cActivityPrefix) + Length(aText)) then
      Exit(True);
    lClause := False;
    i := 1;
    while i <= Length(aText) do
    begin
      lStart := i;
      if (aText[i] = '''') then
      begin
        Inc(i);
        while i <= Length(aText) do
        begin
          if aText[i] = '''' then
          begin
            Inc(i);
            if (i > Length(aText)) or (aText[i] <> '''') then
              Break;
          end;
          Inc(i);
        end;
      end else if (aText[i] = '/') and (i < Length(aText)) and
        (aText[i + 1] = '/') then
      begin
        while (i <= Length(aText)) and not CharInSet(aText[i], [#10, #13]) do
          Inc(i);
      end else if (aText[i] = '{') or ((aText[i] = '(') and
        (i < Length(aText)) and (aText[i + 1] = '*')) then
      begin
        if aText[i] = '{' then
          j := i + 1
        else
          j := i + 2;
        lDirective := (j <= Length(aText)) and (aText[j] = '$');
        if lDirective then
          Inc(j);
        while (j <= Length(aText)) and CharInSet(aText[j], [#9, ' ']) do
          Inc(j);
        i := j;
        while (j <= Length(aText)) and CharInSet(aText[j], ['A'..'Z', 'a'..'z']) do
          Inc(j);
        lDirectiveStart := i;
        i := j;
        if aText[lStart] = '{' then
        begin
          while (i <= Length(aText)) and (aText[i] <> '}') do
            Inc(i);
          lDirectiveEnd := i;
          if i <= Length(aText) then
            Inc(i);
        end else begin
          while (i < Length(aText)) and
            not ((aText[i] = '*') and (aText[i + 1] = ')')) do
            Inc(i);
          lDirectiveEnd := i;
          Inc(i, 2);
          if i > Length(aText) + 1 then
            i := Length(aText) + 1;
        end;
        // Share preprocessing's filename rule: I+ and I- are compiler switches.
        lInclude := lDirective and
          (TDelphiSemanticPreprocessor.IncludeArgumentFromDirective(
            Copy(aText, lDirectiveStart, lDirectiveEnd - lDirectiveStart)) <> '');
        if lInclude and (lClause or UnknownRange(lStart, i - 1)) then
          Exit(True);
      end else if CharInSet(aText[i], ['A'..'Z', 'a'..'z', '_']) then
      begin
        Inc(i);
        while (i <= Length(aText)) and
          CharInSet(aText[i], ['A'..'Z', 'a'..'z', '0'..'9', '_']) do
          Inc(i);
        lToken := Copy(aText, lStart, i - lStart);
        if SameText(lToken, 'uses') then
        begin
          lClause := True;
          aHasUses := True;
        end;
        if (SameText(lToken, 'interface') or SameText(lToken, 'implementation')) and
          UnknownRange(lStart, i - 1) then
          Exit(True);
        if lClause then
          aClauses := aClauses + '#' + LowerCase(lToken);
      end else begin
        if lClause and (aText[i] = '.') then
          aClauses := aClauses + '#.';
        if aText[i] = ';' then
        begin
          if lClause and UnknownAtOffset(aText, aActivity, i) then
            Exit(True);
          lClause := False;
          aClauses := aClauses + '#;';
        end;
        Inc(i);
      end;
      if lClause and UnknownRange(lStart, i - 1) then
        Exit(True);
    end;
    aClauses := aClauses + '#';
  end;

begin
  lExpandedIncludes := TStringList.Create;
  lStack := TStringList.Create;
  try
    lExpandedIncludes.CaseSensitive := False;
    lStack.CaseSensitive := False;
    if not Expand(aSource, aEvidence, '', False, lExpanded, lStates, lKnown) or
      Scan(lExpanded, cActivityPrefix + lStates, lClauses, lHasUses) then
      Exit(True);
    for lFileName in aIncludeFileNames do
      if lExpandedIncludes.IndexOf(lFileName) < 0 then
      begin
        try
          lIncludedText := TFile.ReadAllText(lFileName);
          if Scan(lIncludedText, '', lIncludedClauses, lIncludedUses) or lIncludedUses then
            // An observed import clause without its insertion point cannot prove order.
            Exit(True);
        except
          on E: EInOutError do
            Exit(True);
          on E: EFOpenError do
            Exit(True);
        end;
      end;
    for lImportName in aImports do
    begin
      lImportToken := '#' + LowerCase(lImportName).Replace('.', '#.#') + '#';
      if Pos(lImportToken, lClauses) = 0 then
        Exit(True);
    end;
    Result := False;
  finally
    lStack.Free;
    lExpandedIncludes.Free;
  end;
end;

class function TDelphiSemanticSourceConditionals.UnavailableActivity: string;
begin
  // A malformed-length marker means no source offset is proven active or inactive.
  // We retain this state in the existing evidence slot on both cold and warm models.
  Result := cActivityPrefix;
end;

class function TDelphiSemanticSourceConditionals.EncodeActivity(const aSource,
  aFileName: string; const aSpans: TArray<TDelphiSemanticActivitySpan>): string;
var
  i: Integer;
  lSpan: TDelphiSemanticActivitySpan;
  lState: Char;
begin
  Result := StringOfChar('?', Length(aSource));
  for i := 1 to Length(aSource) do
    if CharInSet(aSource[i], [#9, #10, #13, ' ']) then
      Result[i] := 'I';
  for lSpan in aSpans do
    if SameText(lSpan.FileName, aFileName) then
    begin
      if (lSpan.SourceText <> aSource) or (lSpan.StartOffset < 1) or
        (lSpan.EndOffset > Length(aSource) + 1) or
        (lSpan.EndOffset < lSpan.StartOffset) then
        Exit(UnavailableActivity);
      case lSpan.Activity of
        saActive: lState := 'A';
        saUnknown: lState := '?';
      else
        lState := 'I';
      end;
      for i := lSpan.StartOffset to lSpan.EndOffset - 1 do
        Result[i] := lState;
    end;
  Result := cActivityPrefix + Result;
end;

class function TDelphiSemanticSourceConditionals.SourceForScan(const aSource,
  aEvidence: string): string;
var
  i: Integer;
begin
  if StartsStr(cActivityPrefix, aEvidence) then
  begin
    Result := aSource;
    if Length(aEvidence) <> Length(cActivityPrefix) + Length(aSource) then
      Exit;
    for i := 1 to Length(aSource) do
      if (aEvidence[Length(cActivityPrefix) + i] = 'I') and
        not CharInSet(Result[i], [#13, #10]) then
        Result[i] := ' ';
  end else if (aEvidence <> '') and (Length(aEvidence) = Length(aSource)) then
    Result := aEvidence
  else
    Result := aSource;
end;

class function TDelphiSemanticSourceConditionals.UnknownAtOffset(const aSource,
  aEvidence: string; const aOffset: Integer): Boolean;
begin
  Result := False;
  if not StartsStr(cActivityPrefix, aEvidence) then
    Exit;
  if (Length(aEvidence) <> Length(cActivityPrefix) + Length(aSource)) or
    (aOffset < 1) or (aOffset > Length(aSource)) then
    Exit(True);
  Result := not CharInSet(aEvidence[Length(cActivityPrefix) + aOffset], ['A', 'I']);
end;

class function TDelphiSemanticSourceConditionals.RangeIsKnownActive(const aSource,
  aEvidence: string; const aStartOffset, aEndOffset: Integer): Boolean;
var
  i: Integer;
  lLastOffset: Integer;
  lEncoded: Boolean;
begin
  Result := False;
  if (aStartOffset < 1) or (aEndOffset < aStartOffset) or
    (aEndOffset > Length(aSource) + 1) then
    Exit;
  lEncoded := StartsStr(cActivityPrefix, aEvidence);
  if lEncoded and (Length(aEvidence) <> Length(cActivityPrefix) + Length(aSource)) then
    Exit;
  if (not lEncoded) and (aEvidence <> '') and (Length(aEvidence) <> Length(aSource)) then
    Exit;
  // Source ranges carry inclusive end columns. The legacy EOF sentinel has no character.
  lLastOffset := aEndOffset;
  if lLastOffset > Length(aSource) then
    lLastOffset := Length(aSource);
  for i := aStartOffset to lLastOffset do
  begin
    if lEncoded then
    begin
      // Proven inactive spans preserve the base raw-text rewrite behavior.
      // Only unknown or unavailable activity blocks the whole source range.
      if not CharInSet(aEvidence[Length(cActivityPrefix) + i], ['A', 'I']) then
        Exit;
    end else if not CharInSet(aSource[i], [#9, #10, #13, ' ']) and
      (aEvidence <> '') and (aEvidence[i] <> aSource[i]) then
      Exit;
  end;
  Result := True;
end;

class function TDelphiSemanticSourceConditionals.UnknownAtPosition(const aSource,
  aEvidence: string; const aLine, aColumn: Integer): Boolean;
var
  i: Integer;
  lLine: Integer;
  lStart: Integer;
begin
  Result := False;
  if not StartsStr(cActivityPrefix, aEvidence) then
    Exit;
  lLine := 1;
  lStart := 1;
  for i := 1 to Length(aSource) do
  begin
    if lLine = aLine then
      Exit(UnknownAtOffset(aSource, aEvidence, lStart + aColumn - 1));
    if aSource[i] = #10 then
    begin
      Inc(lLine);
      lStart := i + 1;
    end;
  end;
  Result := True;
end;

class function TDelphiSemanticSourceConditionals.InsideInactiveNeverConditionalRegion(
  const aLines: TArray<string>; const aStartLine, aLine: Integer): Boolean;
var
  i: Integer;
  lInactiveDepth: Integer;
  lLineText: string;
begin
  Result := False;
  if (aStartLine <= 0) or (aLine <= 0) then
    Exit;
  lInactiveDepth := 0;
  for i := aStartLine to aLine do
  begin
    if (i <= 0) or (i > Length(aLines)) then
      Continue;
    lLineText := Trim(aLines[i - 1]);
    if StartsText('{$IFDEF NEVER', lLineText) then
      Inc(lInactiveDepth)
    else if StartsText('{$ENDIF', lLineText) and (lInactiveDepth > 0) then
      Dec(lInactiveDepth);
    if (i = aLine) and (lInactiveDepth > 0) then
      Exit(True);
  end;
end;

class function TDelphiSemanticSourceConditionals.LineHasConditionalDirective(
  const aLineText: string): Boolean;
begin
  Result := StartsText('{$IF', Trim(aLineText));
end;

class function TDelphiSemanticSourceConditionals.LineHasConditionalDirective(
  const aLines: TArray<string>; const aLine: Integer): Boolean;
begin
  Result := (aLine > 0) and (aLine <= Length(aLines)) and
    LineHasConditionalDirective(aLines[aLine - 1]);
end;

end.
