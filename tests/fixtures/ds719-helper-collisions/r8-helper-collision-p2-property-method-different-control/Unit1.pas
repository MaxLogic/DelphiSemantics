unit Unit1;
interface
type
  TRec = class
  public
    function GetCount: Integer;
    property Count: Integer read GetCount;
  end;
  THelp = class helper for TRec
    function AbsentCount: string;
  end;
procedure Run;
implementation
function TRec.GetCount: Integer;
begin
  Result := 11;
end;
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
