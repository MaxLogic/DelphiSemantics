unit Unit1;

interface

type
  TOuter = record
    Struktur: record
      Inner: array[0..1] of record
        Value: Integer;
      end;
      Count: Integer;
    end;
    Own: Integer;
  end;

var
  Count: Integer;

procedure Run;

implementation

procedure Run;
var
  lOuter: TOuter;
begin
  lOuter := Default(TOuter);
  lOuter.Struktur.Count := 20;
  Count := 3;
  with lOuter do
    Count := Count + 1;
  Writeln(Count, ':', lOuter.Struktur.Count);
end;
end.
