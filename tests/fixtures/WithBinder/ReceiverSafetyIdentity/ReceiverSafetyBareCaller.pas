unit ReceiverSafetyBareCaller;

interface

uses
  ReceiverSafetyBareOwner;

type
  THiddenEntry = record
    CallerValue: Integer;
  end;
  TContainer = class
  private
    FValue: THiddenEntry;
  public
    procedure RunMember;
  end;

procedure RunBare;
procedure RunLocal;
procedure RunParameter(const aValue: THiddenEntry);

implementation

procedure RunBare;
begin
  with G do
    Value := 1;
end;

procedure RunLocal;
var
  lLocal: THiddenEntry;
begin
  with lLocal do
    CallerValue := 2;
end;

procedure RunParameter(const aValue: THiddenEntry);
begin
  with aValue do
    CallerValue := 3;
end;

procedure TContainer.RunMember;
begin
  with FValue do
    CallerValue := 4;
end;

end.
