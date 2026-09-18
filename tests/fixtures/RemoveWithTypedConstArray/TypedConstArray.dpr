program TypedConstArray;

{$APPTYPE CONSOLE}

uses
  TypedConstArrayUnit in 'TypedConstArrayUnit.pas';

var
  i: Integer;

begin
  for i := 1 to NRes do
    Words[i] := ResWords[i];
  FindConstWord('ABS');
  FindConstWord('OR');
  FindVarWord('AND');
  FindVarWord('ABS');
  New(Masks[1]);
  Masks[1]^.Art := 1;
  New(Masks[2]);
  Masks[2]^.Art := 2;
  Writeln(Output, ',', PairMemberText, ',', PairPointerText);
  Dispose(Masks[1]);
  Dispose(Masks[2]);
end.
