unit GlobalAnonymousWithUnit;

interface

var
  ModuleError: record
    fc: SmallInt;
    ModuleName: array [0..80] of AnsiChar;
    LineNo: Word;
    Pos: Word;
    ErrorChar: Integer;
  end;

procedure Run;

implementation

procedure Run;
begin
  with ModuleError do
  begin
    fc := LineNo;
    ErrorChar := Pos;
  end;
end;

end.
