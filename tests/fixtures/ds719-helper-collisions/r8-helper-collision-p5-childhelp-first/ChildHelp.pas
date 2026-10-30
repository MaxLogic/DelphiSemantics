unit ChildHelp;
interface
uses TypesUnit;
type TChildHelp = class helper for TRec
  function Count: Integer;
end;
implementation
function TChildHelp.Count: Integer;
begin
  Result := 19;
end;
end.
