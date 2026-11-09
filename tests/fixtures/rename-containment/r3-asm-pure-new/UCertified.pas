unit UCertified;
interface
var SharedValue: Integer;
procedure Touch;
implementation
procedure Touch;
asm
  mov eax, RenamedValue
end;
end.
