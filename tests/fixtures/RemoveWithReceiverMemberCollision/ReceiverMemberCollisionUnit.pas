unit ReceiverMemberCollisionUnit;

interface

type
  TMatrix = array[1..2, 1..2] of Integer;
  TVector = record
    n: Integer;
    v: TMatrix;
  end;

procedure Fill(var v: TVector; const aRun: Boolean);
procedure FillSpaced(var v: TVector);
procedure FillCase(var v: TVector);
procedure FillNamed(var aValue: TVector);
procedure FillLexical(var v: TVector);
procedure FillInline(var aValue: TVector);

implementation

procedure Fill(var v: TVector; const aRun: Boolean);
begin
  if aRun then
    with v do
    begin
      Inc(n);
      v[1, n] := 7;
      v[2, n] := 9;
    end;
end;

procedure FillSpaced(var v: TVector);
begin
  with v do
  begin
    Inc(n);
    v [1, n] := 7;
    v [2, n] := 9;
  end;
end;

procedure FillCase(var v: TVector);
begin
  with v do
  begin
    Inc(n);
    V[1, N] := 7;
    V[2, N] := 9;
  end;
end;

procedure FillNamed(var aValue: TVector);
begin
  with aValue do
  begin
    Inc(n);
    v[1, n] := 7;
    v[2, n] := 9;
  end;
end;

procedure FillLexical(var v: TVector);
var
  lOther: TVector;
  s: string;
  xy: TMatrix;
begin
  lOther := Default(TVector);
  xy := Default(TMatrix);
  with v do
  begin
    n := 1;
    xy[1, n] := 11;
    lOther.v[2, n] := 13;
    v[1, n] := xy[1, n];
    v[2, n] := lOther. v[2, n];
    s := 'v[1, n]'; { v[2, n] is a comment here. }
  end;
  if s <> 'v[1, n]' then
    Halt(2);
end;

procedure FillInline(var aValue: TVector);
begin
  with aValue do
  begin
    n := 1;
    begin
      var lLocal: TMatrix;
      lLocal := Default(TMatrix);
      lLocal[1, 1] := 17;
      if lLocal[1, 1] <> 17 then
        Halt(3);
    end;
  end;
end;

end.
