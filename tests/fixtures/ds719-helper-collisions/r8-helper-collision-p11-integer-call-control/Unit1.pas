unit Unit1;
interface
type TRec = class
  function Count(aValue: Integer): Integer; overload;
end;
THelp = class helper for TRec
  function AbsentCount(const aValue: string): Integer; overload;
end;
procedure Run;
implementation
function TRec.Count(aValue: Integer): Integer;
begin
  Result := 11;
end;
function THelp.AbsentCount(const aValue: string): Integer;
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
      Writeln('WITH=', Count(1));
    end;
    Writeln('QUAL=', R.Count(1));
  finally
    R.Free;
  end;
end;
end.
