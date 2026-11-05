unit Unit1;
interface
type
  TRec = record
    Value: Integer;
    lArr: array[0..0] of Integer;
  end;
procedure Run;
implementation
procedure Run;
var
  lRec: TRec;
  lCount: Integer;
  lArr: array[0..0] of Integer;
begin
  lCount := 13;
  lRec.Value := 2;
  lArr[0] := 11;
  lRec.lArr[0] := 17;
  with lRec do lArr[0] := Value;
  Writeln(lRec.Value, ':', lArr[0]);
  Writeln(lRec.lArr[0]);
end;
end.
