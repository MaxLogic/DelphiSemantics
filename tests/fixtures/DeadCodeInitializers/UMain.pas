unit UMain;

interface

function Value: Integer;
function Doubled: Integer;
function Hidden: Integer;

implementation

uses
  UOther;

procedure Show;
begin
  WriteLn(Value);
end;

var
  GLimit: Integer = 10;
  GOther: Integer = 0;
  PLimit: PInteger = @GLimit;
  GHidden: Integer = 5;

const
  CLimit = 7;
  CDouble = CLimit * 2;

function Value: Integer;
begin
  Result := PLimit^ + GOther;
end;

function Doubled: Integer;
begin
  Result := CDouble;
end;

function Hidden: Integer;
begin
  Result := 0;
  {$IFDEF DS653_NEVER_DEFINED}
  Result := GHidden;
  {$ENDIF}
end;

initialization
  if Hidden <> 0 then
    Show;

end.
