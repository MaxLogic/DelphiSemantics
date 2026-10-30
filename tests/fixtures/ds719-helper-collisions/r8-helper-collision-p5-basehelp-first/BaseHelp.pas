unit BaseHelp;
interface
uses TypesUnit;
type TBaseHelp = class helper for TBase
  function Count: Integer;
end;
implementation
function TBaseHelp.Count: Integer;
begin
  Result := 11;
end;
end.
