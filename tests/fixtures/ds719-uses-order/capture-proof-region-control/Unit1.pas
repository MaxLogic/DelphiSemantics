unit Unit1;
interface
procedure Run;
implementation
uses A;
var
  lReceiver: TCapture;
procedure Unrelated; begin {$REGION unused}{$IFDEF LINUX}Write('');{$ENDIF}{$ENDREGION} end;
procedure Run;
begin
  with lReceiver do Writeln(Data);
end;
end.
