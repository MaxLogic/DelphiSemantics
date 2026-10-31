unit Unit1;
interface
type
  TRec = record Value: Integer; end;
  THolder = class
    function GetItem: TRec;
    property Item: TRec read GetItem;
  end;
procedure Run;
implementation
function THolder.GetItem: TRec;
begin
  Writeln('get');
  Result.Value := 7;
end;
procedure Run;
var lHolder: THolder;
begin
  lHolder := THolder.Create;
  try
    with lHolder.Item do Writeln(Value);
  finally
    lHolder.Free;
  end;
end;
end.
