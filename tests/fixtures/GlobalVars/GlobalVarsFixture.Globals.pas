unit GlobalVarsFixture.Globals;

interface

type
  TGlobalStore = class
  public
    class var
      sCache, sOtherCache: Integer;
  end;

var
  GCounter, GSecondCounter: Integer;
  GUnusedValue: Integer;

threadvar
  GThreadCounter, GOtherThreadCounter: Integer;

const
  GTypedValue: Integer = 7;

procedure TouchGlobals;

implementation

procedure TouchGlobals;
begin
  Inc(GCounter);
  GThreadCounter := GCounter;
  TGlobalStore.sCache := GTypedValue;
end;

end.
