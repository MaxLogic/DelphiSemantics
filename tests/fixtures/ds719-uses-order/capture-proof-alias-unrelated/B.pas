unit B;
interface
uses A;
type TUnrelated = {$IFDEF LINUX}Byte{$ELSE}Integer{$ENDIF};
implementation
end.
