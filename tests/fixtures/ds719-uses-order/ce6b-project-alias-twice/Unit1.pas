unit Unit1;
interface
uses A, MyWin;
procedure Run;
implementation
var
  Item: TRect;
  Top: Integer;
procedure Run;
begin
  Top := 0;
  with Item do
  begin
    Left := 1;
    Top := 5;
  end;
  Writeln(SizeOf(Item), ' ', Top);
end;
end.
