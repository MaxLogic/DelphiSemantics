unit UInit;

interface

implementation

uses
  UEntry;

var
  GTotal: Integer;

initialization
  GTotal := InitUsed;

finalization
  GTotal := GTotal + FinalUsed;

end.
