unit Unit1;
interface
procedure Run;
implementation
uses A;
var
  lReceiver: TCapture;
procedure Unrelated; begin {$IFDEF LINUX}{$SCOPEDENUMS OFF}{$ELSE}{$SCOPEDENUMS ON}{$ENDIF} end; type TNoise = (TCapture);
procedure Run;
begin
  with lReceiver do Writeln(Data);
end;
end.
