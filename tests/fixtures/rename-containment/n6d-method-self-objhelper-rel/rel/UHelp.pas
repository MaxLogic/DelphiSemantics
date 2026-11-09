unit UHelp;
interface
type
  TObjHelper = class helper for TObject
    function GetRenamedValue: Integer;
    property RenamedValue: Integer read GetRenamedValue;
  end;
implementation
function TObjHelper.GetRenamedValue: Integer;
begin
  Result := 1000;
end;
end.
