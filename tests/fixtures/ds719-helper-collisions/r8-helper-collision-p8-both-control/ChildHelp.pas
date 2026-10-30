unit ChildHelp;
interface
uses TypesUnit, ParentHelp;
type TChildHelp = class helper(TParentHelp) for TRec
  function AbsentCount: Integer;
end;
implementation
function TChildHelp.AbsentCount: Integer;
begin
  Result := 19;
end;
end.
