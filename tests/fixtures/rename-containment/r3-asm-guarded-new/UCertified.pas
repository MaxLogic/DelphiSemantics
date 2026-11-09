unit UCertified;
interface
var SharedValue: Integer;
procedure Touch;
implementation
procedure Touch;
begin
{$IFDEF CPUX86}
  asm
    mov eax, RenamedValue
  end;
{$ENDIF}
end;
end.
