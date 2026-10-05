unit ReceiverSafetyCaller;

interface

uses
  ReceiverSafetyOwner;

type
  THiddenEntry = record
    CallerValue: Integer;
  end;

procedure Run;

implementation

procedure Run;
var
  lOuter: TOuter;
begin
  with lOuter do
    with Item^ do
      Value := 1;
end;

end.
