unit ParentHelp;
interface
uses TypesUnit;
type TParentHelp = class helper for TRec
  function Count: Integer;
end;
implementation
function TParentHelp.Count: Integer;
begin
  Result := 11;
end;
end.
