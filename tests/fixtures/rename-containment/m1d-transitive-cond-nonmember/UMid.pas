unit UMid;
interface
procedure MidBump;
implementation
uses {$IFDEF MSWINDOWS}UUser{$ENDIF};
procedure MidBump;
begin
  Bump;
end;
end.
