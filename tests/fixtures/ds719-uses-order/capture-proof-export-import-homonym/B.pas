unit B;
interface
uses A,
{$IFDEF MSWINDOWS}System.Math{$ENDIF}
{$IFDEF LINUX}System.StrUtils{$ENDIF};
{$IFDEF LINUX}type TCapture = record X: Integer; end;{$ENDIF}
implementation
end.
