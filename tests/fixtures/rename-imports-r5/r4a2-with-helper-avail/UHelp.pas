unit UHelp;
interface
uses UCertified;
type
  TCHelper = class helper for TC
    function GetRenamedValue: Integer;
    property RenamedValue: Integer read GetRenamedValue;
  end;
implementation
function TCHelper.GetRenamedValue: Integer;
begin
  Result := 1000;
end;
end.
