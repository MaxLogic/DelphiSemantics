unit InlineHeaderUnit;
interface
uses System.SysUtils;
type
  TMatrix = array[1..2, 1..2] of Integer;
  TVector = record
    v: TMatrix;
    n: Integer;
    e: Exception;
  end;
procedure RunArray(var aValue: TVector);
procedure RunInitializer(var aValue: TVector);
procedure RunFor(var aValue: TVector);
procedure RunHandler(var aValue: TVector);
implementation
procedure RunArray(var aValue: TVector);
begin
  with aValue do
  begin
    var v: TMatrix;
    v := Default(TMatrix);
    v[1, 1] := 17;
  end;
end;
procedure RunInitializer(var aValue: TVector);
begin
  with aValue do
  begin
    var n := n + 2;
    n := n + 1;
    var lLocal := n;
    v[1, 1] := lLocal;
  end;
end;
procedure RunFor(var aValue: TVector);
begin
  with aValue do
  begin
    for var n := 1 to 2 do
      Inc(v[1, 1], n);
  end;
end;
procedure RunHandler(var aValue: TVector);
begin
  with aValue do
  begin
    try
      raise Exception.Create('raised');
    except
      on e: Exception do
        v[1, 1] := Length(e.Message);
    end;
  end;
end;
end.
