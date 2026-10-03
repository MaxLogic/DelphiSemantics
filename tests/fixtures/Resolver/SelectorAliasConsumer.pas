unit SelectorAliasConsumer;

interface

uses
  SelectorAliasProvider;

procedure RunSelector;

implementation

var
  X: TSelectorPointer;
  A: array[0..1] of TSelectorRecord;

procedure RunSelector;
begin
  with DF[0]^ do
    Value := 1;
  with X^ do
    Value := 2;
  with A[0] do
    Value := 3;
end;

end.
