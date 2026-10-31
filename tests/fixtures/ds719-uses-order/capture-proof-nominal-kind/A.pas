unit A;
interface
type TCapture = {$IFDEF LINUX}object{$ELSE}record{$ENDIF}
  Data: Integer;
end;
implementation
end.
