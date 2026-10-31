unit Unit1;
interface
procedure Run;
implementation
uses A, C;
var
  lReceiver: TCapture;

procedure Run;
begin
  with lReceiver do Writeln(Data);
end;
end.
