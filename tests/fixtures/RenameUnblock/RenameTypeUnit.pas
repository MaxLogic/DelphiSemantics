unit RenameTypeUnit;

interface

type
  TSharedType = record
    Value: Integer;
  end;
  PSharedType = ^TSharedType;
  TSharedAlias = TSharedType;
  TSharedArray = array of TSharedType;
  TRecordHolder = record
    Item: TSharedType;
  end;
  TClassHolder = class
    class function GetShared(aIndex: TSharedType): TSharedType;
    property Items[aIndex: TSharedType]: TSharedType read GetShared;
  end;

var
  GlobalShared: TSharedType;

function EchoShared(aValue: TSharedType): TSharedType;

implementation

function EchoShared(aValue: TSharedType): TSharedType;
var
  lLocal: TSharedType;
begin
  lLocal := aValue;
  Result := lLocal;
end;

end.
