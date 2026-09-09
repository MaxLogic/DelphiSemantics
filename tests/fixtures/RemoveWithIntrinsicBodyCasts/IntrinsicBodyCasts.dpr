program IntrinsicBodyCasts;

{$APPTYPE CONSOLE}

uses
  IntrinsicBodyCastsUnit in 'IntrinsicBodyCastsUnit.pas',
  IntrinsicCastMemberShadow in 'IntrinsicCastMemberShadow.pas',
  IntrinsicCastRoutineShadow in 'IntrinsicCastRoutineShadow.pas',
  IntrinsicCastTypeShadow in 'IntrinsicCastTypeShadow.pas';

var
  lReceiver: TBodyCastRecord;
  lDouble: Double;
  lPointer: Pointer;
  lInteger: Integer;
  lMarker: Integer;
begin
  lReceiver := Default(TBodyCastRecord);
  lMarker := 19;
  lReceiver.Number := 12.5;
  lReceiver.IntValue := 17;
  lReceiver.Ptr := @lMarker;
  lDouble := 0;
  WriteDouble(lReceiver, lDouble, True);
  Writeln(Ord(lDouble = 12.5), ',', Ord(lReceiver.Number = 12.5));
  lPointer := nil;
  WritePointer(lReceiver, lPointer, True);
  Writeln(Ord(lPointer = @lMarker));
  lInteger := 0;
  WriteInteger(lReceiver, lInteger, True);
  Writeln(Ord(lInteger = 17));
  lPointer := nil;
  ReadPointer(lReceiver, lPointer, True);
  Writeln(Ord(lPointer = @lMarker));
  lDouble := -3;
  WriteDouble(lReceiver, lDouble, False);
  Writeln(Ord(lDouble = -3));
  lPointer := nil;
  WritePointer(lReceiver, lPointer, False);
  Writeln(Ord(lPointer = nil));
  lInteger := -1;
  WriteInteger(lReceiver, lInteger, False);
  Writeln(Ord(lInteger = -1));
  lPointer := nil;
  ReadPointer(lReceiver, lPointer, False);
  Writeln(Ord(lPointer = nil));
  lReceiver.IntValue := 5;
  ObserveRoutine(lReceiver, lInteger);
  Writeln(lInteger);
  ObserveType(lReceiver, lInteger);
  Writeln(lInteger);
  ObserveMember(5, lInteger);
  Writeln(lInteger);
end.
