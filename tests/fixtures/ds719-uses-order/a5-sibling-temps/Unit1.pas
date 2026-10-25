unit Unit1;
interface
uses U, A;
procedure Run;
implementation
procedure Change(var aFirst: PForeign; var aSecond: PRec);
begin
  with aFirst^ do
    Value := 7;
  with aSecond^ do
    Value := 9;
end;
procedure Run;
var
  lFirst, lSecond: A.TRec;
  lFirstPointer, lSecondPointer: A.PRec;
begin
  lFirstPointer := @lFirst;
  lSecondPointer := @lSecond;
  Change(lFirstPointer, lSecondPointer);
  Writeln(lFirst.Value, ' ', lSecond.Value);
end;
end.
