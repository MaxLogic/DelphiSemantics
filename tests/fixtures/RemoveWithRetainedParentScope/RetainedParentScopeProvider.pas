unit RetainedParentScopeProvider;

interface

procedure PreserveBoundary(var aValue: Integer); overload;
procedure PreserveBoundary(var aValue: string); overload;

implementation

procedure PreserveBoundary(var aValue: Integer);
begin
  Inc(aValue);
end;

procedure PreserveBoundary(var aValue: string);
begin
  aValue := aValue + 'x';
end;

end.
