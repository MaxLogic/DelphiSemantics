program BranchHole;
{$APPTYPE CONSOLE}
const
  Count = 7;
type
  TRec = record
    Value: Integer;
  end;
  TH = record
{$IF SizeOf(Pointer) = 4}
    Dummy: Integer;
{$ELSE}
    helper for TRec
{$IFEND}
    function Count: Integer;
  end;
function TH.Count: Integer;
begin
  Result := 19;
end;
procedure Run;
var
  r: TRec;
begin
  r.Value := 0;
  with r do
  begin
    Writeln(Count);
  end;
  Writeln(Count);
end;
begin
  Run;
end.
