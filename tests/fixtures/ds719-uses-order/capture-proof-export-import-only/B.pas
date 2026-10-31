unit B;
interface
uses A,
{$IFDEF MSWINDOWS}System.Math{$ENDIF}
{$IFDEF LINUX}System.StrUtils{$ENDIF};
type TUnrelated = record X: Integer; end;
implementation
end.
