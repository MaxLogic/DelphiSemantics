unit A;
interface
type TCapture = record
  Data: {$IFDEF LINUX}Byte{$ELSE}Integer{$ENDIF};
end;
implementation
end.
