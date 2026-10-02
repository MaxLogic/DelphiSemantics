unit UEntry;

// DS-660: Value is used only by the program main block, InitUsed only by UInit's start-up
// block and FinalUsed only by its shut-down block. NeverUsed is the control.
// DS-659: IncludedUnused is declared in entry.inc, so its position is in that file.

interface

function Value: Integer;
function InitUsed: Integer;
function FinalUsed: Integer;
function NeverUsed: Integer;

implementation

{$I entry.inc}

function Value: Integer;
begin
  Result := 1;
end;

function InitUsed: Integer;
begin
  Result := 2;
end;

function FinalUsed: Integer;
begin
  Result := 3;
end;

function NeverUsed: Integer;
begin
  Result := 4;
end;

end.
