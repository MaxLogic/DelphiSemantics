unit BaseHelp;
interface
uses TypesUnit;
type TBaseHelp = class helper for TBase
  function AbsentCount: Integer;
end;
implementation
function TBaseHelp.AbsentCount: Integer;
begin
  Result := 11;
end;
end.
