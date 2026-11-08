unit UCertified;
interface
type
  TService = class
  public
    class function SharedValue: Integer; static;
  end;
implementation
class function TService.SharedValue: Integer;
begin
  Result := 4;
end;
end.
