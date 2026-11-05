unit Unit1;
interface
type
  TRec = record
    Value: Integer;
  end;
  THelp = record helper for TRec
    function GetItem(aIndex: Integer): Integer;
    procedure SetItem(aIndex, aValue: Integer);
    property
      lArr[aIndex: Integer]: Integer read GetItem write SetItem;
  end;
procedure Run;
implementation
function THelp.GetItem(aIndex: Integer): Integer;
begin Result := Value; end;
procedure THelp.SetItem(aIndex, aValue: Integer);
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
