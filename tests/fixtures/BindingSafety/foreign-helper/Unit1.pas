unit Unit1;
interface
uses DataUnit, ControlUnit;
type
  TRecHelper = record helper for ControlUnit.TRec
    procedure SetCount(const aValue: Integer);
    property Count: Integer write SetCount;
  end;
var
  Unit1Rec: DataUnit.TRec;
  Count: Integer;
procedure Run;
implementation
procedure TRecHelper.SetCount(const aValue: Integer);
begin
  Value := aValue;
end;
procedure Run;
begin
  with Unit1Rec do Count := 7;
  Writeln(Unit1Rec.Value, ':', Count);
end;
end.
