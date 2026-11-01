unit LocalSelectorAliasConsumer;

interface

uses Provider;

type
  TLocal = record
    LocalValue: Integer;
  end;
  TPtr = ^TLocal;

var
  X: TPtr;

implementation

end.
