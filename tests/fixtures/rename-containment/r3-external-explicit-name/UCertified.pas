unit UCertified;
interface
function GetTickCount: Cardinal; stdcall; external 'kernel32.dll' name 'GetTickCount';
function Ticks: Cardinal;
implementation
function Ticks: Cardinal;
begin
  Result := GetTickCount;
end;
end.
