unit Unit1;
interface
uses A, U;
procedure Run;
implementation
type TLocal = record Value: Integer; end;
var First, Second: TLocal;
procedure Run;
var
  lItem: A.TRec;
begin
  lItem.Value := 0;
  Items[1] := @lItem;
  with Items[1]^ do
  begin
    with First do
    begin
      Value := 1;
      with Second do Value := 2;
    end;
  end;
  Writeln(lItem.Value, ' ', First.Value, ' ', Second.Value);
end;
end.
