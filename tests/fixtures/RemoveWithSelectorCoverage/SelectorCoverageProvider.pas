unit SelectorCoverageProvider;

interface

procedure AdvanceCount(var aCount: Integer);

implementation

procedure AdvanceCount(var aCount: Integer);
begin
  Inc(aCount, 3);
end;

end.
