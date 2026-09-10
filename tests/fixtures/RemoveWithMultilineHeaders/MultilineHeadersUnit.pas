unit MultilineHeadersUnit;

interface

type
  aShadow = Integer;
  TItem = record
    Value: Integer;
  end;

function SingleLine(var aItem: TItem; var aRaw; aAdd: Integer): Integer;
function Wrapped(var aItem: TItem;
  var aRaw; aAdd: Integer): Integer;
function Shadowed(var aItem: TItem;
  aShadow: Integer): Integer;
function Later(aValue: Integer;
  aAdd: Integer): Integer;
function HeaderExtent(aCount: Integer = (1 + (2));
  aText: string = '(x)'
  {
procedure Fake;
  }
  ): Integer;
procedure NestedCalls(var aItem: TItem;
  aAdd: Integer);

implementation

function SingleLine(var aItem: TItem; var aRaw; aAdd: Integer): Integer;
begin
  with aItem do
  begin
    Integer(aRaw) := Value + aAdd;
    SingleLine := Later(Value, aAdd);
  end;
end;

function Wrapped(var aItem: TItem;
  var aRaw; aAdd: Integer): Integer;
begin
  with aItem do
  begin
    Integer(aRaw) := Value + aAdd;
    Wrapped := Later(Value, aAdd);
  end;
end;

function Shadowed(var aItem: TItem;
  aShadow: Integer): Integer;
begin
  with aItem do
    Shadowed := Value + aShadow;
end;

function Later(aValue: Integer;
  aAdd: Integer): Integer;
begin
  Result := aValue * 2 + aAdd;
end;

function HeaderExtent(aCount: Integer; aText: string): Integer;
begin
  Result := aCount + Length(aText);
end;

procedure NestedCalls(var aItem: TItem;
  aAdd: Integer);

  procedure Bump(aValue: Integer);
  begin
    aItem.Value := aItem.Value + aValue;
  end;

  function Inner: Boolean;
  begin
    with aItem do
    begin
      Bump(aAdd);
      Inner := Value > 0;
    end;
  end;

begin
  if not Inner then
    aItem.Value := -1;
end;

end.
