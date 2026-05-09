unit InventoryResolverUnit;

interface

type
  TInventoryEnum = (ikFirst, ikSecond);

  IInventoryBase = interface
    function BaseName: string;
  end;

  IInventoryChild = interface(IInventoryBase)
    function ChildName: string;
  end;

  TOverloadHolder = record
    function Pick(const aValue: Integer): string; overload;
    function Pick(const aValue: string): string; overload;
  end;

const
  cTypedInventory: TInventoryEnum = ikFirst;
  cPlainInventory = 42;

var
  gInterfaceGlobal: IInventoryChild;

procedure UseInventory;

implementation

var
  gImplementationRecord: TOverloadHolder;

procedure UseInventory;
var
  lLocalInterface: IInventoryChild;
begin
  lLocalInterface := gInterfaceGlobal;
  gImplementationRecord.Pick(cPlainInventory);
end;

end.
