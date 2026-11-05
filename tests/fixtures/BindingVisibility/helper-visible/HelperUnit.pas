unit HelperUnit;
interface
uses Unit2;
type
  TRecHelper = record helper for TRec
    function Foo: Integer;
  end;
implementation
function TRecHelper.Foo: Integer;
begin Result := 23; end;
end.
