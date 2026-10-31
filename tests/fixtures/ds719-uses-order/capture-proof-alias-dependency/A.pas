unit A;
interface
type TCapture = record Data: Integer; end;
  TAlternate = record Data: Byte; end;
  TDependency = {$IFDEF LINUX}TAlternate{$ELSE}TCapture{$ENDIF};
implementation
end.
