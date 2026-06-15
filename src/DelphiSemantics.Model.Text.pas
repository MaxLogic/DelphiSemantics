unit DelphiSemantics.Model.Text;

interface

function IsIdentifierChar(const aChar: Char): Boolean;
function SanitizeCodeText(const aText: string): string;

implementation

uses
  System.SysUtils;

function IsIdentifierChar(const aChar: Char): Boolean;
begin
  Result := CharInSet(aChar, ['A'..'Z', 'a'..'z', '0'..'9', '_']);
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