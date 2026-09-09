unit IntrinsicCastTypeShadow;

interface

uses
  IntrinsicBodyCastsUnit;

procedure ObserveType(var aReceiver: TBodyCastRecord; var aResult: Integer);

implementation

type
  Double = type Integer;

procedure ObserveType(var aReceiver: TBodyCastRecord; var aResult: Integer);
begin
  with aReceiver do
  begin
    aResult := Double(IntValue)
  end;
end;

end.
