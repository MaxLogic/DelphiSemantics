program ReceiverMemberCollision;

{$APPTYPE CONSOLE}

uses
  ReceiverMemberCollisionUnit in 'ReceiverMemberCollisionUnit.pas';

procedure PrintValue(const aValue: TVector);
begin
  Writeln(aValue.n, ',', aValue.v[1, 1], ',', aValue.v[2, 1]);
end;

var
  lValue: TVector;
begin
  lValue := Default(TVector);
  Fill(lValue, False);
  PrintValue(lValue);
  Fill(lValue, True);
  PrintValue(lValue);
  lValue := Default(TVector);
  FillSpaced(lValue);
  PrintValue(lValue);
  lValue := Default(TVector);
  FillCase(lValue);
  PrintValue(lValue);
  lValue := Default(TVector);
  FillNamed(lValue);
  PrintValue(lValue);
  lValue := Default(TVector);
  FillLexical(lValue);
  PrintValue(lValue);
  lValue := Default(TVector);
  FillInline(lValue);
  PrintValue(lValue);
end.
