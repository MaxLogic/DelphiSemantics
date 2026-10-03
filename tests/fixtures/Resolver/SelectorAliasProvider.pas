unit SelectorAliasProvider;

interface

type
  TSelectorRecord = record
    Value: Integer;
  end;
  TSelectorPointer = ^TSelectorRecord;

var
  DF: array[0..1] of TSelectorPointer;

implementation

end.
