unit Level1ResolverUnit;

interface

type
  TLevelRecord = record
  private
    function GetItem(const aIndex: Integer): string;
  public
    Value: Integer;
    property Items[const aIndex: Integer]: string read GetItem; default;
  end;

var
  Value: string;
  SharedName: string;
  DuplicateName: string;

procedure ResolveTarget(const SharedName: Integer);

implementation

var
  ImplementationOnly: TLevelRecord;
  DuplicateName: Integer;

function TLevelRecord.GetItem(const aIndex: Integer): string;
begin
  Result := '';
end;

procedure ResolveTarget(const SharedName: Integer);
var
  Value: TLevelRecord;
begin
  Value.Value := SharedName;
end;

end.
