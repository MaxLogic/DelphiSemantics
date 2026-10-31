unit B;
interface
uses A;
type TAlias = {$IFDEF LINUX}TAlternate{$ELSE}TCapture{$ENDIF};
implementation
end.
