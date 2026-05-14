unit DefaultPointerWithUnit;

interface

type
  TDefaultRecord = record
    Value: Integer;
  end;

  PDefaultRecord = ^TDefaultRecord;

  TDefaultList = class
  private
    function GetItem(const aIndex: Integer): PDefaultRecord;
  public
    property Items[const aIndex: Integer]: PDefaultRecord read GetItem; default;
  end;

procedure Run;

implementation

function TDefaultList.GetItem(const aIndex: Integer): PDefaultRecord;
begin
  Result := nil;
end;

procedure Run;
var
  lList: TDefaultList;
begin
  with lList[0]^ do
  begin
    Value := 1;
  end;
end;

end.
