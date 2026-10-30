unit Unit1;
interface
uses A, System.SysUtils;
procedure Run;
implementation
var
  Size: Int64;
procedure Work(var SR: TSearchRec);
begin
  with SR do
  begin
    Time := 7;
    Size := 3;
  end;
end;
procedure Run;
var
  SR: TSearchRec;
begin
  Size := 0;
  Work(SR);
  Writeln(SR.Time, ' ', Size);
end;
end.
