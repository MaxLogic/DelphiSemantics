unit Unit1;
interface
uses ControlUnit;
type
  TBase = class end;
  TItem = class(TBase)
    A: Integer;
  end;
procedure Run;
implementation
var Count: Integer = 100;
procedure Run;
var lItem: TItem;
begin
  lItem := TItem.Create;
  try
    with lItem do A := Count;
    Writeln(lItem.A);
  finally
    lItem.Free;
  end;
end;
end.
