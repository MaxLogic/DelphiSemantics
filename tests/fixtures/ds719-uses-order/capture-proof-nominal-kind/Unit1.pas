unit Unit1;
interface
procedure Run;
implementation
uses A, B;

var Item: TCapture;
procedure Run;
begin
  Item.Data := 7;
  with Item do Writeln(Data);
end;
end.
