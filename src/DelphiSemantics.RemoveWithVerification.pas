unit DelphiSemantics.RemoveWithVerification;

interface

type
  TDelphiSemanticRemoveWithVerificationReplacement = record
    PlainOffset: Integer;
    PlainText: string;
    VerificationText: string;
  end;

// Verification-only text. The published plan and the committed source stay plain.
function RemoveWithVerificationText(const aText: string; const aInitializations: TArray<string>;
  out aReplacements: TArray<TDelphiSemanticRemoveWithVerificationReplacement>): string;

implementation

uses
  System.Generics.Collections, System.Generics.Defaults, System.StrUtils, System.SysUtils,
  DelphiSemantics.Model.Text;

function RemoveWithVerificationText(const aText: string; const aInitializations: TArray<string>;
  out aReplacements: TArray<TDelphiSemanticRemoveWithVerificationReplacement>): string;
var
  lInitialization, lTyped, lCode, lName: string;
  lOffset, lIndex: Integer;
  lReplacement: TDelphiSemanticRemoveWithVerificationReplacement;
  lSeen: TArray<string>;
begin
  Result := aText;
  aReplacements := nil;
  lSeen := nil;
  lCode := SanitizeCodeText(aText);
  for lInitialization in aInitializations do
  begin
    if (lInitialization = '') or MatchStr(lInitialization, lSeen) then
      Continue;
    lSeen := lSeen + [lInitialization];
    // T+ must remain active through the semicolon. Restoring it immediately
    // after @Subject silently permits the mismatched assignment under T-.
    lTyped := '{$IFOPT T-}{$T+}' + lInitialization + '{$T-}{$ELSE}' +
      lInitialization + '{$ENDIF}';
    lOffset := Pos(lInitialization, aText);
    while lOffset > 0 do
    begin
      lName := Copy(lInitialization, 1, Pos(' := ', lInitialization) - 1);
      // Absorbed nested WITH statements can initialize a temp mid-line.
      // Match a code identifier, excluding strings/comments with the existing
      // length-preserving Pascal sanitizer rather than assuming a line start.
      if (lName <> '') and IsWordAt(lCode, lOffset, lName) then
      begin
        lIndex := Length(aReplacements);
        SetLength(aReplacements, lIndex + 1);
        aReplacements[lIndex].PlainOffset := lOffset;
        aReplacements[lIndex].PlainText := lInitialization;
        aReplacements[lIndex].VerificationText := lTyped;
        Inc(lOffset, Length(lInitialization));
      end else
        Inc(lOffset, Length(lInitialization));
      lOffset := PosEx(lInitialization, aText, lOffset);
    end;
  end;
  TArray.Sort<TDelphiSemanticRemoveWithVerificationReplacement>(aReplacements,
    TComparer<TDelphiSemanticRemoveWithVerificationReplacement>.Construct(
      function(const aLeft, aRight: TDelphiSemanticRemoveWithVerificationReplacement): Integer
      begin
        Result := aRight.PlainOffset - aLeft.PlainOffset;
      end));
  for lReplacement in aReplacements do
  begin
    Delete(Result, lReplacement.PlainOffset, Length(lReplacement.PlainText));
    Insert(lReplacement.VerificationText, Result, lReplacement.PlainOffset);
  end;
end;

end.
