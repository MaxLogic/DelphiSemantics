unit UCertified;
interface
function GetCounter: Cardinal; stdcall; external 'kernel32.dll' name 'GetTickCount';
function Ticks: Cardinal;
implementation
function Ticks: Cardinal;
begin
  Result := GetCounter;
end;
end.
