unit Unit1;
interface
procedure Run;
implementation
uses A;
var
  lReceiver: TCapture;
{$IFDEF LINUX}type TUnrelated = record Y: Int64; end;{$ENDIF}
procedure Run;
begin
  with lReceiver do Writeln(Data);
end;
end.
