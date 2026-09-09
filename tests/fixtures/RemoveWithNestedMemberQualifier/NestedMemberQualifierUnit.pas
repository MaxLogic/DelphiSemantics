unit NestedMemberQualifierUnit;
interface
function Run: Integer;
implementation
type
  TOuter = record
    Struktur: packed record
      Count: Integer;
    end;
  end;
function Run: Integer;
var
  lOuter: TOuter;
  lBytes: array [0..0] of Byte;
begin
  lOuter := Default(TOuter);
  with lOuter do
  begin
    FillChar(lBytes, SizeOf(lBytes), 0);
    with Struktur do
      Count := 3;
  end;
  Result := lOuter.Struktur.Count;
end;
end.
