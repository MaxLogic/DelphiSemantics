unit HelperUnit;
interface
uses DataUnit;
type
  THelp = record helper for DataUnit.TRec
    function GetCount: Integer;
    property
      lCount: Integer read GetCount;
  end;
implementation
function THelp.GetCount: Integer;
begin Result := 7; end;
end.
