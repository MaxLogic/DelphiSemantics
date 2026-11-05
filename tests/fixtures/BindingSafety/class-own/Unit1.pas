unit Unit1;
interface
type
  TInner = record
    Count, Padding: Integer;
  end;
  TOuter = class
  public type
    TInner = record
      Count: Integer;
    end;
  public
    class procedure Execute; static;
  end;
procedure Run;
implementation
class procedure TOuter.Execute;
var
  lRec: TInner;
begin
  lRec.Count := 0;
  with lRec do Count := 7;
  Writeln(SizeOf(lRec), ':', lRec.Count);
end;
procedure Run;
begin
  TOuter.Execute;
end;
end.
