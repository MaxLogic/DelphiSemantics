unit GlobalVarsFixture.Consumer;

interface

procedure RunConsumer;

implementation

uses
  GlobalVarsFixture.Globals;

var
  GCounter: Integer;

procedure RunConsumer;
var
  GTypedValue: Integer;
begin
  GCounter := GCounter + 1;
  if GThreadCounter > 0 then
  begin
    TGlobalStore.sCache := 1 + GTypedValue;
  end;
  TouchGlobals;
end;

end.
