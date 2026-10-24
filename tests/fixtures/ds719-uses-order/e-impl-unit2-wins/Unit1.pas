unit Unit1;
interface
uses Winapi.Windows, System.SysUtils;
var
 G: Integer = 0;
 Extra: Integer = 0;
procedure Run;
implementation
uses Unit2;
procedure Run;
var SR: TSearchRec;
begin
  FillChar(SR, SizeOf(SR), 0);
  SR.Name := 'abc';
  with SR do
  begin
    Extra := 5;
  end;
  Writeln(SR.Extra, ' ', Extra);
end;
end.
