unit Unit1;
interface
type
  TRec = record
    Value: Integer;
    function GetItem(aIndex: Integer): Integer;
    procedure SetItem(aIndex, aValue: Integer);
    property lArr[aIndex: Integer]: Integer read GetItem write SetItem;
  end;
procedure Run;
implementation
function TRec.GetItem(aIndex: Integer): Integer;
begin Result := Value; end;
procedure TRec.SetItem(aIndex, aValue: Integer);
begin Value := aValue + 3; end;
procedure Run;
var
  lRec: TRec;
  lCount: Integer;
  lArr: array[0..0] of Integer;
begin
  lCount := 13;
  lRec.Value := 2;
  lArr[0] := 11;
  with lRec do lArr[0] := Value;
  Writeln(lRec.Value, ':', lArr[0]);
end;
end.
