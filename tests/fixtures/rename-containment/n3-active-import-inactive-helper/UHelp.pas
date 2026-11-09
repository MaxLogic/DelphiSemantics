unit UHelp;
interface
uses UCertified;
{$IFDEF RELEASE}
type
  TCHelper = class helper for TC
    function GetRenamedValue: Integer;
    property RenamedValue: Integer read GetRenamedValue;
  end;
{$ENDIF}
var HelpLoaded: Integer;
implementation
{$IFDEF RELEASE}
function TCHelper.GetRenamedValue: Integer;
begin
  Result := 1000;
end;
{$ENDIF}
end.
