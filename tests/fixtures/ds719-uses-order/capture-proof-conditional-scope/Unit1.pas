unit Unit1;
interface
procedure Run;
implementation
uses A;
var
  lReceiver: TCapture;

procedure Run; {$IFDEF LINUX}procedure Inner;{$ENDIF} type TCapture = record Data, Other: Integer; end; {$IFDEF LINUX}begin end;{$ENDIF} begin with lReceiver do Writeln(Data); end;
end.
