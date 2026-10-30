unit Unit1;
interface
type TRec = class
  function Count(aValue: Integer): Integer; overload;
end;
THelp = class helper for TRec
  function Count(const aValue: string): Integer; overload;
end;
procedure Run;
implementation
function TRec.Count(aValue: Integer): Integer;
begin
  Result := 11;
end;
function THelp.Count(const aValue: string): Integer;
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
      Writeln('WITH=', Count('x'));
    end;
    Writeln('QUAL=', R.Count('x'));
  finally
    R.Free;
  end;
end;
end.
