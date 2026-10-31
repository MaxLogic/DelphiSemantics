program ExternalDefine;
{$APPTYPE CONSOLE}
const
  Count = 7;
type
  TRec = record
    Value: Integer;
  end;
{$IFDEF REVIEW_FEATURE}
  TH = record helper for TRec
    function Count: Integer;
  end;
{$ENDIF}
{$IFDEF REVIEW_FEATURE}
function TH.Count: Integer;
begin
  Result := 19;
end;
{$ENDIF}
procedure Run;
var
  r: TRec;
begin
  r.Value := 0;
  with r do
    Writeln(Count);
  Writeln(Count);
end;
begin
  Run;
end.
