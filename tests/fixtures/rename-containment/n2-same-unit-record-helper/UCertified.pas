unit UCertified;
interface
type
  TR = record
    Value: Integer;
  end;
var SharedValue: Integer;
procedure Touch;
implementation
{$IFDEF RELEASE}
type
  TRHelper = record helper for TR
    function RenamedValue: Integer;
  end;
function TRHelper.RenamedValue: Integer;
begin
  Result := 1000;
end;
{$ENDIF}
procedure Touch;
var
  LocalCount: Integer;
  Rec: TR;
begin
  LocalCount := 4;
  with Rec do
    Value := LocalCount;
  SharedValue := Rec.Value;
end;
end.
