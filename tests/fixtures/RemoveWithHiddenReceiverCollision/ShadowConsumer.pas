unit ShadowConsumer;

interface

procedure RunShadow;

implementation

uses
  Provider;

type
  THiddenItem = record
    Value: Integer;
  end;

procedure RunShadow;
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
