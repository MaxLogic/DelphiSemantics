unit Unit1;
interface
type
  TRec = class
  public
    function Count: Integer;
  end;
  THelp = class helper for TRec
    function Count: Integer;
  end;
procedure Run;
implementation
function TRec.Count: Integer;
begin
  Result := 11;
end;
function THelp.Count: Integer;
begin
  Result := 19;
end;
procedure Run;
var
  R: TRec;
begin
  R := TRec.Create;
  try
  with R do
  begin
    Writeln('WITH=', Count);
  end;
  Writeln('QUAL=', R.Count);
  finally
    R.Free;
  end;
end;
end.
