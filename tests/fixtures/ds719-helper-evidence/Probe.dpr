program Probe;
{$APPTYPE CONSOLE}
type
  TTarget = class
  end;
  TH = class
{$IFDEF LINUX}
    (TObject)
{$ELSE}
    helper for TTarget
{$ENDIF}
    function Count: Integer;
  end;
function TH.Count: Integer;
begin
  Result := 19;
end;
var
  lTarget: TTarget;
begin
  lTarget := TTarget.Create;
  try
    Writeln(lTarget.Count);
  finally
    lTarget.Free;
  end;
end.
