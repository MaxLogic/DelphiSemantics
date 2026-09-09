unit ControlledArrayUnsafeUnit;

interface

type
  TUnsafeItem = record
    Value: Integer;
  end;
  TUnsafeArray = array of TUnsafeItem;
  TIndexedItems = class
  private
    function GetItem(const aIndex: Integer): TUnsafeItem;
  public
    property Items[const aIndex: Integer]: TUnsafeItem read GetItem; default;
  end;
  TUnsafeContainer = record
    List: TIndexedItems;
    function Items: TUnsafeArray;
  end;

var
  UnsafeContainer: TUnsafeContainer;

function ReadMethodValue: Integer;
function ReadIndexerValue: Integer;

implementation

function TUnsafeContainer.Items: TUnsafeArray;
begin
  SetLength(Result, 3);
  Result[0].Value := 23;
end;

function TIndexedItems.GetItem(const aIndex: Integer): TUnsafeItem;
begin
  Result.Value := 29 + aIndex;
end;

function ReadMethodValue: Integer;
var
  i: Integer;
begin
  i := 0;
  Result := 0;
  if i = 0 then
    with UnsafeContainer.Items[i] do
      Result := Value;
end;

function ReadIndexerValue: Integer;
var
  i: Integer;
begin
  i := 0;
  Result := 0;
  UnsafeContainer.List := TIndexedItems.Create;
  try
    if i = 0 then
      with UnsafeContainer.List[i] do
        Result := Value;
  finally
    UnsafeContainer.List.Free;
  end;
end;

end.
