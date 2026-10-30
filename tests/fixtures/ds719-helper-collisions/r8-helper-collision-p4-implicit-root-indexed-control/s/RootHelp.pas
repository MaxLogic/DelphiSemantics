unit RootHelp;
interface
type TRootHelp = class helper for TObject
  function AbsentCount: Integer;
end;
implementation
function TRootHelp.AbsentCount: Integer;
begin
  Result := 19;
end;
end.
