unit NestedAnonymousWithUnit;

interface

type
  DBF_File = record
    Struktur: packed record
      Version: Byte;
      RecSize: Integer;
    end;
  end;

procedure Run;

implementation

procedure Run;
var
  DBF: DBF_File;
begin
  with DBF, Struktur do
  begin
    Version := RecSize;
  end;
end;

end.
