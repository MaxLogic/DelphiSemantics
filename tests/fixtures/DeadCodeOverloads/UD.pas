unit UD;

interface

procedure Ov(a: Integer); overload;
procedure Ov(const s: string); overload;
function Lone(x: Integer): Integer;
procedure Helper(a: Integer);
procedure Ov2(a: Integer; b: Integer = 0); overload;
procedure Ov2(const s: string); overload;

implementation

procedure Ov(a: Integer);
begin
end;

procedure Ov(const s: string);
begin
end;

function Lone;
begin
  Result := x;
end;

procedure Helper;
begin
end;

procedure Other;

  procedure Helper;
  begin
  end;

begin
end;

procedure Ov2(a: Integer; b: Integer);
begin
end;

procedure Ov2(const s: string);
begin
end;

end.
