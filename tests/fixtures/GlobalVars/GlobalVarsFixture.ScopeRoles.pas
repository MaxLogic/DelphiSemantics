unit GlobalVarsFixture.ScopeRoles;

interface

uses
  System.Classes;

type
  TScopeStore = class
  private
    fValue: Integer;
  public
    class var
      sSharedValue: Integer;
    procedure WriteField;
  end;

  TSecondScopeStore = class
  public
    class var
      sSharedValue: Integer;
  end;

  TPropertyStore = class(TStringList)
  public
    constructor Create;
  end;

var
  GUnitValue: Integer;

threadvar
  GThreadValue: Integer;

{$J+}
const
  GMutableValue: Integer = 1;
{$J-}
  GImmutableValue: Integer = 2;

function BuildNumber(const aSeed: Integer): Integer;
function OverloadedValue(const aSeed: Integer): Integer; overload;
function OverloadedValue(const aSeed: string): Integer; overload;
procedure TouchNested;
procedure TouchSharedClassVars;

implementation

function BuildNumber(const aSeed: Integer): Integer;
var
  lValue: Integer;
begin
  lValue := aSeed;
  Result := lValue + GUnitValue;
end;

constructor TPropertyStore.Create;
begin
  inherited Create;
  CaseSensitive := False;
  NameValueSeparator := '=';
end;

function OverloadedValue(const aSeed: Integer): Integer;
var
  lValue: Integer;
begin
  lValue := aSeed;
  Result := lValue;
end;

function OverloadedValue(const aSeed: string): Integer;
var
  lValue: Integer;
begin
  lValue := Length(aSeed);
  Result := lValue;
end;

procedure TScopeStore.WriteField;
begin
  fValue := GMutableValue;
end;

procedure TouchNested;
  procedure TouchInner;
  var
    GThreadValue: Integer;
  begin
    GThreadValue := 1;
  end;
var
  lValue: Integer;
begin
  lValue := 1;
  TouchInner;
  GThreadValue := lValue;
end;

procedure TouchSharedClassVars;
begin
  TScopeStore.sSharedValue := 1;
  TSecondScopeStore.sSharedValue := 2;
end;

end.
