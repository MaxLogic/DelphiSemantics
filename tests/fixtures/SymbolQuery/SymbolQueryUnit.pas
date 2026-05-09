unit SymbolQueryUnit;

interface

type
  TSymbolMapFixture = class
  private
    fName: string;
    fEnabled: Boolean;
  public
    property Name: string read fName;
    property Enabled: Boolean read fEnabled;
    procedure Execute;
  end;

  TDeclarationRecord = record
    Value: Integer;
  end;

var
  GlobalQueryValue: TDeclarationRecord;

implementation

procedure TSymbolMapFixture.Execute;
begin
  GlobalQueryValue.Value := 1;
end;

procedure UseSymbols;
var
  lFixture: TSymbolMapFixture;
begin
  lFixture.Name;
  lFixture.Enabled;
  GlobalQueryValue.Value := 2;
  TSymbolMapFixture(nil);
  TSymbolMapFixture(lFixture);
  Length('abc');
end;

end.
