unit DelphiSemantics.Model.Extract;

interface

uses
  DelphiSemantics.Model;

type
  TDelphiSemanticUnitModelExtractorImpl = record
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
  DelphiAST, DelphiAST.Classes, DelphiAST.Consts, SimpleParser.Lexer, SimpleParser.Lexer.Types,
  DelphiSemantics.Model.Coordinates, DelphiSemantics.Model.Text,
  DelphiSemantics.Preprocess, DelphiSemantics.Source, DelphiSemantics.SourceConditionals;

type
  TOffsetRange = record
    StartOffset: Integer;
    EndOffset: Integer;
  end;

  TSemanticSyntaxTreeBuilder = class(TPasSyntaxTreeBuilder)
  protected
    procedure ClassForward; override;
    procedure InterfaceForward; override;
    procedure DispInterfaceForward; override;
    procedure ProceduralDirectiveOf; override;
    procedure LabeledStatement; override;
  end;

  TRoutineHeader = record
    Signature: string;
    SignatureOffset: Integer;
    ReturnType: string;
    ReturnTypeOffset: Integer;
  end;

  TWritableConstantSwitch = record
    EndOffset: Integer;
    Enabled: Boolean;
  end;

  TAstDeclarationScopeFact = record
    Name: string;
    Kind: string;
    InterfaceGuid: string;
    AstHelperKind: string;
    HelperTargetName: string;
    IsHelper: Boolean;
    HelperCovered: Boolean;
    ProcedureSignature: TDelphiSemanticProcedureSignature;
    IsDispInterface: Boolean;
    IsForward: Boolean;
    ScopedEnum: Boolean;
    EnumTypeName: string;
    TypeOwnerPath: string;
    Line: Integer;
    Column: Integer;
    ScopeIndex: Integer;
  end;

  TAstRoutineScope = record
    Name: string;
    ScopeId: string;
    ParentScopeId: string;
    SemanticSignature: string;
    CallingConvention: string;
    ProcedureSignature: TDelphiSemanticProcedureSignature;
    StartLine: Integer;
    StartColumn: Integer;
    EndLine: Integer;
    EndColumn: Integer;
    Depth: Integer;
    ParentIndex: Integer;
    // The begin/asm block of an implemented routine; headers without a body have none.
    HasBody: Boolean;
    Body: TOffsetRange;
  end;

  TTypeMemberActivityRange = record
    Range: TOffsetRange;
    StartLine: Integer;
    EndLine: Integer;
    EndColumn: Integer;
    FileName: string;
    OwnerName: string;
    DeclarationIndex: Integer;
  end;

  TDelphiSemanticExtractionContext = class
  private
    fLineCacheLength: Integer;
    fLineCacheStarts: TArray<Integer>;
    fLineCacheText: string;
    fSectionCache: TDelphiSemanticSourceSections;
    fSectionCacheLength: Integer;
    fSectionCacheText: string;
    fTypeBlockRanges: TArray<TOffsetRange>;
    fTypeMemberActivityRanges: TArray<TTypeMemberActivityRange>;
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
    procedure RecordTypeMemberActivity(const aRange: TTypeMemberActivityRange);
    procedure PublishTypeBodyRanges(const aPreprocess: TDelphiSemanticPreprocessResult;
      const aDeclarations: TList<TDelphiSemanticDeclaration>);
    procedure PublishTypeMemberActivity(const aModel: TDelphiSemanticUnitModel;
      const aPreprocess: TDelphiSemanticPreprocessResult; const aOffsetMap: TArray<Integer>;
      const aDeclarations: TList<TDelphiSemanticDeclaration>;
      const aDiagnostics: TList<TDelphiSemanticModelDiagnostic>);
    function SectionForOffset(const aText: string; const aOffset: Integer): string;
  end;

var
  GTypeBlockAnalysisBuildCount: Integer = 0;

threadvar
  GExtractionContext: TDelphiSemanticExtractionContext;

procedure ExtractMembers(const aText, aFileName: string; const aNode: TSyntaxNode;
  const aDiagnostics: TList<TDelphiSemanticModelDiagnostic>;
  const aDeclarations: TList<TDelphiSemanticDeclaration>;
  const aMembers: TList<TDelphiSemanticMember>;
  const aReferences: TList<TDelphiSemanticReference>); forward;
function ExtractFallbackMembers(const aText: string;
  const aDeclarations: TList<TDelphiSemanticDeclaration>;
  const aMembers: TList<TDelphiSemanticMember>;
  const aReferences: TList<TDelphiSemanticReference>;
  out aOmittedClassVariables: Integer): Integer; forward;
function ActiveExtractionContext: TDelphiSemanticExtractionContext; forward;
function BuildTypeBlockRanges(const aText: string): TArray<TOffsetRange>; forward;

function BuildSourceSections(const aText: string): TDelphiSemanticSourceSections;
var
  lText: string;
begin
  Result := Default(TDelphiSemanticSourceSections);
  lText := aText;
  if (lText <> '') and (lText[1] = #$FEFF) then
    Delete(lText, 1, 1);
  Result.InterfaceOffset := FindSectionKeywordOffset(lText, 'interface');
  Result.ImplementationOffset := FindSectionKeywordOffset(lText, 'implementation');
  Result.InitializationOffset := FindSectionKeywordOffset(lText, 'initialization');
  Result.FinalizationOffset := FindSectionKeywordOffset(lText, 'finalization');
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

const
  // DS-659: preprocessed lines could not be traced to their files, so no fact is verified.
  cIncludeLineMapFailedStatus = 'include-line-map-failed';

// The preprocessor ends every output line with a line break.
function OutputLineCount(const aOutputText: string): Integer;
var
  i: Integer;
begin
  Result := 0;
  for i := 1 to Length(aOutputText) do
    if aOutputText[i] = #10 then
      Inc(Result);
  if (aOutputText <> '') and (aOutputText[Length(aOutputText)] <> #10) then
    Inc(Result);
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

procedure ConsumeTypeKeyword(var aLine, aBlockKind: string);
var
  lMatch: TMatch;
begin
  if not StartsText('type', aLine) then
    Exit;
  lMatch := TRegEx.Match(aLine, '^type\b\s*', [roIgnoreCase]);
  if not lMatch.Success then
    Exit;
  aBlockKind := 'type';
  Delete(aLine, 1, lMatch.Length);
end;

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
      ConsumeTypeKeyword(lScopeLine, lBlockKind);
      if lTypeDepth > 0 then
      begin
        lRange.StartOffset := lOffset + 1;
        lRange.EndOffset := lOffset + Length(lLines[i]) + 1;
        lRanges.Add(lRange);
      end;

      if (lTypeDepth > 0) and SameText(lScopeLine, 'end;') then
      begin
        Dec(lTypeDepth);
        // A nested const/var section ends with its type, not the enclosing type section.
        lBlockKind := 'type';
      end else if SameText(lScopeLine, 'interface') or SameText(lScopeLine, 'implementation') then
      begin
        lBlockKind := '';
        lTypeDepth := 0;
      end else if SameText(lScopeLine, 'const') or SameText(lScopeLine, 'var') then
      begin
        lBlockKind := '';
      end else if lBlockKind = 'type' then
      begin
        lTypeMatch := TRegEx.Match(lScopeLine, '^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*([^;\r\n]+)',
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

function AstNodeName(const aNode: TSyntaxNode): string;
var
  lChild: TSyntaxNode;
begin
  Result := '';
  if not Assigned(aNode) then
    Exit;
  if aNode.HasAttribute(anName) then
    Exit(aNode.GetAttribute(anName));

  for lChild in aNode.ChildNodes do
    if (lChild.Typ = ntName) and (lChild is TValuedSyntaxNode) then
      Exit(TValuedSyntaxNode(lChild).Value);
end;

// Overloads may differ only inside a type (open-array element, generic arguments),
// so the scope key renders the whole parameter type tree, not just its head name.
function AstTypeText(const aTypeNode: TSyntaxNode): string;
var
  lArgument: TSyntaxNode;
  lArguments: string;
  lChild: TSyntaxNode;
begin
  Result := LowerCase(aTypeNode.GetAttribute(anName));
  if aTypeNode.HasAttribute(anType) then
    Result := Trim(LowerCase(aTypeNode.GetAttribute(anType)) + ' ' + Result);
  for lChild in aTypeNode.ChildNodes do
    if lChild.Typ = ntType then
      Result := Result + ' of ' + AstTypeText(lChild)
    else if lChild.Typ = ntTypeArgs then
    begin
      lArguments := '';
      for lArgument in lChild.ChildNodes do
        if lArgument.Typ = ntType then
        begin
          if lArguments <> '' then
            lArguments := lArguments + ',';
          lArguments := lArguments + AstTypeText(lArgument);
        end;
      Result := Result + '<' + lArguments + '>';
    end;
end;

function AstMethodSignature(const aNode: TSyntaxNode): string;
var
  lBuilder: TStringBuilder;
  lChild: TSyntaxNode;
  lParameter: TSyntaxNode;
  lParameters: TSyntaxNode;
  lTypeNode: TSyntaxNode;
begin
  lBuilder := TStringBuilder.Create;
  try
    lParameters := nil;
    for lChild in aNode.ChildNodes do
      if lChild.Typ = ntParameters then
      begin
        lParameters := lChild;
        Break;
      end;
    if Assigned(lParameters) then
      for lParameter in lParameters.ChildNodes do
        if lParameter.Typ = ntParameter then
        begin
          if lBuilder.Length > 0 then
            lBuilder.Append(';');
          if lParameter.HasAttribute(anKind) then
            lBuilder.Append(LowerCase(lParameter.GetAttribute(anKind))).Append(':');
          lTypeNode := lParameter.FindNode(ntType);
          if Assigned(lTypeNode) then
            lBuilder.Append(AstTypeText(lTypeNode));
        end;
    Result := lBuilder.ToString;
  finally
    lBuilder.Free;
  end;
end;

function AstScopeId(const aUnitName, aParentScopeId: string;
  const aNode: TSyntaxNode): string;
begin
  Result := LowerCase(aUnitName) + '|';
  if aParentScopeId <> '' then
    Result := aParentScopeId + '/';
  Result := Result + LowerCase(AstNodeName(aNode)) + '(' +
    AstMethodSignature(aNode) + ')';
end;

function TryReadRoutineHeader(const aText: string; const aLexer: TmwBasePasLex;
  var aNextMatch: TMatch; out aHeader: TRoutineHeader): Boolean; forward;

// Read the source again at the lexical name matched to exactly one AST method.
function TryReadMatchedSourceHeader(const aText: string;
  const aRoutine: TDelphiSemanticRoutine; out aHeader: TRoutineHeader): Boolean;
var
  lLexer: TmwBasePasLex;
  lNextMatch: TMatch;
begin
  Result := False;
  aHeader := Default(TRoutineHeader);
  if (aRoutine.Offset < 1) or (aRoutine.Offset > Length(aText)) then
    Exit;
  lLexer := TmwBasePasLex.Create;
  try
    lLexer.UseDefines := False;
    lLexer.Origin := aText;
    lLexer.RunPos := aRoutine.Offset - 1;
    if (lLexer.TokenPos + 1 <> aRoutine.Offset) or
      not SameText(lLexer.Token, aRoutine.Name) then
      Exit;
    lLexer.NextNoJunk;
    lNextMatch := Default(TMatch);
    Result := TryReadRoutineHeader(aText, lLexer, lNextMatch, aHeader);
  finally
    lLexer.Free;
  end;
end;

function CollectWritableConstantSwitches(const aText: string;
  out aDeclarationText: string): TArray<TWritableConstantSwitch>;
var
  i: Integer;
  lLexer: TmwBasePasLex;
  lEnabled: Boolean;
  lMatch: TMatch;
  lSwitch: TWritableConstantSwitch;
  lSwitches: TList<TWritableConstantSwitch>;
begin
  aDeclarationText := aText;
  lSwitches := TList<TWritableConstantSwitch>.Create;
  lLexer := nil;
  try
    lLexer := TmwBasePasLex.Create;
    lLexer.UseDefines := False;
    lLexer.Origin := aText;
    while lLexer.TokenID <> ptNull do
    begin
      if lLexer.TokenID = ptCompDirect then
      begin
        if TryReadShortCompilerSwitch(lLexer.Token, 'J', lEnabled) then
        begin
          lSwitch.EndOffset := lLexer.TokenPos + lLexer.TokenLen;
          lSwitch.Enabled := lEnabled;
          lSwitches.Add(lSwitch);
        end else
        begin
          lMatch := TRegEx.Match(lLexer.Token,
            '^\{\$J\s*([+-])\}|^\(\*\$J\s*([+-])\*\)', [roIgnoreCase]);
          if lMatch.Success then
          begin
            lSwitch.EndOffset := lLexer.TokenPos + lLexer.TokenLen;
            lSwitch.Enabled := (MatchGroupValue(lMatch, 1) = '+') or
              (MatchGroupValue(lMatch, 2) = '+');
            lSwitches.Add(lSwitch);
          end;
        end;
      end;
      if lLexer.IsCompilerDirective then
        for i := lLexer.TokenPos + 1 to lLexer.TokenPos + lLexer.TokenLen do
          if not CharInSet(aDeclarationText[i], [#10, #13]) then
            aDeclarationText[i] := ' ';
      lLexer.Next;
    end;
    Result := lSwitches.ToArray;
  finally
    lLexer.Free;
    lSwitches.Free;
  end;
end;

function WritableTypedConstantsAtOffset(const aSwitches: TArray<TWritableConstantSwitch>;
  const aOffset: Integer; const aDefault: Boolean): Boolean;
var
  lHigh: Integer;
  lLow: Integer;
  lMiddle: Integer;
begin
  Result := aDefault;
  lLow := 0;
  lHigh := High(aSwitches);
  while lLow <= lHigh do
  begin
    lMiddle := lLow + (lHigh - lLow) div 2;
    if aSwitches[lMiddle].EndOffset <= aOffset then
    begin
      Result := aSwitches[lMiddle].Enabled;
      lLow := lMiddle + 1;
    end else
      lHigh := lMiddle - 1;
  end;
end;

procedure AddLocal(const aLocals: TList<TDelphiSemanticLocal>; const aRoutineName, aName, aKind,
  aTypeName, aText: string; const aOffset: Integer); forward;
procedure ExtractReferencesFromBody(const aText, aBody: string; const aBodyOffset: Integer;
  const aRoutineName: string; const aReferences: TList<TDelphiSemanticReference>); forward;
procedure ExtractLocalsFromRoutine(const aText, aRoutineName: string;
  const aStartOffset, aEndOffset: Integer; const aLocals: TList<TDelphiSemanticLocal>;
  const aReferences: TList<TDelphiSemanticReference>); forward;
procedure ExtractRoutineBodies(const aText: string; const aLocals: TList<TDelphiSemanticLocal>;
  const aReferences: TList<TDelphiSemanticReference>); forward;
function IsReferenceKeyword(const aName: string): Boolean; forward;
function IsTypeReferenceToken(const aName: string): Boolean; forward;

function TextHasWordAt(const aText: string; const aOffset: Integer; const aWord: string): Boolean;
var
  lAfter: Integer;
begin
  lAfter := aOffset + Length(aWord);
  Result := (aOffset >= 1) and SameText(Copy(aText, aOffset, Length(aWord)), aWord) and
    ((lAfter > Length(aText)) or not IsIdentifierChar(aText[lAfter]));
end;

// [first token, token after the block) of a syntax node that records its end. The syntax tree is
// the only authority for where a body ends; a range that does not fit the text is an error, so
// the unit's scope facts fail instead of guessing a boundary (DS-653).
function AstNodeRange(const aText: string; const aNode: TSyntaxNode): TOffsetRange;
var
  lNode: TCompoundSyntaxNode;
begin
  if not (aNode is TCompoundSyntaxNode) then
    raise EInvalidOpException.CreateFmt('Syntax node at %d:%d records no end position',
      [aNode.Line, aNode.Col]);
  lNode := TCompoundSyntaxNode(aNode);
  Result.StartOffset := OffsetOfLineColumn(aText, lNode.Line, lNode.Col);
  Result.EndOffset := OffsetOfLineColumn(aText, lNode.EndLine, lNode.EndCol);
  if (Result.StartOffset < 1) or (Result.EndOffset < Result.StartOffset) then
    raise EInvalidOpException.CreateFmt('Syntax node range %d:%d-%d:%d does not match source',
      [lNode.Line, lNode.Col, lNode.EndLine, lNode.EndCol]);
end;

// The AST owns the declaration and its type start; the lexer only retains source spelling.
function AstLocalTypeText(const aText: string; const aTypeNode: TSyntaxNode;
  const aBodyOffset: Integer; const aLexer: TmwBasePasLex): string;
var
  lAfterOf: Boolean;
  lOffset: Integer;
  lRecordDepth: Integer;
  lRoundDepth: Integer;
  lSquareDepth: Integer;
begin
  lOffset := OffsetOfLineColumn(aText, aTypeNode.Line, aTypeNode.Col);
  if (lOffset < 1) or (lOffset >= aBodyOffset) then
    raise EInvalidOpException.Create('Routine-local AST type has no source position');
  aLexer.RunPos := lOffset - 1;
  if aLexer.TokenPos + 1 <> lOffset then
    raise EInvalidOpException.Create('Routine-local AST type does not start at a source token');
  lAfterOf := False;
  lRecordDepth := 0;
  lRoundDepth := 0;
  lSquareDepth := 0;
  while (aLexer.TokenID <> ptNull) and (aLexer.TokenPos + 1 < aBodyOffset) do
  begin
    if (lRecordDepth = 0) and (lRoundDepth = 0) and (lSquareDepth = 0) and
      (aLexer.TokenID in [ptSemiColon, ptEqual, ptAbsolute]) then
    begin
      Result := Trim(Copy(aText, lOffset, aLexer.TokenPos + 1 - lOffset));
      if Result = '' then
        raise EInvalidOpException.Create('Routine-local AST type has empty source text');
      Exit;
    end;
    // "of object" ends a procedural type; only a record or object type body closes with "end".
    case aLexer.TokenID of
      ptRecord: Inc(lRecordDepth);
      ptObject: if not lAfterOf then Inc(lRecordDepth);
      ptEnd: if lRecordDepth > 0 then Dec(lRecordDepth);
      ptRoundOpen: Inc(lRoundDepth);
      ptRoundClose: if lRoundDepth > 0 then Dec(lRoundDepth);
      ptSquareOpen: Inc(lSquareDepth);
      ptSquareClose: if lSquareDepth > 0 then Dec(lSquareDepth);
    end;
    lAfterOf := aLexer.TokenID = ptOf;
    aLexer.NextNoJunk;
  end;
  raise EInvalidOpException.Create('Routine-local AST type has no source terminator');
end;

// A begin/asm block must close with its own "end"; a range that falls short of it raises.
procedure RequireBlockEnd(const aText: string; const aRange: TOffsetRange; const aWhat: string);
var
  lBlock: string;
begin
  lBlock := TrimRight(SanitizeCodeText(Copy(aText, aRange.StartOffset,
    aRange.EndOffset - aRange.StartOffset)));
  if not TextHasWordAt(lBlock, Length(lBlock) - 2, 'end') or
    ((Length(lBlock) > 3) and IsIdentifierChar(lBlock[Length(lBlock) - 3])) then
    raise EInvalidOpException.CreateFmt('Block of %s at offset %d does not end with "end"',
      [aWhat, aRange.StartOffset]);
end;

procedure TSemanticSyntaxTreeBuilder.ClassForward;
begin
  FStack.Peek.SetAttribute(anType, 'class');
  inherited;
end;

procedure TSemanticSyntaxTreeBuilder.InterfaceForward;
begin
  FStack.Peek.SetAttribute(anType, 'interface');
  inherited;
end;

procedure TSemanticSyntaxTreeBuilder.DispInterfaceForward;
begin
  FStack.Peek.SetAttribute(anType, 'dispinterface');
  inherited;
end;
procedure TSemanticSyntaxTreeBuilder.ProceduralDirectiveOf;
begin
  FStack.Peek.SetAttribute(anType, 'method-pointer');
  inherited;
end;

procedure TSemanticSyntaxTreeBuilder.LabeledStatement;
begin
  // DelphiAST retains label declarations and goto targets, but drops definitions.
  FStack.AddValuedChild(ntLabel, Lexer.Token).SetAttribute(anType, 'definition');
  inherited;
end;

function AstProcedureSignature(const aNode: TSyntaxNode): TDelphiSemanticProcedureSignature;
var
  lParameters: TSyntaxNode;
  lParameter: TSyntaxNode;
  lTypeNode: TSyntaxNode;
  lReturnNode: TSyntaxNode;
  lItems: TList<TDelphiSemanticSignatureParameter>;
  lItem: TDelphiSemanticSignatureParameter;
begin
  Result := Default(TDelphiSemanticProcedureSignature);
  if not Assigned(aNode) then
    Exit;
  Result.Kind := LowerCase(aNode.GetAttribute(anName));
  if aNode.Typ = ntMethod then
    Result.Kind := LowerCase(aNode.GetAttribute(anKind));
  if not MatchText(Result.Kind, ['procedure', 'function']) then
    Exit;
  Result.Known := True;
  Result.OfObject := aNode.GetAttribute(anType) = 'method-pointer';
  Result.CallingConvention := LowerCase(aNode.GetAttribute(anCallingConvention));
  lReturnNode := aNode.FindNode(ntReturnType);
  if Assigned(lReturnNode) then
  begin
    lTypeNode := lReturnNode.FindNode(ntType);
    if Assigned(lTypeNode) then
      Result.ReturnType := lTypeNode.GetAttribute(anName)
    else
      Result.Known := False;
  end;

  lItems := TList<TDelphiSemanticSignatureParameter>.Create;
  try
    lParameters := aNode.FindNode(ntParameters);
    if Assigned(lParameters) then
      for lParameter in lParameters.ChildNodes do
      begin
        if lParameter.Typ <> ntParameter then
        begin
          Result.Known := False;
          Continue;
        end;
        lItem := Default(TDelphiSemanticSignatureParameter);
        lItem.Name := AstNodeName(lParameter);
        lItem.Modifier := LowerCase(lParameter.GetAttribute(anKind));
        lTypeNode := lParameter.FindNode(ntType);
        if Assigned(lTypeNode) then
          lItem.TypeName := lTypeNode.GetAttribute(anName);
        if lItem.TypeName = '' then
          Result.Known := False;
        lItems.Add(lItem);
      end;
    Result.Parameters := lItems.ToArray;
  finally
    lItems.Free;
  end;
end;

function AstInputText(const aText: string; const aSkipBodyAnalysis: Boolean): string;
var
  lOffset: Integer;
begin
  Result := aText;
  if not aSkipBodyAnalysis then
    Exit;
  // DS-713: only the real section can end an interface projection.
  lOffset := BuildSourceSections(aText).ImplementationOffset;
  if lOffset > 0 then
    Result := Copy(aText, 1, lOffset - 1) + 'implementation' + sLineBreak + 'end.';
end;
function ParseModelSyntaxTree(const aText: string): TSyntaxNode;
var
  lBuilder: TPasSyntaxTreeBuilder;
  lStream: TStringStream;
begin
  lBuilder := TSemanticSyntaxTreeBuilder.Create;
  lStream := nil;
  try
    lStream := TStringStream.Create(aText, TEncoding.UTF8);
    Result := lBuilder.Run(lStream);
  finally
    lStream.Free;
    lBuilder.Free;
  end;
end;

function BuildModelSyntaxTree(const aText: string; const aSkipBodyAnalysis: Boolean;
  out aComplete: Boolean; out aOriginalError: string): TSyntaxNode;
begin
  Result := nil;
  aComplete := True;
  aOriginalError := '';
  try
    Result := ParseModelSyntaxTree(aText);
  except
    on e: EParserException do
    begin
      if not aSkipBodyAnalysis then
        raise;
      // Interface-only RTL projections may intentionally omit valid bodies. The full-text
      // message names the real defect, so the retry must not replace it.
      aComplete := False;
      aOriginalError := e.Message;
    end;
  end;
  if aComplete then
    Exit;
  try
    Result := ParseModelSyntaxTree(AstInputText(aText, True));
  except
    on e: EParserException do
      raise EParserException.Create(e.Line, e.Col, e.FileName, aOriginalError);
  end;
end;
function AstOrderedImports(const aSection: TSyntaxNode; var aKnown: Boolean): TArray<string>;
var
  lUses: TSyntaxNode;
  i: Integer;
begin
  Result := nil;
  if not Assigned(aSection) then
    Exit;
  lUses := aSection.FindNode(ntUses);
  if not Assigned(lUses) then
    Exit;
  SetLength(Result, Length(lUses.ChildNodes));
  for i := 0 to High(lUses.ChildNodes) do
  begin
    Result[i] := lUses.ChildNodes[i].GetAttribute(anName);
    if (lUses.ChildNodes[i].Typ <> ntUnit) or (Result[i] = '') then
      aKnown := False;
  end;
end;

function AstDependencyFacts(const aRoot: TSyntaxNode): TDelphiSemanticUnitDependencyFacts;
var
  lImplementation: TSyntaxNode;
begin
  Result := Default(TDelphiSemanticUnitDependencyFacts);
  Result.Known := not Assigned(aRoot.FindNode(ntRequires)) and
    not Assigned(aRoot.FindNode(ntContains));
  Result.InterfaceImports := AstOrderedImports(aRoot.FindNode(ntInterface), Result.Known);
  lImplementation := aRoot.FindNode(ntImplementation);
  Result.ImplementationImports := AstOrderedImports(lImplementation, Result.Known);
  Result.RootImports := AstOrderedImports(aRoot, Result.Known);
  Result.HasInitialization := Assigned(aRoot.FindNode(ntInitialization));
  Result.HasFinalization := Assigned(aRoot.FindNode(ntFinalization));
  if Assigned(lImplementation) then
  begin
    Result.HasInitialization := Result.HasInitialization or
      Assigned(lImplementation.FindNode(ntInitialization));
    Result.HasFinalization := Result.HasFinalization or
      Assigned(lImplementation.FindNode(ntFinalization));
  end;
end;
procedure AddReference(const aReferences: TList<TDelphiSemanticReference>; const aRoutineName,
  aName, aText: string; const aOffset: Integer); forward;

procedure AddDefaultExpressionIdentifier(const aText: string; const aNode: TSyntaxNode;
  const aReferences: TList<TDelphiSemanticReference>);
var
  lName: string;
  lOffset: Integer;
  lReference: TDelphiSemanticReference;
begin
  lName := aNode.GetAttribute(anName);
  lOffset := OffsetOfLineColumn(aText, aNode.Line, aNode.Col);
  if (lName = '') or (lOffset < 1) or
    not SameText(Copy(aText, lOffset, Length(lName)), lName) then
    raise EInvalidOpException.Create('Default parameter identifier does not match source');
  // The AST clones a shared default expression for grouped parameter names.
  for lReference in aReferences do
    if (lReference.Offset = lOffset) and SameText(lReference.Name, lName) then
      Exit;
  AddReference(aReferences, '', lName, aText, lOffset);
end;

procedure ExtractDefaultExpressionReferences(const aText: string;
  const aExpression: TSyntaxNode; const aReferences: TList<TDelphiSemanticReference>);
var
  lNode: TSyntaxNode;
  lNodes: TStack<TSyntaxNode>;
  i: Integer;
begin
  if not Assigned(aExpression) then
    Exit;
  lNodes := TStack<TSyntaxNode>.Create;
  try
    lNodes.Push(aExpression);
    while lNodes.Count > 0 do
    begin
      lNode := lNodes.Pop;
      if lNode.Typ = ntIdentifier then
        AddDefaultExpressionIdentifier(aText, lNode, aReferences);
      for i := High(lNode.ChildNodes) downto 0 do
        lNodes.Push(lNode.ChildNodes[i]);
    end;
  finally
    lNodes.Free;
  end;
end;

procedure EnsureForwardTypeDeclaration(const aText, aName, aTypeName: string;
  const aNode: TSyntaxNode; const aDeclarations: TList<TDelphiSemanticDeclaration>);
var
  lDeclaration: TDelphiSemanticDeclaration;
  lOffset: Integer;
begin
  lOffset := OffsetOfLineColumn(aText, aNode.Line, aNode.Col);
  if (aName = '') or (lOffset < 1) or
    not SameText(Copy(aText, lOffset, Length(aName)), aName) then
    raise EInvalidOpException.Create('Forward type identifier does not match source');
  for lDeclaration in aDeclarations do
    if (lDeclaration.Offset = lOffset) and SameText(lDeclaration.Name, aName) then
      Exit;
  // AST facts also cover a forward declaration beside its type keyword.
  lDeclaration := Default(TDelphiSemanticDeclaration);
  lDeclaration.Name := aName;
  lDeclaration.Kind := 'type';
  lDeclaration.TypeName := aTypeName;
  lDeclaration.SectionKind := SectionForOffset(aText, lOffset);
  lDeclaration.Line := aNode.Line;
  lDeclaration.Column := aNode.Col;
  lDeclaration.Offset := lOffset;
  lDeclaration.EndOffset := lOffset + Length(aName);
  aDeclarations.Add(lDeclaration);
end;

procedure EnsureRoutineTypeDeclaration(const aText: string; const aNode: TSyntaxNode;
  const aDeclarations: TList<TDelphiSemanticDeclaration>);
var
  lDeclaration: TDelphiSemanticDeclaration;
  lEquals: Integer;
  lName: string;
  lOffset: Integer;
  lRange: TOffsetRange;
  lText: string;
  lTypeName: string;
  lTypeText: string;
begin
  lName := AstNodeName(aNode);
  lRange := AstNodeRange(aText, aNode);
  lOffset := lRange.StartOffset;
  if (lName = '') or not TextHasWordAt(aText, lOffset, lName) then
    raise EInvalidOpException.Create('Routine-local type identifier does not match source');
  for lDeclaration in aDeclarations do
    if (lDeclaration.Offset = lOffset) and SameText(lDeclaration.Name, lName) then
      Exit;
  lText := Copy(aText, lRange.StartOffset, lRange.EndOffset - lRange.StartOffset);
  lEquals := Pos('=', lText);
  if lEquals < 1 then
    Exit;
  lTypeText := Trim(Copy(lText, lEquals + 1, MaxInt));
  if EndsText(';', lTypeText) then
    SetLength(lTypeText, Length(lTypeText) - 1);
  lTypeName := NormalizeTypeName(lTypeText);
  // Retain unsupported AST declarations as lexical shadows, without inventing an identity.
  lDeclaration := Default(TDelphiSemanticDeclaration);
  lDeclaration.Name := lName;
  if SameText(lTypeName, 'record') then
    lDeclaration.Kind := 'type'
  else if TRegEx.IsMatch(lTypeName, '^\^?[A-Za-z_][A-Za-z0-9_.]*$') then
    lDeclaration.Kind := 'type-alias'
  else
    lDeclaration.Kind := 'unsupported-local-type';
  lDeclaration.TypeName := lTypeName;
  lDeclaration.SectionKind := SectionForOffset(aText, lOffset);
  lDeclaration.Line := aNode.Line;
  lDeclaration.Column := aNode.Col;
  lDeclaration.Offset := lOffset;
  lDeclaration.EndOffset := lOffset + Length(lName);
  aDeclarations.Add(lDeclaration);
end;
procedure EnsureUnitConstantDeclaration(const aText: string; const aNode: TSyntaxNode;
  const aDeclarations: TList<TDelphiSemanticDeclaration>);
var
  lDeclaration: TDelphiSemanticDeclaration;
  lName: string;
  lNameNode: TSyntaxNode;
  lOffset: Integer;
begin
  // Lexical line scanning can miss constants beside section keywords or peers.
  // Add only declarations proven by the AST; typed constants retain their own path.
  if Assigned(aNode.FindNode(ntType)) then
    Exit;
  lNameNode := aNode.FindNode(ntName);
  if not Assigned(lNameNode) then
    Exit;
  lName := AstNodeName(aNode);
  lOffset := OffsetOfLineColumn(aText, lNameNode.Line, lNameNode.Col);
  if (lName = '') or (lOffset < 1) or
    not SameText(Copy(aText, lOffset, Length(lName)), lName) then
    raise EInvalidOpException.Create('Constant identifier does not match source');
  for lDeclaration in aDeclarations do
    if (lDeclaration.Offset = lOffset) and SameText(lDeclaration.Name, lName) then
      Exit;
  lDeclaration := Default(TDelphiSemanticDeclaration);
  lDeclaration.Name := lName;
  lDeclaration.Kind := 'const';
  lDeclaration.SectionKind := SectionForOffset(aText, lOffset);
  lDeclaration.Line := lNameNode.Line;
  lDeclaration.Column := lNameNode.Col;
  lDeclaration.Offset := lOffset;
  lDeclaration.EndOffset := lOffset + Length(lName);
  aDeclarations.Add(lDeclaration);
end;

function AstEnumValueDeclaration(const aText, aTypeName: string;
  const aNode: TSyntaxNode): TDelphiSemanticDeclaration;
begin
  Result := Default(TDelphiSemanticDeclaration);
  Result.Name := aNode.GetAttribute(anName);
  Result.Offset := OffsetOfLineColumn(aText, aNode.Line, aNode.Col);
  if (Result.Name = '') or (Result.Offset < 1) or
    not SameText(Copy(aText, Result.Offset, Length(Result.Name)), Result.Name) then
    raise EInvalidOpException.Create('Enum value identifier does not match source');
  Result.Kind := 'enum-value';
  Result.TypeName := aTypeName;
  Result.SectionKind := SectionForOffset(aText, Result.Offset);
  Result.Line := aNode.Line;
  Result.Column := aNode.Col;
  Result.EndOffset := Result.Offset + Length(Result.Name);
end;

procedure CollectEnumDeclarations(const aText: string; const aTypeDeclaration: TSyntaxNode;
  const aDeclarations: TList<TDelphiSemanticDeclaration>;
  const aFacts: TList<TAstDeclarationScopeFact>; const aScopeIndex: Integer;
  const aTypeOwnerPath: string);
var
  lTypeNode, lNode: TSyntaxNode;
  lName: string;
  lDeclaration: TDelphiSemanticDeclaration;
  lFact: TAstDeclarationScopeFact;
  i: NativeInt;
begin
  lTypeNode := aTypeDeclaration.FindNode(ntType);
  if not Assigned(lTypeNode) or not SameText(lTypeNode.GetAttribute(anName), 'enum') then
    Exit;
  lName := AstNodeName(aTypeDeclaration);
  // Replace only this declaration's legacy line-based enum entries.
  for i := aDeclarations.Count - 1 downto 0 do
    if SameText(aDeclarations[i].Kind, 'enum-value') and
      SameText(aDeclarations[i].TypeName, lName) and
      (aDeclarations[i].Line = aTypeDeclaration.Line) then
      aDeclarations.Delete(i);
  for lNode in lTypeNode.ChildNodes do
    if lNode.Typ = ntIdentifier then
    begin
      lDeclaration := AstEnumValueDeclaration(aText, lName, lNode);
      aDeclarations.Add(lDeclaration);
      lFact := Default(TAstDeclarationScopeFact);
      lFact.Name := lDeclaration.Name;
      lFact.Kind := 'enum-value';
      lFact.Line := lDeclaration.Line;
      lFact.Column := lDeclaration.Column;
      lFact.ScopeIndex := aScopeIndex;
      lFact.ScopedEnum := SameText(lTypeNode.GetAttribute(anVisibility), 'scoped');
      lFact.EnumTypeName := lName;
      // Unscoped enum values retain unit/routine scope even for nested types.
      if lFact.ScopedEnum then
        lFact.TypeOwnerPath := aTypeOwnerPath;
      aFacts.Add(lFact);
    end;
end;

function AppendTypeOwnerPath(const aOwnerPath, aTypeName: string): string;
begin
  if aOwnerPath = '' then
    Exit(aTypeName);
  Result := aOwnerPath + '.' + aTypeName;
end;

procedure ApplyTypeScope(var aDeclaration: TDelphiSemanticDeclaration;
  const aFact: TAstDeclarationScopeFact);
var
  lOwnerPath: string;
begin
  lOwnerPath := aFact.TypeOwnerPath;
  if aFact.ScopedEnum then
    lOwnerPath := AppendTypeOwnerPath(lOwnerPath, aFact.EnumTypeName);
  if lOwnerPath = '' then
    Exit;
  aDeclaration.ScopeKind := 'type';
  aDeclaration.OwnerName := lOwnerPath;
  aDeclaration.OwnerScopeId := aDeclaration.OwnerScopeId + '|type|' +
    StringReplace(LowerCase(lOwnerPath), '.', '|type|', [rfReplaceAll]);
end;

function IsMutableDeclaration(const aKind: string;
  const aWritableSwitches: TArray<TWritableConstantSwitch>; const aOffset: Integer;
  const aDefaultWritable: Boolean): Boolean;
begin
  Result := not MatchText(aKind, ['const', 'enum-value']) and
    (not SameText(aKind, 'typed-const') or
    WritableTypedConstantsAtOffset(aWritableSwitches, aOffset, aDefaultWritable));
end;
function NestedRoutineDeclarationFact(const aNode: TSyntaxNode;
  const aDeclarations: TList<TDelphiSemanticDeclaration>;
  const aParentScopeIndex: Integer): TAstDeclarationScopeFact;
var
  lDeclaration: TDelphiSemanticDeclaration;
  lName: string;
begin
  Result := Default(TAstDeclarationScopeFact);
  lName := AstNodeName(aNode);
  // DelphiAST folds the routine name into an attribute and removes its name node.
  // Require a unique matching source declaration on the AST header line.
  for lDeclaration in aDeclarations do
    if SameText(lDeclaration.Kind, 'routine') and SameText(lDeclaration.Name, lName) and
      (lDeclaration.Line = aNode.Line) then
    begin
      if Result.Name <> '' then
        Exit(Default(TAstDeclarationScopeFact));
      Result.Name := lName;
      Result.Kind := 'routine';
      Result.Line := lDeclaration.Line;
      Result.Column := lDeclaration.Column;
      Result.ScopeIndex := aParentScopeIndex;
      Result.ProcedureSignature := AstProcedureSignature(aNode);
    end;
end;

procedure EnrichLexicalScopeFacts(const aText, aUnitName: string;
  const aWritableSwitches: TArray<TWritableConstantSwitch>;
  const aOptions: TDelphiSemanticModelOptions;
  const aMembers: TList<TDelphiSemanticMember>;
  const aDeclarations: TList<TDelphiSemanticDeclaration>;
  const aRoutines: TList<TDelphiSemanticRoutine>;
  const aLocals: TList<TDelphiSemanticLocal>;
  const aReferences: TList<TDelphiSemanticReference>;
  const aDiagnostics: TList<TDelphiSemanticModelDiagnostic>;
  var aModel: TDelphiSemanticUnitModel);
var
  i: Integer;
  lChild: TSyntaxNode;
  lComplete: Boolean;
  lDeclaration: TDelphiSemanticDeclaration;
  lDeclarationCount: Integer;
  lDeclarationFacts: TList<TAstDeclarationScopeFact>;
  lDiagnosticCount: Integer;
  lFact: TAstDeclarationScopeFact;
  lHeader: TRoutineHeader;
  lHelperCovered: Boolean;
  lLocal: TDelphiSemanticLocal;
  lLocalCount: Integer;
  lLocalTypeLexer: TmwBasePasLex;
  lMatchedDeclCount: Integer;
  lMatchedFactIndex: Integer;
  lMatchedScopeCount: Integer;
  lMatchedScopeIndex: Integer;
  lMember: TDelphiSemanticMember;
  lMemberCount: Integer;
  lMemberReferences: TList<TDelphiSemanticReference>;
  lOmittedClassVariables: Integer;
  lOriginalError: string;
  lOwnerScopeIndex: Integer;
  lReference: TDelphiSemanticReference;
  lReferenceCount: Integer;
  lRoutine: TDelphiSemanticRoutine;
  lScopeIndex: Integer;
  lScopes: TList<TAstRoutineScope>;
  lSyntaxTree: TSyntaxNode;
  lTypeCount: Integer;
  lUnownedBlocks: TList<TOffsetRange>;

  function FindScopeForPosition(const aLine, aColumn: Integer): Integer;
  var
    lIndex: Integer;
  begin
    Result := -1;
    for lIndex := 0 to Pred(lScopes.Count) do
      if ((aLine > lScopes[lIndex].StartLine) or
        ((aLine = lScopes[lIndex].StartLine) and
        (aColumn >= lScopes[lIndex].StartColumn))) and
        ((aLine < lScopes[lIndex].EndLine) or
        ((aLine = lScopes[lIndex].EndLine) and
        (aColumn < lScopes[lIndex].EndColumn))) and
        ((Result < 0) or (lScopes[lIndex].Depth > lScopes[Result].Depth)) then
        Result := lIndex;
  end;

  procedure CollectFacts(const aNode, aParentNode: TSyntaxNode; const aParentScopeIndex: Integer;
    const aTypeOwnerPath: string);
  var
    lChild: TSyntaxNode;
    lCurrentScopeIndex: Integer;
    lChildTypeOwnerPath: string;
    lGuidNode: TSyntaxNode;
    lHelperNode: TSyntaxNode;
    lHelperTargetNode: TSyntaxNode;
    lLiteralNode: TSyntaxNode;
    lLabelReference: TDelphiSemanticReference;
    lLocalTypeName: string;
    lName: string;
    lNameOffset: Integer;
    lScope: TAstRoutineScope;
    lStatements: TSyntaxNode;
    lTypeNode: TSyntaxNode;
  begin
    lCurrentScopeIndex := aParentScopeIndex;
    lChildTypeOwnerPath := aTypeOwnerPath;
    if (aNode.Typ in [ntInitialization, ntFinalization]) and not aOptions.SkipBodyAnalysis then
    begin
      lStatements := aNode.FindNode(ntStatements);
      if Assigned(lStatements) then
        lUnownedBlocks.Add(AstNodeRange(aText, lStatements));
    end;
    if aNode.Typ = ntMethod then
    begin
      // The nested routine declaration belongs to its enclosing scope.
      if aParentScopeIndex >= 0 then
        lDeclarationFacts.Add(NestedRoutineDeclarationFact(aNode, aDeclarations, aParentScopeIndex));
      lScope := Default(TAstRoutineScope);
      lScope.Name := AstNodeName(aNode);
      lScope.SemanticSignature := '(' + AstMethodSignature(aNode) + ')';
      lScope.CallingConvention := aNode.GetAttribute(anCallingConvention);
      lScope.ProcedureSignature := AstProcedureSignature(aNode);
      lScope.StartLine := aNode.Line;
      lScope.StartColumn := aNode.Col;
      lScope.EndLine := aNode.Line;
      lScope.ParentIndex := aParentScopeIndex;
      if aNode is TCompoundSyntaxNode then
      begin
        lScope.StartLine := TCompoundSyntaxNode(aNode).Line;
        lScope.EndLine := TCompoundSyntaxNode(aNode).EndLine;
        lScope.EndColumn := TCompoundSyntaxNode(aNode).EndCol;
      end;
      // Interface headers, forward and external declarations have no statement block.
      lStatements := aNode.FindNode(ntStatements);
      lScope.HasBody := Assigned(lStatements);
      if Assigned(lStatements) and not aOptions.SkipBodyAnalysis then
      begin
        lScope.Body := AstNodeRange(aText, lStatements);
        if not TextHasWordAt(aText, lScope.Body.StartOffset, 'begin') and
          not TextHasWordAt(aText, lScope.Body.StartOffset, 'asm') then
          raise EInvalidOpException.CreateFmt('Body of routine %s at %d:%d does not match source',
            [lScope.Name, lStatements.Line, lStatements.Col]);
        RequireBlockEnd(aText, lScope.Body, 'routine ' + lScope.Name);
      end;
      if aParentScopeIndex >= 0 then
      begin
        lScope.ParentScopeId := lScopes[aParentScopeIndex].ScopeId;
        lScope.Depth := lScopes[aParentScopeIndex].Depth + 1;
      end;
      lScope.ScopeId := AstScopeId(aUnitName, lScope.ParentScopeId, aNode);
      lCurrentScopeIndex := lScopes.Count;
      lScopes.Add(lScope);
    end else if (aNode.Typ = ntTypeDecl) or
      MatchText(SyntaxNodeNames[aNode.Typ], ['variable', 'constant']) then
    begin
      if (aNode.Typ = ntVariable) and Assigned(aParentNode) and
        (aParentNode.Typ = ntVariables) and (lCurrentScopeIndex >= 0) and
        (aTypeOwnerPath = '') and not aOptions.SkipBodyAnalysis and
        lScopes[lCurrentScopeIndex].HasBody then
      begin
        lName := AstNodeName(aNode);
        lNameOffset := OffsetOfLineColumn(aText, aNode.Line, aNode.Col);
        if lNameOffset < 1 then
          raise EInvalidOpException.Create('Routine-local AST name has no source position');
        if lNameOffset < lScopes[lCurrentScopeIndex].Body.StartOffset then
        begin
          if (lName = '') or not TextHasWordAt(aText, lNameOffset, lName) then
            raise EInvalidOpException.Create('Routine-local AST name does not match source');
          lTypeNode := aNode.FindNode(ntType);
          if not Assigned(lTypeNode) then
            raise EInvalidOpException.Create('Routine-local AST variable has no type');
          if not Assigned(lLocalTypeLexer) then
          begin
            lLocalTypeLexer := TmwBasePasLex.Create;
            lLocalTypeLexer.UseDefines := False;
            lLocalTypeLexer.Origin := aText;
          end;
          lLocalTypeName := AstLocalTypeText(aText, lTypeNode,
            lScopes[lCurrentScopeIndex].Body.StartOffset, lLocalTypeLexer);
          // An anonymous record declares no type name; like a unit-level one it is named after
          // its owner, the routine, so consumers find the synthetic owner of its fields.
          if SameText(lTypeNode.GetAttribute(anType), 'record') then
            lLocalTypeName := lScopes[lCurrentScopeIndex].Name + '.' + lName;
          AddLocal(aLocals, lScopes[lCurrentScopeIndex].Name, lName, 'var', lLocalTypeName, aText,
            lNameOffset);
        end;
      end;
      if (aNode.Typ = ntConstant) and (lCurrentScopeIndex < 0) and (aTypeOwnerPath = '') then
        EnsureUnitConstantDeclaration(aText, aNode, aDeclarations);
      lFact := Default(TAstDeclarationScopeFact);
      lFact.Name := AstNodeName(aNode);
      lFact.Kind := SyntaxNodeNames[aNode.Typ];
      lFact.Line := aNode.Line;
      lFact.Column := aNode.Col;
      lFact.ScopeIndex := lCurrentScopeIndex;
      if aNode.Typ = ntConstant then
        lFact.TypeOwnerPath := aTypeOwnerPath;
      if aNode.Typ = ntTypeDecl then
      begin
        if (lCurrentScopeIndex >= 0) and (aTypeOwnerPath = '') then
          EnsureRoutineTypeDeclaration(aText, aNode, aDeclarations);
        lFact.TypeOwnerPath := aTypeOwnerPath;
        lTypeNode := aNode.FindNode(ntType);
        if Assigned(lTypeNode) then
        begin
          lHelperNode := lTypeNode.FindNode(ntHelper);
          lFact.IsHelper := Assigned(lHelperNode);
          if not Assigned(lHelperNode) then
            lFact.AstHelperKind := 'none'
          else
          begin
            lHelperTargetNode := lHelperNode.FindNode(ntType);
            if Assigned(lHelperTargetNode) then
            begin
              // Only the matched active AST establishes helper kind and target.
              lFact.HelperTargetName := StringReplace(
                lHelperTargetNode.GetAttribute(anName), '&', '', [rfReplaceAll]);
              if SameText(lTypeNode.GetAttribute(anType), 'class') then
                lFact.AstHelperKind := 'class'
              else if SameText(lTypeNode.GetAttribute(anType), 'record') then
                lFact.AstHelperKind := 'record';
            end;
          end;
        end;
        lFact.ProcedureSignature := AstProcedureSignature(lTypeNode);
        lFact.IsForward := SameText(aNode.GetAttribute(anForwarded), 'true');
        if lFact.IsForward then
        begin
          EnsureForwardTypeDeclaration(aText, lFact.Name, aNode.GetAttribute(anType),
            aNode, aDeclarations);
          lFact.IsDispInterface := SameText(aNode.GetAttribute(anType), 'dispinterface');
        end;
        if Assigned(lTypeNode) and
          MatchText(lTypeNode.GetAttribute(anType), ['interface', 'dispinterface']) then
        begin
          lFact.IsDispInterface := SameText(lTypeNode.GetAttribute(anType),
            'dispinterface');
          lGuidNode := lTypeNode.FindNode(ntGuid);
          if Assigned(lGuidNode) then
          begin
            lLiteralNode := lGuidNode.FindNode(ntLiteral);
            if Assigned(lLiteralNode) and (lLiteralNode is TValuedSyntaxNode) then
              lFact.InterfaceGuid := (lLiteralNode as TValuedSyntaxNode).Value;
          end;
        end;
      end;
      if (lFact.Name <> '') or lFact.IsHelper then
        lDeclarationFacts.Add(lFact);
      if aNode.Typ = ntTypeDecl then
      begin
        lChildTypeOwnerPath := AppendTypeOwnerPath(aTypeOwnerPath, lFact.Name);
        CollectEnumDeclarations(aText, aNode, aDeclarations, lDeclarationFacts, lCurrentScopeIndex,
          aTypeOwnerPath);
      end;
    end;

    if (aNode.Typ = ntParameter) and not aOptions.SkipReferenceExtraction then
      ExtractDefaultExpressionReferences(aText, aNode.FindNode(ntExpression), aReferences);

    if (lCurrentScopeIndex >= 0) and not aOptions.SkipBodyAnalysis and
      (aNode.Typ in [ntLabel, ntGoto]) then
    begin
      lLabelReference := Default(TDelphiSemanticReference);
      lLabelReference.Role := 'local-label-declaration';
      if aNode.Typ = ntGoto then
      begin
        lLabelReference.Name := 'goto';
        lLabelReference.Role := 'local-goto-keyword';
      end else if aNode is TValuedSyntaxNode then
      begin
        lLabelReference.Name := TValuedSyntaxNode(aNode).Value;
        if SameText(aNode.GetAttribute(anType), 'definition') then
          lLabelReference.Role := 'local-label-definition'
        else if Assigned(aParentNode) and (aParentNode.Typ = ntGoto) then
          lLabelReference.Role := 'local-label-target';
      end;
      lLabelReference.Line := aNode.Line;
      lLabelReference.Column := aNode.Col;
      lLabelReference.EndLine := aNode.Line;
      lLabelReference.EndColumn := aNode.Col + Length(lLabelReference.Name) - 1;
      lLabelReference.Offset := OffsetOfLineColumn(aText, aNode.Line, aNode.Col);
      lLabelReference.EndOffset := lLabelReference.Offset + Length(lLabelReference.Name);
      lLabelReference.RoutineName := lScopes[lCurrentScopeIndex].Name;
      lLabelReference.RoutineScopeId := lScopes[lCurrentScopeIndex].ScopeId;
      // Keep the syntax role even when source verification fails; consumers must refuse it.
      aReferences.Add(lLabelReference);
    end;

    for lChild in aNode.ChildNodes do
      CollectFacts(lChild, aNode, lCurrentScopeIndex, lChildTypeOwnerPath);
  end;

  function FindDeclarationFact(const aDeclaration: TDelphiSemanticDeclaration;
    out aFact: TAstDeclarationScopeFact; out aFactIndex: Integer): Boolean;
  var
    lIndex: Integer;
  begin
    aFact := Default(TAstDeclarationScopeFact);
    aFactIndex := -1;
    Result := False;
    for lIndex := 0 to Pred(lDeclarationFacts.Count) do
      if SameText(lDeclarationFacts[lIndex].Name, aDeclaration.Name) and
        (lDeclarationFacts[lIndex].Line = aDeclaration.Line) and
        ((lDeclarationFacts[lIndex].Column = aDeclaration.Column) or
        (MatchText(aDeclaration.Kind, ['const', 'typed-const']) and
        SameText(lDeclarationFacts[lIndex].Kind, 'constant'))) and
        ((not lDeclarationFacts[lIndex].IsHelper) or
        MatchText(aDeclaration.Kind, ['type', 'type-alias'])) and
        ((not MatchText(aDeclaration.Kind, ['type', 'type-alias'])) or
        SameText(lDeclarationFacts[lIndex].Kind, 'typedecl')) then
      begin
        // DS-716: helper absence requires a unique AST declaration token, not a same-line name.
        if Result then
        begin
          aFact := Default(TAstDeclarationScopeFact);
          aFactIndex := -1;
          Exit(False);
        end;
        aFact := lDeclarationFacts[lIndex];
        aFactIndex := lIndex;
        Result := True;
      end;
  end;

  // DS-653/DS-657: names used by declarations outside statement blocks are references: const
  // and var initializers (`@GLimit`, `CLimit * 2`), absolute targets, array bounds, default
  // values and the types in headings, including class-method headings inside a type. The
  // syntax tree places each name; one that does not match the source is left out and stays an
  // unclassified occurrence for consumers.
  procedure ExtractDeclarationReferences(const aRoot: TSyntaxNode);
  var
    lKnown: TDictionary<string, Boolean>;
    lReference: TDelphiSemanticReference;

    procedure AddNodeReference(const aNode: TSyntaxNode; const aRole: string);
    var
      lKey: string;
      lName: string;
      lOffset: Integer;
    begin
      lName := aNode.GetAttribute(anName);
      if not IsValidIdent(lName) or IsReferenceKeyword(lName) or
        ((aRole = 'type-reference') and not IsTypeReferenceToken(lName)) then
        Exit;
      lOffset := OffsetOfLineColumn(aText, aNode.Line, aNode.Col);
      if not TextHasWordAt(aText, lOffset, lName) then
        Exit;
      lKey := LowerCase(lName) + #1 + IntToStr(lOffset);
      if lKnown.ContainsKey(lKey) then
        Exit;
      lKnown.Add(lKey, True);
      AddReference(lMemberReferences, '', lName, aText, lOffset);
      lReference := lMemberReferences.Last;
      lReference.Role := aRole;
      lMemberReferences[lMemberReferences.Count - 1] := lReference;
    end;

    procedure Walk(const aNode: TSyntaxNode);
    var
      lChild: TSyntaxNode;
    begin
      // Statements are scanned as bodies; attributes and type parameters declare names.
      if aNode.Typ in [ntStatements, ntAttributes, ntTypeParams] then
        Exit;
      if (aNode.Typ = ntType) and SameText(aNode.GetAttribute(anName), 'enum') then
        Exit;
      if aNode.Typ = ntIdentifier then
        AddNodeReference(aNode, 'reference')
      else if aNode.Typ = ntType then
        AddNodeReference(aNode, 'type-reference');
      for lChild in aNode.ChildNodes do
        Walk(lChild);
    end;

  var
    lDelta: Integer;
  begin
    lKnown := TDictionary<string, Boolean>.Create;
    try
      // Line-scan offsets can sit one character off until reconciliation; key each known
      // reference by the position where its name actually starts.
      for lReference in lMemberReferences do
        for lDelta in TArray<Integer>.Create(0, 1, -1) do
          if TextHasWordAt(aText, lReference.Offset + lDelta, lReference.Name) then
          begin
            lKnown.AddOrSetValue(LowerCase(lReference.Name) + #1 +
              IntToStr(lReference.Offset + lDelta), True);
            Break;
          end;
      Walk(aRoot);
    finally
      lKnown.Free;
    end;
  end;

  // DS-653: statements come only from each routine's own begin/asm block and from the main,
  // initialization and finalization blocks. AST variables already carry routine ownership.
  procedure ExtractAstBodies;
  var
    lBlock: TOffsetRange;
    lIndex: Integer;
    lScope: TAstRoutineScope;
  begin
    for lIndex := 0 to Pred(lScopes.Count) do
    begin
      lScope := lScopes[lIndex];
      if not lScope.HasBody then
        Continue;
      // Assembler operands, registers and labels are no Pascal names; the syntax tree does not
      // classify them, so an asm body yields no references and consumers list its occurrences.
      if not TextHasWordAt(aText, lScope.Body.StartOffset, 'asm') then
        ExtractReferencesFromBody(aText, Copy(aText, lScope.Body.StartOffset,
          lScope.Body.EndOffset - lScope.Body.StartOffset), lScope.Body.StartOffset, lScope.Name,
          lMemberReferences);
    end;
    for lBlock in lUnownedBlocks do
      ExtractReferencesFromBody(aText, Copy(aText, lBlock.StartOffset,
        lBlock.EndOffset - lBlock.StartOffset), lBlock.StartOffset, '', lMemberReferences);
  end;

begin
  aModel.ScopeModelStatus := 'ast-failed';
  aModel.ScopeModelVersion := 'declaration-scope-v1';
  aModel.RejectedDeclarationCount := 0;
  for i := 0 to Pred(aDeclarations.Count) do
  begin
    lDeclaration := aDeclarations[i];
    lDeclaration.DeclarationRole := 'invalid';
    lDeclaration.AstHelperKind := '';
    lDeclaration.ScopeKind := 'unknown';
    lDeclaration.OwnerName := '';
    lDeclaration.OwnerScopeId := '';
    lDeclaration.SymbolId := '';
    aDeclarations[i] := lDeclaration;
    Inc(aModel.RejectedDeclarationCount);
  end;
  lDeclarationFacts := TList<TAstDeclarationScopeFact>.Create;
  lScopes := TList<TAstRoutineScope>.Create;
  lUnownedBlocks := TList<TOffsetRange>.Create;
  lSyntaxTree := nil;
  lLocalTypeLexer := nil;
  lMemberReferences := nil;
  if not aOptions.SkipReferenceExtraction then
    lMemberReferences := aReferences;
  lDeclarationCount := aDeclarations.Count;
  lDiagnosticCount := aDiagnostics.Count;
  lLocalCount := aLocals.Count;
  lMemberCount := aMembers.Count;
  lReferenceCount := aReferences.Count;
  try
    try
      lSyntaxTree := BuildModelSyntaxTree(aText, aOptions.SkipBodyAnalysis, lComplete,
        lOriginalError);
      if lComplete then
        aModel.DependencyFacts := AstDependencyFacts(lSyntaxTree);
      CollectFacts(lSyntaxTree, nil, -1, '');
      ExtractMembers(aText, aModel.FileName, lSyntaxTree, aDiagnostics, aDeclarations, aMembers,
        lMemberReferences);
      if not aOptions.SkipBodyAnalysis then
      begin
        // A program, library or old-style unit main block is a direct child of the root.
        for lChild in lSyntaxTree.ChildNodes do
          if lChild.Typ = ntStatements then
          begin
            lUnownedBlocks.Add(AstNodeRange(aText, lChild));
            RequireBlockEnd(aText, lUnownedBlocks.Last, 'the main block');
          end;
        if Assigned(lMemberReferences) then
          ExtractDeclarationReferences(lSyntaxTree);
        ExtractAstBodies;
      end;
      if lComplete then
        aModel.ScopeModelStatus := 'ast'
      else
      begin
        aModel.ScopeModelStatus := 'ast-interface-only';
        AddDiagnostic(aDiagnostics, 'AST_BODY_PARSE_FAILED', lOriginalError, aModel.FileName, 0);
      end;
      aModel.RejectedDeclarationCount := 0;
    except
      on e: Exception do
      begin
        // Drop partial syntax-backed facts; the bounded line scan below replaces them.
        aDeclarations.Count := lDeclarationCount;
        aDiagnostics.Count := lDiagnosticCount;
        aLocals.Count := lLocalCount;
        aMembers.Count := lMemberCount;
        aReferences.Count := lReferenceCount;
        AddDiagnostic(aDiagnostics, 'SCOPE_MODEL_FAILED', e.Message, aModel.FileName, 0);
        lTypeCount := ExtractFallbackMembers(aText, aDeclarations, aMembers, lMemberReferences,
          lOmittedClassVariables);
        // Without a syntax tree no body has a proven end. The line scan keeps the occurrences
        // visible, and the 'ast-failed' status makes consumers list them instead of trusting
        // their routine attribution.
        if not aOptions.SkipBodyAnalysis then
          ExtractRoutineBodies(aText, aLocals, lMemberReferences);
        for i := lDeclarationCount to Pred(aDeclarations.Count) do
        begin
          lDeclaration := aDeclarations[i];
          lDeclaration.DeclarationRole := 'invalid';
          lDeclaration.ScopeKind := 'unknown';
          aDeclarations[i] := lDeclaration;
          Inc(aModel.RejectedDeclarationCount);
        end;
        if lTypeCount > 0 then
          AddDiagnostic(aDiagnostics, 'MEMBERS_UNVERIFIED', Format(
            'Members of %d class, record or interface types come from a line scan because ' +
            'the syntax tree is unavailable; they are unverified and every type is incomplete. ' +
            '%d class variables were left out.', [lTypeCount, lOmittedClassVariables]),
            aModel.FileName, 0);
        Exit;
      end;
    end;

    for i := 0 to Pred(aDeclarations.Count) do
    begin
      lDeclaration := aDeclarations[i];
      if FindDeclarationFact(lDeclaration, lFact, lMatchedFactIndex) then
      begin
        lDeclaration.DeclarationRole := IfThen(lFact.IsForward, 'forward', 'declaration');
        if lFact.ScopeIndex < 0 then
        begin
          lDeclaration.ScopeKind := 'unit';
          lDeclaration.OwnerName := aUnitName;
          lDeclaration.OwnerScopeId := LowerCase(aUnitName);
        end else
        begin
          lDeclaration.ScopeKind := 'routine';
          lDeclaration.OwnerName := lScopes[lFact.ScopeIndex].Name;
          lDeclaration.OwnerScopeId := lScopes[lFact.ScopeIndex].ScopeId;
        end;
        ApplyTypeScope(lDeclaration, lFact);
        lDeclaration.SymbolId := lDeclaration.OwnerScopeId + '|' +
          LowerCase(lDeclaration.Kind) + '|' + LowerCase(lDeclaration.Name);
        lDeclaration.InterfaceGuid := lFact.InterfaceGuid;
        lDeclaration.AstHelperKind := lFact.AstHelperKind;
        if lFact.AstHelperKind <> '' then
          lDeclaration.HelperTargetName := lFact.HelperTargetName;
        lDeclaration.ProcedureSignature := lFact.ProcedureSignature;
        lDeclaration.IsDispInterface := lFact.IsDispInterface;
        if lFact.IsHelper then
        begin
          // Coverage is the exact unique fact actually assigned to this declaration.
          lFact.HelperCovered := True;
          lDeclarationFacts[lMatchedFactIndex] := lFact;
        end;
        lDeclaration.Mutable := IsMutableDeclaration(lDeclaration.Kind, aWritableSwitches,
          OffsetOfLineColumn(aText, lDeclaration.Line, lDeclaration.Column),
          aOptions.WritableTypedConstants);
      end else
      begin
        lDeclaration.DeclarationRole := 'invalid';
        lDeclaration.ScopeKind := 'unknown';
        Inc(aModel.RejectedDeclarationCount);
      end;
      aDeclarations[i] := lDeclaration;
    end;

    // DS-716: the line scanner can omit escaped or same-line helper declarations.
    // Count their active AST facts as rejected rather than infer a helper-free context.
    for lFact in lDeclarationFacts do
      if lFact.IsHelper then
      begin
        lHelperCovered := lFact.HelperCovered;
        if not lHelperCovered then
          for lDeclaration in aDeclarations do
            if SameText(lDeclaration.DeclarationRole, 'invalid') and
              MatchText(lDeclaration.Kind, ['type', 'type-alias']) and
              SameText(lDeclaration.Name, lFact.Name) and
              (lDeclaration.Line = lFact.Line) and (lDeclaration.Column = lFact.Column) then
            begin
              lHelperCovered := True;
              Break;
            end;
        if not lHelperCovered then
        begin
          Inc(aModel.RejectedDeclarationCount);
          AddDiagnostic(aDiagnostics, 'AST_HELPER_DECLARATION_UNINDEXED',
            Format('An active helper declaration at column %d has no indexed declaration; ' +
              'helper absence is unverified.', [lFact.Column]),
            aModel.FileName, lFact.Line);
        end;
      end;

    for i := 0 to Pred(aRoutines.Count) do
    begin
      lRoutine := aRoutines[i];
      lMatchedScopeCount := 0;
      lMatchedScopeIndex := -1;
      for lScopeIndex := 0 to Pred(lScopes.Count) do
        if SameText(lScopes[lScopeIndex].Name,
          QualifiedRoutineName(lRoutine.OwnerName, lRoutine.Name)) and
          (lScopes[lScopeIndex].StartLine = lRoutine.Line) then
        begin
          Inc(lMatchedScopeCount);
          lMatchedScopeIndex := lScopeIndex;
        end;
      if lMatchedScopeCount = 1 then
      begin
        lRoutine.ScopeId := lScopes[lMatchedScopeIndex].ScopeId;
        lRoutine.ParentScopeId := lScopes[lMatchedScopeIndex].ParentScopeId;
        lRoutine.CallingConvention := lScopes[lMatchedScopeIndex].CallingConvention;
        lRoutine.ProcedureSignature := lScopes[lMatchedScopeIndex].ProcedureSignature;
        lRoutine.EndLine := lScopes[lMatchedScopeIndex].EndLine;
        lRoutine.EndColumn := lScopes[lMatchedScopeIndex].EndColumn;
        if lScopes[lMatchedScopeIndex].HasBody then
          lRoutine.AstScopeKind := 'body'
        else
          lRoutine.AstScopeKind := 'header';
        lRoutine.AstSemanticSignature := lScopes[lMatchedScopeIndex].SemanticSignature;
        if TryReadMatchedSourceHeader(aText, lRoutine, lHeader) and
          SameText(lHeader.Signature, lRoutine.Signature) and
          SameText(lHeader.ReturnType, lRoutine.ReturnType) then
        begin
          lRoutine.AstSourceSignature := lHeader.Signature;
          lRoutine.AstSourceSignatureVerified := True;
        end;
      end;
      aRoutines[i] := lRoutine;
    end;

    for i := 0 to Pred(aMembers.Count) do
    begin
      lMember := aMembers[i];
      lOwnerScopeIndex := FindScopeForPosition(lMember.Line, lMember.Column);
      if lOwnerScopeIndex < 0 then
        Continue;
      lMatchedDeclCount := 0;
      for lDeclaration in aDeclarations do
        if SameText(lDeclaration.Name, lMember.OwnerName) and
          SameText(lDeclaration.ScopeKind, 'routine') and
          SameText(lDeclaration.OwnerScopeId, lScopes[lOwnerScopeIndex].ScopeId) and
          (lDeclaration.Offset < lMember.Offset) then
        begin
          Inc(lMatchedDeclCount);
          lMember.OwnerScopeId := lDeclaration.OwnerScopeId;
          lMember.OwnerSymbolId := lDeclaration.SymbolId;
        end;
      if lMatchedDeclCount <> 1 then
      begin
        lMember.OwnerScopeId := '';
        lMember.OwnerSymbolId := '';
      end;
      aMembers[i] := lMember;
    end;

    for i := 0 to Pred(aLocals.Count) do
    begin
      lLocal := aLocals[i];
      lFact.ScopeIndex := FindScopeForPosition(lLocal.Line, lLocal.Column);
      if lFact.ScopeIndex >= 0 then
      begin
        lLocal.RoutineName := lScopes[lFact.ScopeIndex].Name;
        lLocal.RoutineScopeId := lScopes[lFact.ScopeIndex].ScopeId;
      end;
      aLocals[i] := lLocal;
    end;

    for i := 0 to Pred(aReferences.Count) do
    begin
      lReference := aReferences[i];
      if StartsText('local-label-', lReference.Role) or
        (lReference.Role = 'local-goto-keyword') then
        Continue;
      lFact.ScopeIndex := FindScopeForPosition(lReference.Line, lReference.Column);
      if lFact.ScopeIndex >= 0 then
      begin
        lReference.RoutineName := lScopes[lFact.ScopeIndex].Name;
        lReference.RoutineScopeId := lScopes[lFact.ScopeIndex].ScopeId;
      end;
      aReferences[i] := lReference;
    end;
  finally
    lLocalTypeLexer.Free;
    lSyntaxTree.Free;
    lUnownedBlocks.Free;
    lScopes.Free;
    lDeclarationFacts.Free;
  end;
end;

procedure AddDeclaration(const aDeclarations: TList<TDelphiSemanticDeclaration>;
  const aName, aKind, aTypeName, aSection, aText: string; const aOffset: Integer;
  const aBaseTypeName: string = ''; const aHelperTargetName: string = '');
var
  lDeclaration: TDelphiSemanticDeclaration;
begin
  lDeclaration := Default(TDelphiSemanticDeclaration);
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
  lMember := Default(TDelphiSemanticMember);
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
  lCleanText: string;
  lImplementationPos: Integer;
  lMatch: TMatch;
  lSection: string;
begin
  lCleanText := SanitizeCodeText(aText);
  lImplementationPos := Pos('implementation', LowerCase(lCleanText));
  lMatch := TRegEx.Match(lCleanText, '\buses\s+(.*?);', [roIgnoreCase, roSingleLine]);
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

procedure AddTypeDeclaration(const aDeclarations: TList<TDelphiSemanticDeclaration>;
  const aText, aLine, aName, aTypeName, aTypeText: string; const aLineOffset: Integer);
var
  lNameOffset: Integer;
  lSection: string;
begin
  lNameOffset := TextOffsetInLine(aLine, aName, aLineOffset) + 1;
  lSection := SectionForOffset(aText, lNameOffset);
  if MatchText(aTypeName, ['enum', 'class', 'interface', 'record']) then
    AddDeclaration(aDeclarations, aName, 'type', aTypeName, lSection, aText,
      lNameOffset, ExtractBaseTypeName(aTypeText), ExtractHelperTargetName(aTypeText))
  else
    AddDeclaration(aDeclarations, aName, 'type-alias', aTypeName, lSection, aText, lNameOffset);
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
        // Resume sibling type declarations after any nested declaration section.
        lBlockKind := 'type';
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
        ConsumeTypeKeyword(lScopeLine, lBlockKind);
        if TRegEx.IsMatch(lScopeLine, '^(const|resourcestring|var|threadvar)\b',
          [roIgnoreCase]) then
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
              AddTypeDeclaration(aDeclarations, aText, lLines[i], lName, lTypeName, lTypeText, lOffset);

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
  lDeclaredType: string;
  lEndLine: Integer;
  lHeaderDepth: Integer;
  lHeaderOffset: Integer;
  lHeaderText: string;
  lInImplementation: Boolean;
  lInRoutine: Boolean;
  lLine: string;
  lLineOffset: Integer;
  lLines: TStringList;
  lMatch: TMatch;
  lName: string;
  lNameMatch: TMatch;
  lNameOffset: Integer;
  lOffset: Integer;
  lSection: string;
  lSkipUntilLine: Integer;
  lSyntheticTypeName: string;
  lTypeDepth: Integer;
  lTypeLength: Integer;
  lTypeOffset: Integer;
  lTypeText: string;
begin
  lLines := TStringList.Create;
  try
    lLines.Text := aText;
    lHeaderText := SanitizeCodeText(aText);
    lBlockKind := '';
    lInImplementation := False;
    lInRoutine := False;
    lOffset := 0;
    lSkipUntilLine := 0;
    for i := 0 to Pred(lLines.Count) do
    begin
      lLine := lLines[i].Trim;
      lLineOffset := lOffset + Length(lLines[i]) - Length(lLines[i].TrimLeft);
      // DS-730: a physical comment line cannot declare a symbol in an open section.
      if Copy(lHeaderText, lOffset + 1, Length(lLines[i])).Trim = '' then
      begin
        Inc(lOffset, Length(lLines[i]) + Length(sLineBreak));
        Continue;
      end;
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
      end else if TRegEx.IsMatch(Copy(lHeaderText, lOffset + 1, Length(lLines[i])).Trim,
        '^(?:(?:class\s+)?(?:procedure|function|constructor|destructor)|class\s+operator)\b', [roIgnoreCase]) then
      begin
        lBlockKind := '';
        // Header exclusion preserves the existing body-declaration inventory.
        if lInImplementation and
          (StartsText('procedure ', lLine) or StartsText('function ', lLine)) then
          lInRoutine := True;
        lHeaderDepth := 0;
        lHeaderOffset := lOffset + 1;
        while lHeaderOffset <= Length(lHeaderText) do
        begin
          case lHeaderText[lHeaderOffset] of
            '(':
              Inc(lHeaderDepth);
            ')':
              Dec(lHeaderDepth);
            ';':
              if lHeaderDepth = 0 then
                Break;
          end;
          Inc(lHeaderOffset);
        end;
        lSkipUntilLine := LineOfOffset(aText, lHeaderOffset);
      end else if lInRoutine and SameText(lLine, 'end;') then
      begin
        lInRoutine := False;
      end else if (not lInRoutine) and
        SameText(StripTrailingDeclarationComment(lLine), 'end;') then
      begin
        lBlockKind := '';
      end else if not lInRoutine then
      begin
        lMatch := TRegEx.Match(lLine, '^(const|resourcestring|var|threadvar|type)\b\s*',
          [roIgnoreCase]);
        if lMatch.Success then
        begin
          lBlockKind := LowerCase(lMatch.Groups[1].Value);
          if lBlockKind = 'type' then
            lBlockKind := '';
          Inc(lLineOffset, lMatch.Length);
          lLine := Copy(lLine, lMatch.Length + 1, MaxInt);
        end;
        if MatchText(lBlockKind, ['const', 'resourcestring']) then
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
              MatchGroupValue(lMatch, 2).Trim, lSection, aText,
              lLineOffset + lMatch.Groups[1].Index);
            AddTypeReferences(aReferences, '', MatchGroupValue(lMatch, 2).Trim, aText,
              TextOffsetInLine(lLines[i], MatchGroupValue(lMatch, 2).Trim, lOffset));
          end;
        end else if MatchText(lBlockKind, ['var', 'threadvar']) then
        begin
          lMatch := TRegEx.Match(lLine,
            '^([A-Za-z_][A-Za-z0-9_]*(?:\s*,\s*[A-Za-z_][A-Za-z0-9_]*)*)\s*:(?!=)\s*([^;]+);',
            [roIgnoreCase]);
          if lMatch.Success then
          begin
            lSection := SectionForOffset(aText, lOffset + 1);
            lTypeOffset := lLineOffset + lMatch.Groups[2].Index;
            lTypeText := Copy(lHeaderText, lTypeOffset, lMatch.Groups[2].Length);
            lTypeLength := Length(lTypeText);
            lTypeDepth := 0;
            for j := 1 to Length(lTypeText) do
            begin
              case lTypeText[j] of
                '(', '[':
                  Inc(lTypeDepth);
                ')', ']':
                  Dec(lTypeDepth);
                '=':
                  if lTypeDepth = 0 then
                  begin
                    lTypeLength := j - 1;
                    Break;
                  end;
              end;
            end;
            lDeclaredType := Copy(lMatch.Groups[2].Value, 1, lTypeLength).Trim;
            for lNameMatch in TRegEx.Matches(lMatch.Groups[1].Value,
              '[A-Za-z_][A-Za-z0-9_]*') do
            begin
              lNameOffset := lLineOffset + lMatch.Groups[1].Index + lNameMatch.Index - 1;
              AddDeclaration(aDeclarations, lNameMatch.Value, lBlockKind,
                lDeclaredType, lSection, aText, lNameOffset);
            end;
            AddTypeReferences(aReferences, '', Copy(lTypeText, 1, lTypeLength), aText,
              lTypeOffset);
          end else if TryAnonymousRecordVarStart(lLine, lName) then
          begin
            lSection := SectionForOffset(aText, lOffset + 1);
            lNameOffset := lLineOffset - lOffset + Pos(LowerCase(lName), LowerCase(lLine));
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

function MaskMemberVisibility(var aLine, aCleanBody, aVisibility: string;
  const aBodyStart: Integer): Boolean;
var
  i: Integer;
  lMatch: TMatch;
begin
  lMatch := TRegEx.Match(aLine,
    '^[ \t]*((?:strict[ \t]+)?(?:private|protected)|public|published)\b', [roIgnoreCase]);
  Result := lMatch.Success and (aBodyStart > 0) and
    (aBodyStart + lMatch.Length - 1 <= Length(aCleanBody));
  if not Result then
    Exit;
  aVisibility := TRegEx.Replace(lMatch.Groups[1].Value, '[ \t]+', ' ').ToLower;
  // Mask only the prefix so anchored member extraction retains original source coordinates.
  for i := 1 to lMatch.Length do
  begin
    aLine[i] := ' ';
    aCleanBody[aBodyStart + i - 1] := ' ';
  end;
end;
const
  // Capture groups are shared by ordinary and normalized variant-field scans.
  cMemberFieldPrefix =
    '(?:(strict[ \t]+(?:private|protected)|private|protected|public|published)[ \t]+)?' +
    '(class\s+var\s+)?(&?[A-Za-z_][A-Za-z0-9_]*(?:\s*,\s*&?[A-Za-z_][A-Za-z0-9_]*)*)';

procedure UpdateFieldSection(const aMatch: TMatch; var aVisibility: string;
  var aClassVariables: Boolean);
begin
  if aMatch.Groups[1].Value <> '' then
  begin
    aVisibility := TRegEx.Replace(aMatch.Groups[1].Value, '[ \t]+', ' ').ToLower;
    aClassVariables := False;
  end;
  if aMatch.Groups[2].Value <> '' then
    aClassVariables := True;
end;
function PreviousCodeChar(const aCleanText: string; const aIndex: Integer): Char;
var
  i: Integer;
begin
  i := aIndex - 1;
  while (i >= 1) and (aCleanText[i] <= ' ') do
    Dec(i);
  if i < 1 then
    Exit(#0);
  Result := aCleanText[i];
end;

// Splits physical body lines where the syntax tree starts another member, so every member
// on a line gets its own scan. Continuations of a comma-separated field list stay whole.
procedure BuildMemberSegments(const aBody, aCleanBody: string; const aBodyOffset: Integer;
  const aSplitOffsets: TArray<Integer>; const aSegments: TStringList;
  const aSegmentOffsets: TList<Integer>);
var
  i: Integer;
  lLine: string;
  lLineEnd: Integer;
  lLines: TStringList;
  lOffset: Integer;
  lSplit: Integer;
  lSplitIndex: Integer;
  lStart: Integer;
begin
  lLines := TStringList.Create;
  try
    lLines.Text := aBody;
    lOffset := aBodyOffset;
    lSplitIndex := 0;
    for i := 0 to Pred(lLines.Count) do
    begin
      lLine := lLines[i];
      lLineEnd := lOffset + Length(lLine);
      lStart := lOffset;
      while (lSplitIndex <= High(aSplitOffsets)) and (aSplitOffsets[lSplitIndex] < lLineEnd) do
      begin
        lSplit := aSplitOffsets[lSplitIndex];
        Inc(lSplitIndex);
        if (lSplit <= lStart) or
          (Trim(Copy(aCleanBody, lStart - aBodyOffset + 1, lSplit - lStart)) = '') or
          (PreviousCodeChar(aCleanBody, lSplit - aBodyOffset + 1) = ',') then
          Continue;
        aSegments.Add(Copy(lLine, lStart - lOffset + 1, lSplit - lStart));
        aSegmentOffsets.Add(lStart);
        lStart := lSplit;
      end;
      aSegments.Add(Copy(lLine, lStart - lOffset + 1, MaxInt));
      aSegmentOffsets.Add(lStart);
      Inc(lOffset, Length(lLine) + Length(sLineBreak));
    end;
  finally
    lLines.Free;
  end;
end;

// Returns the exact name offset so coordinate reconciliation never has to search for it.
function MemberNameOffset(const aText, aSegment, aName: string; const aSegmentOffset,
  aNameIndex: Integer): Integer;
begin
  Result := aSegmentOffset + Length(aSegment) - Length(TrimLeft(aSegment)) + aNameIndex - 1;
  if not IsWordAt(aText, Result, aName) then
    Result := aSegmentOffset + 1;
end;

procedure ExtractMembersFromBody(const aText, aOwnerName, aBody: string; const aBodyOffset: Integer;
  const aDeclarations: TList<TDelphiSemanticDeclaration>;
  const aMembers: TList<TDelphiSemanticMember>;
  const aReferences: TList<TDelphiSemanticReference>;
  const aSplitOffsets: TArray<Integer>);
var
  lCleanBody: string;
  lCleanSegment: string;
  lConsumedEnd: Integer;
  lDefaultProperty: Boolean;
  lFieldMatch: TMatch;
  lFieldRegex: TRegEx;
  i: Integer;
  lInClassVarSection: Boolean;
  lIndexedProperty: Boolean;
  lLine: string;
  lMethodMatch: TMatch;
  lName: string;
  lNameOffset: Integer;
  lNameMatch: TMatch;
  lNamesOffset: Integer;
  lNestedBody: string;
  lNestedBodyOffset: Integer;
  lNestedOwnerName: string;
  lNestedRecordMatch: TMatch;
  lOffset: Integer;
  lPropertyMatch: TMatch;
  lSearchFrom: Integer;
  lSegment: string;
  lSegmentOffsets: TList<Integer>;
  lSegments: TStringList;
  lTypeName: string;
  lTypeOffset: Integer;
  lVisibility: string;
begin
  lSegments := TStringList.Create;
  lSegmentOffsets := nil;
  try
    lSegmentOffsets := TList<Integer>.Create;
    lCleanBody := SanitizeCodeText(aBody);
    BuildMemberSegments(aBody, lCleanBody, aBodyOffset, aSplitOffsets, lSegments,
      lSegmentOffsets);
    lFieldRegex := TRegEx.Create('\G[ \t]*' + cMemberFieldPrefix +
      '\s*:([^;\r\n]+);', [roIgnoreCase]);
    lConsumedEnd := 0;
    lInClassVarSection := False;
    lNestedBody := '';
    lNestedBodyOffset := 0;
    lNestedOwnerName := '';
    lVisibility := 'public';
    for i := 0 to Pred(lSegments.Count) do
    begin
      lOffset := lSegmentOffsets[i];
      if lOffset < lConsumedEnd then
        Continue;
      lLine := lSegments[i];
      if (lNestedOwnerName = '') and
        MaskMemberVisibility(lLine, lCleanBody, lVisibility, lOffset - aBodyOffset + 1) then
        lInClassVarSection := False;
      lSegment := lLine;
      // Comments never shape a member: a trailing comment with a colon and a parenthesis must
      // not turn an ordinary member line into a variant field list.
      lCleanSegment := Copy(lCleanBody, lOffset - aBodyOffset + 1, Length(lSegment)).Trim;
      lLine := NormalizeVariantMemberLine(lCleanSegment);
      if lLine = lCleanSegment then
        lLine := lSegment.Trim;
      if lNestedOwnerName <> '' then
      begin
        if TRegEx.IsMatch(lLine, '^end\s*;', [roIgnoreCase]) then
        begin
          ExtractMembersFromBody(aText, lNestedOwnerName, lNestedBody, lNestedBodyOffset,
            aDeclarations, aMembers, aReferences, nil);
          lNestedBody := '';
          lNestedOwnerName := '';
        end else
          lNestedBody := lNestedBody + lSegment + sLineBreak;
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
          lNameOffset := Pos(LowerCase(lName), LowerCase(lSegment));
          if lNameOffset <= 0 then
            lNameOffset := 1;
          lNestedOwnerName := aOwnerName + '.' + lName;
          AddDeclaration(aDeclarations, lNestedOwnerName, 'type', 'record',
            SectionForOffset(aText, lOffset + lNameOffset), aText, lOffset + lNameOffset);
          AddMember(aMembers, aOwnerName, lName, 'field', lNestedOwnerName, lVisibility, '',
            aText, False, False, lOffset + lNameOffset);
          lNestedBodyOffset := lOffset + Length(lSegment) + Length(sLineBreak);
        end else
        begin
          lPropertyMatch := TRegEx.Match(lLine,
          '^(?:class\s+)?property\s+&?([A-Za-z_][A-Za-z0-9_]*)\s*(\[[^\]]+\])?\s*:\s*([^;]+)',
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
              MemberNameOffset(aText, lSegment, lPropertyMatch.Groups[1].Value, lOffset,
              lPropertyMatch.Groups[1].Index));
            AddParameterTypeReferences(aReferences, '', MatchGroupValue(lPropertyMatch, 2),
              aText, TextOffsetInLine(lSegment, MatchGroupValue(lPropertyMatch, 2), lOffset));
            AddTypeReferences(aReferences, '', lPropertyMatch.Groups[3].Value.Trim, aText,
              TextOffsetInLine(lSegment, lPropertyMatch.Groups[3].Value.Trim, lOffset));
          end else
          begin
            lMethodMatch := TRegEx.Match(lLine,
              '^(?:class\s+)?(procedure|function|constructor|destructor)\s+&?' +
              '([A-Za-z_][A-Za-z0-9_]*)\s*(\([^\r\n]*\))?\s*(?::\s*([^;]+))?',
              [roIgnoreCase]);
            if lMethodMatch.Success then
            begin
              lInClassVarSection := False;
              AddMember(aMembers, aOwnerName, lMethodMatch.Groups[2].Value, 'method',
                MatchGroupValue(lMethodMatch, 4).Trim, lVisibility, MatchGroupValue(lMethodMatch, 3),
                aText, False, False, MemberNameOffset(aText, lSegment,
                lMethodMatch.Groups[2].Value, lOffset, lMethodMatch.Groups[2].Index));
              AddParameterTypeReferences(aReferences, '', MatchGroupValue(lMethodMatch, 3),
                aText, TextOffsetInLine(lSegment, MatchGroupValue(lMethodMatch, 3), lOffset));
              AddTypeReferences(aReferences, '', MatchGroupValue(lMethodMatch, 4).Trim, aText,
                lOffset + MatchGroupIndex(lMethodMatch, 4) - 1);
            end else
            begin
              lSearchFrom := 1;
              if lLine = lSegment.Trim then
                lFieldMatch := lFieldRegex.Match(lCleanBody, lOffset - aBodyOffset + 1)
              else
                // Variant labels and closing parentheses use the existing normalized form.
                lFieldMatch := TRegEx.Match(lLine, '\G\s*' + cMemberFieldPrefix +
                  '\s*:\s*([^;]+);', [roIgnoreCase]);
              while lFieldMatch.Success do
              begin
                UpdateFieldSection(lFieldMatch, lVisibility, lInClassVarSection);
                if lLine = lSegment.Trim then
                begin
                  lNamesOffset := aBodyOffset + lFieldMatch.Groups[3].Index - 1;
                  lTypeOffset := aBodyOffset + lFieldMatch.Groups[4].Index - 1;
                  lTypeName := Copy(aBody, lFieldMatch.Groups[4].Index,
                    lFieldMatch.Groups[4].Length);
                  Inc(lTypeOffset, Length(lTypeName) - Length(lTypeName.TrimLeft));
                  lTypeName := lTypeName.Trim;
                  lConsumedEnd := aBodyOffset + lFieldMatch.Index + lFieldMatch.Length - 1;
                end else begin
                  // Search forward so later variant fields never reuse an earlier position.
                  lNamesOffset := PosEx(lFieldMatch.Groups[3].Value, lSegment, lSearchFrom);
                  if lNamesOffset <= 0 then
                    lNamesOffset := 1;
                  lSearchFrom := lNamesOffset + lFieldMatch.Groups[3].Length;
                  lNamesOffset := lOffset + lNamesOffset - 1;
                  lTypeName := lFieldMatch.Groups[4].Value.Trim;
                  lTypeOffset := PosEx(lTypeName, lSegment, lSearchFrom);
                  if lTypeOffset <= 0 then
                    lTypeOffset := 1
                  else
                    lSearchFrom := lTypeOffset + Length(lTypeName);
                  lTypeOffset := lOffset + lTypeOffset - 1;
                end;
                lNameMatch := TRegEx.Match(lFieldMatch.Groups[3].Value, '[A-Za-z_][A-Za-z0-9_]*');
                while lNameMatch.Success do
                begin
                  lNameOffset := lNamesOffset + lNameMatch.Index - 1;
                  if lInClassVarSection then
                    AddMember(aMembers, aOwnerName, lNameMatch.Value, 'class-var',
                      lTypeName, lVisibility, '', aText, False, False, lNameOffset)
                  else
                    AddMember(aMembers, aOwnerName, lNameMatch.Value, 'field',
                      lTypeName, lVisibility, '', aText, False, False, lNameOffset);
                  lNameMatch := lNameMatch.NextMatch;
                end;
                AddTypeReferences(aReferences, '', lTypeName, aText, lTypeOffset);
                lFieldMatch := lFieldMatch.NextMatch;
              end;
            end;
          end;
        end;
      end;
    end;
    if lNestedOwnerName <> '' then
      ExtractMembersFromBody(aText, lNestedOwnerName, lNestedBody, lNestedBodyOffset,
        aDeclarations, aMembers, aReferences, nil);
  finally
    lSegmentOffsets.Free;
    lSegments.Free;
  end;
end;

type
  // One member as the syntax tree declares it; the line scan supplies its detailed facts.
  TAstMemberFact = record
    Category: string;
    Name: string;
    Visibility: string;
    Offset: Integer;
    Node: TSyntaxNode;
  end;

  TFallbackTypeBlock = record
    OwnerName: string;
    HeaderOffset: Integer;
    BodyOffset: Integer;
    AnonymousRecordDepth: Integer;
    NestedRanges: TArray<TOffsetRange>;
  end;

function AstVisibilityName(const aNode: TSyntaxNode; out aVisibility: string): Boolean;
begin
  Result := True;
  case aNode.Typ of
    ntPrivate:
      aVisibility := 'private';
    ntProtected:
      aVisibility := 'protected';
    ntPublic:
      aVisibility := 'public';
    ntPublished:
      aVisibility := 'published';
    ntStrictPrivate:
      aVisibility := 'strict private';
    ntStrictProtected:
      aVisibility := 'strict protected';
  else
    Result := False;
  end;
end;

function IsAstMemberStart(const aNode: TSyntaxNode): Boolean;
begin
  Result := (aNode.Typ = ntField) or (aNode.Typ = ntMethod) or (aNode.Typ = ntProperty);
end;

// Collects the members a type declares, in source order. Operators, method resolution clauses
// and property redeclarations without a type only split the scan; they were never member facts.
procedure CollectAstTypeMembers(const aText: string; const aParent: TSyntaxNode;
  const aVisibility: string; const aFacts: TList<TAstMemberFact>;
  const aSplitOffsets: TList<Integer>; const aNestedTypes: TList<TSyntaxNode>);
var
  lChild: TSyntaxNode;
  lFact: TAstMemberFact;
  lNested: TSyntaxNode;
  lVisibility: string;
begin
  for lChild in aParent.ChildNodes do
  begin
    if AstVisibilityName(lChild, lVisibility) then
    begin
      CollectAstTypeMembers(aText, lChild, lVisibility, aFacts, aSplitOffsets, aNestedTypes);
      Continue;
    end;
    lFact := Default(TAstMemberFact);
    lFact.Visibility := aVisibility;
    lFact.Node := lChild;
    case lChild.Typ of
      ntField:
        begin
          lFact.Category := 'field';
          lFact.Name := AstNodeName(lChild);
        end;
      ntName:
        // Variant-part fields stay plain names in the syntax tree.
        if lChild is TValuedSyntaxNode then
        begin
          lFact.Category := 'field';
          lFact.Name := TValuedSyntaxNode(lChild).Value;
        end;
      ntMethod:
        if MatchText(lChild.GetAttribute(anKind),
          ['procedure', 'function', 'constructor', 'destructor']) and
          not Assigned(lChild.FindNode(ntResolutionClause)) then
        begin
          lFact.Category := 'method';
          lFact.Name := AstNodeName(lChild);
          if Pos('<', lFact.Name) > 0 then
            lFact.Name := Copy(lFact.Name, 1, Pos('<', lFact.Name) - 1);
        end;
      ntProperty:
        if Assigned(lChild.FindNode(ntType)) then
        begin
          lFact.Category := 'property';
          lFact.Name := lChild.GetAttribute(anName);
        end;
      ntTypeSection:
        for lNested in lChild.ChildNodes do
          if lNested.Typ = ntTypeDecl then
            aNestedTypes.Add(lNested);
    end;
    if IsAstMemberStart(lChild) then
      aSplitOffsets.Add(OffsetOfLineColumn(aText, lChild.Line, lChild.Col));
    if lFact.Category <> '' then
    begin
      // An escaped identifier (&Label) names the member Label.
      if StartsText('&', lFact.Name) then
        Delete(lFact.Name, 1, 1);
      lFact.Offset := OffsetOfLineColumn(aText, lChild.Line, lChild.Col);
      aFacts.Add(lFact);
    end;
  end;
end;

function NextSplitOffset(const aSplitOffsets: TArray<Integer>; const aOffset: Integer): Integer;
var
  lHigh: Integer;
  lLow: Integer;
  lMiddle: Integer;
begin
  Result := MaxInt;
  lLow := 0;
  lHigh := High(aSplitOffsets);
  while lLow <= lHigh do
  begin
    lMiddle := (lLow + lHigh) div 2;
    if aSplitOffsets[lMiddle] > aOffset then
    begin
      Result := aSplitOffsets[lMiddle];
      lHigh := lMiddle - 1;
    end else
      lLow := lMiddle + 1;
  end;
end;

function MemberCategory(const aKind: string): string;
begin
  if SameText(aKind, 'class-var') then
    Exit('field');
  Result := LowerCase(aKind);
end;

// A field the line scan cannot read (a final field without `;`, or a type on the next line) is
// rebuilt from the syntax tree only when the tree proves every fact: an instance field whose
// name and single plain type identifier sit at the tree's own source positions. Inline types
// (array, record, set, enumeration) carry child nodes or an anType, and pointer types carry
// anType, so the tree rejects them. A generic type is rejected by IsWordAt, not by those two
// checks: DelphiAST collapses `TArray<Integer>` into the single name `TArray.Integer`, which
// the dotted-identifier pattern accepts but the source text at that position contradicts -
// IsWordAt is the proof that the name we store is the text the source declares, so it must
// not be relaxed. A procedural type is refused by its stored name, and a body with class
// variables leaves the member kind unproven; both are refused below.
function TryAstFieldMember(const aText, aOwnerName: string; const aFact: TAstMemberFact;
  const aHasClassVariables: Boolean; const aMembers: TList<TDelphiSemanticMember>;
  const aReferences: TList<TDelphiSemanticReference>): Boolean;
var
  lNameOffset: Integer;
  lTypeName: string;
  lTypeNode: TSyntaxNode;
  lTypeOffset: Integer;
begin
  Result := False;
  if aHasClassVariables or (aFact.Category <> 'field') or (aFact.Node.Typ <> ntField) then
    Exit;
  lTypeNode := aFact.Node.FindNode(ntType);
  if not Assigned(lTypeNode) or lTypeNode.HasChildren or lTypeNode.HasAttribute(anType) then
    Exit;
  lTypeName := lTypeNode.GetAttribute(anName);
  if not TRegEx.IsMatch(lTypeName, '^[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*$') then
    Exit;
  // A procedural type would be stored as the type named `procedure`, which is never a real type.
  // We refuse on the stored name text, so every procedural form is refused whatever node shape
  // the parser produced - `procedure`, `procedure of object` and their parameter lists alike.
  // Observed on the bare form before this guard existed: ds706\focused-red3.log.
  if MatchText(lTypeName, ['procedure', 'function']) then
    Exit;
  lNameOffset := aFact.Offset;
  if (lNameOffset >= 1) and (lNameOffset <= Length(aText)) and (aText[lNameOffset] = '&') then
    Inc(lNameOffset);
  lTypeOffset := OffsetOfLineColumn(aText, lTypeNode.Line, lTypeNode.Col);
  if not IsWordAt(aText, lNameOffset, aFact.Name) or
    not IsWordAt(aText, lTypeOffset, lTypeName) then
    Exit;
  AddMember(aMembers, aOwnerName, aFact.Name, 'field', lTypeName, aFact.Visibility, '', aText,
    False, False, lNameOffset);
  AddTypeReferences(aReferences, '', lTypeName, aText, lTypeOffset);
  Result := True;
end;

// Pairs each syntax member with one scanned member of the same owner, name and category inside
// the member's own source span. Visibility and method signatures come from the syntax tree.
// A scanned member without a syntax counterpart was invented by the line scan (for example a
// parameter on a method's continuation line) and is removed. A syntax member the scan missed is
// rebuilt from the tree when TryAstFieldMember proves it; otherwise it makes the type
// incomplete, and its names are returned in aUnscanned.
function ReconcileTypeMembers(const aText, aBody, aOwnerName: string;
  const aFacts: TList<TAstMemberFact>; const aSplitOffsets: TArray<Integer>;
  const aMembers: TList<TDelphiSemanticMember>;
  const aReferences: TList<TDelphiSemanticReference>; const aFirstMember: Integer;
  out aUnscanned: string): Boolean;
var
  j: Integer;
  lEnd: Integer;
  lFact: TAstMemberFact;
  lFound: Integer;
  lHasClassVariables: Boolean;
  lMatched: TArray<Boolean>;
  lMember: TDelphiSemanticMember;
  lMissing: TList<TAstMemberFact>;
  lRebuilt: Integer;
begin
  Result := True;
  aUnscanned := '';
  SetLength(lMatched, aMembers.Count - aFirstMember);
  lMissing := TList<TAstMemberFact>.Create;
  try
    for lFact in aFacts do
    begin
      lEnd := NextSplitOffset(aSplitOffsets, lFact.Offset);
      lFound := -1;
      for j := aFirstMember to Pred(aMembers.Count) do
      begin
        lMember := aMembers[j];
        if not lMatched[j - aFirstMember] and (lMember.Offset >= lFact.Offset) and
          (lMember.Offset < lEnd) and SameText(lMember.OwnerName, aOwnerName) and
          SameText(lMember.Name, lFact.Name) and
          (MemberCategory(lMember.Kind) = lFact.Category) then
        begin
          lFound := j;
          Break;
        end;
      end;
      if lFound < 0 then
      begin
        lMissing.Add(lFact);
        Continue;
      end;
      lMatched[lFound - aFirstMember] := True;
      lMember := aMembers[lFound];
      lMember.Visibility := lFact.Visibility;
      if lFact.Category = 'method' then
      begin
        lMember.ProcedureSignature := AstProcedureSignature(lFact.Node);
        if SameText(lFact.Node.GetAttribute(anClass), 'true') then
          lMember.ProcedureSignature.Known := False;
      end;
      aMembers[lFound] := lMember;
    end;
    for j := Pred(aMembers.Count) downto aFirstMember do
      if not lMatched[j - aFirstMember] and SameText(aMembers[j].OwnerName, aOwnerName) then
        aMembers.Delete(j);
    if lMissing.Count = 0 then
      Exit;
    // The syntax tree does not mark class variables, so their presence leaves the kind unproven.
    // Class constants are deliberately not covered here. In their common form the parser gives
    // them a constant node, not a member fact, so they never reach this rebuild. One form does:
    // a typed class constant whose name is a soft keyword (`class const Name: Integer = 1;`)
    // leaves the parser's constant loop immediately and is parsed as a class field, so it
    // becomes an ntField fact with a clean type node and is rebuilt here as a plain `field`.
    // Its name, type, offset and visibility are right and nothing can misbind, so this is kind
    // imprecision rather than a safety hole; DS-710 owns the proper accounting.
    // TUnitModelTests.ClassConstantIsNotAMemberFact pins both forms.
    lHasClassVariables := TRegEx.IsMatch(SanitizeCodeText(aBody),
      '\bclass\s+(?:thread)?var\b', [roIgnoreCase]);
    for lFact in lMissing do
    begin
      lRebuilt := aMembers.Count;
      if TryAstFieldMember(aText, aOwnerName, lFact, lHasClassVariables, aMembers,
        aReferences) then
      begin
        // Keep source order so consumers see the member where the scan would have placed it.
        lMember := aMembers[lRebuilt];
        aMembers.Delete(lRebuilt);
        j := aFirstMember;
        while (j < aMembers.Count) and (aMembers[j].Offset < lMember.Offset) do
          Inc(j);
        aMembers.Insert(j, lMember);
      end else
      begin
        Result := False;
        aUnscanned := aUnscanned + IfThen(aUnscanned <> '', ', ') + lFact.Name;
      end;
    end;
  finally
    lMissing.Free;
  end;
end;

procedure BlankRange(var aText: string; const aStartIndex, aEndIndex: Integer);
var
  i: Integer;
begin
  for i := aStartIndex to aEndIndex do
    if (i >= 1) and (i <= Length(aText)) and not CharInSet(aText[i], [#10, #13]) then
      aText[i] := ' ';
end;

procedure TDelphiSemanticExtractionContext.RecordTypeMemberActivity(
  const aRange: TTypeMemberActivityRange);
var
  lIndex: Integer;
begin
  lIndex := Length(fTypeMemberActivityRanges);
  SetLength(fTypeMemberActivityRanges, lIndex + 1);
  fTypeMemberActivityRanges[lIndex] := aRange;
end;

procedure TDelphiSemanticExtractionContext.PublishTypeBodyRanges(
  const aPreprocess: TDelphiSemanticPreprocessResult;
  const aDeclarations: TList<TDelphiSemanticDeclaration>);
var
  i: Integer;
  lDeclaration: TDelphiSemanticDeclaration;
  lFirst, lLast, lOrigin: TDelphiSemanticSourceLineOrigin;
  lRange: TTypeMemberActivityRange;
  lVerified: Boolean;
begin
  for lRange in fTypeMemberActivityRanges do
  begin
    if (lRange.DeclarationIndex < 0) or (lRange.DeclarationIndex >= aDeclarations.Count) or
      (lRange.StartLine <= 0) or (lRange.EndLine > Length(aPreprocess.LineOrigins)) then
      Continue;
    lFirst := aPreprocess.LineOrigins[lRange.StartLine - 1];
    lLast := aPreprocess.LineOrigins[lRange.EndLine - 1];
    lVerified := (lFirst.Line > 0) and (lLast.Line >= lFirst.Line) and
      (lRange.EndColumn > 0) and (lFirst.FileName <> '') and
      SameText(lFirst.FileName, lLast.FileName);
    lDeclaration := aDeclarations[lRange.DeclarationIndex];
    // Standalone includes do not destroy the parent's AST endpoints. Mixed inline
    // origins still have no exact physical containment authority.
    for i := lRange.StartLine - 1 to lRange.EndLine - 1 do
    begin
      lOrigin := aPreprocess.LineOrigins[i];
      if lOrigin.Mixed or (lOrigin.Line <= 0) or (lOrigin.FileName = '') then
      begin
        lVerified := False;
        Continue;
      end;
    end;
    if not lVerified or (lDeclaration.Line <> lFirst.Line) then
      Continue;
    lDeclaration.TypeBodyEndLine := lLast.Line;
    lDeclaration.TypeBodyEndColumn := lRange.EndColumn;
    aDeclarations[lRange.DeclarationIndex] := lDeclaration;
  end;
end;

procedure TDelphiSemanticExtractionContext.PublishTypeMemberActivity(
  const aModel: TDelphiSemanticUnitModel;
  const aPreprocess: TDelphiSemanticPreprocessResult; const aOffsetMap: TArray<Integer>;
  const aDeclarations: TList<TDelphiSemanticDeclaration>;
  const aDiagnostics: TList<TDelphiSemanticModelDiagnostic>);
var
  i: Integer;
  lRange: TTypeMemberActivityRange;
  lOrigin, lSegmentFirst, lSegmentLast: TDelphiSemanticSourceLineOrigin;
  lSpan: TDelphiSemanticActivitySpan;
  lDeclaration: TDelphiSemanticDeclaration;
  lFileName: string;
  lLine, lRawStart, lRawEnd, lSpanStartLine, lSpanEndLine: Integer;
  lMapped, lOriginsKnown, lUnverified: Boolean;
begin
  // No-context extraction publishes no project activity authority.
  if aModel.VerifiedActiveSourceText = '' then
    Exit;
  for lRange in fTypeMemberActivityRanges do
  begin
    lMapped := (lRange.Range.StartOffset > 0) and
      (lRange.Range.EndOffset > lRange.Range.StartOffset) and
      (lRange.Range.EndOffset - 1 < Length(aOffsetMap));
    lRawStart := 0;
    lRawEnd := 0;
    if lMapped then
    begin
      lRawStart := aOffsetMap[lRange.Range.StartOffset];
      lRawEnd := aOffsetMap[lRange.Range.EndOffset - 1];
      lMapped := (lRawStart > 0) and (lRawEnd >= lRawStart);
    end;
    lOriginsKnown := (lRange.StartLine > 0) and
      (lRange.EndLine <= Length(aPreprocess.LineOrigins));
    if lOriginsKnown then
    begin
      for i := lRange.StartLine - 1 to lRange.EndLine - 1 do
      begin
        lOrigin := aPreprocess.LineOrigins[i];
        if lOrigin.Mixed or (lOrigin.Line <= 0) or
          (not SameText(lOrigin.FileName, aModel.FileName)) then
          lMapped := False;
        if lOrigin.Mixed or (lOrigin.Line <= 0) or (lOrigin.FileName = '') or
          (lOrigin.ExpansionId = '') then
          lOriginsKnown := False;
      end;
    end;
    if lMapped then
      lUnverified := not TDelphiSemanticSourceConditionals.RangeIsKnownActive(
        aModel.SourceText, aModel.VerifiedActiveSourceText, lRawStart, lRawEnd)
    else if lOriginsKnown and aPreprocess.ActivityEvidenceAvailable then
    begin
      lUnverified := False;
      // Partition only output lines inside this body by physical origin and inclusion
      // instance. Reusing an include elsewhere cannot taint this occurrence.
      i := lRange.StartLine - 1;
      while (i < lRange.EndLine) and (not lUnverified) do
      begin
        lSegmentFirst := aPreprocess.LineOrigins[i];
        lSegmentLast := lSegmentFirst;
        Inc(i);
        while i < lRange.EndLine do
        begin
          lOrigin := aPreprocess.LineOrigins[i];
          if (not SameText(lOrigin.FileName, lSegmentFirst.FileName)) or
            (lOrigin.ExpansionId <> lSegmentFirst.ExpansionId) or
            (lOrigin.Line < lSegmentLast.Line) then
            Break;
          lSegmentLast := lOrigin;
          Inc(i);
        end;
        for lSpan in aPreprocess.ActivitySpans do
          if (lSpan.Activity = TDelphiSemanticSourceActivity.saUnknown) and
            SameText(lSpan.FileName, lSegmentFirst.FileName) and
            (lSpan.ExpansionId = lSegmentFirst.ExpansionId) then
          begin
            lSpanStartLine := LineOfOffset(lSpan.SourceText, lSpan.StartOffset);
            lSpanEndLine := LineOfOffset(lSpan.SourceText, lSpan.EndOffset - 1);
            if (lSpanStartLine <= lSegmentLast.Line) and
              (lSpanEndLine >= lSegmentFirst.Line) then
            begin
              lUnverified := True;
              Break;
            end;
          end;
      end;
    end else
      lUnverified := aPreprocess.HasUnknownActivity or
        (not aPreprocess.ActivityEvidenceAvailable);
    if not lUnverified then
      Continue;
    lFileName := lRange.FileName;
    lLine := lRange.StartLine;
    if (lRange.DeclarationIndex >= 0) and
      (lRange.DeclarationIndex < aDeclarations.Count) then
    begin
      lDeclaration := aDeclarations[lRange.DeclarationIndex];
      if lDeclaration.FileName <> '' then
        lFileName := lDeclaration.FileName;
      lLine := lDeclaration.Line;
    end;
    AddDiagnostic(aDiagnostics, 'MEMBERS_ACTIVITY_UNVERIFIED', lRange.OwnerName +
      ': declaration contains source whose conditional activity is unknown; ' +
      'its members are unverified.', lFileName, lLine);
  end;
end;

function ExtractTypeMembers(const aText, aOwnerPrefix, aFileName: string;
  const aNode: TSyntaxNode; const aDiagnostics: TList<TDelphiSemanticModelDiagnostic>;
  const aDeclarations: TList<TDelphiSemanticDeclaration>;
  const aMembers: TList<TDelphiSemanticMember>;
  const aReferences: TList<TDelphiSemanticReference>): Boolean;
var
  lBody: string;
  lBodyOffset: Integer;
  lEnd: Integer;
  lActivityRange: TTypeMemberActivityRange;
  lDeclaration: TDelphiSemanticDeclaration;
  i: Integer;
  lMatchingDeclarations: Integer;
  lFacts: TList<TAstMemberFact>;
  lFirstMember: Integer;
  lHeader: TMatch;
  lNested: TList<TSyntaxNode>;
  lNestedNode: TSyntaxNode;
  lOwnerName: string;
  lSplitOffsets: TArray<Integer>;
  lSplits: TList<Integer>;
  lStart: Integer;
  lText: string;
  lTypeNode: TSyntaxNode;
  lUnscanned: string;
begin
  Result := False;
  if (aNode.Typ <> ntTypeDecl) or not (aNode is TCompoundSyntaxNode) then
    Exit;
  lTypeNode := aNode.FindNode(ntType);
  if not Assigned(lTypeNode) or not MatchText(lTypeNode.GetAttribute(anType),
    ['class', 'interface', 'record']) then
    Exit;
  Result := True;
  // The AST bounds the declaration, including same-line end tokens.
  lStart := OffsetOfLineColumn(aText, aNode.Line, aNode.Col);
  lEnd := OffsetOfLineColumn(aText, TCompoundSyntaxNode(aNode).EndLine,
    TCompoundSyntaxNode(aNode).EndCol);
  lText := Copy(aText, lStart, lEnd - lStart);
  lHeader := TRegEx.Match(lText,
    '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*((?:class|record)\s+helper\s+for\s+' +
    '[A-Za-z_][A-Za-z0-9_.]*|(?:class|interface)(?:\s*\([^)]+\))?|' +
    '(?:packed\s+)?record)\b', [roIgnoreCase]);
  // An unreadable header (a generic type, for example) has no type declaration either.
  if not lHeader.Success then
    Exit;
  lOwnerName := lHeader.Groups[1].Value;
  if aOwnerPrefix <> '' then
    lOwnerName := aOwnerPrefix + '.' + lOwnerName;
  lActivityRange := Default(TTypeMemberActivityRange);
  lActivityRange.Range.StartOffset := lStart;
  lActivityRange.Range.EndOffset := lEnd;
  lActivityRange.StartLine := aNode.Line;
  lActivityRange.EndLine := TCompoundSyntaxNode(aNode).EndLine;
  lActivityRange.EndColumn := TCompoundSyntaxNode(aNode).EndCol;
  lActivityRange.FileName := aFileName;
  lActivityRange.OwnerName := lOwnerName;
  lActivityRange.DeclarationIndex := -1;
  lMatchingDeclarations := 0;
  for i := 0 to aDeclarations.Count - 1 do
  begin
    lDeclaration := aDeclarations[i];
    if SameText(lDeclaration.Kind, 'type') and
      SameText(lDeclaration.Name, lHeader.Groups[1].Value) and
      (lDeclaration.Line = aNode.Line) then
    begin
      Inc(lMatchingDeclarations);
      lActivityRange.DeclarationIndex := i;
    end;
  end;
  if lMatchingDeclarations <> 1 then
    lActivityRange.DeclarationIndex := -1;
  ActiveExtractionContext.RecordTypeMemberActivity(lActivityRange);
  lFacts := TList<TAstMemberFact>.Create;
  lSplits := nil;
  lNested := nil;
  try
    lSplits := TList<Integer>.Create;
    lNested := TList<TSyntaxNode>.Create;
    CollectAstTypeMembers(aText, lTypeNode, 'public', lFacts, lSplits, lNested);
    lSplits.Sort;
    lSplitOffsets := lSplits.ToArray;
    lBodyOffset := lStart + lHeader.Length;
    lBody := Copy(lText, lHeader.Length + 1, MaxInt);
    // Nested declarations get their own owner; blanking them keeps the outer offsets unchanged.
    for lNestedNode in lNested do
      if lNestedNode is TCompoundSyntaxNode then
        BlankRange(lBody, OffsetOfLineColumn(aText, lNestedNode.Line, lNestedNode.Col) -
          lBodyOffset + 1, OffsetOfLineColumn(aText, TCompoundSyntaxNode(lNestedNode).EndLine,
          TCompoundSyntaxNode(lNestedNode).EndCol) - lBodyOffset);
    lFirstMember := aMembers.Count;
    ExtractMembersFromBody(aText, lOwnerName, lBody, lBodyOffset, aDeclarations, aMembers,
      aReferences, lSplitOffsets);
    // Missed names are listed so an unsupported layout is recorded, not just refused later.
    if not ReconcileTypeMembers(aText, lBody, lOwnerName, lFacts, lSplitOffsets, aMembers,
      aReferences, lFirstMember, lUnscanned) then
      AddDiagnostic(aDiagnostics, 'MEMBERS_INCOMPLETE', Format('Members of %s could not be ' +
        'reconciled with the syntax tree; its member facts are incomplete. Not scanned: %s.',
        [lOwnerName, lUnscanned]), aFileName, aNode.Line);
    // DelphiAST omits ordinary class constants and parses some soft-keyword names
    // as fields. Neither shape establishes a complete, correctly classified member list.
    if TRegEx.IsMatch(SanitizeCodeText(lBody), '\bclass\s+const\b', [roIgnoreCase]) then
      AddDiagnostic(aDiagnostics, 'MEMBERS_INCOMPLETE', Format('Members of %s are incomplete: ' +
        'class constants are not modelled reliably.', [lOwnerName]), aFileName, aNode.Line);
    for lNestedNode in lNested do
      ExtractTypeMembers(aText, lOwnerName, aFileName, lNestedNode, aDiagnostics, aDeclarations,
        aMembers, aReferences);
  finally
    lNested.Free;
    lSplits.Free;
    lFacts.Free;
  end;
end;

procedure ExtractMembers(const aText, aFileName: string; const aNode: TSyntaxNode;
  const aDiagnostics: TList<TDelphiSemanticModelDiagnostic>;
  const aDeclarations: TList<TDelphiSemanticDeclaration>;
  const aMembers: TList<TDelphiSemanticMember>;
  const aReferences: TList<TDelphiSemanticReference>);
var
  lPending: TStack<TSyntaxNode>;
  lNode: TSyntaxNode;
  i: Integer;
begin
  lPending := TStack<TSyntaxNode>.Create;
  try
    lPending.Push(aNode);
    while lPending.Count > 0 do
    begin
      lNode := lPending.Pop;
      if not ExtractTypeMembers(aText, '', aFileName, lNode, aDiagnostics, aDeclarations,
        aMembers, aReferences) then
        for i := High(lNode.ChildNodes) downto 0 do
          lPending.Push(lNode.ChildNodes[i]);
    end;
  finally
    lPending.Free;
  end;
end;

// A block header opens a body unless it is a forward, class-of, empty-descendant or one-line
// declaration.
function FallbackHeaderOpensBody(const aRest: string): Boolean;
var
  lRest: string;
begin
  lRest := Trim(aRest);
  Result := not (StartsText(';', lRest) or TRegEx.IsMatch(lRest, '^of\b', [roIgnoreCase]) or
    TRegEx.IsMatch(lRest, '^\([^)]*\)\s*;', [roIgnoreCase]) or
    TRegEx.IsMatch(lRest, '\bend\s*;', [roIgnoreCase]));
end;

// Without a syntax tree, a parameter on a heading's continuation line would read as a field.
procedure BlankHeadingContinuations(var aBody: string);
var
  i: Integer;
  lClean: string;
  lDepth: Integer;
  lLine: string;
  lLineEnd: Integer;
  lLineStart: Integer;
begin
  lClean := SanitizeCodeText(aBody);
  lDepth := 0;
  lLineStart := 1;
  while lLineStart <= Length(lClean) do
  begin
    lLineEnd := lLineStart;
    while (lLineEnd <= Length(lClean)) and not CharInSet(lClean[lLineEnd], [#10, #13]) do
      Inc(lLineEnd);
    lLine := Copy(lClean, lLineStart, lLineEnd - lLineStart);
    if lDepth > 0 then
      BlankRange(aBody, lLineStart, lLineEnd - 1);
    if (lDepth > 0) or TRegEx.IsMatch(lLine, '^\s*(?:(?:strict\s+)?(?:private|protected|' +
      'public|published)\s+)?(?:class\s+)?(?:procedure|function|constructor|destructor|' +
      'property)\b', [roIgnoreCase]) then
    begin
      for i := 1 to Length(lLine) do
        if CharInSet(lLine[i], ['(', '[']) then
          Inc(lDepth)
        else if CharInSet(lLine[i], [')', ']']) and (lDepth > 0) then
          Dec(lDepth);
    end;
    lLineStart := lLineEnd;
    while (lLineStart <= Length(lClean)) and CharInSet(lClean[lLineStart], [#10, #13]) do
      Inc(lLineStart);
  end;
end;

// Bounded member scan for a unit whose syntax tree is unavailable. Each block ends at its own
// `end;` line, so members never leak into later types; nested named types get qualified owners
// and are blanked from their parent. Class variables are left out: global-vars reports every
// class-var member as a verified declaration. Returns the number of scanned types.
function ExtractFallbackMembers(const aText: string;
  const aDeclarations: TList<TDelphiSemanticDeclaration>;
  const aMembers: TList<TDelphiSemanticMember>;
  const aReferences: TList<TDelphiSemanticReference>;
  out aOmittedClassVariables: Integer): Integer;
var
  i: Integer;
  j: Integer;
  lBlock: TFallbackTypeBlock;
  lBlocks: TList<TFallbackTypeBlock>;
  lBody: string;
  lCleanLine: string;
  lFirstMember: Integer;
  lHeader: TMatch;
  lLines: TStringList;
  lOffset: Integer;
  lParent: TFallbackTypeBlock;
  lRange: TOffsetRange;
begin
  Result := 0;
  aOmittedClassVariables := 0;
  lLines := TStringList.Create;
  lBlocks := nil;
  try
    lBlocks := TList<TFallbackTypeBlock>.Create;
    lLines.Text := SanitizeCodeText(aText);
    lOffset := 1;
    for i := 0 to Pred(lLines.Count) do
    begin
      lCleanLine := lLines[i];
      lHeader := TRegEx.Match(lCleanLine, '^\s*(?:type\s+)?([A-Za-z_][A-Za-z0-9_]*)' +
        '(?:\s*<[^>]*>)?\s*=\s*(?:packed\s+)?(?:class|record|interface)\b(?:\s*\([^)]*\))?',
        [roIgnoreCase]);
      if lHeader.Success and FallbackHeaderOpensBody(Copy(lCleanLine,
        lHeader.Index + lHeader.Length, MaxInt)) then
      begin
        lBlock := Default(TFallbackTypeBlock);
        lBlock.OwnerName := lHeader.Groups[1].Value;
        if lBlocks.Count > 0 then
          lBlock.OwnerName := lBlocks[lBlocks.Count - 1].OwnerName + '.' + lBlock.OwnerName;
        lBlock.HeaderOffset := lOffset + lHeader.Groups[1].Index - 1;
        lBlock.BodyOffset := lOffset + lHeader.Index + lHeader.Length - 1;
        lBlocks.Add(lBlock);
      end else if lBlocks.Count > 0 then
      begin
        lBlock := lBlocks[lBlocks.Count - 1];
        if TRegEx.IsMatch(lCleanLine, '^\s*[A-Za-z_][A-Za-z0-9_]*\s*:\s*(?:packed\s+)?record\b',
          [roIgnoreCase]) and not TRegEx.IsMatch(lCleanLine, '\bend\s*;', [roIgnoreCase]) then
        begin
          Inc(lBlock.AnonymousRecordDepth);
          lBlocks[lBlocks.Count - 1] := lBlock;
        end else if TRegEx.IsMatch(lCleanLine, '^\s*end\s*;', [roIgnoreCase]) then
        begin
          if lBlock.AnonymousRecordDepth > 0 then
          begin
            Dec(lBlock.AnonymousRecordDepth);
            lBlocks[lBlocks.Count - 1] := lBlock;
          end else
          begin
            lBlocks.Delete(lBlocks.Count - 1);
            lBody := Copy(aText, lBlock.BodyOffset, lOffset - lBlock.BodyOffset);
            for lRange in lBlock.NestedRanges do
              BlankRange(lBody, lRange.StartOffset - lBlock.BodyOffset + 1,
                lRange.EndOffset - lBlock.BodyOffset);
            BlankHeadingContinuations(lBody);
            lFirstMember := aMembers.Count;
            ExtractMembersFromBody(aText, lBlock.OwnerName, lBody, lBlock.BodyOffset,
              aDeclarations, aMembers, aReferences, nil);
            for j := Pred(aMembers.Count) downto lFirstMember do
              if SameText(aMembers[j].Kind, 'class-var') then
              begin
                aMembers.Delete(j);
                Inc(aOmittedClassVariables);
              end;
            Inc(Result);
            if lBlocks.Count > 0 then
            begin
              lParent := lBlocks[lBlocks.Count - 1];
              lRange.StartOffset := lBlock.HeaderOffset;
              lRange.EndOffset := lOffset + Length(lCleanLine);
              lParent.NestedRanges := lParent.NestedRanges + [lRange];
              lBlocks[lBlocks.Count - 1] := lParent;
            end;
          end;
        end;
      end;
      Inc(lOffset, Length(lCleanLine) + Length(sLineBreak));
    end;
  finally
    lBlocks.Free;
    lLines.Free;
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
    lText := SanitizeCodeText(lText);
    for lParameter in lText.Split([';']) do
    begin
      lMatch := TRegEx.Match(lParameter.Trim,
        '^(?:(const|var|out)\s+)?([A-Za-z_][A-Za-z0-9_,\s]*)\s*:\s*([^=]+?)(?:\s*=.*)?$',
        [roIgnoreCase, roSingleLine]);
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

  lParameterText := SanitizeCodeText(lParameterText);
  lMatch := TRegEx.Match(lParameterText,
    '(?:(?:const|var|out)\s+)?[A-Za-z_][A-Za-z0-9_,\s]*\s*:\s*([^;=\)\r\n]+)',
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
  lRoutine := Default(TDelphiSemanticRoutine);
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

function AtFollowingRoutine(const aLexer: TmwBasePasLex; var aNextMatch: TMatch): Boolean;
begin
  while aNextMatch.Success and (MatchGroupIndex(aNextMatch, 1) < aLexer.TokenPos + 1) do
    aNextMatch := aNextMatch.NextMatch;
  Result := aNextMatch.Success and (MatchGroupIndex(aNextMatch, 1) = aLexer.TokenPos + 1) and
    (aLexer.TokenID in [ptProcedure, ptFunction, ptConstructor, ptDestructor]);
end;

function TryReadRoutineHeader(const aText: string; const aLexer: TmwBasePasLex;
  var aNextMatch: TMatch; out aHeader: TRoutineHeader): Boolean;
var
  lDepth: Integer;
begin
  Result := False;
  aHeader := Default(TRoutineHeader);
  if aLexer.TokenID = ptRoundOpen then
  begin
    aHeader.SignatureOffset := aLexer.TokenPos + 1;
    lDepth := 1;
    repeat
      aLexer.NextNoJunk;
      if AtFollowingRoutine(aLexer, aNextMatch) then
        Exit;
      if aLexer.TokenID in [ptNull, ptBegin, ptEnd] then
        Exit;
      if aLexer.TokenID = ptRoundOpen then
        Inc(lDepth)
      else if aLexer.TokenID = ptRoundClose then
        Dec(lDepth);
    until lDepth = 0;
    aHeader.Signature := Copy(aText, aHeader.SignatureOffset,
      aLexer.TokenPos + aLexer.TokenLen - aHeader.SignatureOffset + 1);
    aLexer.NextNoJunk;
  end;
  if aLexer.TokenID = ptColon then
  begin
    aLexer.NextNoJunk;
    aHeader.ReturnTypeOffset := aLexer.TokenPos + 1;
    while not (aLexer.TokenID in [ptSemiColon, ptNull, ptBegin, ptEnd]) do
    begin
      if AtFollowingRoutine(aLexer, aNextMatch) then
        Exit;
      aLexer.NextNoJunk;
    end;
    if (aLexer.TokenID <> ptSemiColon) or
      (aLexer.TokenPos + 1 = aHeader.ReturnTypeOffset) then
      Exit;
    aHeader.ReturnType := Trim(Copy(aText, aHeader.ReturnTypeOffset,
      aLexer.TokenPos - aHeader.ReturnTypeOffset + 1));
  end;
  Result := aLexer.TokenID = ptSemiColon;
end;

procedure ExtractRoutines(const aText: string; const aDeclarations: TList<TDelphiSemanticDeclaration>;
  const aRoutines: TList<TDelphiSemanticRoutine>;
  const aReferences: TList<TDelphiSemanticReference>);
var
  lHeader: TRoutineHeader;
  lLexer: TmwBasePasLex;
  lMatch: TMatch;
  lNameOffset: Integer;
  lNextMatch: TMatch;
  lOwnerName: string;
  lPrefix: string;
  lRoutineName: string;
  lSection: string;
begin
  lLexer := TmwBasePasLex.Create;
  try
    lLexer.UseDefines := False;
    lLexer.Origin := aText;
    lMatch := TRegEx.Match(aText,
      '^\s*(?:class\s+)?(procedure|function|constructor|destructor)\s+' +
      '((?:[A-Za-z_][A-Za-z0-9_]*\.)?)' +
      '([A-Za-z_][A-Za-z0-9_]*)\s*', [roIgnoreCase, roMultiLine]);
    while lMatch.Success do
    begin
      lNextMatch := lMatch.NextMatch;
      // Advance once through the unit so comment/string matches cannot become routines.
      while (lLexer.TokenID <> ptNull) and
        (lLexer.TokenPos + 1 < MatchGroupIndex(lMatch, 1)) do
        lLexer.NextNoJunk;
      if (lLexer.TokenPos + 1 <> MatchGroupIndex(lMatch, 1)) or
        (not (lLexer.TokenID in [ptProcedure, ptFunction, ptConstructor, ptDestructor])) or
        IsOffsetInsideTypeBlock(aText, lMatch.Index + 1) then
      begin
        lMatch := lNextMatch;
        Continue;
      end;
      while (lLexer.TokenID <> ptNull) and
        (lLexer.TokenPos + 1 < lMatch.Index + lMatch.Length) do
        lLexer.NextNoJunk;
      if not TryReadRoutineHeader(aText, lLexer, lNextMatch, lHeader) then
      begin
        lMatch := lNextMatch;
        Continue;
      end;
      lPrefix := lMatch.Groups[2].Value;
      lRoutineName := lMatch.Groups[3].Value;
      lOwnerName := lPrefix.Trim;
      if EndsText('.', lOwnerName) then
        lOwnerName := Copy(lOwnerName, 1, Length(lOwnerName) - 1);
      lNameOffset := lMatch.Index + Pos(lRoutineName, lMatch.Value) - 1;
      lSection := SectionForOffset(aText, lMatch.Index + 1);
      AddRoutine(aRoutines, lRoutineName, lOwnerName, lSection, lHeader.Signature,
        lHeader.ReturnType, aText, lNameOffset, lHeader.SignatureOffset);
      AddParameterTypeReferences(aReferences, QualifiedRoutineName(lOwnerName, lRoutineName),
        lHeader.Signature, aText, lHeader.SignatureOffset);
      AddTypeReferences(aReferences, QualifiedRoutineName(lOwnerName, lRoutineName),
        lHeader.ReturnType, aText, lHeader.ReturnTypeOffset);
      if lOwnerName = '' then
        AddDeclaration(aDeclarations, lRoutineName, 'routine', lHeader.ReturnType,
          lSection, aText, lNameOffset);
      lMatch := lNextMatch;
    end;
  finally
    lLexer.Free;
  end;
end;

// Scans the declaration part [aStartOffset, aEndOffset) of one routine line by line. A var
// section ends at the next section keyword, so fields of a local record type are no locals.
procedure ExtractLocalsFromRoutine(const aText, aRoutineName: string;
  const aStartOffset, aEndOffset: Integer; const aLocals: TList<TDelphiSemanticLocal>;
  const aReferences: TList<TDelphiSemanticReference>);
var
  lInVarSection: Boolean;
  lLine: string;
  lLineEnd: Integer;
  lLineStart: Integer;
  lLocalMatch: TMatch;
  lName: string;
  lNameOffset: Integer;
  lNames: string;
  lRawLine: string;
  lRawName: string;
begin
  lInVarSection := False;
  lLineStart := aStartOffset;
  while lLineStart < aEndOffset do
  begin
    lLineEnd := lLineStart;
    while (lLineEnd < aEndOffset) and not CharInSet(aText[lLineEnd], [#10, #13]) do
      Inc(lLineEnd);
    lRawLine := Copy(aText, lLineStart, lLineEnd - lLineStart);
    lLine := lRawLine.Trim;
    if SameText(lLine, 'var') then
      lInVarSection := True
    else if SameText(lLine, 'begin') then
      Break
    else if TextHasWordAt(lLine, 1, 'type') or TextHasWordAt(lLine, 1, 'const') or
      TextHasWordAt(lLine, 1, 'resourcestring') or TextHasWordAt(lLine, 1, 'label') then
      lInVarSection := False
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
          lNameOffset := TextOffsetInLine(lRawLine, lName, lLineStart);
          AddLocal(aLocals, aRoutineName, lName, 'var',
            lLocalMatch.Groups[2].Value.Trim, aText, lNameOffset);
        end;
        AddTypeReferences(aReferences, aRoutineName, lLocalMatch.Groups[2].Value.Trim, aText,
          TextOffsetInLine(lRawLine, lLocalMatch.Groups[2].Value.Trim, lLineStart));
      end;
    end;
    lLineStart := lLineEnd;
    if (lLineStart < aEndOffset) and (aText[lLineStart] = #13) then
      Inc(lLineStart);
    if (lLineStart < aEndOffset) and (aText[lLineStart] = #10) then
      Inc(lLineStart);
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

// Line-scan fallback for units without a syntax tree only: a routine's span runs to the next
// header, so its facts are unverified ('ast-failed') and consumers must not trust them.
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
      '^\s*(?:class\s+)?(?:procedure|function|constructor|destructor)\s+' +
      '((?:[A-Za-z_][A-Za-z0-9_]*\.)?)' +
      '([A-Za-z_][A-Za-z0-9_]*)[^;\r\n]*;',
      [roIgnoreCase, roMultiLine]);
    while lMatch.Success do
    begin
      if not IsOffsetInsideTypeBlock(aText, lMatch.Index + 1) then
      begin
        lNames.Add(QualifiedRoutineName(MatchGroupValue(lMatch, 1).Trim.TrimRight(['.']),
          MatchGroupValue(lMatch, 2)));
        lStarts.Add(lMatch.Index);
      end;
      lMatch := lMatch.NextMatch;
    end;

    for i := 0 to Pred(lStarts.Count) do
    begin
      if i < Pred(lStarts.Count) then
        lEndOffset := lStarts[i + 1]
      else
        lEndOffset := Length(aText);

      lRoutineText := Copy(aText, lStarts[i] + 1, lEndOffset - lStarts[i]);
      ExtractLocalsFromRoutine(aText, lNames[i], lStarts[i] + 1, lEndOffset + 1, aLocals,
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
  lBlockKinds: TArray<string>;
  lClosedBlockKind: string;
  lCommentMode: Integer;
  lLastCodeEndOffset: Integer;
  lPreviousCodeToken: string;
  lTokenEndOffset: Integer;
  lTokenStartOffset: Integer;
  lTopLevelThenCount: Integer;
  lToken: string;

  procedure PushBlockKind(const aKind: string);
  var
    lIndex: Integer;
  begin
    lIndex := Length(lBlockKinds);
    SetLength(lBlockKinds, lIndex + 1);
    lBlockKinds[lIndex] := LowerCase(aKind);
  end;

  function PopBlockKind: string;
  begin
    Result := '';
    if Length(lBlockKinds) = 0 then
      Exit;
    Result := lBlockKinds[High(lBlockKinds)];
    SetLength(lBlockKinds, Length(lBlockKinds) - 1);
  end;

  function NextCodeTokenEquals(const aStartIndex: Integer; const aToken: string):
    Boolean;
  var
    lIndex: Integer;
    lTokenText: string;
  begin
    Result := False;
    lIndex := aStartIndex;
    while lIndex <= Length(aText) do
    begin
      if CharInSet(aText[lIndex], [#9, #10, #13, ' ']) then
      begin
        Inc(lIndex);
        Continue;
      end;
      if (aText[lIndex] = '/') and (lIndex < Length(aText)) and
        (aText[lIndex + 1] = '/') then
      begin
        while (lIndex <= Length(aText)) and
          (not CharInSet(aText[lIndex], [#10, #13])) do
          Inc(lIndex);
        Continue;
      end;
      if aText[lIndex] = '{' then
      begin
        Inc(lIndex);
        while (lIndex <= Length(aText)) and (aText[lIndex] <> '}') do
          Inc(lIndex);
        if lIndex <= Length(aText) then
          Inc(lIndex);
        Continue;
      end;
      if (aText[lIndex] = '(') and (lIndex < Length(aText)) and
        (aText[lIndex + 1] = '*') then
      begin
        Inc(lIndex, 2);
        while (lIndex < Length(aText)) and
          ((aText[lIndex] <> '*') or (aText[lIndex + 1] <> ')')) do
          Inc(lIndex);
        if lIndex < Length(aText) then
          Inc(lIndex, 2);
        Continue;
      end;
      Break;
    end;
    if (lIndex > Length(aText)) or
      (not CharInSet(aText[lIndex], ['A'..'Z', 'a'..'z', '_'])) then
      Exit;

    lTokenText := '';
    while (lIndex <= Length(aText)) and
      CharInSet(aText[lIndex], ['A'..'Z', 'a'..'z', '0'..'9', '_']) do
    begin
      lTokenText := lTokenText + aText[lIndex];
      Inc(lIndex);
    end;
    Result := SameText(lTokenText, aToken);
  end;

  function FindNextSemicolonOutsideTrivia(const aStartIndex: Integer): Integer;
  var
    lIndex: Integer;
  begin
    lIndex := aStartIndex;
    while lIndex <= Length(aText) do
    begin
      if aText[lIndex] = '''' then
      begin
        Inc(lIndex);
        while lIndex <= Length(aText) do
        begin
          if aText[lIndex] = '''' then
          begin
            if (lIndex < Length(aText)) and (aText[lIndex + 1] = '''') then
              Inc(lIndex)
            else
              Break;
          end;
          Inc(lIndex);
        end;
      end else if (aText[lIndex] = '/') and (lIndex < Length(aText)) and
        (aText[lIndex + 1] = '/') then
      begin
        while (lIndex <= Length(aText)) and
          (not CharInSet(aText[lIndex], [#10, #13])) do
          Inc(lIndex);
      end else if aText[lIndex] = '{' then
      begin
        Inc(lIndex);
        while (lIndex <= Length(aText)) and (aText[lIndex] <> '}') do
          Inc(lIndex);
      end else if (aText[lIndex] = '(') and (lIndex < Length(aText)) and
        (aText[lIndex + 1] = '*') then
      begin
        Inc(lIndex, 2);
        while (lIndex < Length(aText)) and
          ((aText[lIndex] <> '*') or (aText[lIndex + 1] <> ')')) do
          Inc(lIndex);
        if lIndex < Length(aText) then
          Inc(lIndex);
      end else if aText[lIndex] = ';' then
        Exit(lIndex);
      Inc(lIndex);
    end;

    Result := Length(aText);
  end;

  function PreviousNonWhitespaceOffset(const aStartIndex: Integer): Integer;
  begin
    Result := aStartIndex;
    while (Result > 0) and CharInSet(aText[Result], [#9, #10, #13, ' ']) do
      Dec(Result);
  end;
begin
  if (aBodyStartOffset < 1) or (aBodyStartOffset > Length(aText)) then
    Exit(Length(aText));

  lBlockDepth := 0;
  lCommentMode := 0;
  lLastCodeEndOffset := 0;
  lPreviousCodeToken := '';
  lTopLevelThenCount := 0;
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
      lTokenStartOffset := i;
      while (i <= Length(aText)) and CharInSet(aText[i], ['A'..'Z', 'a'..'z', '0'..'9', '_']) do
      begin
        lToken := lToken + aText[i];
        Inc(i);
      end;
      Dec(i);
      lTokenEndOffset := i;
      // DS-671: escaped words are identifiers, never block/control tokens.
      if (lTokenStartOffset > 1) and (aText[lTokenStartOffset - 1] = '&') then
      begin
        lPreviousCodeToken := '&' + lToken;
        lLastCodeEndOffset := lTokenEndOffset;
        Inc(i);
        Continue;
      end;
      if SameText(lToken, 'then') and (lBlockDepth = 0) then
        Inc(lTopLevelThenCount);
      if SameText(lToken, 'else') and (lBlockDepth = 0) then
      begin
        if lTopLevelThenCount > 0 then
          Dec(lTopLevelThenCount)
        else if lLastCodeEndOffset > 0 then
          Exit(PreviousNonWhitespaceOffset(lTokenStartOffset - 1));
      end;
      if SameText(lToken, 'begin') or SameText(lToken, 'case') or
        SameText(lToken, 'try') then
      begin
        PushBlockKind(lPreviousCodeToken);
        Inc(lBlockDepth);
      end else if SameText(lToken, 'repeat') then
      begin
        PushBlockKind('repeat');
        Inc(lBlockDepth);
      end else if SameText(lToken, 'until') and
        (Length(lBlockKinds) > 0) and SameText(lBlockKinds[High(lBlockKinds)],
        'repeat') then
      begin
        Dec(lBlockDepth);
        PopBlockKind;
      end else if SameText(lToken, 'end') then
      begin
        if lBlockDepth = 0 then
          Exit(PreviousNonWhitespaceOffset(lTokenStartOffset - 1));
        Dec(lBlockDepth);
        lClosedBlockKind := PopBlockKind;
        if lBlockDepth = 0 then
        begin
          if NextCodeTokenEquals(i + 1, 'else') then
          begin
            if (lTopLevelThenCount > 0) or SameText(lClosedBlockKind, 'then') then
            begin
              lPreviousCodeToken := lToken;
              lLastCodeEndOffset := lTokenEndOffset;
              Inc(i);
              Continue;
            end;
            Exit(i);
          end;
          if NextCodeTokenEquals(i + 1, 'end') then
            Exit(lTokenEndOffset);
          Exit(FindNextSemicolonOutsideTrivia(i));
        end;
      end;
      lPreviousCodeToken := lToken;
      lLastCodeEndOffset := lTokenEndOffset;
    end else if (aText[i] = ';') and (lBlockDepth = 0) then
      Exit(i);
    Inc(i);
  end;

  Exit(Length(aText));
end;

procedure ExtractWithStatements(const aText: string; const aItems: TList<TDelphiSemanticWithStatement>;
  const aRangeText: string = '');
var
  i: Integer;
  lBodyStartOffset: Integer;
  lCleanText: string;
  lSourceText: string;
  lEndOffset: Integer;
  lItem: TDelphiSemanticWithStatement;
  lMatch: TMatch;
  lSelectorParts: TArray<string>;
begin
  // Active witnesses select headers; the raw source owns body text and statement ends.
  // Inactive references retain base checking and unknown suffixes retain their apply barrier.
  lSourceText := aRangeText;
  if lSourceText = '' then
    lSourceText := aText;
  lCleanText := SanitizeCodeText(aText);
  lMatch := TRegEx.Match(lCleanText, '(?<!&)\bwith\b\s+(.*?)\s+(?<!&)\bdo\b', [roIgnoreCase, roSingleLine]);
  while lMatch.Success do
  begin
    lItem := Default(TDelphiSemanticWithStatement);
    lBodyStartOffset := lMatch.Index + lMatch.Length;
    lEndOffset := FindWithStatementEndOffset(lSourceText, lBodyStartOffset);
    lItem.Line := LineOfOffset(lSourceText, lMatch.Index);
    lItem.Column := ColumnOfOffset(lSourceText, lMatch.Index);
    lItem.EndLine := LineOfOffset(lSourceText, lEndOffset);
    lItem.EndColumn := ColumnOfOffset(lSourceText, lEndOffset);
    if (lBodyStartOffset <= Length(lSourceText)) and (lSourceText[lBodyStartOffset] = #10) then
    begin
      // The body retains this LF; its relative line index counts it once.
      lItem.BodyLine := LineOfOffset(lSourceText, lBodyStartOffset - 1);
      lItem.BodyColumn := ColumnOfOffset(lSourceText, lBodyStartOffset - 1) + 1;
    end else begin
      lItem.BodyLine := LineOfOffset(lSourceText, lBodyStartOffset);
      lItem.BodyColumn := ColumnOfOffset(lSourceText, lBodyStartOffset);
    end;
    lItem.BodyEndLine := lItem.EndLine;
    lItem.BodyEndColumn := lItem.EndColumn;
    lItem.SelectorText := Copy(aText, lMatch.Groups[1].Index,
      lMatch.Groups[1].Length).Trim;
    lSelectorParts := lItem.SelectorText.Split([',']);
    lItem.SelectorCount := Length(lSelectorParts);
    lItem.NestingDepth := 0;
    for i := 0 to Pred(aItems.Count) do
      if (aItems[i].Line <= lItem.Line) and (aItems[i].EndLine >= lItem.Line) and
        (aItems[i].NestingDepth >= lItem.NestingDepth) then
        lItem.NestingDepth := aItems[i].NestingDepth + 1;
    lItem.BodyText := Copy(lSourceText, lBodyStartOffset, lEndOffset - lBodyStartOffset + 1);
    lItem.HasScopedDeclaration := TRegEx.IsMatch(lItem.BodyText,
      '^\s*(?:var|const|type)\b', [roIgnoreCase, roMultiLine]);
    lItem.Text := Copy(lSourceText, lMatch.Index, lEndOffset - lMatch.Index + 1);
    aItems.Add(lItem);
    lMatch := lMatch.NextMatch;
  end;
end;

function TryBuildActiveRootSource(const aSourceText, aFileName: string;
  const aSpans: TArray<TDelphiSemanticCopiedSourceSpan>; out aActiveSource: string): Boolean;
var
  i, j: Integer;
  lLength: Integer;
  lRootWitnessVerified: Boolean;
  lSpan: TDelphiSemanticCopiedSourceSpan;
begin
  aActiveSource := aSourceText;
  for i := 1 to Length(aActiveSource) do
    if not CharInSet(aActiveSource[i], [#13, #10]) then
      aActiveSource[i] := ' ';
  lRootWitnessVerified := False;
  for lSpan in aSpans do
  begin
    if not SameText(lSpan.FileName, aFileName) then
      Continue;
    if not lRootWitnessVerified then
    begin
      if lSpan.SourceText <> aSourceText then
        Exit(False);
      lRootWitnessVerified := True;
    end;
    lLength := lSpan.OutputEndOffset - lSpan.OutputStartOffset;
    if (lLength < 0) or (lSpan.SourceStartOffset <= 0) or
      (lSpan.SourceStartOffset > Length(aSourceText) + 1) or
      (lLength > Length(aSourceText) - lSpan.SourceStartOffset + 1) then
      Exit(False);
    for j := 0 to lLength - 1 do
      aActiveSource[lSpan.SourceStartOffset + j] := aSourceText[lSpan.SourceStartOffset + j];
  end;
  Result := lRootWitnessVerified;
end;

function ReconcileWithStatementCoordinates(const aSourceText, aFileName: string;
  const aSpans: TArray<TDelphiSemanticCopiedSourceSpan>;
  const aWithStatements: TList<TDelphiSemanticWithStatement>): Boolean;
var
  lActiveSource: string;
  lBestDistance: Integer;
  lBestIndex: Integer;
  lCandidateDistance: Integer;
  i: Integer;
  j: Integer;
  lItem: TDelphiSemanticWithStatement;
  lRootStatements: TList<TDelphiSemanticWithStatement>;
begin
  Result := True;
  if aWithStatements.Count = 0 then
    Exit;
  // Use the preprocessor's copied source witnesses to preserve physical offsets
  // without restoring code excluded by the selected compiler configuration.
  if not TryBuildActiveRootSource(aSourceText, aFileName, aSpans, lActiveSource) then
  begin
    aWithStatements.Clear;
    Exit(False);
  end;
  lRootStatements := TList<TDelphiSemanticWithStatement>.Create;
  try
    ExtractWithStatements(lActiveSource, lRootStatements, aSourceText);
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

// Several extractors can describe one name at one source position (a line scan and the syntax
// tree); one fact per position is kept, the first, so a consumer never edits a place twice.
function CopiedSpanAtOffset(const aSpans: TArray<TDelphiSemanticCopiedSourceSpan>;
  const aOffset: Integer): Integer;
var
  lHigh: Integer;
  lLow: Integer;
  lMiddle: Integer;
begin
  Result := -1;
  lLow := 0;
  lHigh := High(aSpans);
  while lLow <= lHigh do
  begin
    lMiddle := lLow + (lHigh - lLow) div 2;
    if aSpans[lMiddle].OutputStartOffset <= aOffset then
    begin
      Result := lMiddle;
      lLow := lMiddle + 1;
    end else
      lHigh := lMiddle - 1;
  end;
end;

procedure CapturePhysicalReferenceOccurrences(const aExpandedText: string;
  const aSpans: TArray<TDelphiSemanticCopiedSourceSpan>;
  const aReferences: TList<TDelphiSemanticReference>;
  const aDiagnostics: TList<TDelphiSemanticModelDiagnostic>;
  const aRootFileName: string; const aOutputOffsetShift: Integer;
  var aModel: TDelphiSemanticUnitModel);
var
  lExistingIndex: Integer;
  lExistingOccurrence: TDelphiSemanticPhysicalReferenceOccurrence;
  lKey: Int64;
  lOccurrence: TDelphiSemanticPhysicalReferenceOccurrence;
  lOccurrences: TList<TDelphiSemanticPhysicalReferenceOccurrence>;
  lPhysicalLineStartValid: Boolean;
  lReference: TDelphiSemanticReference;
  lSeen: TDictionary<Int64, Integer>;
  lSourceOffset: Integer;
  lSpan: TDelphiSemanticCopiedSourceSpan;
  lSpanIndex: Integer;
  lTokenLength: Integer;
  lWitnessOffset: Integer;
begin
  lOccurrences := TList<TDelphiSemanticPhysicalReferenceOccurrence>.Create;
  lSeen := TDictionary<Int64, Integer>.Create;
  try
    for lReference in aReferences do
    begin
      lOccurrence := Default(TDelphiSemanticPhysicalReferenceOccurrence);
      lOccurrence.Name := lReference.Name;
      lOccurrence.Role := lReference.Role;
      lOccurrence.RoutineName := lReference.RoutineName;
      lOccurrence.RoutineScopeId := lReference.RoutineScopeId;
      lOccurrence.OutputStartOffset := lReference.Offset;
      lOccurrence.OutputEndOffset := lReference.EndOffset;
      lTokenLength := lReference.EndOffset - lReference.Offset;
      lWitnessOffset := lReference.Offset + aOutputOffsetShift;
      lSpanIndex := CopiedSpanAtOffset(aSpans, lWitnessOffset);
      if (lReference.Offset > 0) and (lTokenLength > 0) and
        (lReference.EndOffset <= Length(aExpandedText) + 1) and
        (lSpanIndex >= 0) then
      begin
        lSpan := aSpans[lSpanIndex];
        lSourceOffset := lSpan.SourceStartOffset + lWitnessOffset - lSpan.OutputStartOffset;
        lOccurrence.ExpansionId := lSpan.ExpansionId;
        lOccurrence.FileName := lSpan.FileName;
        lOccurrence.Line := lSpan.Line;
        lOccurrence.Column := lSpan.Column + lWitnessOffset - lSpan.OutputStartOffset;
        if (lSpan.Line = 1) and (lSpan.SourceText <> '') then
          if lSpan.SourceText[1] = #$FEFF then
            Dec(lOccurrence.Column);
        lOccurrence.EndLine := lOccurrence.Line;
        lOccurrence.EndColumn := lOccurrence.Column + lTokenLength - 1;
        lPhysicalLineStartValid := (lSpan.Line = 1) and
          (lSpan.SourceLineStartOffset = 1);
        if (lSpan.Line > 1) and (lSpan.SourceLineStartOffset > 1) and
          (lSpan.SourceLineStartOffset <= Length(lSpan.SourceText) + 1) then
          lPhysicalLineStartValid :=
            (lSpan.SourceText[lSpan.SourceLineStartOffset - 1] = #10) or
            (lSpan.SourceText[lSpan.SourceLineStartOffset - 1] = #13);
        lOccurrence.Verified := (lSpan.OutputStartOffset > 0) and
          (lSpan.OutputEndOffset >= lWitnessOffset + lTokenLength) and
          (lSpan.OutputEndOffset <= Length(aExpandedText) + aOutputOffsetShift + 1) and
          (lSpan.ExpansionId <> '') and (lSpan.FileName <> '') and
          (lSpan.Line > 0) and (lOccurrence.Column > 0) and
          lPhysicalLineStartValid and
          (lSpan.SourceStartOffset = lSpan.SourceLineStartOffset + lSpan.Column - 1) and
          (lSourceOffset > 0) and
          (lSourceOffset + lTokenLength - 1 <= Length(lSpan.SourceText));
        if lOccurrence.Verified then
          lOccurrence.Verified := Copy(aExpandedText, lReference.Offset, lTokenLength) =
            Copy(lSpan.SourceText, lSourceOffset, lTokenLength);
      end;
      if not lOccurrence.Verified then
        AddDiagnostic(aDiagnostics, 'PHYSICAL_REFERENCE_ORIGIN_UNVERIFIED',
          'No matching copied-source witness for expanded reference ' +
          lReference.Name + ' at offset ' + IntToStr(lReference.Offset) + '.',
          aRootFileName, 0);
      if lOccurrence.Verified then
      begin
        lKey := (Int64(lOccurrence.OutputStartOffset) shl 32) or
          Cardinal(lOccurrence.OutputEndOffset);
        if lSeen.TryGetValue(lKey, lExistingIndex) then
        begin
          lExistingOccurrence := lOccurrences[lExistingIndex];
          if SameText(lExistingOccurrence.Name, lOccurrence.Name) and
            SameText(lExistingOccurrence.Role, lOccurrence.Role) and
            ((lExistingOccurrence.RoutineName = '') or (lOccurrence.RoutineName = '') or
              SameText(lExistingOccurrence.RoutineName, lOccurrence.RoutineName)) and
            ((lExistingOccurrence.RoutineScopeId = '') or
              (lOccurrence.RoutineScopeId = '') or
              SameText(lExistingOccurrence.RoutineScopeId,
                lOccurrence.RoutineScopeId)) then
          begin
            if lExistingOccurrence.RoutineName = '' then
              lExistingOccurrence.RoutineName := lOccurrence.RoutineName;
            if lExistingOccurrence.RoutineScopeId = '' then
              lExistingOccurrence.RoutineScopeId := lOccurrence.RoutineScopeId;
            lOccurrences[lExistingIndex] := lExistingOccurrence;
            Continue;
          end;
          lExistingOccurrence.Verified := False;
          lOccurrences[lExistingIndex] := lExistingOccurrence;
          AddDiagnostic(aDiagnostics, 'PHYSICAL_REFERENCE_DESCRIPTION_CONFLICT',
            'Conflicting descriptions of one expanded reference token.',
            aRootFileName, 0);
          Continue;
        end;
        lSeen.Add(lKey, lOccurrences.Count);
      end;
      lOccurrences.Add(lOccurrence);
    end;
    aModel.PhysicalReferenceOccurrences := lOccurrences.ToArray;
  finally
    lSeen.Free;
    lOccurrences.Free;
  end;
end;

procedure CaptureUnknownIncludeReferences(const aRootFileName: string;
  const aSpans: TArray<TDelphiSemanticActivitySpan>;
  const aReferences: TList<TDelphiSemanticReference>);
var
  i: Integer;
  lLexer: TmwBasePasLex;
  lLine: Integer;
  lLineStart: Integer;
  lOffset: Integer;
  lReference: TDelphiSemanticReference;
  lSpan: TDelphiSemanticActivitySpan;
begin
  // Possible include text must refuse rename even when absent from the chosen AST branch.
  for lSpan in aSpans do
    if (lSpan.Activity = saUnknown) and not SameText(lSpan.FileName, aRootFileName) then
    begin
      lLexer := TmwBasePasLex.Create;
      try
        lLexer.UseDefines := False;
        lLexer.Origin := lSpan.SourceText;
        lLexer.RunPos := lSpan.StartOffset - 1;
        while (lLexer.TokenID <> ptNull) and
          (lLexer.TokenPos + 1 < lSpan.EndOffset) do
        begin
          if lLexer.TokenID = ptIdentifier then
          begin
            lOffset := lLexer.TokenPos + 1;
            lLine := 1;
            lLineStart := 1;
            for i := 1 to lOffset - 1 do
              if lSpan.SourceText[i] = #10 then
              begin
                Inc(lLine);
                lLineStart := i + 1;
              end;
            lReference := Default(TDelphiSemanticReference);
            lReference.Name := lLexer.Token;
            if StartsText('&', lReference.Name) then
              Delete(lReference.Name, 1, 1);
            lReference.FileName := lSpan.FileName;
            lReference.Line := lLine;
            lReference.Column := lOffset - lLineStart + 1;
            lReference.Offset := lOffset;
            lReference.EndOffset := lOffset + lLexer.TokenLen;
            lReference.Role := 'unverified-condition';
            // Replace a selected-branch AST reference at the same physical position.
            for i := Pred(aReferences.Count) downto 0 do
              if SameText(aReferences[i].FileName, lReference.FileName) and
                (aReferences[i].Line = lReference.Line) and
                (aReferences[i].Column = lReference.Column) then
                aReferences.Delete(i);
            aReferences.Add(lReference);
          end;
          lLexer.Next;
        end;
      finally
        lLexer.Free;
      end;
    end;
end;

procedure RemoveDuplicateReferences(const aReferences: TList<TDelphiSemanticReference>);
var
  i: Integer;
  lKey: string;
  lKeptCount: Integer;
  lSeen: TDictionary<string, Boolean>;
begin
  lSeen := TDictionary<string, Boolean>.Create(aReferences.Count);
  try
    lKeptCount := 0;
    for i := 0 to Pred(aReferences.Count) do
    begin
      lKey := LowerCase(aReferences[i].Name) + #1 + LowerCase(aReferences[i].FileName) + #1 +
        IntToStr(aReferences[i].Line) + #1 + IntToStr(aReferences[i].Column);
      // A reference without a position is never merged with another one.
      if (aReferences[i].Line > 0) and (aReferences[i].Column > 0) then
      begin
        if lSeen.ContainsKey(lKey) then
          Continue;
        lSeen.Add(lKey, True);
      end;
      aReferences[lKeptCount] := aReferences[i];
      Inc(lKeptCount);
    end;
    aReferences.Count := lKeptCount;
  finally
    lSeen.Free;
  end;
end;

procedure SeparateLocalLabelReferences(var aModel: TDelphiSemanticUnitModel;
  const aReferences: TList<TDelphiSemanticReference>);
var
  i: Integer;
  lKeptCount: Integer;
  lLabels: TList<TDelphiSemanticReference>;
  lReference: TDelphiSemanticReference;
begin
  lLabels := TList<TDelphiSemanticReference>.Create;
  try
    lKeptCount := 0;
    for i := 0 to Pred(aReferences.Count) do
    begin
      lReference := aReferences[i];
      if StartsText('local-label-', lReference.Role) or
        (lReference.Role = 'local-goto-keyword') then
      begin
        // Never apply the ordinary name-search coordinate repair to syntax safety facts.
        // Included labels retain provenance but cannot authorize a root-file rewrite.
        if (lReference.FileName = '') and
          ((lReference.Offset <= 0) or (lReference.Name = '') or
          not SameText(Copy(aModel.SourceText, lReference.Offset,
          Length(lReference.Name)), lReference.Name)) then
          aModel.ScopeModelStatus := 'label-source-map-failed';
        lLabels.Add(lReference);
      end else
      begin
        aReferences[lKeptCount] := lReference;
        Inc(lKeptCount);
      end;
    end;
    aReferences.Count := lKeptCount;
    aModel.LocalLabelReferences := lLabels.ToArray;
  finally
    lLabels.Free;
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

class function TDelphiSemanticUnitModelExtractorImpl.ExtractFromFile(
  const aOptions: TDelphiSemanticModelOptions): TDelphiSemanticUnitModel;
var
  lDeclarations: TList<TDelphiSemanticDeclaration>;
  lDeclarationText: string;
  lExtractionContext: TDelphiSemanticExtractionContext;
  lDiagnostics: TList<TDelphiSemanticModelDiagnostic>;
  lImplementationUses: TList<string>;
  lInterfaceUses: TList<string>;
  i: Integer;
  j: Integer;
  lLocals: TList<TDelphiSemanticLocal>;
  lMatch: TMatch;
  lMembers: TList<TDelphiSemanticMember>;
  lOffsetMap: TArray<Integer>;
  lOutputOffsetShift: Integer;
  lObservationError: string;
  lOrigin: TDelphiSemanticSourceLineOrigin;
  lPreprocessOptions: TDelphiSemanticPreprocessOptions;
  lPreprocessResult: TDelphiSemanticPreprocessResult;
  lReferenceSink: TList<TDelphiSemanticReference>;
  lReferences: TList<TDelphiSemanticReference>;
  lRoutines: TList<TDelphiSemanticRoutine>;
  lSourceResult: TDelphiSemanticSourceLoadResult;
  lText: string;
  lPreviousExtractionContext: TDelphiSemanticExtractionContext;
  lWithStatements: TList<TDelphiSemanticWithStatement>;
  lWithStatement: TDelphiSemanticWithStatement;
  lWritableSwitches: TArray<TWritableConstantSwitch>;
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
    Result.SourceObservations := lSourceResult.SourceObservations;
    Result.EncodingName := lSourceResult.Source.EncodingName;
    Result.LineEndingName := lSourceResult.Source.LineEndingName;
    Result.LineBreak := lSourceResult.Source.LineBreak;
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
    SetLength(Result.IncludeFileNames, Length(lPreprocessResult.Includes));
    for i := 0 to High(lPreprocessResult.Includes) do
      Result.IncludeFileNames[i] := lPreprocessResult.Includes[i].FileName;
    if (lPreprocessResult.SourceObservations <> nil) and
      not TDelphiSemanticSourceEvidence.TryMerge(lSourceResult.SourceObservations,
        lPreprocessResult.SourceObservations, Result.SourceObservations, lObservationError) then
    begin
      Result.Success := False;
      AddDiagnostic(lDiagnostics, lObservationError,
        'Source bytes changed during extraction.', aOptions.SourceFileName, 0);
    end;
    // Publication follows actual activity, including unsupported conditional frames.
    // A structural/source failure cannot publish a partial inactivity proof.
    if aOptions.ProjectContextApplied and (Result.SourceObservations <> nil) and
      lPreprocessResult.ActivityEvidenceAvailable then
    begin
      if lPreprocessResult.HasUnknownActivity then
        Result.VerifiedActiveSourceText := TDelphiSemanticSourceConditionals.EncodeActivity(
          Result.SourceText, lSourceResult.Source.FileName, lPreprocessResult.ActivitySpans)
      else begin
        // A copied-text witness blanks directives even when their activity is known.
        // Validate its root coverage, then publish activity independently of text.
        if TryBuildActiveRootSource(Result.SourceText, lSourceResult.Source.FileName,
          lPreprocessResult.CopiedSourceSpans, Result.VerifiedActiveSourceText) then
          Result.VerifiedActiveSourceText := TDelphiSemanticSourceConditionals.EncodeActivity(
            Result.SourceText, lSourceResult.Source.FileName, lPreprocessResult.ActivitySpans)
        else
          Result.VerifiedActiveSourceText :=
            TDelphiSemanticSourceConditionals.UnavailableActivity;
      end;
    end else if aOptions.ProjectContextApplied then
      Result.VerifiedActiveSourceText := TDelphiSemanticSourceConditionals.UnavailableActivity;
    // No-context extraction still needs its active reference partition after JSON/cache
    // round trips. Keep this witness separate from the project activity authority.
    if not aOptions.ProjectContextApplied and (Result.SourceObservations <> nil) and
      lPreprocessResult.ActivityEvidenceAvailable then
    begin
      if lPreprocessResult.HasUnknownActivity then
        Result.ReferenceScanSourceText := TDelphiSemanticSourceConditionals.SourceForScan(
          Result.SourceText, TDelphiSemanticSourceConditionals.EncodeActivity(
          Result.SourceText, lSourceResult.Source.FileName, lPreprocessResult.ActivitySpans))
      else if not TryBuildActiveRootSource(Result.SourceText, lSourceResult.Source.FileName,
        lPreprocessResult.CopiedSourceSpans, Result.ReferenceScanSourceText) then
        Result.ReferenceScanSourceText := '';
    end;
    AddPreprocessDiagnostics(lDiagnostics, lPreprocessResult.Diagnostics);
    lText := lPreprocessResult.OutputText;
    lOutputOffsetShift := 0;
    if lText = '' then
      lText := lSourceResult.Source.Text;
    if (lText <> '') and (lText[1] = #$FEFF) then
    begin
      Delete(lText, 1, 1);
      lOutputOffsetShift := 1;
    end;

    if not aOptions.ProjectContextApplied then
      AddDiagnostic(lDiagnostics, 'NO_PROJECT_CONTEXT',
        'No full project/compiler context was applied.', aOptions.SourceFileName, 0);

    Result.FileName := lSourceResult.Source.FileName;
    Result.SourceSections := BuildSourceSections(lSourceResult.Source.Text);
    lMatch := TRegEx.Match(lText, '^\s*unit\s+([A-Za-z_][A-Za-z0-9_\.]*)\s*;',
      [roIgnoreCase, roMultiLine]);
    if lMatch.Success then
      Result.UnitName := lMatch.Groups[1].Value;

    if Length(lPreprocessResult.Includes) > 0 then
    begin
      ExtractWithStatements(lText, lWithStatements);
      for lWithStatement in lWithStatements do
        for j := lWithStatement.Line to lWithStatement.EndLine do
        begin
          if (j <= 0) or (j > Length(lPreprocessResult.LineOrigins)) then
            Continue;
          lOrigin := lPreprocessResult.LineOrigins[j - 1];
          if lOrigin.Mixed or ((lOrigin.FileName <> '') and
            not SameText(lOrigin.FileName, lSourceResult.Source.FileName)) then
          begin
            Result.ScopeModelStatus := 'include-with-unverified';
            AddDiagnostic(lDiagnostics, 'WITH_IN_INCLUDE_UNVERIFIED',
              'A with statement crosses or comes from an include file; its source range is unverified.',
              lOrigin.FileName, lOrigin.Line);
            lWithStatements.Clear;
            AssignModelArrays(Result, lDiagnostics, lInterfaceUses, lImplementationUses,
              lDeclarations, lMembers, lRoutines, lLocals, lReferences, lWithStatements);
            Exit;
          end;
        end;
      lWithStatements.Clear;
    end;

    if aOptions.WithStatementsOnly then
    begin
      ExtractWithStatements(lText, lWithStatements);
      if not ReconcileWithStatementCoordinates(lSourceResult.Source.Text,
        lSourceResult.Source.FileName, lPreprocessResult.CopiedSourceSpans, lWithStatements) then
      begin
        Result.Success := False;
        Result.ScopeModelStatus := 'with-source-map-failed';
        AddDiagnostic(lDiagnostics, 'WITH_SOURCE_MAP_FAILED',
          'Active WITH source could not be traced to the original file.', aOptions.SourceFileName, 0);
      end;
      AssignModelArrays(Result, lDiagnostics, lInterfaceUses, lImplementationUses, lDeclarations,
        lMembers, lRoutines, lLocals, lReferences, lWithStatements);
      Exit;
    end;

    ExtractUses(lText, lInterfaceUses, lImplementationUses);
    ExtractContains(lText, lImplementationUses);
    lReferenceSink := lReferences;
    if aOptions.SkipReferenceExtraction then
      lReferenceSink := nil;
    lWritableSwitches := CollectWritableConstantSwitches(lText, lDeclarationText);
    ExtractTypeDeclarations(lText, lDeclarations, lReferenceSink);
    ExtractConstVarDeclarations(lDeclarationText, Result.UnitName, lDeclarations, lMembers,
      lReferenceSink);
    ExtractRoutines(lText, lDeclarations, lRoutines, lReferenceSink);
    // Routine bodies and locals come from syntax-tree ranges inside EnrichLexicalScopeFacts.
    if not aOptions.SkipBodyAnalysis then
      ExtractWithStatements(lText, lWithStatements);
    EnrichLexicalScopeFacts(lText, Result.UnitName, lWritableSwitches,
      aOptions, lMembers,
      lDeclarations, lRoutines, lLocals, lReferences, lDiagnostics, Result);
    if Result.Success and not aOptions.SkipReferenceExtraction and
      (lPreprocessResult.OutputText <> '') then
    begin
      CapturePhysicalReferenceOccurrences(lText, lPreprocessResult.CopiedSourceSpans,
        lReferences, lDiagnostics, Result.FileName, lOutputOffsetShift, Result);
      Result.PhysicalReferenceOccurrencesAvailable :=
        not aOptions.SkipBodyAnalysis and SameText(Result.ScopeModelStatus, 'ast');
    end;
    // DS-659: with includes, output lines no longer match source lines. Each fact moves to the
    // file and line its text came from; include facts are never mapped onto this unit.
    if Length(lPreprocessResult.Includes) > 0 then
    begin
      if (Length(lPreprocessResult.LineOrigins) <> OutputLineCount(lPreprocessResult.OutputText))
        or not AttributeLineOrigins(TPath.GetFullPath(aOptions.SourceFileName),
        lPreprocessResult.LineOrigins, lReferences, lDeclarations, lMembers, lRoutines,
        lLocals) then
      begin
        // Without a line map no fact position can be trusted, so the unit is unverified.
        AddDiagnostic(lDiagnostics, 'INCLUDE_LINE_MAP_FAILED',
          'Preprocessed lines could not be traced to their source files.',
          aOptions.SourceFileName, 0);
        Result.ScopeModelStatus := cIncludeLineMapFailedStatus;
      end;
    end;
    lOffsetMap := BuildOutputToSourceOffsetMap(lSourceResult.Source.Text, lText);
    if lReferences.Count > 0 then
      ApplyReferenceSourceOffsetMap(lSourceResult.Source.Text, lOffsetMap, lReferences);
    ApplyRoutineSourceOffsetMap(lSourceResult.Source.Text, lOffsetMap, lRoutines);
    ApplyDeclarationSourceOffsetMap(lSourceResult.Source.Text, lOffsetMap, lDeclarations);
    ApplyMemberSourceOffsetMap(lSourceResult.Source.Text, lOffsetMap, lMembers);
    ApplyLocalSourceOffsetMap(lSourceResult.Source.Text, lOffsetMap, lLocals);
    ReconcileDeclarationCoordinates(lSourceResult.Source.Text, lDeclarations);
    lExtractionContext.PublishTypeBodyRanges(lPreprocessResult, lDeclarations);
    lExtractionContext.PublishTypeMemberActivity(Result, lPreprocessResult, lOffsetMap,
      lDeclarations, lDiagnostics);
    if not ReconcileWithStatementCoordinates(lSourceResult.Source.Text,
      lSourceResult.Source.FileName, lPreprocessResult.CopiedSourceSpans, lWithStatements) then
    begin
      Result.Success := False;
      Result.ScopeModelStatus := 'with-source-map-failed';
      AddDiagnostic(lDiagnostics, 'WITH_SOURCE_MAP_FAILED',
        'Active WITH source could not be traced to the original file.', aOptions.SourceFileName, 0);
    end;
    if lReferences.Count > 0 then
    begin
      SeparateLocalLabelReferences(Result, lReferences);
      ReconcileReferencesCoordinates(lSourceResult.Source.Text, lReferences, Result.Metrics);
      RemoveDuplicateReferences(lReferences);
    end;
    ReconcileMemberCoordinates(lSourceResult.Source.Text, lMembers);
    ReconcileRoutineCoordinates(lSourceResult.Source.Text, lRoutines);
    ReconcileLocalCoordinates(lSourceResult.Source.Text, lLocals);

    CaptureUnknownIncludeReferences(lSourceResult.Source.FileName,
      lPreprocessResult.ActivitySpans, lReferences);
    RemoveDuplicateReferences(lReferences);
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

class function TDelphiSemanticUnitModelExtractorImpl.TypeBlockAnalysisBuildCount: Integer;
begin
  Result := TInterlocked.CompareExchange(GTypeBlockAnalysisBuildCount, 0, 0);
end;

class procedure TDelphiSemanticUnitModelExtractorImpl.ResetTypeBlockAnalysisBuildCount;
begin
  TInterlocked.Exchange(GTypeBlockAnalysisBuildCount, 0);
  if Assigned(GExtractionContext) then
    GExtractionContext.ResetTypeBlockRanges;
end;

end.
