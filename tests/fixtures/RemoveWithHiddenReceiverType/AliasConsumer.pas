unit AliasConsumer;

interface

procedure RunAlias;

implementation

uses
  Provider;

procedure RunAlias;
begin
  ResetItems;
  with VisibleCurrent^ do
  begin
    Value := 1;
    SwitchReceiver;
    Value := Value + 1;
  end;
end;

end.
