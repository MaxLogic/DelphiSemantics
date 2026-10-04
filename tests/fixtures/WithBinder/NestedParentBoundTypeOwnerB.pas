unit NestedParentBoundTypeOwnerB;

interface

uses
  NestedParentBoundTypeOwnerA;

type
  TAltEntry = record
    AltValue: Integer;
  end;
  PAltEntry = ^TAltEntry;
  TMaskType = class
  private
    function GetItem(const aIndex: Integer): PAltEntry;
  public
    property Items[const aIndex: Integer]: PAltEntry read GetItem; default;
  end;
  TLocalDatFile = record
    Maske: TMaskType;
  end;

procedure RunImportedBoundType;
procedure RunLocalThenImported;
procedure RunImportedThenLocal;

implementation

function TMaskType.GetItem(const aIndex: Integer): PAltEntry;
begin
  Result := nil;
end;

procedure RunImportedBoundType;
var
  D: NestedParentBoundTypeOwnerA.TDatFile;
begin
  with D do
    with Maske[0]^ do
      Value := 1;
end;

procedure RunLocalThenImported;
var
  D: NestedParentBoundTypeOwnerA.TDatFile;
  L: TLocalDatFile;
begin
  with L do
    with Maske[0]^ do
      AltValue := 1;
  with D do
    with Maske[0]^ do
      Value := 1;
end;

procedure RunImportedThenLocal;
var
  D: NestedParentBoundTypeOwnerA.TDatFile;
  L: TLocalDatFile;
begin
  with D do
    with Maske[0]^ do
      Value := 1;
  with L do
    with Maske[0]^ do
      AltValue := 1;
end;

end.
