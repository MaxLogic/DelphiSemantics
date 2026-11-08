unit UCertified;
interface
type
  TC = class(TObject)
  end;
function MakeIt: TObject;
implementation
function MakeIt: TObject;
begin
  Result := TC.Create;
end;
end.
