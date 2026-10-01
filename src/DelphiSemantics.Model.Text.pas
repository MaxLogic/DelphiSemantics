unit DelphiSemantics.Model.Text;

interface

function NormalizeRoutineSignature(const aSignature: string): string;
function IsIdentifierStart(const aChar: Char): Boolean;
function IsIdentifierChar(const aChar: Char): Boolean;
function IsMemberAccessDot(const aText: string; const aIndex: Integer): Boolean;
function IsWordAt(const aText: string; const aOffset: Integer; const aWord: string): Boolean; overload;
function IsWordAt(const aText, aWord: string; const aIndex: Integer): Boolean; overload;
function TextContainsIdentifier(const aText, aIdentifier: string): Boolean;
function SanitizeCodeText(const aText: string): string;
function TrySplitTopLevelCommaList(const aText: string; out aParts: TArray<string>): Boolean;

implementation

uses
  System.Generics.Collections, System.StrUtils, System.SysUtils,
  AutoFree, SimpleParser.Lexer, SimpleParser.Lexer.Types;

type
  TCommaListLexer = class(TmwBasePasLex)
  private
    fFailed: Boolean;
    procedure HandleMessage(aSender: TObject; const aKind: TMessageEventType;
      const aMessage: string; x, y: Integer);
  end;

procedure TCommaListLexer.HandleMessage(aSender: TObject;
  const aKind: TMessageEventType; const aMessage: string; x, y: Integer);
begin
  fFailed := True;
end;

function NormalizeRoutineSignature(const aSignature: string): string;
var
  g: TGarbos;
  lBuilder: TStringBuilder;
  lLexer: TCommaListLexer;
  lToken: string;
begin
  g := Default(TGarbos);
  GC(lBuilder, TStringBuilder.Create, g);
  GC(lLexer, TCommaListLexer.Create, g);
  lLexer.OnMessage := lLexer.HandleMessage;
  lLexer.UseDefines := False;
  lLexer.Origin := aSignature;
  while (lLexer.TokenID <> ptNull) and not lLexer.fFailed do
  begin
    if not IsTokenIDJunk(lLexer.TokenID) then
    begin
      if lLexer.TokenID in [ptUnknown, ptError] then
        Exit('invalid:' + aSignature);
      lToken := lLexer.Token;
      // Literal contents retain case and spacing; length framing preserves token boundaries.
      if Pos('''', lToken) = 0 then
        lToken := LowerCase(lToken);
      lBuilder.Append(Length(lToken)).Append(':').Append(lToken);
    end;
    lLexer.Next;
  end;
  if lLexer.fFailed then
    Exit('invalid:' + aSignature);
  Result := lBuilder.ToString;
end;

function TrySplitTopLevelCommaList(const aText: string; out aParts: TArray<string>): Boolean;
var
  g: TGarbos;
  lDepth: Integer;
  lHasToken: Boolean;
  lLexer: TCommaListLexer;
  lParts: TList<string>;
  lStack: TArray<TptTokenKind>;
  lStart: Integer;
begin
  Result := False;
  aParts := nil;
  if Pos(#0, aText) > 0 then
    Exit;
  g := Default(TGarbos);
  GC(lLexer, TCommaListLexer.Create, g);
  GC(lParts, TList<string>.Create, g);
  lLexer.OnMessage := lLexer.HandleMessage;
  lLexer.UseDefines := False;
  lLexer.Origin := aText;
  SetLength(lStack, Length(aText));
  lDepth := 0;
  lStart := 1;
  lHasToken := False;
  while (lLexer.TokenID <> ptNull) and not lLexer.fFailed do
  begin
    if not IsTokenIDJunk(lLexer.TokenID) then
    begin
      if lLexer.TokenID in [ptUnknown, ptError] then
        Exit;
      if lLexer.TokenID in [ptRoundOpen, ptSquareOpen] then
      begin
        lStack[lDepth] := lLexer.TokenID;
        Inc(lDepth);
      end else if lLexer.TokenID in [ptRoundClose, ptSquareClose] then
      begin
        if lDepth = 0 then
          Exit;
        Dec(lDepth);
        if ((lLexer.TokenID = ptRoundClose) and (lStack[lDepth] <> ptRoundOpen)) or
          ((lLexer.TokenID = ptSquareClose) and (lStack[lDepth] <> ptSquareOpen)) then
          Exit;
      end else if (lLexer.TokenID = ptComma) and (lDepth = 0) then
      begin
        if not lHasToken then
          Exit;
        lParts.Add(Trim(Copy(aText, lStart, lLexer.TokenPos + 1 - lStart)));
        lStart := lLexer.TokenPos + lLexer.TokenLen + 1;
        lHasToken := False;
        lLexer.Next;
        Continue;
      end;
      lHasToken := True;
    end;
    lLexer.Next;
  end;
  if lLexer.fFailed or (lDepth <> 0) or not lHasToken then
    Exit;
  lParts.Add(Trim(Copy(aText, lStart, MaxInt)));
  aParts := lParts.ToArray;
  Result := True;
end;

function IsIdentifierStart(const aChar: Char): Boolean;
begin
  Result := CharInSet(aChar, ['A'..'Z', 'a'..'z', '_']);
end;

function IsIdentifierChar(const aChar: Char): Boolean;
begin
  Result := IsIdentifierStart(aChar) or CharInSet(aChar, ['0'..'9']);
end;

function IsMemberAccessDot(const aText: string; const aIndex: Integer): Boolean;
begin
  // Either dot of a range separator `..` (subranges, case labels, set and array bounds)
  // is not a member access.
  Result := (aIndex > 0) and (aIndex <= Length(aText)) and (aText[aIndex] = '.') and
    not ((aIndex > 1) and (aText[aIndex - 1] = '.')) and
    not ((aIndex < Length(aText)) and (aText[aIndex + 1] = '.'));
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
