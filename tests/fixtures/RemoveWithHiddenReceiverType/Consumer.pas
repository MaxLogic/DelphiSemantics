unit Consumer;

interface

procedure RunHidden;

implementation

uses
  Provider;

procedure RunHidden;
begin
  ResetItems;
  with Current^ do
  begin
    Value := 1;
    SwitchReceiver;
    Value := Value + 1;
  end;
end;

end.
