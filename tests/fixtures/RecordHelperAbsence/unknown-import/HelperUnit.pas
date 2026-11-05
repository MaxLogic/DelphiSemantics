unit HelperUnit;
interface
uses DataUnit;
type
{$IFOPT R+}
  THelp = record helper for DataUnit.TRec
    function GetCount: Integer;
    property lCount: Integer read GetCount;
  end;
{$ENDIF}
implementation
{$IFOPT R+}
function THelp.GetCount: Integer;
begin Result := 7; end;
{$ENDIF}
end.
