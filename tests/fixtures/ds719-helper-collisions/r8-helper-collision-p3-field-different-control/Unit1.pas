unit Unit1;
interface
type
  TBase = class
  public
    Count: Integer;
  end;
  TRec = class(TBase) end;
  THelp = class helper for TRec
    function AbsentCount: string;
  end;
procedure Run;
implementation
function THelp.AbsentCount: string;
begin
  Result := 'H19';
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
