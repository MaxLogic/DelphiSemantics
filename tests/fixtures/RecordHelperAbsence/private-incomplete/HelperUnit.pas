unit HelperUnit;
interface
implementation
uses DataUnit;
type
  THelp = record helper for DataUnit.TRec
    function GetCount: Integer;
    property
      lCount: Integer read GetCount;
  end;
function THelp.GetCount: Integer;
begin Result := 7; end;
end.
