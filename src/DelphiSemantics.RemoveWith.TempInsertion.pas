unit DelphiSemantics.RemoveWith.TempInsertion;

interface

function TryFindTempInsertionLine(const aLines: TArray<string>;
  const aBeforeLine: Integer; const aRoutineName: string;
  out aLine: Integer; out aHasVarSection: Boolean): Boolean;

implementation

uses
  System.StrUtils, System.SysUtils;

// Shared extraction of the planner's existing insertion rule. A failed source
// lookup never invents a position at which a capture type would be visible.
function TryFindTempInsertionLine(const aLines: TArray<string>;
  const aBeforeLine: Integer; const aRoutineName: string;
  out aLine: Integer; out aHasVarSection: Boolean): Boolean;
var
  lBeginLine: Integer;
  lInsertLine: Integer;
  lLineIndex: Integer;
  lText: string;
  lRoutineLine: Integer;
begin
  Result := False;
  aHasVarSection := False;
  aLine := 0;
  if (aBeforeLine < 1) or (aBeforeLine > Length(aLines)) then
    Exit;
  lRoutineLine := 0;
  for lLineIndex := aBeforeLine downto 1 do
  begin
    if (aRoutineName <> '') and ContainsText(aLines[lLineIndex - 1],
      aRoutineName) and (ContainsText(aLines[lLineIndex - 1], 'procedure') or
      ContainsText(aLines[lLineIndex - 1], 'function') or
      ContainsText(aLines[lLineIndex - 1], 'constructor') or
      ContainsText(aLines[lLineIndex - 1], 'destructor')) then
    begin
      lRoutineLine := lLineIndex;
      Break;
    end;
  end;
  lInsertLine := 0;
  if lRoutineLine > 0 then
  begin
    lBeginLine := 0;
    for lLineIndex := lRoutineLine + 1 to Length(aLines) do
    begin
      lText := Trim(aLines[lLineIndex - 1]);
      if SameText(lText, 'var') then
        aHasVarSection := True;
      if aHasVarSection and (SameText(lText, 'label') or SameText(lText, 'const') or
        SameText(lText, 'type') or StartsText('procedure ', lText) or
        StartsText('function ', lText) or StartsText('constructor ', lText) or
        StartsText('destructor ', lText)) then
      begin
        lInsertLine := lLineIndex;
        Break;
      end else if (not aHasVarSection) and (SameText(lText, 'label') or
        SameText(lText, 'const') or SameText(lText, 'type')) then
      begin
        lBeginLine := lLineIndex;
        lInsertLine := lLineIndex;
        Break;
      end else if StartsText('procedure ', lText) or StartsText('function ', lText) or
        StartsText('constructor ', lText) or StartsText('destructor ', lText) then
      begin
        lBeginLine := lLineIndex;
        lInsertLine := lLineIndex;
        Break;
      end else if StartsText('begin', lText) and ((Length(lText) = Length('begin')) or
        StartsText('{', Trim(Copy(lText, Length('begin') + 1, MaxInt))) or
        StartsText('//', Trim(Copy(lText, Length('begin') + 1, MaxInt)))) then
      begin
        lBeginLine := lLineIndex;
        lInsertLine := lLineIndex;
        Break;
      end;
    end;
    if (lBeginLine <> 0) or (lInsertLine <> 0) then
    begin
      aLine := lInsertLine;
      Exit(True);
    end;
  end;
  for lLineIndex := aBeforeLine downto 1 do
  begin
    lText := Trim(aLines[lLineIndex - 1]);
    if StartsText('begin', lText) and ((Length(lText) = Length('begin')) or
      StartsText('{', Trim(Copy(lText, Length('begin') + 1, MaxInt))) or
      StartsText('//', Trim(Copy(lText, Length('begin') + 1, MaxInt)))) then
    begin
      aLine := lLineIndex;
      Exit(True);
    end;
  end;
end;

end.
