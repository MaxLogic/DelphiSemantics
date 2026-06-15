unit DelphiSemantics.Model;

interface

type
  TDelphiSemanticModelOptions = record
    SourceFileName: string;
    Defines: TArray<string>;
    SearchPaths: TArray<string>;
    ProjectContextApplied: Boolean;
    SkipBodyAnalysis: Boolean;
    SkipReferenceExtraction: Boolean;
    WithStatementsOnly: Boolean;
  end;

  TDelphiSemanticModelDiagnostic = record
    Code: string;
    Message: string;
    FileName: string;
    Line: Integer;
  end;

  TDelphiSemanticDeclaration = record
    Name: string;
    Kind: string;
    TypeName: string;
    BaseTypeName: string;
    HelperTargetName: string;
    SectionKind: string;
    Line: Integer;
    Column: Integer;
    Offset: Integer;
    EndOffset: Integer;
  end;

  TDelphiSemanticMember = record
    OwnerName: string;
    Name: string;
    Kind: string;
    TypeName: string;
    Visibility: string;
    Signature: string;
    IsIndexed: Boolean;
    IsDefault: Boolean;
    Line: Integer;
    Column: Integer;
    Offset: Integer;
    EndOffset: Integer;
  end;

  TDelphiSemanticParameter = record
    RoutineName: string;
    Name: string;
    TypeName: string;
    Modifier: string;
    Line: Integer;
    Column: Integer;
    Offset: Integer;
    EndOffset: Integer;
  end;

  TDelphiSemanticRoutine = record
    Name: string;
    OwnerName: string;
    SectionKind: string;
    Signature: string;
    ReturnType: string;
    Line: Integer;
    Column: Integer;
    Offset: Integer;
    EndOffset: Integer;
    Parameters: TArray<TDelphiSemanticParameter>;
  end;

  TDelphiSemanticLocal = record
    RoutineName: string;
    Name: string;
    Kind: string;
    TypeName: string;
    Line: Integer;
    Column: Integer;
    Offset: Integer;
    EndOffset: Integer;
  end;

  TDelphiSemanticReference = record
    Name: string;
    RoutineName: string;
    Role: string;
    SectionKind: string;
    Line: Integer;
    Column: Integer;
    Offset: Integer;
    EndOffset: Integer;
    EndLine: Integer;
    EndColumn: Integer;
  end;

  TDelphiSemanticWithStatement = record
    Line: Integer;
    Column: Integer;
    EndLine: Integer;
    EndColumn: Integer;
    BodyLine: Integer;
    BodyColumn: Integer;
    BodyEndLine: Integer;
    BodyEndColumn: Integer;
    SelectorText: string;
    SelectorCount: Integer;
    NestingDepth: Integer;
    HasScopedDeclaration: Boolean;
    BodyText: string;
    Text: string;
  end;

  TDelphiSemanticSourceSections = record
    InterfaceOffset: Integer;
    ImplementationOffset: Integer;
    InitializationOffset: Integer;
    FinalizationOffset: Integer;
  end;

  TDelphiSemanticUnitModelMetrics = record
    ReferenceReconciliationFallbackCount: Integer;
    ReferenceReconciliationNameScanCount: Integer;
    ReferenceOccurrenceTableBuildCount: Integer;
  end;

  TDelphiSemanticUnitModel = record
    Success: Boolean;
    FileName: string;
    UnitName: string;
    SourceText: string;
    EncodingName: string;
    SourceSections: TDelphiSemanticSourceSections;
    InterfaceUses: TArray<string>;
    ImplementationUses: TArray<string>;
    Declarations: TArray<TDelphiSemanticDeclaration>;
    Members: TArray<TDelphiSemanticMember>;
    Routines: TArray<TDelphiSemanticRoutine>;
    Locals: TArray<TDelphiSemanticLocal>;
    References: TArray<TDelphiSemanticReference>;
    WithStatements: TArray<TDelphiSemanticWithStatement>;
    Diagnostics: TArray<TDelphiSemanticModelDiagnostic>;
    Metrics: TDelphiSemanticUnitModelMetrics;
  end;

  TDelphiSemanticUnitModelExtractor = record
  public
    class function TypeBlockAnalysisBuildCount: Integer; static;
    class procedure ResetTypeBlockAnalysisBuildCount; static;
    class function ExtractFromFile(const aOptions: TDelphiSemanticModelOptions):
      TDelphiSemanticUnitModel; static;
  end;

implementation

uses
  System.Classes, System.Generics.Collections, System.IOUtils, System.RegularExpressions,
  System.StrUtils, System.SyncObjs, System.SysUtils,
  DelphiSemantics.Preprocess, DelphiSemantics.Source;

type
  TOffsetRange = record
    StartOffset: Integer;
    EndOffset: Integer;
  end;

  TReferenceCoordinateCandidate = record
    Offset: Integer;
    Line: Integer;
    Column: Integer;
  end;

  TReferenceCandidateList = TList<TReferenceCoordinateCandidate>;
  TReferenceOccurrenceIndex = TObjectDictionary<string, TReferenceCandidateList>;

  TDelphiSemanticExtractionContext = class
  private
    fLineCacheLength: Integer;
    fLineCacheStarts: TArray<Integer>;
    fLineCacheText: string;
    fSectionCache: TDelphiSemanticSourceSections;
    fSectionCacheLength: Integer;
    fSectionCacheText: string;
    fTypeBlockRanges: TArray<TOffsetRange>;
    fTypeBlockRangesLength: Integer;
    fTypeBlockRangesText: string;
  public
    constructor Create;
    function ColumnOfOffset(const aText: string; const aOffset: Integer): Integer;
    procedure EnsureLineCache(const aText: string);
    procedure EnsureSectionCache(const aText: string);
    procedure EnsureTypeBlockRanges(const aText: string);
    function IsOffsetInsideTypeBlock(const aText: string; const aOffset: Integer): Boolean;
    function LineIndexOfOffset(const aText: string; const aOffset: Integer): Integer;
    function LineOfOffset(const aText: string; const aOffset: Integer): Integer;
    function OffsetOfLineColumn(const aText: string; const aLine, aColumn: Integer): Integer;
    procedure ResetTypeBlockRanges;
    function SectionForOffset(const aText: string; const aOffset: Integer): string;
  end;

var
  GTypeBlockAnalysisBuildCount: Integer = 0;

threadvar
  GExtractionContext: TDelphiSemanticExtractionContext;

function SanitizeCodeText(const aText: string): string; forward;
function ActiveExtractionContext: TDelphiSemanticExtractionContext; forward;
function BuildTypeBlockRanges(const aText: string): TArray<TOffsetRange>; forward;

function IsIdentifierChar(const aChar: Char): Boolean;
begin
  Result := CharInSet(aChar, ['A'..'Z', 'a'..'z', '0'..'9', '_']);
end;

function FindSectionKeywordOffset(const aLowerText, aKeyword: string): Integer;
var
  lAfter: Integer;
  lOffset: Integer;
begin
  lOffset := PosEx(aKeyword, aLowerText, 1);
  while lOffset > 0 do
  begin
    lAfter := lOffset + Length(aKeyword);
    if ((lOffset = 1) or not IsIdentifierChar(aLowerText[lOffset - 1])) and
      ((lAfter > Length(aLowerText)) or not IsIdentifierChar(aLowerText[lAfter])) then
      Exit(lOffset);

    lOffset := PosEx(aKeyword, aLowerText, lAfter);
  end;

  Result := 0;
end;

function BuildSourceSections(const aText: string): TDelphiSemanticSourceSections;
var
  lLowerText: string;
  lText: string;
begin
  Result := Default(TDelphiSemanticSourceSections);
  lText := aText;
  if (lText <> '') and (lText[1] = #$FEFF) then
    Delete(lText, 1, 1);
  lLowerText := LowerCase(SanitizeCodeText(lText));
  Result.InterfaceOffset := FindSectionKeywordOffset(lLowerText, 'interface');
  Result.ImplementationOffset := FindSectionKeywordOffset(lLowerText, 'implementation');
  Result.InitializationOffset := FindSectionKeywordOffset(lLowerText, 'initialization');
  Result.FinalizationOffset := FindSectionKeywordOffset(lLowerText, 'finalization');
end;

function LineIndexOfOffset(const aText: string; const aOffset: Integer): Integer;
begin
  Result := ActiveExtractionContext.LineIndexOfOffset(aText, aOffset);
end;

procedure AddDiagnostic(const aDiagnostics: TList<TDelphiSemanticModelDiagnostic>;
  const aCode, aMessage, aFileName: string; const aLine: Integer);
var
  lDiagnostic: TDelphiSemanticModelDiagnostic;
begin
  lDiagnostic.Code := aCode;
  lDiagnostic.Message := aMessage;
  lDiagnostic.FileName := aFileName;
  lDiagnostic.Line := aLine;
  aDiagnostics.Add(lDiagnostic);
end;

procedure AddSourceDiagnostics(const aDiagnostics: TList<TDelphiSemanticModelDiagnostic>;
  const aSourceDiagnostics: TArray<TDelphiSemanticSourceDiagnostic>);
var
  lDiagnostic: TDelphiSemanticSourceDiagnostic;
begin
  for lDiagnostic in aSourceDiagnostics do
    AddDiagnostic(aDiagnostics, lDiagnostic.Code, lDiagnostic.Message, lDiagnostic.FileName, 0);
end;

procedure AddPreprocessDiagnostics(const aDiagnostics: TList<TDelphiSemanticModelDiagnostic>;
  const aPreprocessDiagnostics: TArray<TDelphiSemanticPreprocessDiagnostic>);
var
  lDiagnostic: TDelphiSemanticPreprocessDiagnostic;
begin
  for lDiagnostic in aPreprocessDiagnostics do
    AddDiagnostic(aDiagnostics, lDiagnostic.Code, lDiagnostic.Message, lDiagnostic.FileName,
      lDiagnostic.Line);
end;

function LineOfOffset(const aText: string; const aOffset: Integer): Integer;
begin
  Result := ActiveExtractionContext.LineOfOffset(aText, aOffset);
end;

function ColumnOfOffset(const aText: string; const aOffset: Integer): Integer;
begin
  Result := ActiveExtractionContext.ColumnOfOffset(aText, aOffset);
end;

function OffsetOfLineColumn(const aText: string; const aLine, aColumn: Integer): Integer;
begin
  Result := ActiveExtractionContext.OffsetOfLineColumn(aText, aLine, aColumn);
end;

function NormalizeTypeName(const aTypeName: string): string; forward;
function StripTrailingDeclarationComment(const aLine: string): string; forward;

function BuildTypeBlockRanges(const aText: string): TArray<TOffsetRange>;
var
  i: Integer;
  lBlockKind: string;
  lLine: string;
  lLines: TStringList;
  lOffset: Integer;
  lRange: TOffsetRange;
  lRanges: TList<TOffsetRange>;
  lScopeLine: string;
  lTypeDepth: Integer;
  lTypeMatch: TMatch;
  lTypeName: string;
begin
  lLines := TStringList.Create;
  lRanges := TList<TOffsetRange>.Create;
  try
    lLines.Text := aText;
    lBlockKind := '';
    lOffset := 0;
    lTypeDepth := 0;
    for i := 0 to Pred(lLines.Count) do
    begin
      lLine := lLines[i].Trim;
      lScopeLine := StripTrailingDeclarationComment(lLine);
      if lTypeDepth > 0 then
      begin
        lRange.StartOffset := lOffset + 1;
        lRange.EndOffset := lOffset + Length(lLines[i]) + 1;
        lRanges.Add(lRange);
      end;

      if (lTypeDepth > 0) and SameText(lScopeLine, 'end;') then
      begin
        Dec(lTypeDepth);
      end else if SameText(lScopeLine, 'interface') or SameText(lScopeLine, 'implementation') then
      begin
        lBlockKind := '';
        lTypeDepth := 0;
      end else if SameText(lScopeLine, 'type') then
      begin
        lBlockKind := 'type';
      end else if SameText(lScopeLine, 'const') or SameText(lScopeLine, 'var') then
      begin
        lBlockKind := '';
      end else if lBlockKind = 'type' then
      begin
        lTypeMatch := TRegEx.Match(lLine, '^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*([^;\r\n]+)',
          [roIgnoreCase]);
        if lTypeMatch.Success then
        begin
          lTypeName := NormalizeTypeName(lTypeMatch.Groups[2].Value);
          if MatchText(lTypeName, ['class', 'interface', 'record']) and
            (not ContainsText(lScopeLine, ' end')) and (not EndsText(';', lScopeLine)) then
            Inc(lTypeDepth);
        end;
      end;

      Inc(lOffset, Length(lLines[i]) + Length(sLineBreak));
    end;
    Result := lRanges.ToArray;
  finally
    lRanges.Free;
    lLines.Free;
  end;
end;

function ActiveExtractionContext: TDelphiSemanticExtractionContext;
begin
  if not Assigned(GExtractionContext) then
    raise EInvalidOperation.Create('Delphi semantic extraction context is not assigned.');

  Result := GExtractionContext;
end;

constructor TDelphiSemanticExtractionContext.Create;
begin
  inherited Create;
  fLineCacheLength := -1;
  fSectionCacheLength := -1;
  fTypeBlockRangesLength := -1;
end;

procedure TDelphiSemanticExtractionContext.EnsureLineCache(const aText: string);
var
  i: Integer;
  lCount: Integer;
  lIndex: Integer;
begin
  if (Pointer(aText) = Pointer(fLineCacheText)) and (Length(aText) = fLineCacheLength) then
    Exit;

  fLineCacheLength := Length(aText);
  fLineCacheText := aText;
  lCount := 1;
  for i := 1 to Length(aText) do
    if aText[i] = #10 then
      Inc(lCount);

  SetLength(fLineCacheStarts, lCount);
  fLineCacheStarts[0] := 1;
  lIndex := 1;
  for i := 1 to Length(aText) do
    if aText[i] = #10 then
    begin
      fLineCacheStarts[lIndex] := i + 1;
      Inc(lIndex);
    end;
end;

function TDelphiSemanticExtractionContext.LineIndexOfOffset(const aText: string;
  const aOffset: Integer): Integer;
var
  lHigh: Integer;
  lLow: Integer;
  lMid: Integer;
  lOffset: Integer;
begin
  EnsureLineCache(aText);
  lOffset := aOffset;
  if lOffset < 1 then
    lOffset := 1;
  if lOffset > Length(aText) then
    lOffset := Length(aText);
  if (lOffset > 0) and (lOffset <= Length(aText)) and (aText[lOffset] = #10) then
    Inc(lOffset);

  lLow := 0;
  lHigh := High(fLineCacheStarts);
  Result := 0;
  while lLow <= lHigh do
  begin
    lMid := (lLow + lHigh) div 2;
    if fLineCacheStarts[lMid] <= lOffset then
    begin
      Result := lMid;
      lLow := lMid + 1;
    end else
      lHigh := lMid - 1;
  end;
end;

function TDelphiSemanticExtractionContext.LineOfOffset(const aText: string;
  const aOffset: Integer): Integer;
begin
  Result := LineIndexOfOffset(aText, aOffset) + 1;
end;

function TDelphiSemanticExtractionContext.ColumnOfOffset(const aText: string;
  const aOffset: Integer): Integer;
var
  lIndex: Integer;
begin
  lIndex := LineIndexOfOffset(aText, aOffset);
  Result := aOffset - fLineCacheStarts[lIndex] + 1;
  if Result < 1 then
    Result := 1;
end;

function TDelphiSemanticExtractionContext.OffsetOfLineColumn(const aText: string; const aLine,
  aColumn: Integer): Integer;
var
  lIndex: Integer;
begin
  Result := 0;
  if (aLine <= 0) or (aColumn <= 0) then
    Exit;

  EnsureLineCache(aText);
  lIndex := aLine - 1;
  if (lIndex < 0) or (lIndex > High(fLineCacheStarts)) then
    Exit;

  Result := fLineCacheStarts[lIndex] + aColumn - 1;
  if Result > Length(aText) then
    Result := 0;
end;

procedure TDelphiSemanticExtractionContext.EnsureSectionCache(const aText: string);
begin
  if (Pointer(aText) = Pointer(fSectionCacheText)) and (Length(aText) = fSectionCacheLength) then
    Exit;

  fSectionCacheLength := Length(aText);
  fSectionCacheText := aText;
  fSectionCache := BuildSourceSections(aText);
end;

function TDelphiSemanticExtractionContext.SectionForOffset(const aText: string;
  const aOffset: Integer): string;
begin
  EnsureSectionCache(aText);
  if (fSectionCache.FinalizationOffset > 0) and (aOffset >= fSectionCache.FinalizationOffset) then
    Exit('finalization');
  if (fSectionCache.InitializationOffset > 0) and
    (aOffset >= fSectionCache.InitializationOffset) then
    Exit('initialization');
  if (fSectionCache.ImplementationOffset > 0) and
    (aOffset >= fSectionCache.ImplementationOffset) then
    Exit('implementation');

  Result := 'interface';
end;

procedure TDelphiSemanticExtractionContext.EnsureTypeBlockRanges(const aText: string);
begin
  if (Pointer(aText) = Pointer(fTypeBlockRangesText)) and
    (Length(aText) = fTypeBlockRangesLength) then
    Exit;

  fTypeBlockRangesLength := Length(aText);
  fTypeBlockRangesText := aText;
  fTypeBlockRanges := BuildTypeBlockRanges(aText);
  TInterlocked.Increment(GTypeBlockAnalysisBuildCount);
end;

function TDelphiSemanticExtractionContext.IsOffsetInsideTypeBlock(const aText: string;
  const aOffset: Integer): Boolean;
var
  lHigh: Integer;
  lLow: Integer;
  lMid: Integer;
begin
  EnsureTypeBlockRanges(aText);
  lLow := 0;
  lHigh := High(fTypeBlockRanges);
  while lLow <= lHigh do
  begin
    lMid := lLow + (lHigh - lLow) div 2;
    if aOffset < fTypeBlockRanges[lMid].StartOffset then
    begin
      lHigh := lMid - 1;
    end else if aOffset > fTypeBlockRanges[lMid].EndOffset then
    begin
      lLow := lMid + 1;
    end else
      Exit(True);
  end;

  Result := False;
end;

procedure TDelphiSemanticExtractionContext.ResetTypeBlockRanges;
begin
  fTypeBlockRangesLength := -1;
  fTypeBlockRangesText := '';
  fTypeBlockRanges := nil;
end;

function SectionForOffset(const aText: string; const aOffset: Integer): string;
begin
  Result := ActiveExtractionContext.SectionForOffset(aText, aOffset);
end;

function MatchGroupValue(const aMatch: TMatch; const aIndex: Integer): string;
begin
  if aIndex < aMatch.Groups.Count then
    Result := aMatch.Groups[aIndex].Value
  else
    Result := '';
end;

function MatchGroupIndex(const aMatch: TMatch; const aIndex: Integer): Integer;
begin
  if aIndex < aMatch.Groups.Count then
    Result := aMatch.Groups[aIndex].Index
  else
    Result := 0;
end;

function QualifiedRoutineName(const aOwnerName, aRoutineName: string): string;
begin
  if aOwnerName = '' then
    Exit(aRoutineName);

  Result := aOwnerName + '.' + aRoutineName;
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

procedure AddDeclaration(const aDeclarations: TList<TDelphiSemanticDeclaration>;
  const aName, aKind, aTypeName, aSection, aText: string; const aOffset: Integer;
  const aBaseTypeName: string = ''; const aHelperTargetName: string = '');
var
  lDeclaration: TDelphiSemanticDeclaration;
begin
  lDeclaration.Name := aName;
  lDeclaration.Kind := aKind;
  lDeclaration.TypeName := aTypeName;
  lDeclaration.BaseTypeName := aBaseTypeName;
  lDeclaration.HelperTargetName := aHelperTargetName;
  lDeclaration.SectionKind := aSection;
  lDeclaration.Line := LineOfOffset(aText, aOffset);
  lDeclaration.Column := ColumnOfOffset(aText, aOffset);
  lDeclaration.Offset := aOffset;
  lDeclaration.EndOffset := aOffset + Length(aName);
  aDeclarations.Add(lDeclaration);
end;

function NormalizeMemberTypeName(const aTypeName: string): string;
begin
  Result := Trim(aTypeName);
  while EndsText(')', Result) and (Pos('(', Result) = 0) do
    Result := Trim(Copy(Result, 1, Length(Result) - 1));
end;

function NormalizeVariantMemberLine(const aLine: string): string;
var
  lInnerText: string;
  lOpenPos: Integer;
  lText: string;
begin
  Result := aLine;
  lText := Trim(aLine);
  lOpenPos := Pos('(', lText);
  if (lOpenPos > 1) and (Pos(':', Copy(lText, 1, lOpenPos - 1)) > 0) then
  begin
    lInnerText := Copy(lText, lOpenPos + 1, MaxInt);
    if Pos(':', lInnerText) > 0 then
      lText := Trim(Copy(lText, lOpenPos, MaxInt));
  end;

  if StartsText('(', lText) then
  begin
    lText := Trim(Copy(lText, 2, MaxInt));
    if EndsText(');', lText) then
      Result := Trim(Copy(lText, 1, Length(lText) - 2)) + ';'
    else if EndsText(')', lText) then
      Result := Trim(Copy(lText, 1, Length(lText) - 1)) + ';'
    else
      Result := lText;
  end else if EndsText(');', lText) then
    Result := Trim(Copy(lText, 1, Length(lText) - 2)) + ';';
end;

procedure AddMember(const aMembers: TList<TDelphiSemanticMember>; const aOwnerName, aName, aKind,
  aTypeName, aVisibility, aSignature, aText: string; const aIsIndexed, aIsDefault: Boolean;
  const aOffset: Integer);
var
  lMember: TDelphiSemanticMember;
begin
  lMember.OwnerName := aOwnerName;
  lMember.Name := aName;
  lMember.Kind := aKind;
  lMember.TypeName := NormalizeMemberTypeName(aTypeName);
  lMember.Visibility := aVisibility;
  lMember.Signature := aSignature;
  lMember.IsIndexed := aIsIndexed;
  lMember.IsDefault := aIsDefault;
  lMember.Line := LineOfOffset(aText, aOffset);
  lMember.Column := ColumnOfOffset(aText, aOffset);
  lMember.Offset := aOffset;
  lMember.EndOffset := aOffset + Length(aName);
  aMembers.Add(lMember);
end;

procedure AddLocal(const aLocals: TList<TDelphiSemanticLocal>; const aRoutineName, aName, aKind,
  aTypeName, aText: string; const aOffset: Integer);
var
  lLocal: TDelphiSemanticLocal;
begin
  lLocal.RoutineName := aRoutineName;
  lLocal.Name := aName;
  lLocal.Kind := aKind;
  lLocal.TypeName := aTypeName;
  lLocal.Line := LineOfOffset(aText, aOffset);
  lLocal.Column := ColumnOfOffset(aText, aOffset);
  lLocal.Offset := aOffset;
  lLocal.EndOffset := aOffset + Length(aName);
  aLocals.Add(lLocal);
end;

procedure AddReference(const aReferences: TList<TDelphiSemanticReference>; const aRoutineName,
  aName, aText: string; const aOffset: Integer);
var
  lReference: TDelphiSemanticReference;
begin
  if not Assigned(aReferences) then
    Exit;

  lReference.Name := aName;
  lReference.RoutineName := aRoutineName;
  lReference.Role := 'reference';
  lReference.SectionKind := SectionForOffset(aText, aOffset);
  lReference.Line := LineOfOffset(aText, aOffset);
  lReference.Column := ColumnOfOffset(aText, aOffset);
  lReference.Offset := aOffset;
  lReference.EndOffset := aOffset + Length(aName);
  lReference.EndLine := lReference.Line;
  lReference.EndColumn := lReference.Column + Length(aName) - 1;
  aReferences.Add(lReference);
end;

function IsTypeReferenceToken(const aName: string): Boolean;
begin
  Result := (aName <> '') and not MatchText(aName, ['array', 'class', 'const', 'file',
    'function', 'interface', 'of', 'packed', 'procedure', 'record', 'set', 'string', 'type',
    'var', 'Integer', 'Cardinal', 'Boolean', 'Byte', 'Char', 'Double', 'Extended', 'Int64',
    'LongInt', 'Pointer', 'Single', 'SmallInt', 'WideChar', 'Word']);
end;

procedure AddTypeReferences(const aReferences: TList<TDelphiSemanticReference>;
  const aRoutineName, aTypeText, aText: string; const aTypeTextOffset: Integer);
var
  lMatch: TMatch;
  lReference: TDelphiSemanticReference;
begin
  if not Assigned(aReferences) then
    Exit;

  if aTypeText.Trim = '' then
    Exit;

  lMatch := TRegEx.Match(aTypeText, '\b[A-Za-z_][A-Za-z0-9_]*\b', [roIgnoreCase]);
  while lMatch.Success do
  begin
    if IsTypeReferenceToken(lMatch.Value) then
    begin
      lReference := Default(TDelphiSemanticReference);
      lReference.Name := lMatch.Value;
      lReference.RoutineName := aRoutineName;
      lReference.Role := 'type-reference';
      lReference.SectionKind := SectionForOffset(aText, aTypeTextOffset + lMatch.Index - 1);
      lReference.Line := LineOfOffset(aText, aTypeTextOffset + lMatch.Index - 1);
      lReference.Column := ColumnOfOffset(aText, aTypeTextOffset + lMatch.Index - 1);
      lReference.Offset := aTypeTextOffset + lMatch.Index - 1;
      lReference.EndOffset := lReference.Offset + Length(lReference.Name);
      lReference.EndLine := lReference.Line;
      lReference.EndColumn := lReference.Column + Length(lReference.Name) - 1;
      aReferences.Add(lReference);
    end;
    lMatch := lMatch.NextMatch;
  end;
end;

function TextOffsetInLine(const aLine, aText: string; const aLineOffset: Integer): Integer;
var
  lOffset: Integer;
begin
  lOffset := Pos(aText, aLine);
  if lOffset <= 0 then
    lOffset := 1;
  Result := aLineOffset + lOffset - 1;
end;

procedure AddParameterTypeReferences(const aReferences: TList<TDelphiSemanticReference>;
  const aRoutineName, aParameterText, aText: string; const aParameterTextOffset: Integer); forward;

function ExtractUsesUnitName(const aUsesItem: string): string;
var
  lMatch: TMatch;
begin
  Result := aUsesItem.Trim;
  lMatch := TRegEx.Match(Result, '^([A-Za-z_][A-Za-z0-9_\.]*)\b',
    [roIgnoreCase]);
  if lMatch.Success then
    Result := lMatch.Groups[1].Value;
end;

procedure AddUses(const aList: TList<string>; const aUsesText: string);
var
  lPart: string;
  lUnitName: string;
begin
  for lPart in aUsesText.Split([',']) do
  begin
    lUnitName := ExtractUsesUnitName(lPart);
    if lUnitName <> '' then
      aList.Add(lUnitName);
  end;
end;

procedure ExtractUses(const aText: string; const aInterfaceUses, aImplementationUses: TList<string>);
var
  lImplementationPos: Integer;
  lMatch: TMatch;
  lSection: string;
begin
  lImplementationPos := Pos('implementation', LowerCase(aText));
  lMatch := TRegEx.Match(aText, '\buses\s+(.*?);', [roIgnoreCase, roSingleLine]);
  while lMatch.Success do
  begin
    if (lImplementationPos > 0) and (lMatch.Index + 1 > lImplementationPos) then
      lSection := 'implementation'
    else
      lSection := 'interface';

    if lSection = 'interface' then
      AddUses(aInterfaceUses, lMatch.Groups[1].Value)
    else
      AddUses(aImplementationUses, lMatch.Groups[1].Value);
    lMatch := lMatch.NextMatch;
  end;
end;

procedure ExtractContains(const aText: string; const aImplementationUses: TList<string>);
var
  lMatch: TMatch;
begin
  lMatch := TRegEx.Match(aText, '\bcontains\s+(.*?);', [roIgnoreCase, roSingleLine]);
  while lMatch.Success do
  begin
    AddUses(aImplementationUses, lMatch.Groups[1].Value);
    lMatch := lMatch.NextMatch;
  end;
end;

function NormalizeTypeName(const aTypeName: string): string;
begin
  Result := aTypeName.Trim;
  if StartsText('(', Result) then
    Result := 'enum'
  else if StartsText('class', Result) or ContainsText(Result, ' class') then
    Result := 'class'
  else if StartsText('record', Result) or ContainsText(Result, ' record') then
    Result := 'record'
  else if StartsText('interface', Result) or ContainsText(Result, ' interface') then
    Result := 'interface';
end;

function StripTrailingDeclarationComment(const aLine: string): string;
var
  i: Integer;
  lInString: Boolean;
  lText: string;
begin
  lText := aLine;
  lInString := False;
  i := 1;
  while i <= Length(lText) do
  begin
    if lText[i] = '''' then
    begin
      if lInString and (i < Length(lText)) and (lText[i + 1] = '''') then
        Inc(i)
      else
        lInString := not lInString;
    end else if not lInString then
    begin
      if (i < Length(lText)) and (lText[i] = '/') and (lText[i + 1] = '/') then
        Exit(Copy(lText, 1, i - 1).Trim);
      if (lText[i] = '{') and not StartsText('{$', Copy(lText, i, MaxInt)) then
        Exit(Copy(lText, 1, i - 1).Trim);
      if (i < Length(lText)) and (lText[i] = '(') and (lText[i + 1] = '*') and
        not StartsText('(*$', Copy(lText, i, MaxInt)) then
        Exit(Copy(lText, 1, i - 1).Trim);
    end;
    Inc(i);
  end;

  Result := lText.Trim;
end;

function ExtractBaseTypeName(const aTypeText: string): string;
var
  lMatch: TMatch;
begin
  lMatch := TRegEx.Match(aTypeText, '\b(?:class|interface)\s*\(\s*([A-Za-z_][A-Za-z0-9_\.]*)',
    [roIgnoreCase]);
  if lMatch.Success then
    Result := lMatch.Groups[1].Value
  else
    Result := '';
end;

function ExtractHelperTargetName(const aTypeText: string): string;
var
  lMatch: TMatch;
begin
  lMatch := TRegEx.Match(aTypeText,
    '\b(?:class|record)\s+helper\s+for\s+([A-Za-z_][A-Za-z0-9_\.]*)', [roIgnoreCase]);
  if lMatch.Success then
    Result := lMatch.Groups[1].Value
  else
    Result := '';
end;

procedure ExtractEnumValues(const aText: string; const aDeclarations: TList<TDelphiSemanticDeclaration>;
  const aOwnerName, aEnumText, aSection: string; const aOffset: Integer);
var
  lEnumMatch: TMatch;
  lEnumName: string;
  lEnumPart: string;
begin
  lEnumMatch := TRegEx.Match(aEnumText, '\((.*?)\)', [roSingleLine]);
  if not lEnumMatch.Success then
    Exit;

  for lEnumPart in lEnumMatch.Groups[1].Value.Split([',']) do
  begin
    lEnumName := lEnumPart.Trim;
    if Pos('=', lEnumName) > 0 then
      lEnumName := Copy(lEnumName, 1, Pos('=', lEnumName) - 1).Trim;
    if lEnumName <> '' then
      AddDeclaration(aDeclarations, lEnumName, 'enum-value', aOwnerName, aSection, aText,
        aOffset);
  end;
end;

procedure ExtractTypeDeclarations(const aText: string;
  const aDeclarations: TList<TDelphiSemanticDeclaration>;
  const aReferences: TList<TDelphiSemanticReference>);
var
  i: Integer;
  lBlockKind: string;
  lInImplementation: Boolean;
  lInRoutine: Boolean;
  lLine: string;
  lLines: TStringList;
  lMatch: TMatch;
  lName: string;
  lScopeLine: string;
  lOffset: Integer;
  lPendingEnumName: string;
  lPendingEnumOffset: Integer;
  lPendingEnumSection: string;
  lPendingEnumText: string;
  lSection: string;
  lTypeName: string;
  lTypeText: string;
  lTypeDepth: Integer;
begin
  lLines := TStringList.Create;
  try
    lLines.Text := aText;
    lBlockKind := '';
    lInImplementation := False;
    lInRoutine := False;
    lOffset := 0;
    lPendingEnumName := '';
    lPendingEnumOffset := 0;
    lPendingEnumSection := '';
    lPendingEnumText := '';
    lTypeDepth := 0;
    for i := 0 to Pred(lLines.Count) do
    begin
      lLine := lLines[i].Trim;
      lScopeLine := StripTrailingDeclarationComment(lLine);
      if lPendingEnumName <> '' then
      begin
        lPendingEnumText := lPendingEnumText + ' ' + lScopeLine;
        if Pos(')', lScopeLine) > 0 then
        begin
          ExtractEnumValues(aText, aDeclarations, lPendingEnumName, lPendingEnumText,
            lPendingEnumSection, lPendingEnumOffset);
          lPendingEnumName := '';
          lPendingEnumText := '';
        end;
      end else if (lTypeDepth > 0) and SameText(lScopeLine, 'end;') then
      begin
        Dec(lTypeDepth);
      end else if SameText(lScopeLine, 'implementation') then
      begin
        lInImplementation := True;
        lBlockKind := '';
      end else if SameText(lScopeLine, 'interface') then
      begin
        lInImplementation := False;
        lBlockKind := '';
      end else if (lTypeDepth = 0) and
        (StartsText('procedure ', lScopeLine) or StartsText('function ', lScopeLine) or
        StartsText('class procedure ', lScopeLine) or
        StartsText('class function ', lScopeLine)) then
      begin
        lBlockKind := '';
        if lInImplementation then
          lInRoutine := True;
      end else if lInRoutine and SameText(lScopeLine, 'end;') then
      begin
        lInRoutine := False;
      end else if not lInRoutine then
      begin
        if SameText(lScopeLine, 'type') then
          lBlockKind := 'type'
        else if SameText(lScopeLine, 'const') or SameText(lScopeLine, 'var') then
          lBlockKind := ''
        else if lBlockKind = 'type' then
        begin
          lMatch := TRegEx.Match(lScopeLine, '^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*([^;\r\n]+)',
            [roIgnoreCase]);
          if lMatch.Success then
          begin
            lName := lMatch.Groups[1].Value;
            lTypeText := lMatch.Groups[2].Value;
            AddTypeReferences(aReferences, '', lTypeText, aText, TextOffsetInLine(lLines[i],
              lTypeText, lOffset));
            lTypeName := NormalizeTypeName(lTypeText);
            lSection := SectionForOffset(aText, lOffset + 1);
            if not SameText(lName, 'Result') then
            begin
              if MatchText(lTypeName, ['enum', 'class', 'interface', 'record']) then
                AddDeclaration(aDeclarations, lName, 'type', lTypeName, lSection, aText,
                  lOffset + 1, ExtractBaseTypeName(lTypeText), ExtractHelperTargetName(lTypeText))
              else
                AddDeclaration(aDeclarations, lName, 'type-alias', lTypeName, lSection, aText,
                  lOffset + 1);
            end;

            if lTypeName = 'enum' then
            begin
              if Pos(')', lTypeText) > 0 then
                ExtractEnumValues(aText, aDeclarations, lName, lMatch.Groups[2].Value, lSection,
                  lOffset + 1)
              else
              begin
                lPendingEnumName := lName;
                lPendingEnumText := lTypeText;
                lPendingEnumSection := lSection;
                lPendingEnumOffset := lOffset + 1;
              end;
            end else if MatchText(lTypeName, ['class', 'interface', 'record']) and
              (not ContainsText(lScopeLine, ' end')) and (not EndsText(';', lScopeLine)) then
              Inc(lTypeDepth);
          end;
        end;
      end;
      Inc(lOffset, Length(lLines[i]) + Length(sLineBreak));
    end;
  finally
    lLines.Free;
  end;
end;

function TryAnonymousRecordVarStart(const aLine: string; out aName: string): Boolean;
var
  lMatch: TMatch;
begin
  lMatch := TRegEx.Match(aLine, '^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(?:packed\s+)?record\b',
    [roIgnoreCase]);
  Result := lMatch.Success;
  if Result then
    aName := lMatch.Groups[1].Value
  else
    aName := '';
end;

function FindAnonymousRecordEndLine(const aLines: TStringList; const aStartIndex: Integer): Integer;
var
  i: Integer;
begin
  Result := aStartIndex;
  for i := aStartIndex + 1 to Pred(aLines.Count) do
  begin
    if SameText(aLines[i].Trim, 'end;') or SameText(aLines[i].Trim, 'end') then
      Exit(i);
  end;
end;

procedure AddAnonymousRecordMembers(const aText: string; const aLines: TStringList;
  const aOwnerName: string; const aStartIndex, aEndIndex, aStartOffset: Integer;
  const aMembers: TList<TDelphiSemanticMember>;
  const aReferences: TList<TDelphiSemanticReference>);
var
  i: Integer;
  lFieldMatch: TMatch;
  lName: string;
  lNameOffset: Integer;
  lOffset: Integer;
begin
  lOffset := aStartOffset;
  for i := aStartIndex to aEndIndex do
  begin
    lFieldMatch := TRegEx.Match(aLines[i].Trim,
      '^([A-Za-z_][A-Za-z0-9_]*(?:\s*,\s*[A-Za-z_][A-Za-z0-9_]*)*)\s*:\s*([^;]+);',
      [roIgnoreCase]);
    if lFieldMatch.Success then
    begin
      for lName in lFieldMatch.Groups[1].Value.Split([',']) do
      begin
        if lName.Trim = '' then
          Continue;
        lNameOffset := Pos(LowerCase(lName.Trim), LowerCase(aLines[i]));
        if lNameOffset <= 0 then
          lNameOffset := 1;
        AddMember(aMembers, aOwnerName, lName.Trim, 'field', lFieldMatch.Groups[2].Value.Trim,
          '', '', aText, False, False, lOffset + lNameOffset);
      end;
      AddTypeReferences(aReferences, '', lFieldMatch.Groups[2].Value.Trim, aText,
        TextOffsetInLine(aLines[i], lFieldMatch.Groups[2].Value.Trim, lOffset));
    end;
    Inc(lOffset, Length(aLines[i]) + Length(sLineBreak));
  end;
end;

procedure ExtractConstVarDeclarations(const aText, aUnitName: string;
  const aDeclarations: TList<TDelphiSemanticDeclaration>; const aMembers:
  TList<TDelphiSemanticMember>; const aReferences: TList<TDelphiSemanticReference>);
var
  i: Integer;
  j: Integer;
  lBlockKind: string;
  lDeclarationKind: string;
  lEndLine: Integer;
  lInImplementation: Boolean;
  lInRoutine: Boolean;
  lLine: string;
  lLines: TStringList;
  lMatch: TMatch;
  lName: string;
  lNameOffset: Integer;
  lOffset: Integer;
  lSection: string;
  lSkipUntilLine: Integer;
  lSyntheticTypeName: string;
begin
  lLines := TStringList.Create;
  try
    lLines.Text := aText;
    lBlockKind := '';
    lInImplementation := False;
    lInRoutine := False;
    lOffset := 0;
    lSkipUntilLine := 0;
    for i := 0 to Pred(lLines.Count) do
    begin
      lLine := lLines[i].Trim;
      if i < lSkipUntilLine then
      begin
        Inc(lOffset, Length(lLines[i]) + Length(sLineBreak));
        Continue;
      end;
      if SameText(lLine, 'implementation') then
      begin
        lInImplementation := True;
        lBlockKind := '';
      end else if SameText(lLine, 'interface') then
      begin
        lInImplementation := False;
        lBlockKind := '';
      end else if StartsText('procedure ', lLine) or StartsText('function ', lLine) then
      begin
        lBlockKind := '';
        if lInImplementation then
          lInRoutine := True;
      end else if lInRoutine and SameText(lLine, 'end;') then
      begin
        lInRoutine := False;
      end else if not lInRoutine then
      begin
        if SameText(lLine, 'const') then
          lBlockKind := 'const'
        else if SameText(lLine, 'resourcestring') then
          lBlockKind := 'resourcestring'
        else if SameText(lLine, 'var') then
          lBlockKind := 'var'
        else if SameText(lLine, 'threadvar') then
          lBlockKind := 'threadvar'
        else if SameText(lLine, 'type') then
          lBlockKind := ''
        else if MatchText(lBlockKind, ['const', 'resourcestring']) then
        begin
          lMatch := TRegEx.Match(lLine, '^([A-Za-z_][A-Za-z0-9_]*)\s*(?::\s*([^=]+?))?\s*=',
            [roIgnoreCase]);
          if lMatch.Success then
          begin
            lSection := SectionForOffset(aText, lOffset + 1);
            if SameText(lBlockKind, 'resourcestring') then
              lDeclarationKind := 'resourcestring'
            else if MatchGroupValue(lMatch, 2).Trim <> '' then
              lDeclarationKind := 'typed-const'
            else
              lDeclarationKind := 'const';
            AddDeclaration(aDeclarations, lMatch.Groups[1].Value, lDeclarationKind,
              MatchGroupValue(lMatch, 2).Trim, lSection, aText, lOffset + 1);
            AddTypeReferences(aReferences, '', MatchGroupValue(lMatch, 2).Trim, aText,
              TextOffsetInLine(lLines[i], MatchGroupValue(lMatch, 2).Trim, lOffset));
          end;
        end else if MatchText(lBlockKind, ['var', 'threadvar']) then
        begin
          lMatch := TRegEx.Match(lLine,
            '^([A-Za-z_][A-Za-z0-9_]*(?:\s*,\s*[A-Za-z_][A-Za-z0-9_]*)*)\s*:\s*([^;]+);',
            [roIgnoreCase]);
          if lMatch.Success then
          begin
            lSection := SectionForOffset(aText, lOffset + 1);
            for lName in lMatch.Groups[1].Value.Split([',']) do
              if lName.Trim <> '' then
              begin
                lNameOffset := Pos(LowerCase(lName.Trim), LowerCase(lLines[i]));
                if lNameOffset <= 0 then
                  lNameOffset := 1;
                AddDeclaration(aDeclarations, lName.Trim, lBlockKind,
                  lMatch.Groups[2].Value.Trim, lSection, aText, lOffset + lNameOffset);
              end;
            AddTypeReferences(aReferences, '', lMatch.Groups[2].Value.Trim, aText,
              TextOffsetInLine(lLines[i], lMatch.Groups[2].Value.Trim, lOffset));
          end else if TryAnonymousRecordVarStart(lLine, lName) then
          begin
            lSection := SectionForOffset(aText, lOffset + 1);
            lNameOffset := Pos(LowerCase(lName), LowerCase(lLines[i]));
            if lNameOffset <= 0 then
              lNameOffset := 1;
            if aUnitName <> '' then
              lSyntheticTypeName := aUnitName + '.' + lName
            else
              lSyntheticTypeName := lName;
            lEndLine := FindAnonymousRecordEndLine(lLines, i);
            AddDeclaration(aDeclarations, lSyntheticTypeName, 'type', 'record', lSection,
              aText, lOffset + lNameOffset);
            AddDeclaration(aDeclarations, lName, lBlockKind, lSyntheticTypeName, lSection,
              aText, lOffset + lNameOffset);

            j := lOffset + Length(lLines[i]) + Length(sLineBreak);
            AddAnonymousRecordMembers(aText, lLines, lSyntheticTypeName, i + 1, lEndLine - 1, j,
              aMembers, aReferences);
            lSkipUntilLine := lEndLine + 1;
          end;
        end;
      end;
      Inc(lOffset, Length(lLines[i]) + Length(sLineBreak));
    end;
  finally
    lLines.Free;
  end;
end;

procedure ExtractMembersFromBody(const aText, aOwnerName, aBody: string; const aBodyOffset: Integer;
  const aDeclarations: TList<TDelphiSemanticDeclaration>;
  const aMembers: TList<TDelphiSemanticMember>;
  const aReferences: TList<TDelphiSemanticReference>);
var
  lDefaultProperty: Boolean;
  lFieldMatch: TMatch;
  i: Integer;
  lInClassVarSection: Boolean;
  lIndexedProperty: Boolean;
  lLine: string;
  lLines: TStringList;
  lMethodMatch: TMatch;
  lName: string;
  lNameOffset: Integer;
  lNestedBody: string;
  lNestedBodyOffset: Integer;
  lNestedOwnerName: string;
  lNestedRecordMatch: TMatch;
  lOffset: Integer;
  lPropertyMatch: TMatch;
  lVisibility: string;
begin
  lLines := TStringList.Create;
  try
    lLines.Text := aBody;
    lOffset := aBodyOffset;
    lInClassVarSection := False;
    lNestedBody := '';
    lNestedBodyOffset := 0;
    lNestedOwnerName := '';
    lVisibility := 'public';
    for i := 0 to Pred(lLines.Count) do
    begin
      lLine := NormalizeVariantMemberLine(lLines[i].Trim);
      if lNestedOwnerName <> '' then
      begin
        if TRegEx.IsMatch(lLine, '^end\s*;', [roIgnoreCase]) then
        begin
          ExtractMembersFromBody(aText, lNestedOwnerName, lNestedBody, lNestedBodyOffset,
            aDeclarations, aMembers, aReferences);
          lNestedBody := '';
          lNestedBodyOffset := 0;
          lNestedOwnerName := '';
        end else
          lNestedBody := lNestedBody + lLines[i] + sLineBreak;
      end else if MatchText(lLine, ['private', 'protected', 'public', 'published', 'strict private',
        'strict protected']) then
      begin
        lInClassVarSection := False;
        lVisibility := lLine;
      end else if SameText(lLine, 'class var') then
      begin
        lInClassVarSection := True;
      end else if lLine <> '' then
      begin
        lNestedRecordMatch := TRegEx.Match(lLine,
          '^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(?:packed\s+)?record\b', [roIgnoreCase]);
        if lNestedRecordMatch.Success then
        begin
          lInClassVarSection := False;
          lName := lNestedRecordMatch.Groups[1].Value;
          lNameOffset := Pos(LowerCase(lName), LowerCase(lLines[i]));
          if lNameOffset <= 0 then
            lNameOffset := 1;
          lNestedOwnerName := aOwnerName + '.' + lName;
          AddDeclaration(aDeclarations, lNestedOwnerName, 'type', 'record',
            SectionForOffset(aText, lOffset + lNameOffset), aText, lOffset + lNameOffset);
          AddMember(aMembers, aOwnerName, lName, 'field', lNestedOwnerName, lVisibility, '',
            aText, False, False, lOffset + lNameOffset);
          lNestedBodyOffset := lOffset + Length(lLines[i]) + Length(sLineBreak);
        end else
        begin
          lPropertyMatch := TRegEx.Match(lLine,
          '^property\s+([A-Za-z_][A-Za-z0-9_]*)\s*(\[[^\]]+\])?\s*:\s*([^;]+)',
          [roIgnoreCase]);
          if lPropertyMatch.Success then
          begin
            lInClassVarSection := False;
            lIndexedProperty := MatchGroupValue(lPropertyMatch, 2).Trim <> '';
            lDefaultProperty := TRegEx.IsMatch(lLine, ';\s*default\s*;', [roIgnoreCase]) or
              TRegEx.IsMatch(lLine, ';\s*default\s*$', [roIgnoreCase]);
            AddMember(aMembers, aOwnerName, lPropertyMatch.Groups[1].Value, 'property',
              lPropertyMatch.Groups[3].Value.Trim.Split([' '])[0], lVisibility,
              MatchGroupValue(lPropertyMatch, 2).Trim, aText, lIndexedProperty, lDefaultProperty,
              lOffset + 1);
            AddParameterTypeReferences(aReferences, '', MatchGroupValue(lPropertyMatch, 2),
              aText, TextOffsetInLine(lLines[i], MatchGroupValue(lPropertyMatch, 2), lOffset));
            AddTypeReferences(aReferences, '', lPropertyMatch.Groups[3].Value.Trim, aText,
              TextOffsetInLine(lLines[i], lPropertyMatch.Groups[3].Value.Trim, lOffset));
          end else
          begin
            lMethodMatch := TRegEx.Match(lLine,
              '^(?:class\s+)?(procedure|function|constructor|destructor)\s+' +
              '([A-Za-z_][A-Za-z0-9_]*)\s*(\([^\r\n]*\))?\s*(?::\s*([^;]+))?',
              [roIgnoreCase]);
            if lMethodMatch.Success then
            begin
              lInClassVarSection := False;
              AddMember(aMembers, aOwnerName, lMethodMatch.Groups[2].Value, 'method',
                MatchGroupValue(lMethodMatch, 4).Trim, lVisibility, MatchGroupValue(lMethodMatch, 3),
                aText, False, False, lOffset + 1);
              AddParameterTypeReferences(aReferences, '', MatchGroupValue(lMethodMatch, 3),
                aText, TextOffsetInLine(lLines[i], MatchGroupValue(lMethodMatch, 3), lOffset));
              AddTypeReferences(aReferences, '', MatchGroupValue(lMethodMatch, 4).Trim, aText,
                lOffset + MatchGroupIndex(lMethodMatch, 4) - 1);
            end else
            begin
              lFieldMatch := TRegEx.Match(lLine,
                '^(class\s+var\s+)?([A-Za-z_][A-Za-z0-9_]*(?:\s*,\s*[A-Za-z_][A-Za-z0-9_]*)*)\s*:\s*([^;]+);',
                [roIgnoreCase]);
              if lFieldMatch.Success then
              begin
                for lName in lFieldMatch.Groups[2].Value.Split([',']) do
                  if lName.Trim <> '' then
                  begin
                    lNameOffset := Pos(LowerCase(lName.Trim), LowerCase(lLines[i]));
                    if lNameOffset <= 0 then
                      lNameOffset := 1;
                    if lInClassVarSection or (MatchGroupValue(lFieldMatch, 1).Trim <> '') then
                      AddMember(aMembers, aOwnerName, lName.Trim, 'class-var',
                        lFieldMatch.Groups[3].Value.Trim, lVisibility, '', aText, False, False,
                        lOffset + lNameOffset)
                    else
                      AddMember(aMembers, aOwnerName, lName.Trim, 'field',
                        lFieldMatch.Groups[3].Value.Trim, lVisibility, '', aText, False, False,
                        lOffset + lNameOffset);
                  end;
                AddTypeReferences(aReferences, '', lFieldMatch.Groups[3].Value.Trim, aText,
                  TextOffsetInLine(lLines[i], lFieldMatch.Groups[3].Value.Trim, lOffset));
              end;
            end;
          end;
        end;
      end;
      Inc(lOffset, Length(lLines[i]) + Length(sLineBreak));
    end;
    if lNestedOwnerName <> '' then
      ExtractMembersFromBody(aText, lNestedOwnerName, lNestedBody, lNestedBodyOffset,
        aDeclarations, aMembers, aReferences);
  finally
    lLines.Free;
  end;
end;

procedure ExtractMembers(const aText: string; const aDeclarations: TList<TDelphiSemanticDeclaration>;
  const aMembers: TList<TDelphiSemanticMember>;
  const aReferences: TList<TDelphiSemanticReference>);
var
  lMatch: TMatch;
begin
  lMatch := TRegEx.Match(aText,
    '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*((?:class|interface)(?:\s*\([^)]+\))?|' +
    '(?:class|record)\s+helper\s+for\s+[A-Za-z_][A-Za-z0-9_]*|record)\b(.*?)^\s*end\s*;',
    [roIgnoreCase, roMultiLine, roSingleLine]);
  while lMatch.Success do
  begin
    ExtractMembersFromBody(aText, lMatch.Groups[1].Value, lMatch.Groups[3].Value,
      lMatch.Groups[3].Index, aDeclarations, aMembers, aReferences);
    lMatch := lMatch.NextMatch;
  end;
end;

procedure AddRoutineParameter(const aParameters: TList<TDelphiSemanticParameter>;
  const aRoutineName, aName, aTypeName, aModifier, aText: string; const aNameOffset: Integer);
var
  lParameter: TDelphiSemanticParameter;
begin
  lParameter.RoutineName := aRoutineName;
  lParameter.Name := aName;
  lParameter.TypeName := aTypeName;
  lParameter.Modifier := aModifier;
  lParameter.Line := LineOfOffset(aText, aNameOffset);
  lParameter.Column := ColumnOfOffset(aText, aNameOffset);
  lParameter.Offset := aNameOffset;
  lParameter.EndOffset := aNameOffset + Length(aName);
  aParameters.Add(lParameter);
end;

function ParseParameters(const aRoutineName, aParameterText, aText: string;
  const aSignatureOffset: Integer):
  TArray<TDelphiSemanticParameter>;
var
  lMatch: TMatch;
  lName: string;
  lNameOffset: Integer;
  lNames: string;
  lNamesOffset: Integer;
  lParameter: string;
  lParameterOffset: Integer;
  lParameters: TList<TDelphiSemanticParameter>;
  lText: string;
begin
  lParameters := TList<TDelphiSemanticParameter>.Create;
  try
    lText := aParameterText.Trim;
    if (Length(lText) >= 2) and (lText[1] = '(') and (lText[Length(lText)] = ')') then
      lText := Copy(lText, 2, Length(lText) - 2);

    lParameterOffset := aSignatureOffset + Pos(lText, aParameterText) - 1;
    for lParameter in lText.Split([';']) do
    begin
      lMatch := TRegEx.Match(lParameter.Trim,
        '^(?:(const|var|out)\s+)?([A-Za-z_][A-Za-z0-9_,\s]*)\s*:\s*(.+)$',
        [roIgnoreCase]);
      if not lMatch.Success then
        lMatch := TRegEx.Match(lParameter.Trim,
          '^(?:(const|var|out)\s+)([A-Za-z_][A-Za-z0-9_,\s]*)$',
          [roIgnoreCase]);
      if lMatch.Success then
      begin
        lNames := lMatch.Groups[2].Value;
        lNamesOffset := lParameterOffset + Pos(lNames, lParameter) - 1;
        for lName in lNames.Split([',']) do
          if lName.Trim <> '' then
          begin
            lNameOffset := lNamesOffset + Pos(lName.Trim, lNames) - 1;
            AddRoutineParameter(lParameters, aRoutineName, lName.Trim,
              MatchGroupValue(lMatch, 3).Trim, lMatch.Groups[1].Value.Trim, aText, lNameOffset);
          end;
      end;
      Inc(lParameterOffset, Length(lParameter) + 1);
    end;

    Result := lParameters.ToArray;
  finally
    lParameters.Free;
  end;
end;

procedure AddParameterTypeReferences(const aReferences: TList<TDelphiSemanticReference>;
  const aRoutineName, aParameterText, aText: string; const aParameterTextOffset: Integer);
var
  lMatch: TMatch;
  lParameterText: string;
  lParameterTextOffset: Integer;
begin
  if aParameterText.Trim = '' then
    Exit;

  lParameterText := Trim(aParameterText);
  lParameterTextOffset := aParameterTextOffset + Pos(lParameterText, aParameterText) - 1;
  if (lParameterText <> '') and CharInSet(lParameterText[1], ['(', '[']) then
  begin
    Delete(lParameterText, 1, 1);
    Inc(lParameterTextOffset);
  end;
  if (lParameterText <> '') and CharInSet(lParameterText[Length(lParameterText)], [')', ']']) then
    Delete(lParameterText, Length(lParameterText), 1);

  lMatch := TRegEx.Match(lParameterText,
    '(?:(?:const|var|out)\s+)?[A-Za-z_][A-Za-z0-9_,\s]*\s*:\s*([^;\)\r\n]+)',
    [roIgnoreCase]);
  while lMatch.Success do
  begin
    AddTypeReferences(aReferences, aRoutineName, lMatch.Groups[1].Value.Trim, aText,
      lParameterTextOffset + lMatch.Groups[1].Index - 1);
    lMatch := lMatch.NextMatch;
  end;
end;

procedure AddRoutine(const aRoutines: TList<TDelphiSemanticRoutine>; const aName, aOwnerName,
  aSection, aSignature, aReturnType, aText: string; const aNameOffset, aSignatureOffset:
  Integer);
var
  lRoutine: TDelphiSemanticRoutine;
begin
  lRoutine.Name := aName;
  lRoutine.OwnerName := aOwnerName;
  lRoutine.SectionKind := aSection;
  lRoutine.Signature := aSignature;
  lRoutine.ReturnType := aReturnType.Trim;
  lRoutine.Line := LineOfOffset(aText, aNameOffset);
  lRoutine.Column := ColumnOfOffset(aText, aNameOffset);
  lRoutine.Offset := aNameOffset;
  lRoutine.EndOffset := aNameOffset + Length(aName);
  lRoutine.Parameters := ParseParameters(aName, aSignature, aText, aSignatureOffset);
  aRoutines.Add(lRoutine);
end;

function IsOffsetInsideTypeBlock(const aText: string; const aOffset: Integer): Boolean;
begin
  Result := ActiveExtractionContext.IsOffsetInsideTypeBlock(aText, aOffset);
end;

procedure ExtractRoutines(const aText: string; const aDeclarations: TList<TDelphiSemanticDeclaration>;
  const aRoutines: TList<TDelphiSemanticRoutine>;
  const aReferences: TList<TDelphiSemanticReference>);
var
  lMatch: TMatch;
  lNameOffset: Integer;
  lOwnerName: string;
  lPrefix: string;
  lRoutineName: string;
  lSection: string;
begin
  lMatch := TRegEx.Match(aText,
    '^\s*(?:class\s+)?(procedure|function)\s+((?:[A-Za-z_][A-Za-z0-9_]*\.)?)' +
    '([A-Za-z_][A-Za-z0-9_]*)\s*(\([^\r\n]*\))?\s*(?::\s*([^;\r\n]+))?\s*;',
    [roIgnoreCase, roMultiLine]);
  while lMatch.Success do
  begin
    if IsOffsetInsideTypeBlock(aText, lMatch.Index + 1) then
    begin
      lMatch := lMatch.NextMatch;
      Continue;
    end;

    lPrefix := lMatch.Groups[2].Value;
    lRoutineName := lMatch.Groups[3].Value;
    lOwnerName := lPrefix.Trim;
    if EndsText('.', lOwnerName) then
      lOwnerName := Copy(lOwnerName, 1, Length(lOwnerName) - 1);
    lNameOffset := lMatch.Index + Pos(lRoutineName, lMatch.Value) - 1;
    lSection := SectionForOffset(aText, lMatch.Index + 1);
    AddRoutine(aRoutines, lRoutineName, lOwnerName, lSection, MatchGroupValue(lMatch, 4),
      MatchGroupValue(lMatch, 5), aText, lNameOffset, MatchGroupIndex(lMatch, 4));
    AddParameterTypeReferences(aReferences, QualifiedRoutineName(lOwnerName, lRoutineName),
      MatchGroupValue(lMatch, 4), aText, MatchGroupIndex(lMatch, 4));
    AddTypeReferences(aReferences, QualifiedRoutineName(lOwnerName, lRoutineName),
      MatchGroupValue(lMatch, 5).Trim, aText, MatchGroupIndex(lMatch, 5));
    if lOwnerName = '' then
      AddDeclaration(aDeclarations, lRoutineName, 'routine', MatchGroupValue(lMatch, 5).Trim,
        lSection, aText, lNameOffset);
    lMatch := lMatch.NextMatch;
  end;
end;

procedure ExtractLocalsFromRoutine(const aText, aRoutineName, aRoutineText: string;
  const aRoutineOffset: Integer; const aLocals: TList<TDelphiSemanticLocal>;
  const aReferences: TList<TDelphiSemanticReference>);
var
  i: Integer;
  lInVarSection: Boolean;
  lLine: string;
  lLines: TStringList;
  lLocalMatch: TMatch;
  lName: string;
  lNameOffset: Integer;
  lNames: string;
  lOffset: Integer;
  lRawName: string;
begin
  lLines := TStringList.Create;
  try
    lLines.Text := aRoutineText;
    lOffset := aRoutineOffset;
    lInVarSection := False;
    for i := 0 to Pred(lLines.Count) do
    begin
      lLine := lLines[i].Trim;
      if SameText(lLine, 'var') then
        lInVarSection := True
      else if SameText(lLine, 'begin') then
        Break
      else if lInVarSection then
      begin
        lLocalMatch := TRegEx.Match(lLine, '^([A-Za-z_][A-Za-z0-9_,\s]*)\s*:\s*([^;]+);',
          [roIgnoreCase]);
        if lLocalMatch.Success then
        begin
          lNames := lLocalMatch.Groups[1].Value;
          for lRawName in lNames.Split([',']) do
          begin
            lName := lRawName.Trim;
            if lName = '' then
              Continue;
            lNameOffset := TextOffsetInLine(lLines[i], lName, lOffset);
            AddLocal(aLocals, aRoutineName, lName, 'var',
              lLocalMatch.Groups[2].Value.Trim, aText, lNameOffset);
          end;
          AddTypeReferences(aReferences, aRoutineName, lLocalMatch.Groups[2].Value.Trim, aText,
            TextOffsetInLine(lLines[i], lLocalMatch.Groups[2].Value.Trim, lOffset));
        end;
      end;
      Inc(lOffset, Length(lLines[i]) + Length(sLineBreak));
    end;
  finally
    lLines.Free;
  end;
end;

function IsReferenceKeyword(const aName: string): Boolean;
begin
  Result := MatchText(aName, ['begin', 'case', 'class', 'const', 'do', 'else', 'end', 'for',
    'function', 'if', 'implementation', 'interface', 'not', 'of', 'or', 'procedure', 'program',
    'record', 'repeat', 'then', 'type', 'unit', 'until', 'uses', 'var', 'while', 'with']);
end;

procedure ExtractReferencesFromBody(const aText, aBody: string; const aBodyOffset: Integer;
  const aRoutineName: string; const aReferences: TList<TDelphiSemanticReference>);
var
  lCleanBody: string;
  lMatch: TMatch;
begin
  lCleanBody := SanitizeCodeText(aBody);
  lMatch := TRegEx.Match(lCleanBody, '\b[A-Za-z_][A-Za-z0-9_]*\b', [roIgnoreCase]);
  while lMatch.Success do
  begin
    if not IsReferenceKeyword(lMatch.Value) then
      AddReference(aReferences, aRoutineName, lMatch.Value, aText, aBodyOffset + lMatch.Index - 1);
    lMatch := lMatch.NextMatch;
  end;
end;

procedure ExtractRoutineBodies(const aText: string; const aLocals: TList<TDelphiSemanticLocal>;
  const aReferences: TList<TDelphiSemanticReference>);
var
  i: Integer;
  lBodyBegin: Integer;
  lBodyOffset: Integer;
  lEndOffset: Integer;
  lMatch: TMatch;
  lNames: TList<string>;
  lRoutineText: string;
  lStarts: TList<Integer>;
begin
  lNames := nil;
  lStarts := nil;
  try
    lNames := TList<string>.Create;
    lStarts := TList<Integer>.Create;
    lMatch := TRegEx.Match(aText,
      '^\s*(?:class\s+)?(?:procedure|function)\s+((?:[A-Za-z_][A-Za-z0-9_]*\.)?)' +
      '([A-Za-z_][A-Za-z0-9_]*)[^;\r\n]*;',
      [roIgnoreCase, roMultiLine]);
    while lMatch.Success do
    begin
      lNames.Add(QualifiedRoutineName(MatchGroupValue(lMatch, 1).Trim.TrimRight(['.']),
        MatchGroupValue(lMatch, 2)));
      lStarts.Add(lMatch.Index);
      lMatch := lMatch.NextMatch;
    end;

    for i := 0 to Pred(lStarts.Count) do
    begin
      if i < Pred(lStarts.Count) then
        lEndOffset := lStarts[i + 1]
      else
        lEndOffset := Length(aText);

      lRoutineText := Copy(aText, lStarts[i] + 1, lEndOffset - lStarts[i]);
      ExtractLocalsFromRoutine(aText, lNames[i], lRoutineText, lStarts[i], aLocals,
        aReferences);
      lBodyBegin := Pos('begin', LowerCase(lRoutineText));
      if lBodyBegin > 0 then
      begin
        lBodyOffset := lStarts[i] + lBodyBegin - 1;
        ExtractReferencesFromBody(aText, Copy(lRoutineText, lBodyBegin, MaxInt), lBodyOffset,
          lNames[i], aReferences);
      end;
    end;
  finally
    lStarts.Free;
    lNames.Free;
  end;
end;

function FindWithStatementEndOffset(const aText: string; const aBodyStartOffset: Integer): Integer;
var
  i: Integer;
  lBlockDepth: Integer;
  lCommentMode: Integer;
  lToken: string;
begin
  if (aBodyStartOffset < 1) or (aBodyStartOffset > Length(aText)) then
    Exit(Length(aText));

  lBlockDepth := 0;
  lCommentMode := 0;
  i := aBodyStartOffset;
  while i <= Length(aText) do
  begin
    if lCommentMode = 1 then
    begin
      if (aText[i] = '*') and (i < Length(aText)) and (aText[i + 1] = ')') then
      begin
        lCommentMode := 0;
        Inc(i);
      end;
    end else if lCommentMode = 2 then
    begin
      if aText[i] = '}' then
        lCommentMode := 0;
    end else if lCommentMode = 3 then
    begin
      if CharInSet(aText[i], [#10, #13]) then
        lCommentMode := 0;
    end else if aText[i] = '''' then
    begin
      Inc(i);
      while i <= Length(aText) do
      begin
        if aText[i] = '''' then
        begin
          if (i < Length(aText)) and (aText[i + 1] = '''') then
            Inc(i)
          else
            Break;
        end;
        Inc(i);
      end;
    end else if (aText[i] = '(') and (i < Length(aText)) and (aText[i + 1] = '*') then
    begin
      lCommentMode := 1;
      Inc(i);
    end else if aText[i] = '{' then
    begin
      lCommentMode := 2;
    end else if (aText[i] = '/') and (i < Length(aText)) and (aText[i + 1] = '/') then
    begin
      lCommentMode := 3;
      Inc(i);
    end else if CharInSet(aText[i], ['A'..'Z', 'a'..'z', '_']) then
    begin
      lToken := '';
      while (i <= Length(aText)) and CharInSet(aText[i], ['A'..'Z', 'a'..'z', '0'..'9', '_']) do
      begin
        lToken := lToken + aText[i];
        Inc(i);
      end;
      Dec(i);
      if SameText(lToken, 'begin') then
      begin
        Inc(lBlockDepth);
      end else if SameText(lToken, 'end') then
      begin
        if lBlockDepth > 0 then
          Dec(lBlockDepth);
        if lBlockDepth = 0 then
        begin
          while (i <= Length(aText)) and (aText[i] <> ';') do
            Inc(i);
          if i <= Length(aText) then
            Exit(i);
          Exit(Length(aText));
        end;
      end;
    end else if (aText[i] = ';') and (lBlockDepth = 0) then
      Exit(i);
    Inc(i);
  end;

  Exit(Length(aText));
end;

procedure ExtractWithStatements(const aText: string; const aItems: TList<TDelphiSemanticWithStatement>);
var
  i: Integer;
  lBodyStartOffset: Integer;
  lCleanText: string;
  lEndOffset: Integer;
  lItem: TDelphiSemanticWithStatement;
  lMatch: TMatch;
  lSelectorParts: TArray<string>;
begin
  lCleanText := SanitizeCodeText(aText);
  lMatch := TRegEx.Match(lCleanText, '\bwith\b\s+(.*?)\s+\bdo\b', [roIgnoreCase, roSingleLine]);
  while lMatch.Success do
  begin
    lItem := Default(TDelphiSemanticWithStatement);
    lBodyStartOffset := lMatch.Index + lMatch.Length;
    lEndOffset := FindWithStatementEndOffset(aText, lBodyStartOffset);
    lItem.Line := LineOfOffset(aText, lMatch.Index);
    lItem.Column := ColumnOfOffset(aText, lMatch.Index);
    lItem.EndLine := LineOfOffset(aText, lEndOffset);
    lItem.EndColumn := ColumnOfOffset(aText, lEndOffset);
    lItem.BodyLine := LineOfOffset(aText, lBodyStartOffset);
    lItem.BodyColumn := ColumnOfOffset(aText, lBodyStartOffset);
    lItem.BodyEndLine := lItem.EndLine;
    lItem.BodyEndColumn := lItem.EndColumn;
    lItem.SelectorText := lMatch.Groups[1].Value.Trim;
    lSelectorParts := lItem.SelectorText.Split([',']);
    lItem.SelectorCount := Length(lSelectorParts);
    lItem.NestingDepth := 0;
    for i := 0 to Pred(aItems.Count) do
      if (aItems[i].Line <= lItem.Line) and (aItems[i].EndLine >= lItem.Line) and
        (aItems[i].NestingDepth >= lItem.NestingDepth) then
        lItem.NestingDepth := aItems[i].NestingDepth + 1;
    lItem.BodyText := Copy(aText, lBodyStartOffset, lEndOffset - lBodyStartOffset + 1);
    lItem.HasScopedDeclaration := TRegEx.IsMatch(lItem.BodyText,
      '^\s*(?:var|const|type)\b', [roIgnoreCase, roMultiLine]);
    lItem.Text := Copy(aText, lMatch.Index, lEndOffset - lMatch.Index + 1);
    aItems.Add(lItem);
    lMatch := lMatch.NextMatch;
  end;
end;

procedure ReconcileDeclarationCoordinates(const aSourceText: string;
  const aDeclarations: TList<TDelphiSemanticDeclaration>);
var
  i: Integer;
  lBestColumn: Integer;
  lBestDistance: Integer;
  lBestLine: Integer;
  lCandidateColumn: Integer;
  lCandidateDistance: Integer;
  lCandidateLine: Integer;
  lCandidateOffset: Integer;
  lDeclaration: TDelphiSemanticDeclaration;
  lMatch: TMatch;
begin
  for i := 0 to Pred(aDeclarations.Count) do
  begin
    lDeclaration := aDeclarations[i];
    if (lDeclaration.Offset >= 1) and (lDeclaration.Offset + Length(lDeclaration.Name) - 1 <=
      Length(aSourceText)) and SameText(Copy(aSourceText, lDeclaration.Offset,
      Length(lDeclaration.Name)), lDeclaration.Name) then
    begin
      lDeclaration.Line := LineOfOffset(aSourceText, lDeclaration.Offset);
      lDeclaration.Column := ColumnOfOffset(aSourceText, lDeclaration.Offset);
      aDeclarations[i] := lDeclaration;
      Continue;
    end;

    lBestColumn := 0;
    lBestDistance := MaxInt;
    lBestLine := 0;
    lMatch := TRegEx.Match(aSourceText, '^(\s*)' + TRegEx.Escape(lDeclaration.Name) + '\b',
      [roIgnoreCase, roMultiLine]);
    while lMatch.Success do
    begin
      lCandidateOffset := lMatch.Index + Length(lMatch.Groups[1].Value);
      lCandidateLine := LineOfOffset(aSourceText, lCandidateOffset);
      lCandidateColumn := ColumnOfOffset(aSourceText, lCandidateOffset);
      lCandidateDistance := Abs(lCandidateLine - lDeclaration.Line);
      if lCandidateDistance < lBestDistance then
      begin
        lBestDistance := lCandidateDistance;
        lBestLine := lCandidateLine;
        lBestColumn := lCandidateColumn;
        lDeclaration.Offset := lCandidateOffset;
        lDeclaration.EndOffset := lCandidateOffset + Length(lDeclaration.Name);
      end;
      lMatch := lMatch.NextMatch;
    end;
    if lBestLine > 0 then
    begin
      lDeclaration.Line := lBestLine;
      lDeclaration.Column := lBestColumn;
      aDeclarations[i] := lDeclaration;
    end;
  end;
end;

procedure ReconcileWithStatementCoordinates(const aSourceText: string;
  const aWithStatements: TList<TDelphiSemanticWithStatement>);
var
  lBestDistance: Integer;
  lBestIndex: Integer;
  lCandidateDistance: Integer;
  i: Integer;
  j: Integer;
  lItem: TDelphiSemanticWithStatement;
  lRootStatements: TList<TDelphiSemanticWithStatement>;
begin
  lRootStatements := TList<TDelphiSemanticWithStatement>.Create;
  try
    ExtractWithStatements(aSourceText, lRootStatements);
    for i := 0 to Pred(aWithStatements.Count) do
    begin
      lItem := aWithStatements[i];
      lBestDistance := MaxInt;
      lBestIndex := -1;
      for j := 0 to Pred(lRootStatements.Count) do
      begin
        if SameText(lRootStatements[j].SelectorText, lItem.SelectorText) then
        begin
          lCandidateDistance := Abs(lRootStatements[j].Line - lItem.Line);
          if lCandidateDistance < lBestDistance then
          begin
            lBestDistance := lCandidateDistance;
            lBestIndex := j;
          end;
        end;
      end;
      if lBestIndex >= 0 then
      begin
        aWithStatements[i] := lRootStatements[lBestIndex];
        lRootStatements.Delete(lBestIndex);
      end;
    end;
  finally
    lRootStatements.Free;
  end;
end;

function BuildOutputToSourceOffsetMap(const aSourceText, aOutputText: string): TArray<Integer>;
var
  i: Integer;
  j: Integer;
  lOutputLines: TStringList;
  lOutputOffset: Integer;
  lOutputLine: string;
  lSourceLines: TStringList;
  lSourceOffset: Integer;
  lSourceLine: string;
begin
  SetLength(Result, Length(aOutputText) + 1);
  lSourceLines := TStringList.Create;
  lOutputLines := TStringList.Create;
  try
    lSourceLines.Text := aSourceText;
    lOutputLines.Text := aOutputText;
    lSourceOffset := 1;
    lOutputOffset := 1;
    for i := 0 to Pred(lOutputLines.Count) do
    begin
      lOutputLine := lOutputLines[i];
      if i < lSourceLines.Count then
        lSourceLine := lSourceLines[i]
      else
        lSourceLine := '';

      if lOutputLine = lSourceLine then
        for j := 0 to Length(lOutputLine) - 1 do
          Result[lOutputOffset + j] := lSourceOffset + j;

      Inc(lSourceOffset, Length(lSourceLine) + Length(sLineBreak));
      Inc(lOutputOffset, Length(lOutputLine) + Length(sLineBreak));
    end;
  finally
    lOutputLines.Free;
    lSourceLines.Free;
  end;
end;

procedure ApplyReferenceSourceOffsetMap(const aSourceText: string; const aOffsetMap:
  TArray<Integer>; const aReferences: TList<TDelphiSemanticReference>);
var
  i: Integer;
  lMappedOffset: Integer;
  lReference: TDelphiSemanticReference;
begin
  for i := 0 to Pred(aReferences.Count) do
  begin
    lReference := aReferences[i];
    lMappedOffset := OffsetOfLineColumn(aSourceText, lReference.Line, lReference.Column);
    if ((lMappedOffset <= 0) or (lMappedOffset + Length(lReference.Name) - 1 >
      Length(aSourceText)) or not SameText(Copy(aSourceText, lMappedOffset,
      Length(lReference.Name)), lReference.Name)) and (Length(aOffsetMap) > 0) and
      (lReference.Offset > 0) and (lReference.Offset <= High(aOffsetMap)) then
      lMappedOffset := aOffsetMap[lReference.Offset];

    if (lMappedOffset <= 0) or (lMappedOffset + Length(lReference.Name) - 1 >
      Length(aSourceText)) or not SameText(Copy(aSourceText, lMappedOffset,
      Length(lReference.Name)), lReference.Name) then
      Continue;

    lReference.Offset := lMappedOffset;
    lReference.EndOffset := lMappedOffset + Length(lReference.Name);
    lReference.Line := LineOfOffset(aSourceText, lMappedOffset);
    lReference.Column := ColumnOfOffset(aSourceText, lMappedOffset);
    lReference.EndLine := lReference.Line;
    lReference.EndColumn := lReference.Column + Length(lReference.Name) - 1;
    lReference.SectionKind := SectionForOffset(aSourceText, lMappedOffset);
    aReferences[i] := lReference;
  end;
end;

function SourceRangeMatchesRoutine(const aSourceText: string;
  const aRoutine: TDelphiSemanticRoutine): Boolean;
begin
  Result := (aRoutine.Offset >= 1) and (aRoutine.Offset + Length(aRoutine.Name) - 1 <=
    Length(aSourceText)) and SameText(Copy(aSourceText, aRoutine.Offset,
    Length(aRoutine.Name)), aRoutine.Name);
end;

procedure AssignRoutineSourceRange(var aRoutine: TDelphiSemanticRoutine;
  const aSourceText: string; const aOffset: Integer);
begin
  aRoutine.Offset := aOffset;
  aRoutine.EndOffset := aOffset + Length(aRoutine.Name);
  aRoutine.Line := LineOfOffset(aSourceText, aOffset);
  aRoutine.Column := ColumnOfOffset(aSourceText, aOffset);
end;

procedure ApplyRoutineSourceOffsetMap(const aSourceText: string; const aOffsetMap:
  TArray<Integer>; const aRoutines: TList<TDelphiSemanticRoutine>);
var
  i: Integer;
  lMappedOffset: Integer;
  lRoutine: TDelphiSemanticRoutine;
begin
  for i := 0 to Pred(aRoutines.Count) do
  begin
    lRoutine := aRoutines[i];
    lMappedOffset := OffsetOfLineColumn(aSourceText, lRoutine.Line, lRoutine.Column);
    if ((lMappedOffset <= 0) or (lMappedOffset + Length(lRoutine.Name) - 1 >
      Length(aSourceText)) or not SameText(Copy(aSourceText, lMappedOffset,
      Length(lRoutine.Name)), lRoutine.Name)) and (Length(aOffsetMap) > 0) and
      (lRoutine.Offset > 0) and (lRoutine.Offset <= High(aOffsetMap)) then
      lMappedOffset := aOffsetMap[lRoutine.Offset];

    if (lMappedOffset <= 0) or (lMappedOffset + Length(lRoutine.Name) - 1 >
      Length(aSourceText)) or not SameText(Copy(aSourceText, lMappedOffset,
      Length(lRoutine.Name)), lRoutine.Name) then
      Continue;

    AssignRoutineSourceRange(lRoutine, aSourceText, lMappedOffset);
    aRoutines[i] := lRoutine;
  end;
end;

procedure ApplyDeclarationSourceOffsetMap(const aSourceText: string; const aOffsetMap:
  TArray<Integer>; const aDeclarations: TList<TDelphiSemanticDeclaration>);
var
  i: Integer;
  lDeclaration: TDelphiSemanticDeclaration;
  lMappedOffset: Integer;
begin
  for i := 0 to Pred(aDeclarations.Count) do
  begin
    lDeclaration := aDeclarations[i];
    lMappedOffset := OffsetOfLineColumn(aSourceText, lDeclaration.Line,
      lDeclaration.Column);
    if ((lMappedOffset <= 0) or (lMappedOffset + Length(lDeclaration.Name) - 1 >
      Length(aSourceText)) or not SameText(Copy(aSourceText, lMappedOffset,
      Length(lDeclaration.Name)), lDeclaration.Name)) and (Length(aOffsetMap) > 0) and
      (lDeclaration.Offset > 0) and (lDeclaration.Offset <= High(aOffsetMap)) then
      lMappedOffset := aOffsetMap[lDeclaration.Offset];

    if (lMappedOffset <= 0) or (lMappedOffset + Length(lDeclaration.Name) - 1 >
      Length(aSourceText)) or not SameText(Copy(aSourceText, lMappedOffset,
      Length(lDeclaration.Name)), lDeclaration.Name) then
      Continue;

    lDeclaration.Offset := lMappedOffset;
    lDeclaration.EndOffset := lMappedOffset + Length(lDeclaration.Name);
    lDeclaration.Line := LineOfOffset(aSourceText, lMappedOffset);
    lDeclaration.Column := ColumnOfOffset(aSourceText, lMappedOffset);
    aDeclarations[i] := lDeclaration;
  end;
end;

procedure ApplyMemberSourceOffsetMap(const aSourceText: string; const aOffsetMap:
  TArray<Integer>; const aMembers: TList<TDelphiSemanticMember>);
var
  i: Integer;
  lMappedOffset: Integer;
  lMember: TDelphiSemanticMember;
begin
  for i := 0 to Pred(aMembers.Count) do
  begin
    lMember := aMembers[i];
    lMappedOffset := OffsetOfLineColumn(aSourceText, lMember.Line, lMember.Column);
    if ((lMappedOffset <= 0) or (lMappedOffset + Length(lMember.Name) - 1 >
      Length(aSourceText)) or not SameText(Copy(aSourceText, lMappedOffset,
      Length(lMember.Name)), lMember.Name)) and (Length(aOffsetMap) > 0) and
      (lMember.Offset > 0) and (lMember.Offset <= High(aOffsetMap)) then
      lMappedOffset := aOffsetMap[lMember.Offset];

    if (lMappedOffset <= 0) or (lMappedOffset + Length(lMember.Name) - 1 >
      Length(aSourceText)) or not SameText(Copy(aSourceText, lMappedOffset,
      Length(lMember.Name)), lMember.Name) then
      Continue;

    lMember.Offset := lMappedOffset;
    lMember.EndOffset := lMappedOffset + Length(lMember.Name);
    lMember.Line := LineOfOffset(aSourceText, lMappedOffset);
    lMember.Column := ColumnOfOffset(aSourceText, lMappedOffset);
    aMembers[i] := lMember;
  end;
end;

procedure ApplyLocalSourceOffsetMap(const aSourceText: string; const aOffsetMap:
  TArray<Integer>; const aLocals: TList<TDelphiSemanticLocal>);
var
  i: Integer;
  lLocal: TDelphiSemanticLocal;
  lMappedOffset: Integer;
begin
  for i := 0 to Pred(aLocals.Count) do
  begin
    lLocal := aLocals[i];
    lMappedOffset := OffsetOfLineColumn(aSourceText, lLocal.Line, lLocal.Column);
    if ((lMappedOffset <= 0) or (lMappedOffset + Length(lLocal.Name) - 1 >
      Length(aSourceText)) or not SameText(Copy(aSourceText, lMappedOffset,
      Length(lLocal.Name)), lLocal.Name)) and (Length(aOffsetMap) > 0) and
      (lLocal.Offset > 0) and (lLocal.Offset <= High(aOffsetMap)) then
      lMappedOffset := aOffsetMap[lLocal.Offset];

    if (lMappedOffset <= 0) or (lMappedOffset + Length(lLocal.Name) - 1 >
      Length(aSourceText)) or not SameText(Copy(aSourceText, lMappedOffset,
      Length(lLocal.Name)), lLocal.Name) then
      Continue;

    lLocal.Offset := lMappedOffset;
    lLocal.EndOffset := lMappedOffset + Length(lLocal.Name);
    lLocal.Line := LineOfOffset(aSourceText, lMappedOffset);
    lLocal.Column := ColumnOfOffset(aSourceText, lMappedOffset);
    aLocals[i] := lLocal;
  end;
end;

procedure ReconcileReferencesCoordinates(const aSourceText: string;
  const aReferences: TList<TDelphiSemanticReference>; var aMetrics:
  TDelphiSemanticUnitModelMetrics);
var
  i: Integer;
  lBestColumn: Integer;
  lBestDistance: Integer;
  lBestLine: Integer;
  lBestOffset: Integer;
  lCandidateColumn: Integer;
  lCandidateDistance: Integer;
  lCandidateLine: Integer;
  lCandidateOffset: Integer;
  lCandidate: TReferenceCoordinateCandidate;
  lCandidates: TReferenceCandidateList;
  lCleanText: string;
  lOccurrenceIndex: TReferenceOccurrenceIndex;
  lReference: TDelphiSemanticReference;

  function SourceTextMatchesReference(const aOffset: Integer;
    const aReference: TDelphiSemanticReference): Boolean;
  begin
    Result := (aOffset >= 1) and (aOffset + Length(aReference.Name) - 1 <=
      Length(aSourceText)) and SameText(Copy(aSourceText, aOffset, Length(aReference.Name)),
      aReference.Name);
  end;

  function SourceRangeMatchesReference(const aOffset: Integer;
    const aReference: TDelphiSemanticReference): Boolean;
  begin
    Result := SourceTextMatchesReference(aOffset, aReference) and
      (LineOfOffset(aSourceText, aOffset) = aReference.Line) and
      (ColumnOfOffset(aSourceText, aOffset) = aReference.Column);
  end;

  function BuildReferenceOccurrenceIndex: TReferenceOccurrenceIndex;
  var
    i: Integer;
    lCandidate: TReferenceCoordinateCandidate;
    lKey: string;
    lList: TReferenceCandidateList;
    lName: string;
    lStartOffset: Integer;
  begin
    Result := TReferenceOccurrenceIndex.Create([doOwnsValues]);
    Inc(aMetrics.ReferenceOccurrenceTableBuildCount);
    i := 1;
    while i <= Length(lCleanText) do
    begin
      if CharInSet(lCleanText[i], ['A'..'Z', 'a'..'z', '_']) then
      begin
        lStartOffset := i;
        Inc(i);
        while (i <= Length(lCleanText)) and IsIdentifierChar(lCleanText[i]) do
          Inc(i);
        lName := Copy(lCleanText, lStartOffset, i - lStartOffset);
        lKey := LowerCase(lName);
        if not Result.TryGetValue(lKey, lList) then
        begin
          lList := TReferenceCandidateList.Create;
          Result.Add(lKey, lList);
        end;
        lCandidate.Offset := lStartOffset;
        lCandidate.Line := LineOfOffset(lCleanText, lStartOffset);
        lCandidate.Column := ColumnOfOffset(lCleanText, lStartOffset);
        lList.Add(lCandidate);
      end else
        Inc(i);
    end;
  end;

  function CandidatesForName(const aName: string): TReferenceCandidateList;
  var
    lKey: string;
  begin
    if lOccurrenceIndex = nil then
      lOccurrenceIndex := BuildReferenceOccurrenceIndex;

    lKey := LowerCase(aName);
    if lOccurrenceIndex.TryGetValue(lKey, Result) then
      Exit;

    Result := nil;
  end;

  procedure AssignReferenceSourceRange(var aReference: TDelphiSemanticReference;
    const aOffset: Integer);
  begin
    aReference.Line := LineOfOffset(aSourceText, aOffset);
    aReference.Column := ColumnOfOffset(aSourceText, aOffset);
    aReference.Offset := aOffset;
    aReference.EndOffset := aOffset + Length(aReference.Name);
    aReference.EndLine := aReference.Line;
    aReference.EndColumn := aReference.Column + Length(aReference.Name) - 1;
  end;
begin
  lCleanText := SanitizeCodeText(aSourceText);
  lOccurrenceIndex := nil;
  try
    for i := 0 to Pred(aReferences.Count) do
    begin
      lReference := aReferences[i];
      if SourceRangeMatchesReference(lReference.Offset, lReference) then
      begin
        AssignReferenceSourceRange(lReference, lReference.Offset);
        aReferences[i] := lReference;
        Continue;
      end;

      Inc(aMetrics.ReferenceReconciliationFallbackCount);
      lBestColumn := 0;
      lBestDistance := MaxInt;
      lBestLine := 0;
      lBestOffset := 0;
      lCandidates := CandidatesForName(lReference.Name);
      if lCandidates <> nil then
        for lCandidate in lCandidates do
        begin
          lCandidateOffset := lCandidate.Offset;
          lCandidateLine := lCandidate.Line;
          lCandidateColumn := lCandidate.Column;
          lCandidateDistance := Abs(lCandidateLine - lReference.Line) * 10000 +
            Abs(lCandidateColumn - lReference.Column);
          if lCandidateDistance < lBestDistance then
          begin
            lBestDistance := lCandidateDistance;
            lBestLine := lCandidateLine;
            lBestColumn := lCandidateColumn;
            lBestOffset := lCandidateOffset;
          end;
        end;
      if lBestLine > 0 then
      begin
        AssignReferenceSourceRange(lReference, lBestOffset);
        aReferences[i] := lReference;
      end;
    end;
  finally
    lOccurrenceIndex.Free;
  end;
end;

procedure ReconcileMemberCoordinates(const aSourceText: string;
  const aMembers: TList<TDelphiSemanticMember>);
var
  i: Integer;
  lBestColumn: Integer;
  lBestDistance: Integer;
  lBestLine: Integer;
  lCandidateColumn: Integer;
  lCandidateDistance: Integer;
  lCandidateLine: Integer;
  lCandidateOffset: Integer;
  lCleanText: string;
  lMatch: TMatch;
  lMember: TDelphiSemanticMember;
begin
  lCleanText := '';
  for i := 0 to Pred(aMembers.Count) do
  begin
    lMember := aMembers[i];
    if (lMember.Offset >= 1) and (lMember.Offset + Length(lMember.Name) - 1 <=
      Length(aSourceText)) and SameText(Copy(aSourceText, lMember.Offset,
      Length(lMember.Name)), lMember.Name) then
    begin
      lMember.Line := LineOfOffset(aSourceText, lMember.Offset);
      lMember.Column := ColumnOfOffset(aSourceText, lMember.Offset);
      aMembers[i] := lMember;
      Continue;
    end;

    lBestColumn := 0;
    lBestDistance := MaxInt;
    lBestLine := 0;
    if lCleanText = '' then
      lCleanText := SanitizeCodeText(aSourceText);
    lMatch := TRegEx.Match(lCleanText,
      '^(\s*(?:(?:property|procedure|function|constructor|destructor)\s+)?)' +
      TRegEx.Escape(lMember.Name) + '\b', [roIgnoreCase, roMultiLine]);
    while lMatch.Success do
    begin
      lCandidateOffset := lMatch.Index + Length(lMatch.Groups[1].Value);
      lCandidateLine := LineOfOffset(lCleanText, lCandidateOffset);
      lCandidateColumn := ColumnOfOffset(lCleanText, lCandidateOffset);
      lCandidateDistance := Abs(lCandidateLine - lMember.Line);
      if lCandidateDistance < lBestDistance then
      begin
        lBestDistance := lCandidateDistance;
        lBestLine := lCandidateLine;
        lBestColumn := lCandidateColumn;
        lMember.Offset := lCandidateOffset;
        lMember.EndOffset := lCandidateOffset + Length(lMember.Name);
      end;
      lMatch := lMatch.NextMatch;
    end;
    if lBestLine > 0 then
    begin
      lMember.Line := lBestLine;
      lMember.Column := lBestColumn;
      aMembers[i] := lMember;
    end;
  end;
end;

procedure ReconcileRoutineCoordinates(const aSourceText: string;
  const aRoutines: TList<TDelphiSemanticRoutine>);
var
  i: Integer;
  lBestColumn: Integer;
  lBestDistance: Integer;
  lBestLine: Integer;
  lCandidateColumn: Integer;
  lCandidateDistance: Integer;
  lCandidateLine: Integer;
  lCandidateOffset: Integer;
  lCleanText: string;
  lMatch: TMatch;
  lRoutine: TDelphiSemanticRoutine;
begin
  lCleanText := '';
  for i := 0 to Pred(aRoutines.Count) do
  begin
    lRoutine := aRoutines[i];
    if SourceRangeMatchesRoutine(aSourceText, lRoutine) then
    begin
      AssignRoutineSourceRange(lRoutine, aSourceText, lRoutine.Offset);
      aRoutines[i] := lRoutine;
      Continue;
    end;

    lBestColumn := 0;
    lBestDistance := MaxInt;
    lBestLine := 0;
    if lCleanText = '' then
      lCleanText := SanitizeCodeText(aSourceText);
    lMatch := TRegEx.Match(lCleanText,
      '^\s*(?:class\s+)?(?:procedure|function)\s+(?:[A-Za-z_][A-Za-z0-9_]*\.)?' +
      TRegEx.Escape(lRoutine.Name) + '\b', [roIgnoreCase, roMultiLine]);
    while lMatch.Success do
    begin
      lCandidateOffset := lMatch.Index + Pos(lRoutine.Name, lMatch.Value) - 1;
      lCandidateLine := LineOfOffset(lCleanText, lCandidateOffset);
      lCandidateColumn := ColumnOfOffset(lCleanText, lCandidateOffset);
      lCandidateDistance := Abs(lCandidateLine - lRoutine.Line);
      if lCandidateDistance < lBestDistance then
      begin
        lBestDistance := lCandidateDistance;
        lBestLine := lCandidateLine;
        lBestColumn := lCandidateColumn;
        lRoutine.Offset := lCandidateOffset;
        lRoutine.EndOffset := lCandidateOffset + Length(lRoutine.Name);
      end;
      lMatch := lMatch.NextMatch;
    end;
    if lBestLine > 0 then
    begin
      lRoutine.Line := lBestLine;
      lRoutine.Column := lBestColumn;
      aRoutines[i] := lRoutine;
    end;
  end;
end;

procedure ReconcileLocalCoordinates(const aSourceText: string;
  const aLocals: TList<TDelphiSemanticLocal>);
var
  i: Integer;
  lBestColumn: Integer;
  lBestDistance: Integer;
  lBestLine: Integer;
  lCandidateColumn: Integer;
  lCandidateDistance: Integer;
  lCandidateLine: Integer;
  lCandidateOffset: Integer;
  lCleanText: string;
  lLocal: TDelphiSemanticLocal;
  lMatch: TMatch;
begin
  lCleanText := '';
  for i := 0 to Pred(aLocals.Count) do
  begin
    lLocal := aLocals[i];
    if (lLocal.Offset >= 1) and (lLocal.Offset + Length(lLocal.Name) - 1 <=
      Length(aSourceText)) and SameText(Copy(aSourceText, lLocal.Offset,
      Length(lLocal.Name)), lLocal.Name) then
    begin
      lLocal.Line := LineOfOffset(aSourceText, lLocal.Offset);
      lLocal.Column := ColumnOfOffset(aSourceText, lLocal.Offset);
      aLocals[i] := lLocal;
      Continue;
    end;

    lBestColumn := 0;
    lBestDistance := MaxInt;
    lBestLine := 0;
    if lCleanText = '' then
      lCleanText := SanitizeCodeText(aSourceText);
    lMatch := TRegEx.Match(lCleanText, '^(\s*)' + TRegEx.Escape(lLocal.Name) + '\b\s*:',
      [roIgnoreCase, roMultiLine]);
    while lMatch.Success do
    begin
      lCandidateOffset := lMatch.Index + Length(lMatch.Groups[1].Value);
      lCandidateLine := LineOfOffset(lCleanText, lCandidateOffset);
      lCandidateColumn := ColumnOfOffset(lCleanText, lCandidateOffset);
      lCandidateDistance := Abs(lCandidateLine - lLocal.Line);
      if lCandidateDistance < lBestDistance then
      begin
        lBestDistance := lCandidateDistance;
        lBestLine := lCandidateLine;
        lBestColumn := lCandidateColumn;
        lLocal.Offset := lCandidateOffset;
        lLocal.EndOffset := lCandidateOffset + Length(lLocal.Name);
      end;
      lMatch := lMatch.NextMatch;
    end;
    if lBestLine > 0 then
    begin
      lLocal.Line := lBestLine;
      lLocal.Column := lBestColumn;
      aLocals[i] := lLocal;
    end;
  end;
end;

procedure AssignModelArrays(var aModel: TDelphiSemanticUnitModel;
  const aDiagnostics: TList<TDelphiSemanticModelDiagnostic>; const aInterfaceUses,
  aImplementationUses: TList<string>; const aDeclarations: TList<TDelphiSemanticDeclaration>;
  const aMembers: TList<TDelphiSemanticMember>; const aRoutines: TList<TDelphiSemanticRoutine>;
  const aLocals: TList<TDelphiSemanticLocal>; const aReferences: TList<TDelphiSemanticReference>;
  const aWithStatements: TList<TDelphiSemanticWithStatement>);
begin
  aModel.InterfaceUses := aInterfaceUses.ToArray;
  aModel.ImplementationUses := aImplementationUses.ToArray;
  aModel.Declarations := aDeclarations.ToArray;
  aModel.Members := aMembers.ToArray;
  aModel.Routines := aRoutines.ToArray;
  aModel.Locals := aLocals.ToArray;
  aModel.References := aReferences.ToArray;
  aModel.WithStatements := aWithStatements.ToArray;
  aModel.Diagnostics := aDiagnostics.ToArray;
end;

class function TDelphiSemanticUnitModelExtractor.ExtractFromFile(
  const aOptions: TDelphiSemanticModelOptions): TDelphiSemanticUnitModel;
var
  lDeclarations: TList<TDelphiSemanticDeclaration>;
  lExtractionContext: TDelphiSemanticExtractionContext;
  lDiagnostics: TList<TDelphiSemanticModelDiagnostic>;
  lImplementationUses: TList<string>;
  lInterfaceUses: TList<string>;
  lLocals: TList<TDelphiSemanticLocal>;
  lMatch: TMatch;
  lMembers: TList<TDelphiSemanticMember>;
  lOffsetMap: TArray<Integer>;
  lPreprocessOptions: TDelphiSemanticPreprocessOptions;
  lPreprocessResult: TDelphiSemanticPreprocessResult;
  lReferenceSink: TList<TDelphiSemanticReference>;
  lReferences: TList<TDelphiSemanticReference>;
  lRoutines: TList<TDelphiSemanticRoutine>;
  lSourceResult: TDelphiSemanticSourceLoadResult;
  lText: string;
  lPreviousExtractionContext: TDelphiSemanticExtractionContext;
  lWithStatements: TList<TDelphiSemanticWithStatement>;
begin
  Result := Default(TDelphiSemanticUnitModel);
  lExtractionContext := nil;
  lDiagnostics := nil;
  lInterfaceUses := nil;
  lImplementationUses := nil;
  lDeclarations := nil;
  lMembers := nil;
  lRoutines := nil;
  lLocals := nil;
  lReferences := nil;
  lWithStatements := nil;
  lPreviousExtractionContext := GExtractionContext;
  lExtractionContext := TDelphiSemanticExtractionContext.Create;
  GExtractionContext := lExtractionContext;
  try
    lDiagnostics := TList<TDelphiSemanticModelDiagnostic>.Create;
    lInterfaceUses := TList<string>.Create;
    lImplementationUses := TList<string>.Create;
    lDeclarations := TList<TDelphiSemanticDeclaration>.Create;
    lMembers := TList<TDelphiSemanticMember>.Create;
    lRoutines := TList<TDelphiSemanticRoutine>.Create;
    lLocals := TList<TDelphiSemanticLocal>.Create;
    lReferences := TList<TDelphiSemanticReference>.Create;
    lWithStatements := TList<TDelphiSemanticWithStatement>.Create;

    lSourceResult := TDelphiSemanticSourceLoader.LoadFile(aOptions.SourceFileName);
    Result.Success := lSourceResult.Success;
    Result.FileName := lSourceResult.Source.FileName;
    Result.SourceText := lSourceResult.Source.Text;
    if not lSourceResult.Success then
    begin
      AddSourceDiagnostics(lDiagnostics, lSourceResult.Diagnostics);
      AssignModelArrays(Result, lDiagnostics, lInterfaceUses, lImplementationUses, lDeclarations,
        lMembers, lRoutines, lLocals, lReferences, lWithStatements);
      Exit;
    end;

    lPreprocessOptions := Default(TDelphiSemanticPreprocessOptions);
    lPreprocessOptions.SourceFileName := aOptions.SourceFileName;
    lPreprocessOptions.SourceText := lSourceResult.Source.Text;
    lPreprocessOptions.Defines := aOptions.Defines;
    lPreprocessOptions.SearchPaths := aOptions.SearchPaths;
    lPreprocessResult := TDelphiSemanticPreprocessor.PreprocessFile(lPreprocessOptions);
    Result.Success := lPreprocessResult.Success;
    AddPreprocessDiagnostics(lDiagnostics, lPreprocessResult.Diagnostics);
    lText := lPreprocessResult.OutputText;
    if lText = '' then
      lText := lSourceResult.Source.Text;
    if (lText <> '') and (lText[1] = #$FEFF) then
      Delete(lText, 1, 1);

    if not aOptions.ProjectContextApplied then
      AddDiagnostic(lDiagnostics, 'NO_PROJECT_CONTEXT',
        'No full project/compiler context was applied.', aOptions.SourceFileName, 0);

    Result.FileName := lSourceResult.Source.FileName;
    Result.EncodingName := lSourceResult.Source.EncodingName;
    Result.SourceSections := BuildSourceSections(lSourceResult.Source.Text);
    lMatch := TRegEx.Match(lText, '^\s*unit\s+([A-Za-z_][A-Za-z0-9_\.]*)\s*;',
      [roIgnoreCase, roMultiLine]);
    if lMatch.Success then
      Result.UnitName := lMatch.Groups[1].Value;

    if aOptions.WithStatementsOnly then
    begin
      ExtractWithStatements(lText, lWithStatements);
      ReconcileWithStatementCoordinates(lSourceResult.Source.Text, lWithStatements);
      AssignModelArrays(Result, lDiagnostics, lInterfaceUses, lImplementationUses, lDeclarations,
        lMembers, lRoutines, lLocals, lReferences, lWithStatements);
      Exit;
    end;

    ExtractUses(lText, lInterfaceUses, lImplementationUses);
    ExtractContains(lText, lImplementationUses);
    lReferenceSink := lReferences;
    if aOptions.SkipReferenceExtraction then
      lReferenceSink := nil;
    ExtractTypeDeclarations(lText, lDeclarations, lReferenceSink);
    ExtractConstVarDeclarations(lText, Result.UnitName, lDeclarations, lMembers,
      lReferenceSink);
    ExtractMembers(lText, lDeclarations, lMembers, lReferenceSink);
    ExtractRoutines(lText, lDeclarations, lRoutines, lReferenceSink);
    if not aOptions.SkipBodyAnalysis then
    begin
      ExtractRoutineBodies(lText, lLocals, lReferenceSink);
      ExtractWithStatements(lText, lWithStatements);
    end;
    lOffsetMap := BuildOutputToSourceOffsetMap(lSourceResult.Source.Text, lText);
    if lReferences.Count > 0 then
      ApplyReferenceSourceOffsetMap(lSourceResult.Source.Text, lOffsetMap, lReferences);
    ApplyRoutineSourceOffsetMap(lSourceResult.Source.Text, lOffsetMap, lRoutines);
    ApplyDeclarationSourceOffsetMap(lSourceResult.Source.Text, lOffsetMap, lDeclarations);
    ApplyMemberSourceOffsetMap(lSourceResult.Source.Text, lOffsetMap, lMembers);
    ApplyLocalSourceOffsetMap(lSourceResult.Source.Text, lOffsetMap, lLocals);
    ReconcileDeclarationCoordinates(lSourceResult.Source.Text, lDeclarations);
    ReconcileWithStatementCoordinates(lSourceResult.Source.Text, lWithStatements);
    if lReferences.Count > 0 then
      ReconcileReferencesCoordinates(lSourceResult.Source.Text, lReferences, Result.Metrics);
    ReconcileMemberCoordinates(lSourceResult.Source.Text, lMembers);
    ReconcileRoutineCoordinates(lSourceResult.Source.Text, lRoutines);
    ReconcileLocalCoordinates(lSourceResult.Source.Text, lLocals);

    AssignModelArrays(Result, lDiagnostics, lInterfaceUses, lImplementationUses, lDeclarations,
      lMembers, lRoutines, lLocals, lReferences, lWithStatements);
  finally
    GExtractionContext := lPreviousExtractionContext;
    lExtractionContext.Free;
    lWithStatements.Free;
    lReferences.Free;
    lLocals.Free;
    lRoutines.Free;
    lMembers.Free;
    lDeclarations.Free;
    lImplementationUses.Free;
    lInterfaceUses.Free;
    lDiagnostics.Free;
  end;
end;

class function TDelphiSemanticUnitModelExtractor.TypeBlockAnalysisBuildCount: Integer;
begin
  Result := TInterlocked.CompareExchange(GTypeBlockAnalysisBuildCount, 0, 0);
end;

class procedure TDelphiSemanticUnitModelExtractor.ResetTypeBlockAnalysisBuildCount;
begin
  TInterlocked.Exchange(GTypeBlockAnalysisBuildCount, 0);
  if Assigned(GExtractionContext) then
    GExtractionContext.ResetTypeBlockRanges;
end;

end.
