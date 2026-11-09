unit UDM;
interface
uses System.Classes, UCertified;
type
  TDM = class(TBaseDM)
  end;
function Peek: Integer;
implementation
{$R *.dfm}
function Peek: Integer;
begin
  Result := SharedValue;
end;
end.
