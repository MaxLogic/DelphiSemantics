unit ChildHelp;
interface
uses TypesUnit, ParentHelp;
type TChildHelp = class helper(TParentHelp) for TRec
  function Count: Integer;
end;
implementation
function TChildHelp.Count: Integer;
begin
  Result := 19;
end;
end.
