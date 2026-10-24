unit Unit1;
interface
uses Unit3, Unit2, System.SysUtils;
procedure Run;
implementation
procedure Run;
begin
  GRec.Name := 'abc';
  with GRec do
  begin
    Name := 'xyz';
  end;
  Writeln(GRec.Extra, ' ', GRec.Name);
end;
end.
