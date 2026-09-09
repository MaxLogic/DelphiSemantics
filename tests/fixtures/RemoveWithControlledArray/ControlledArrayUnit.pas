unit ControlledArrayUnit;

interface

type
  TItem = record
    Value: Integer;
  end;
  TContainer = record
    Items: array[0..2] of TItem;
  end;

var
  Container: TContainer;

procedure RunLoop(const aStart, aLimit: Integer; out aIndex: Integer);
procedure RunGuard(const aEnabled: Boolean; var aIndex: Integer);
procedure RunPlain(var aIndex: Integer);
procedure RunPointer(var aIndex: Integer);

implementation

{$R+}

procedure RunLoop(const aStart, aLimit: Integer; out aIndex: Integer);

  // Retain the nested declaration boundary from the historical case.
  procedure ApplyEntries;
  var
    i: Integer;
  begin
    i := aStart;
    while i < aLimit do
      with Container.Items[i] do
      begin
        Inc(Value);
        Inc(i);
        Inc(Value, 10);
      end;
    aIndex := i;
  end;

begin
  ApplyEntries;
end;

procedure RunGuard(const aEnabled: Boolean; var aIndex: Integer);
begin
  if aEnabled then
    with Container.Items[aIndex] do
    begin
      Inc(Value);
      Inc(aIndex);
      Inc(Value, 10);
    end;
end;

procedure RunPlain(var aIndex: Integer);
begin
  with Container.Items[aIndex] do
  begin
    Inc(Value);
    Inc(aIndex);
    Inc(Value, 10);
  end;
end;

procedure RunPointer(var aIndex: Integer);
var
  p: ^TItem;
begin
  p := @Container.Items[aIndex];
  with p^ do
  begin
    Inc(Value);
    Inc(aIndex);
    Inc(Value, 10);
  end;
end;

end.
