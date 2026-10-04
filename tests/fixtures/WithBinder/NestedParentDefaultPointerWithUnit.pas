unit NestedParentDefaultPointerWithUnit;

interface

type
  TMaskEntry = record
    Value: Integer;
  end;
  PMaskEntry = ^TMaskEntry;
  TAltEntry = record
    AltValue: Integer;
  end;
  PAltEntry = ^TAltEntry;
  TMaskType = class
  private
    function GetItem(const aIndex: Integer): PMaskEntry;
  public
    property Items[const aIndex: Integer]: PMaskEntry read GetItem; default;
  end;
  TAltMaskType = class
  private
    function GetItem(const aIndex: Integer): PAltEntry;
  public
    property Items[const aIndex: Integer]: PAltEntry read GetItem; default;
  end;
  TDatFile = record
    Maske: TMaskType;
  end;
  TAltDatFile = record
    Maske: TAltMaskType;
  end;
  TNoMask = record
    Other: Integer;
  end;

procedure RunNested;
procedure RunShadow;
procedure RunNearestParent;
procedure RunLexicalFallback;
procedure RunUnresolved;

implementation

function TMaskType.GetItem(const aIndex: Integer): PMaskEntry;
begin
  Result := nil;
end;

function TAltMaskType.GetItem(const aIndex: Integer): PAltEntry;
begin
  Result := nil;
end;

procedure RunNested;
var
  D: TDatFile;
  i: Integer;
begin
  with D do
    with Maske[i]^ do
      Value := 1;
end;

procedure RunShadow;
var
  D: TDatFile;
  Maske: TAltMaskType;
begin
  with D do
    with Maske[0]^ do
      Value := 1;
end;

procedure RunNearestParent;
var
  D: TDatFile;
  A: TAltDatFile;
begin
  with D do
    with A do
      with Maske[0]^ do
        AltValue := 1;
end;

procedure RunLexicalFallback;
var
  N: TNoMask;
  Maske: TAltMaskType;
begin
  with N do
    with Maske[0]^ do
      AltValue := 1;
end;

procedure RunUnresolved;
var
  N: TNoMask;
begin
  with N do
    with Missing[0]^ do
      Other := 1;
end;

end.
