unit DirectConsumer;

interface

procedure RunDirect;

implementation

uses
  HiddenTypes, Provider;

procedure RunDirect;
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
