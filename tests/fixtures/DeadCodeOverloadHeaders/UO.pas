unit UO;

interface

procedure Ov4(a, b: Integer); overload;
procedure Ov6(a: Integer; b: Integer = 0); overload;

implementation

procedure Ov4(a: Integer; b: Integer);
begin
end;

procedure Ov4(const s: string); overload;
begin
end;

procedure Ov6(a: Integer; b: Integer);
begin
end;

procedure Ov6(const s: string); overload;
begin
end;

procedure Lonely;
begin
end;

end.
