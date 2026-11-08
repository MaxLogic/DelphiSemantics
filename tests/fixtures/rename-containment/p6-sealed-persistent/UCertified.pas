unit UCertified;
interface
uses System.Classes;
type
  TC = class sealed(TPersistent)
    FV: Integer;
    property Value: Integer read FV write FV;
  end;
var SharedValue: Integer;
procedure Touch;
implementation
procedure Touch;
begin
  SharedValue := 4;
end;
end.
