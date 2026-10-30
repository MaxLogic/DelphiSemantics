unit ChildHelp;
interface
uses TypesUnit;
type TChildHelp = class helper for TRec
  function AbsentCount: Integer;
end;
implementation
function TChildHelp.AbsentCount: Integer;
begin
  Result := 19;
end;
end.
