unit DelphiSemantics.ComparisonContext;

interface

{$IFDEF MSWINDOWS}
uses
  Winapi.Windows;
{$ENDIF}

type
  // Operation boundary policy: DS checks at each alternate-source lookup;
  // DAK checks at Prepare before its filename Matches batch. Unreadable NLS
  // always disables reuse. This state never represents filesystem currentness.
  TDelphiSemanticComparisonContext = class
  private
    fAvailable: Boolean;
{$IFDEF MSWINDOWS}
    fLocale: LCID;
    fVersion: TNlsVersionInfoEx;
{$ENDIF}
  protected
{$IFDEF MSWINDOWS}
    function ReadComparisonContext(out aLocale: LCID;
      out aVersion: TNlsVersionInfoEx): Boolean; virtual;
{$ENDIF}
    // Only the owner's operation entry point may advance this stamp: DS
    // BeginCall or DAK Prepare. Helpers must not consume a second comparison.
    function BeginOperation: Boolean;
  public
    property ComparisonAvailable: Boolean read fAvailable;
  end;

implementation

uses
  System.SysUtils;

{$IFDEF MSWINDOWS}
function TDelphiSemanticComparisonContext.ReadComparisonContext(out aLocale: LCID;
  out aVersion: TNlsVersionInfoEx): Boolean;
begin
  aLocale := GetUserDefaultLCID;
  aVersion := Default(TNlsVersionInfoEx);
  aVersion.dwNLSVersionInfoSize := SizeOf(aVersion);
  Result := Winapi.Windows.GetNLSVersionEx(DWORD(Winapi.Windows.COMPARE_STRING),
    PWideChar(Winapi.Windows.LOCALE_NAME_USER_DEFAULT), @aVersion);
end;
{$ENDIF}

function TDelphiSemanticComparisonContext.BeginOperation: Boolean;
{$IFDEF MSWINDOWS}
var
  lLocale: LCID;
  lVersion: TNlsVersionInfoEx;
  lAvailable: Boolean;
{$ENDIF}
begin
{$IFDEF MSWINDOWS}
  lAvailable := ReadComparisonContext(lLocale, lVersion);
  Result := lAvailable and fAvailable and (lLocale = fLocale) and
    CompareMem(@lVersion, @fVersion, SizeOf(lVersion));
  fAvailable := lAvailable;
  fLocale := lLocale;
  fVersion := lVersion;
{$ELSE}
  fAvailable := False;
  Result := False;
{$ENDIF}
end;

end.
