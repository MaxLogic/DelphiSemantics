unit DelphiSemantics.Model.Text;

interface

function IsIdentifierStart(const aChar: Char): Boolean;
function IsIdentifierChar(const aChar: Char): Boolean;
function IsWordAt(const aText: string; const aOffset: Integer; const aWord: string): Boolean; overload;
function IsWordAt(const aText, aWord: string; const aIndex: Integer): Boolean; overload;
function TextContainsIdentifier(const aText, aIdentifier: string): Boolean;
function SanitizeCodeText(const aText: string): string;

implementation

uses
  System.StrUtils, System.SysUtils;

function IsIdentifierStart(const aChar: Char): Boolean;
begin
  Result := CharInSet(aChar, ['A'..'Z', 'a'..'z', '_']);
end;

function IsIdentifierChar(const aChar: Char): Boolean;
begin
  Result := IsIdentifierStart(aChar) or CharInSet(aChar, ['0'..'9']);
end;

function IsWordAt(const aText: string; const aOffset: Integer; const aWord: string): Boolean; overload;
var
  lAfterOffset: Integer;
begin
  Result := False;
  if (aOffset < 1) or (aWord = '') or (aOffset + Length(aWord) - 1 > Length(aText)) then
    Exit;

  lAfterOffset := aOffset + Length(aWord);
  Result := SameText(Copy(aText, aOffset, Length(aWord)), aWord) and
    ((aOffset = 1) or not IsIdentifierChar(aText[aOffset - 1])) and
    ((lAfterOffset > Length(aText)) or not IsIdentifierChar(aText[lAfterOffset]));
end;

function IsWordAt(const aText, aWord: string; const aIndex: Integer): Boolean; overload;
begin
  Result := IsWordAt(aText, aIndex, aWord);
end;

function TextContainsIdentifier(const aText, aIdentifier: string): Boolean;
var
  lIndex: Integer;
begin
  Result := False;
  if (aText = '') or (aIdentifier = '') then
    Exit;

  lIndex := Pos(aIdentifier, aText);
  while lIndex > 0 do
  begin
    if IsWordAt(aText, lIndex, aIdentifier) then
      Exit(True);
    lIndex := PosEx(aIdentifier, aText, lIndex + 1);
  end;
end;

function SanitizeCodeText(const aText: string): string;
var
  i: Integer;
  lCommentMode: Integer;
  sb: TStringBuilder;
begin
  sb := TStringBuilder.Create(Length(aText));
  try
    lCommentMode := 0;
    i := 1;
    while i <= Length(aText) do
    begin
      if lCommentMode = 1 then
      begin
        if CharInSet(aText[i], [#10, #13]) then
          sb.Append(aText[i])
        else
          sb.Append(' ');
        if (aText[i] = '*') and (i < Length(aText)) and (aText[i + 1] = ')') then
        begin
          sb.Append(' ');
          Inc(i);
          lCommentMode := 0;
        end;
      end else if lCommentMode = 2 then
      begin
        if CharInSet(aText[i], [#10, #13]) then
          sb.Append(aText[i])
        else
          sb.Append(' ');
        if aText[i] = '}' then
          lCommentMode := 0;
      end else if lCommentMode = 3 then
      begin
        if CharInSet(aText[i], [#10, #13]) then
        begin
          sb.Append(aText[i]);
          lCommentMode := 0;
        end else
          sb.Append(' ');
      end else if aText[i] = '''' then
      begin
        sb.Append(' ');
        Inc(i);
        while i <= Length(aText) do
        begin
          if CharInSet(aText[i], [#10, #13]) then
            sb.Append(aText[i])
          else
            sb.Append(' ');
          if aText[i] = '''' then
          begin
            if (i < Length(aText)) and (aText[i + 1] = '''') then
            begin
              Inc(i);
              sb.Append(' ');
            end else
              Break;
          end;
          Inc(i);
        end;
      end else if (aText[i] = '(') and (i < Length(aText)) and (aText[i + 1] = '*') then
      begin
        sb.Append(' ');
        sb.Append(' ');
        Inc(i);
        lCommentMode := 1;
      end else if aText[i] = '{' then
      begin
        sb.Append(' ');
        lCommentMode := 2;
      end else if (aText[i] = '/') and (i < Length(aText)) and (aText[i + 1] = '/') then
      begin
        sb.Append(' ');
        sb.Append(' ');
        Inc(i);
        lCommentMode := 3;
      end else
        sb.Append(aText[i]);
      Inc(i);
    end;
    Result := sb.ToString;
  finally
    sb.Free;
  end;
end;

end.
