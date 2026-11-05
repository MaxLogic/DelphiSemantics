unit Unit1;
interface
type
  TWrong = record
    Count, Padding: Integer;
  end;
  TRight = record
    Count: Integer;
  end;
procedure Run;
implementation
procedure Execute(var aRec: TWrong); overload;
begin
  with aRec do Count := 3;
end;
procedure Execute(var aRec: TRight); overload;
begin
  with aRec do Count := 7;
end;
procedure Run;
var
  lRec: TRight;
  lWrong: TWrong;
begin
  lRec.Count := 0;
  lWrong.Count := 0;
  Execute(lWrong);
  Execute(lRec);
  Writeln(SizeOf(lRec), ':', lRec.Count, ':', lWrong.Count);
end;
end.
