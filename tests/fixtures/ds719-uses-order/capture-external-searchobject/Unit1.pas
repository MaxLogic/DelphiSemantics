unit Unit1;
interface
uses System.SysUtils;
type TSearchObject = TSearchRec;
procedure Run;
implementation
procedure Run;
var lValue: TSearchObject;
begin
  lValue := Default(TSearchObject);
  lValue.Name := 'abc';
  with lValue do Name := 'Z';
  Writeln(lValue.Name);
end;
end.
