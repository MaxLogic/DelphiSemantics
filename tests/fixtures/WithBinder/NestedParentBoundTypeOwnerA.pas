unit NestedParentBoundTypeOwnerA;

interface

type
  TMaskEntry = record
    Value: Integer;
  end;
  PMaskEntry = ^TMaskEntry;
  TMaskType = class
  private
    function GetItem(const aIndex: Integer): PMaskEntry;
  public
    property Items[const aIndex: Integer]: PMaskEntry read GetItem; default;
  end;
  TDatFile = record
    Maske: TMaskType;
  end;

implementation

function TMaskType.GetItem(const aIndex: Integer): PMaskEntry;
begin
  Result := nil;
end;

end.
