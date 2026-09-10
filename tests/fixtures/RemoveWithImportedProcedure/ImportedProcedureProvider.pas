unit ImportedProcedureProvider;

interface

procedure AdvanceCount(var aCount: Integer);
function AdvancedCount(const aCount: Integer): Integer;

procedure AmbiguousAdvance(var aCount: Integer); overload;
procedure AmbiguousAdvance(var aText: string); overload;

implementation

procedure AdvanceCount(var aCount: Integer);
begin
  Inc(aCount, 3);
end;

function AdvancedCount(const aCount: Integer): Integer;
begin
  Result := aCount + 3;
end;

procedure AmbiguousAdvance(var aCount: Integer);
begin
  Inc(aCount, 20);
end;

procedure AmbiguousAdvance(var aText: string);
begin
  aText := aText + 'x';
end;

end.
