unit Unit1;
interface
uses ClassBase;
type
  TInner = record
    Count, Padding: Integer;
  end;
  TChild = class(TOuter)
  public
    class procedure Execute; static;
  end;
procedure Run;
implementation
class procedure TChild.Execute;
var
  lRec: TInner;
begin
  lRec.Count := 0;
  with lRec do Count := 7;
  Writeln(SizeOf(lRec), ':', lRec.Count);
end;
procedure Run;
begin
  TChild.Execute;
end;
end.
