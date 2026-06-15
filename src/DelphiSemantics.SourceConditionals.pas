unit DelphiSemantics.SourceConditionals;

interface

type
  TDelphiSemanticSourceConditionals = record
  public
    class function InsideInactiveNeverConditionalRegion(const aLines: TArray<string>;
      const aStartLine, aLine: Integer): Boolean; static;
    class function LineHasConditionalDirective(const aLineText: string): Boolean; overload; static;
    class function LineHasConditionalDirective(const aLines: TArray<string>;
      const aLine: Integer): Boolean; overload; static;
  end;

implementation

uses
  System.StrUtils, System.SysUtils;

class function TDelphiSemanticSourceConditionals.InsideInactiveNeverConditionalRegion(
  const aLines: TArray<string>; const aStartLine, aLine: Integer): Boolean;
var
  i: Integer;
  lInactiveDepth: Integer;
  lLineText: string;
begin
  Result := False;
  if (aStartLine <= 0) or (aLine <= 0) then
    Exit;
  lInactiveDepth := 0;
  for i := aStartLine to aLine do
  begin
    if (i <= 0) or (i > Length(aLines)) then
      Continue;
    lLineText := Trim(aLines[i - 1]);
    if StartsText('{$IFDEF NEVER', lLineText) then
      Inc(lInactiveDepth)
    else if StartsText('{$ENDIF', lLineText) and (lInactiveDepth > 0) then
      Dec(lInactiveDepth);
    if (i = aLine) and (lInactiveDepth > 0) then
      Exit(True);
  end;
end;

class function TDelphiSemanticSourceConditionals.LineHasConditionalDirective(
  const aLineText: string): Boolean;
begin
  Result := StartsText('{$IF', Trim(aLineText));
end;

class function TDelphiSemanticSourceConditionals.LineHasConditionalDirective(
  const aLines: TArray<string>; const aLine: Integer): Boolean;
begin
  Result := (aLine > 0) and (aLine <= Length(aLines)) and
    LineHasConditionalDirective(aLines[aLine - 1]);
end;

end.
