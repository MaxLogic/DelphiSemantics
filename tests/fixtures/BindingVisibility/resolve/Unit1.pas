unit Unit1;
interface
type
  TC = class
  public
    const Count = 5;
    const OnlyMember = 7;
  end;
const Count: Integer = 17;
procedure Run;
implementation
procedure Run;
begin
  Writeln(Count);
  Writeln(TC.Count);
  Writeln(TC.OnlyMember);
end;
end.
