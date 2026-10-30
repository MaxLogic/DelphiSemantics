unit RootHelp;
interface
type TRootHelp = class helper for TObject
  function Count: Integer;
end;
implementation
function TRootHelp.Count: Integer;
begin
  Result := 19;
end;
end.
