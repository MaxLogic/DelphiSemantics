unit Unit1;

interface

type
  TOuter = record
    Struktur: record
      Inner: record
        Value: Integer;
      end;
      Count: Integer;
    end;
    Own: Integer;
  end;

procedure Run;

implementation

procedure Run;
var
  lOuter: TOuter;
begin
  lOuter := Default(TOuter);
  lOuter.Struktur.Count := 20;
  with lOuter do
    Count := 1;
end;
end.
