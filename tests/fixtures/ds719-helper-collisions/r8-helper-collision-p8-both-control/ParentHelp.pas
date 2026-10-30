unit ParentHelp;
interface
uses TypesUnit;
type TParentHelp = class helper for TRec
  function AbsentCount: Integer;
end;
implementation
function TParentHelp.AbsentCount: Integer;
begin
  Result := 11;
end;
end.
