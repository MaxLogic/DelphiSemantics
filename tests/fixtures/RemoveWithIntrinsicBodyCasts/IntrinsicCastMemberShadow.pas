unit IntrinsicCastMemberShadow;

interface

procedure ObserveMember(const aValue: Integer; var aResult: Integer);

implementation

type
  TShadowRecord = record
    IntValue: Integer;
    function Double(const aValue: Integer): Integer;
  end;

function TShadowRecord.Double(const aValue: Integer): Integer;
begin
  Result := aValue + 200;
end;

procedure ObserveMember(const aValue: Integer; var aResult: Integer);
var
  lReceiver: TShadowRecord;
begin
  lReceiver.IntValue := aValue;
  with lReceiver do
  begin
    aResult := Double(IntValue)
  end;
end;

end.
