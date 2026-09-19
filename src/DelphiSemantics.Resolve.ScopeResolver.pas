unit DelphiSemantics.Resolve.ScopeResolver;

interface

uses
  DelphiSemantics.Model;

type
  TDelphiSemanticRoutineScopeIndex = record
  private
    fParentNamesByLine: TArray<TArray<string>>;
    fRoutineNamesByLine: TArray<string>;
  public
    function ParentRoutineNamesForLine(const aRoutineName: string; const aLine: Integer):
      TArray<string>;
    function RoutineNameForLine(const aLine: Integer): string;
  end;

  TDelphiSemanticScopeResolver = record
  public
    class function BuildRoutineScopeIndex(const aModel: TDelphiSemanticUnitModel):
      TDelphiSemanticRoutineScopeIndex; overload; static;
    class function BuildRoutineScopeIndex(const aModel: TDelphiSemanticUnitModel;
      const aLines: TArray<Integer>): TDelphiSemanticRoutineScopeIndex; overload; static;
  end;

implementation

uses
  System.Classes, System.Generics.Collections, System.IOUtils, System.Math,
  System.RegularExpressions, System.StrUtils, System.SysUtils,
  SimpleParser.Lexer, SimpleParser.Lexer.Types;

type
  TRoutineFrame = record
    Name: string;
    Begun: Boolean;
    BlockDepth: Integer;
  end;

function ContainsRoutineName(const aNames: TList<string>; const aName: string): Boolean;
var
  lName: string;
begin
  for lName in aNames do
    if SameText(lName, aName) then
      Exit(True);

  Result := False;
end;

function FrameRoutineName(const aFrames: TList<TRoutineFrame>): string;
begin
  if aFrames.Count = 0 then
    Exit('');

  Result := aFrames.Last.Name;
end;

function IsScopeIdentifierChar(const aChar: Char): Boolean;
begin
  Result := CharInSet(aChar, ['A'..'Z', 'a'..'z', '0'..'9', '_']);
end;

function StartsWithScopeWord(const aText, aWord: string): Boolean;
begin
  Result := (Length(aText) >= Length(aWord)) and
    SameText(Copy(aText, 1, Length(aWord)), aWord) and
    ((Length(aText) = Length(aWord)) or
    (not IsScopeIdentifierChar(aText[Length(aWord) + 1])));
end;

function ReadScopeToken(const aLine: string; var aIndex: Integer; out aToken: string):
  Boolean; forward;

function ContainsScopeWord(const aText, aWord: string): Boolean;
var
  lIndex: Integer;
  lToken: string;
begin
  lIndex := 1;
  while ReadScopeToken(aText, lIndex, lToken) do
    if SameText(lToken, aWord) then
      Exit(True);

  Result := False;
end;

function LineStartsEndClosedBlock(const aLine: string): Boolean;
var
  lText: string;
begin
  lText := TrimLeft(aLine);
  Result := StartsWithScopeWord(lText, 'try') or StartsWithScopeWord(lText, 'asm') or
    (StartsWithScopeWord(lText, 'case') and ContainsScopeWord(lText, 'of'));
end;

function FrameParentNames(const aFrames: TList<TRoutineFrame>;
  const aRoutineName: string): TArray<string>;
var
  i: Integer;
  lNames: TList<string>;
  lRoutineName: string;
begin
  lNames := TList<string>.Create;
  try
    for i := Pred(aFrames.Count) downto 0 do
    begin
      lRoutineName := aFrames[i].Name;
      if not SameText(lRoutineName, aRoutineName) and
        not ContainsRoutineName(lNames, lRoutineName) then
        lNames.Add(lRoutineName);
    end;
    Result := lNames.ToArray;
  finally
    lNames.Free;
  end;
end;

function RoutineHasNoBody(const aLexer: TmwBasePasLex; const aLineNumber,
  aLastLine: Integer): Boolean;
var
  lDepth: Integer;
begin
  Result := False;
  while (aLexer.TokenID <> ptNull) and (aLexer.PosXY.Y < aLineNumber) do
    aLexer.NextNoJunk;
  if aLexer.PosXY.Y <> aLineNumber then
    Exit;

  lDepth := 0;
  while (aLexer.TokenID <> ptNull) and (aLexer.PosXY.Y <= aLastLine) do
  begin
    if aLexer.TokenID = ptRoundOpen then
      Inc(lDepth)
    else if aLexer.TokenID = ptRoundClose then
      Dec(lDepth)
    else if (aLexer.TokenID = ptSemiColon) and (lDepth = 0) then
      Break;
    aLexer.NextNoJunk;
  end;
  if aLexer.TokenID <> ptSemiColon then
    Exit;
  aLexer.NextNoJunk;

  while (aLexer.TokenID <> ptNull) and (aLexer.PosXY.Y <= aLastLine) do
  begin
    if aLexer.ExID in [ptForward, ptExternal] then
      Exit(True);
    if not (aLexer.ExID in [ptAbstract, ptCdecl, ptDynamic, ptExport, ptDelayed,
      ptFar, ptMessage, ptNear, ptOverload, ptOverride, ptPascal, ptRegister,
      ptReintroduce, ptSafeCall, ptStdCall, ptVirtual, ptLibrary, ptPlatform,
      ptLocal, ptVarargs, ptAssembler, ptStatic, ptInline, ptExperimental,
      ptDeprecated, ptNoreturn]) then
      Exit;
    repeat
      aLexer.NextNoJunk;
    until (aLexer.TokenID in [ptNull, ptSemiColon]) or (aLexer.PosXY.Y > aLastLine);
    if aLexer.TokenID = ptSemiColon then
      aLexer.NextNoJunk;
  end;
end;

procedure ApplyRoutineDeclaration(const aLine: string; const aFrames: TList<TRoutineFrame>;
  const aLexer: TmwBasePasLex; const aLineNumber, aLastLine: Integer);
var
  lFrame: TRoutineFrame;
  lMatch: TMatch;
begin
  lMatch := TRegEx.Match(aLine,
    '^\s*(?:class\s+)?(?:procedure|function|constructor|destructor)\s+' +
    '([A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*)\b', [roIgnoreCase]);
  if not lMatch.Success then
    Exit;
  if RoutineHasNoBody(aLexer, aLineNumber, aLastLine) then
    Exit;

  lFrame := Default(TRoutineFrame);
  lFrame.Name := lMatch.Groups[1].Value;
  aFrames.Add(lFrame);
end;

function ReadScopeToken(const aLine: string; var aIndex: Integer; out aToken: string):
  Boolean;
var
  lStart: Integer;
begin
  while (aIndex <= Length(aLine)) and (not IsScopeIdentifierChar(aLine[aIndex])) do
    Inc(aIndex);

  lStart := aIndex;
  while (aIndex <= Length(aLine)) and IsScopeIdentifierChar(aLine[aIndex]) do
    Inc(aIndex);

  Result := lStart <= Length(aLine);
  if Result then
    aToken := Copy(aLine, lStart, aIndex - lStart)
  else
    aToken := '';
end;

procedure ApplyBlockTokens(const aLine: string; const aFrames: TList<TRoutineFrame>);
var
  lFrame: TRoutineFrame;
  lIndex: Integer;
  lToken: string;
begin
  if LineStartsEndClosedBlock(aLine) and (aFrames.Count > 0) then
  begin
    lFrame := aFrames.Last;
    if lFrame.Begun then
    begin
      Inc(lFrame.BlockDepth);
      aFrames[Pred(aFrames.Count)] := lFrame;
    end;
  end;

  lIndex := 1;
  while ReadScopeToken(aLine, lIndex, lToken) do
  begin
    if aFrames.Count > 0 then
    begin
      lFrame := aFrames.Last;
      if SameText(lToken, 'begin') then
      begin
        lFrame.Begun := True;
        Inc(lFrame.BlockDepth);
        aFrames[Pred(aFrames.Count)] := lFrame;
      end else if SameText(lToken, 'end') and lFrame.Begun and (lFrame.BlockDepth > 0) then
      begin
        Dec(lFrame.BlockDepth);
        if lFrame.BlockDepth = 0 then
          aFrames.Delete(Pred(aFrames.Count))
        else
          aFrames[Pred(aFrames.Count)] := lFrame;
      end;
    end;
  end;
end;

function CleanSourceLine(const aLine: string): string;
var
  i: Integer;
  lInString: Boolean;
begin
  Result := aLine;
  lInString := False;
  i := 1;
  while i <= Length(Result) do
  begin
    if lInString then
    begin
      if Result[i] = '''' then
      begin
        Result[i] := ' ';
        if (i < Length(Result)) and (Result[i + 1] = '''') then
        begin
          Inc(i);
          Result[i] := ' ';
        end else
          lInString := False;
      end else
        Result[i] := ' ';
    end else if (Result[i] = '/') and (i < Length(Result)) and (Result[i + 1] = '/') then
    begin
      while i <= Length(Result) do
      begin
        Result[i] := ' ';
        Inc(i);
      end;
      Break;
    end else if Result[i] = '''' then
    begin
      Result[i] := ' ';
      lInString := True;
    end;
    Inc(i);
  end;
end;

function TDelphiSemanticRoutineScopeIndex.ParentRoutineNamesForLine(
  const aRoutineName: string; const aLine: Integer): TArray<string>;
begin
  if (aLine < Low(fParentNamesByLine)) or (aLine > High(fParentNamesByLine)) then
    Exit(nil);

  Result := Copy(fParentNamesByLine[aLine]);
end;

function TDelphiSemanticRoutineScopeIndex.RoutineNameForLine(const aLine: Integer): string;
begin
  if (aLine < Low(fRoutineNamesByLine)) or (aLine > High(fRoutineNamesByLine)) then
    Exit('');

  Result := fRoutineNamesByLine[aLine];
end;

class function TDelphiSemanticScopeResolver.BuildRoutineScopeIndex(
  const aModel: TDelphiSemanticUnitModel): TDelphiSemanticRoutineScopeIndex;
begin
  Result := BuildRoutineScopeIndex(aModel, nil);
end;

class function TDelphiSemanticScopeResolver.BuildRoutineScopeIndex(
  const aModel: TDelphiSemanticUnitModel; const aLines: TArray<Integer>):
  TDelphiSemanticRoutineScopeIndex;
var
  i: Integer;
  lCaptureAll: Boolean;
  lCaptureLines: TArray<Boolean>;
  lFrames: TList<TRoutineFrame>;
  lInImplementation: Boolean;
  lLexer: TmwBasePasLex;
  lLine: string;
  lLineNumber: Integer;
  lLines: TStringList;
  lMaxCaptureLine: Integer;
  lSourceText: string;
begin
  Result := Default(TDelphiSemanticRoutineScopeIndex);
  lFrames := TList<TRoutineFrame>.Create;
  lLines := TStringList.Create;
  lLexer := nil;
  try
    lSourceText := aModel.SourceText;
    if lSourceText = '' then
    begin
      if not TFile.Exists(aModel.FileName) then
        Exit;

      lSourceText := TFile.ReadAllText(aModel.FileName);
    end;

    if lSourceText = '' then
      Exit;

    lLines.Text := lSourceText;
    SetLength(Result.fRoutineNamesByLine, lLines.Count + 1);
    SetLength(Result.fParentNamesByLine, lLines.Count + 1);
    lCaptureAll := Length(aLines) = 0;
    lMaxCaptureLine := 0;
    if not lCaptureAll then
    begin
      SetLength(lCaptureLines, lLines.Count + 1);
      for lLineNumber in aLines do
        if (lLineNumber >= 1) and (lLineNumber <= lLines.Count) then
        begin
          lCaptureLines[lLineNumber] := True;
          if lLineNumber > lMaxCaptureLine then
            lMaxCaptureLine := lLineNumber;
        end;
    end;
    if lCaptureAll then
      lMaxCaptureLine := lLines.Count;
    lLexer := TmwBasePasLex.Create;
    lLexer.UseDefines := False;
    lLexer.Origin := lSourceText;
    lInImplementation := False;
    for i := 0 to lLines.Count - 1 do
    begin
      if (not lCaptureAll) and (lMaxCaptureLine > 0) and
        ((i + 1) > lMaxCaptureLine) then
        Break;

      lLine := CleanSourceLine(lLines[i]);
      if SameText(lLine.Trim, 'implementation') then
      begin
        lInImplementation := True;
        Continue;
      end;

      if lInImplementation then
      begin
        if lCaptureAll then
        begin
          Result.fRoutineNamesByLine[i + 1] := FrameRoutineName(lFrames);
          if lFrames.Count > 1 then
            Result.fParentNamesByLine[i + 1] := FrameParentNames(lFrames,
              Result.fRoutineNamesByLine[i + 1]);
        end else if lCaptureLines[i + 1] then
        begin
          Result.fRoutineNamesByLine[i + 1] := FrameRoutineName(lFrames);
          if lFrames.Count > 1 then
            Result.fParentNamesByLine[i + 1] := FrameParentNames(lFrames,
              Result.fRoutineNamesByLine[i + 1]);
        end;
        ApplyRoutineDeclaration(lLine, lFrames, lLexer, i + 1, lMaxCaptureLine);
        ApplyBlockTokens(lLine, lFrames);
      end;
    end;
  finally
    lLexer.Free;
    lLines.Free;
    lFrames.Free;
  end;
end;

end.
