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
      TDelphiSemanticRoutineScopeIndex; static;
  end;

implementation

uses
  System.Classes, System.Generics.Collections, System.IOUtils, System.Math,
  System.RegularExpressions, System.StrUtils, System.SysUtils;

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

function LineStartsEndClosedBlock(const aLine: string): Boolean;
begin
  Result := TRegEx.IsMatch(aLine, '^\s*(try|case\b.*\bof|asm)\b', [roIgnoreCase]);
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

procedure ApplyRoutineDeclaration(const aLine: string; const aFrames: TList<TRoutineFrame>);
var
  lFrame: TRoutineFrame;
  lMatch: TMatch;
begin
  lMatch := TRegEx.Match(aLine,
    '^\s*(?:class\s+)?(?:procedure|function)\s+(?:[A-Za-z_][A-Za-z0-9_]*\.)?' +
    '([A-Za-z_][A-Za-z0-9_]*)\b', [roIgnoreCase]);
  if not lMatch.Success then
    Exit;

  lFrame := Default(TRoutineFrame);
  lFrame.Name := lMatch.Groups[1].Value;
  aFrames.Add(lFrame);
end;

procedure ApplyBlockTokens(const aLine: string; const aFrames: TList<TRoutineFrame>);
var
  lFrame: TRoutineFrame;
  lMatch: TMatch;
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

  lMatch := TRegEx.Match(aLine, '\b(begin|end)\b', [roIgnoreCase]);
  while lMatch.Success do
  begin
    if aFrames.Count > 0 then
    begin
      lFrame := aFrames.Last;
      if SameText(lMatch.Value, 'begin') then
      begin
        lFrame.Begun := True;
        Inc(lFrame.BlockDepth);
        aFrames[Pred(aFrames.Count)] := lFrame;
      end else if lFrame.Begun and (lFrame.BlockDepth > 0) then
      begin
        Dec(lFrame.BlockDepth);
        if lFrame.BlockDepth = 0 then
          aFrames.Delete(Pred(aFrames.Count))
        else
          aFrames[Pred(aFrames.Count)] := lFrame;
      end;
    end;
    lMatch := lMatch.NextMatch;
  end;
end;

function CleanSourceLine(const aLine: string): string;
begin
  Result := TRegEx.Replace(aLine, '''(?:''''|[^''])*''', ' ', [roSingleLine]);
  Result := TRegEx.Replace(Result, '//.*$', ' ', [roIgnoreCase]);
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
var
  i: Integer;
  lFrames: TList<TRoutineFrame>;
  lInImplementation: Boolean;
  lLine: string;
  lLines: TStringList;
begin
  Result := Default(TDelphiSemanticRoutineScopeIndex);
  lFrames := TList<TRoutineFrame>.Create;
  lLines := TStringList.Create;
  try
    if not TFile.Exists(aModel.FileName) then
      Exit;

    lLines.Text := TFile.ReadAllText(aModel.FileName);
    SetLength(Result.fRoutineNamesByLine, lLines.Count + 1);
    SetLength(Result.fParentNamesByLine, lLines.Count + 1);
    lInImplementation := False;
    for i := 0 to lLines.Count - 1 do
    begin
      lLine := CleanSourceLine(lLines[i]);
      if SameText(lLine.Trim, 'implementation') then
      begin
        lInImplementation := True;
        Continue;
      end;

      if lInImplementation then
      begin
        Result.fRoutineNamesByLine[i + 1] := FrameRoutineName(lFrames);
        Result.fParentNamesByLine[i + 1] := FrameParentNames(lFrames,
          Result.fRoutineNamesByLine[i + 1]);
        ApplyRoutineDeclaration(lLine, lFrames);
        ApplyBlockTokens(lLine, lFrames);
      end;
    end;
  finally
    lLines.Free;
    lFrames.Free;
  end;
end;

end.
