unit Level2ResolverUnit;

interface

type
  TBaseRecord = record
    Value: Integer;
  end;

  TAliasRecord = TBaseRecord;
  TPointerRecord = ^TBaseRecord;
  TRecordArray = array[0..1] of TBaseRecord;

  TIndexedRecord = record
  private
    function GetItem(const aIndex: Integer): TBaseRecord;
  public
    property Items[const aIndex: Integer]: TBaseRecord read GetItem; default;
  end;

procedure OuterScope(const OuterParam: TBaseRecord);

implementation

function TIndexedRecord.GetItem(const aIndex: Integer): TBaseRecord;
begin
  Result.Value := aIndex;
end;

procedure OuterScope(const OuterParam: TBaseRecord);
var
  OuterValue: TBaseRecord;
  Shadowed: TBaseRecord;
  ArrayValue: TRecordArray;
  PointerValue: TPointerRecord;
  IndexedValue: TIndexedRecord;

  procedure InnerScope(const Shadowed: TIndexedRecord);
  var
    InnerValue: TBaseRecord;
  begin
    InnerValue.Value := OuterValue.Value;
    InnerValue.Value := OuterParam.Value;
    InnerValue.Value := ArrayValue[0].Value;
    InnerValue.Value := PointerValue^.Value;
    InnerValue.Value := IndexedValue.Items[0].Value;
    InnerValue.Value := IndexedValue[0].Value;
  end;

begin
  OuterValue.Value := 1;
  InnerScope(IndexedValue);
end;

end.
