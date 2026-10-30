unit Unit1;
interface
type
  TWrong = record Count: Integer; end;
  TRight = record Count: Integer; end;
  TBase = class
  public
    function Next: TWrong;
  end;
  TRec = class(TBase) end;
  THelp = class helper for TRec
    function Next: TRight;
  end;
procedure Run;
implementation
function TBase.Next: TWrong;
begin
  Result.Count := 11;
end;
function THelp.Next: TRight;
begin
  Result.Count := 19;
end;
procedure Run;
var
  R: TRec;
begin
  R := TRec.Create;
  try
    with R.Next do
    begin
      Writeln('WITH=', Count);
    end;
    Writeln('QUAL=', R.Next.Count);
  finally
    R.Free;
  end;
end;
end.
