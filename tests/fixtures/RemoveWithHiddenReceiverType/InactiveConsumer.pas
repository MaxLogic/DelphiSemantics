unit InactiveConsumer;

interface

procedure RunInactive;

implementation

uses
{$IFDEF IMPORT_HIDDEN_TYPE}
  HiddenTypes,
{$ENDIF}
  Provider;

procedure RunInactive;
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
