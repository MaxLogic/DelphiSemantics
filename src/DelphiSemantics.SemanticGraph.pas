unit DelphiSemantics.SemanticGraph;

interface

uses
  DelphiSemantics.Model, DelphiSemantics.ProjectContext, DelphiSemantics.Resolve.UnitNameWitness;

type
  TDelphiSemanticProjectGraphId = record
    Value: string;
  end;

  TDelphiSemanticUnitGraphId = record
    Value: string;
  end;

  TDelphiSemanticGraphSymbolId = record
    Value: string;
  end;

  TDelphiSemanticGraphReferenceId = record
    Value: string;
  end;

  TDelphiSemanticGraphWithStatementId = record
    Value: string;
  end;

  TDelphiSemanticGraphTypeId = record
    Value: string;
  end;

  TDelphiSemanticSourceRange = record
    FileName: string;
    Line: Integer;
    Column: Integer;
    EndLine: Integer;
    EndColumn: Integer;
    Offset: Integer;
    EndOffset: Integer;
  end;

  TDelphiSemanticGraphUnit = record
    Id: TDelphiSemanticUnitGraphId;
    ProjectId: TDelphiSemanticProjectGraphId;
    UnitName: string;
    FileName: string;
    SourceKind: string;
    ScopeModelStatus: string;
    InterfaceImports: TArray<string>;
    ImplementationImports: TArray<string>;
    ImportsKnown: Boolean;
    AliasConflictNames: TArray<string>;
    TypeNamesKnown: Boolean;
    CaptureScopeProof: TDelphiSemanticCaptureScopeProof;
    CaptureExportProof: TDelphiSemanticCaptureScopeProof;
    HelperFactsKnown: Boolean;
    HelperScopeKnown: Boolean;
    UnindexedHelpers: TArray<TDelphiSemanticUnindexedHelperFact>;
    SourceText: string;
    SourceRange: TDelphiSemanticSourceRange;
  end;

  TDelphiSemanticGraphSymbol = record
    Id: TDelphiSemanticGraphSymbolId;
    UnitId: TDelphiSemanticUnitGraphId;
    Name: string;
    Kind: string;
    OwnerName: string;
    SourceRange: TDelphiSemanticSourceRange;
  end;

  TDelphiSemanticGraphDeclaration = record
    SymbolId: TDelphiSemanticGraphSymbolId;
    UnitId: TDelphiSemanticUnitGraphId;
    Name: string;
    Kind: string;
    TypeName: string;
    SectionKind: string;
    ScopeKind: string;
    OwnerDeclaredId: TDelphiSemanticGraphTypeId;
    OwnerScopeId: string;
    SemanticSymbolId: string;
    SourceRange: TDelphiSemanticSourceRange;
  end;

  TDelphiSemanticGraphType = record
    Synthetic: Boolean;
    OwnerName: string;
    SymbolId: TDelphiSemanticGraphSymbolId;
    DeclaredId: TDelphiSemanticGraphTypeId;
    CanonicalId: TDelphiSemanticGraphTypeId;
    UnderlyingId: TDelphiSemanticGraphTypeId;
    UnitId: TDelphiSemanticUnitGraphId;
    Name: string;
    Kind: string;
    CanonicalName: string;
    UnderlyingName: string;
    BaseTypeName: string;
    HelperTargetName: string;
    HelperParentName: string;
    SectionKind: string;
    ScopeKind: string;
    OwnerScopeId: string;
    SemanticSymbolId: string;
    SourceRange: TDelphiSemanticSourceRange;
    VisibilityRange: TDelphiSemanticSourceRange;
  end;

  TDelphiSemanticGraphMember = record
    SymbolId: TDelphiSemanticGraphSymbolId;
    UnitId: TDelphiSemanticUnitGraphId;
    OwnerName: string;
    OwnerScopeId: string;
    OwnerSemanticSymbolId: string;
    Name: string;
    Kind: string;
    TypeName: string;
    Visibility: string;
    Signature: string;
    IsIndexed: Boolean;
    IsDefault: Boolean;
    SourceRange: TDelphiSemanticSourceRange;
  end;

  TDelphiSemanticGraphParameter = record
    SymbolId: TDelphiSemanticGraphSymbolId;
    UnitId: TDelphiSemanticUnitGraphId;
    RoutineName: string;
    RoutineScopeId: string;
    Name: string;
    TypeName: string;
    Modifier: string;
    SourceRange: TDelphiSemanticSourceRange;
  end;

  TDelphiSemanticGraphRoutine = record
    SymbolId: TDelphiSemanticGraphSymbolId;
    UnitId: TDelphiSemanticUnitGraphId;
    Name: string;
    OwnerName: string;
    SectionKind: string;
    Signature: string;
    ReturnType: string;
    ScopeId: string;
    ParentScopeId: string;
    AstScopeKind: string;
    AstSemanticSignature: string;
    AstSourceSignature: string;
    AstSourceSignatureVerified: Boolean;
    SourceRange: TDelphiSemanticSourceRange;
  end;

  TDelphiSemanticGraphLocal = record
    SymbolId: TDelphiSemanticGraphSymbolId;
    UnitId: TDelphiSemanticUnitGraphId;
    RoutineName: string;
    RoutineScopeId: string;
    Name: string;
    Kind: string;
    TypeName: string;
    SourceRange: TDelphiSemanticSourceRange;
  end;

  TDelphiSemanticGraphReference = record
    Id: TDelphiSemanticGraphReferenceId;
    UnitId: TDelphiSemanticUnitGraphId;
    Name: string;
    RoutineName: string;
    RoutineScopeId: string;
    Role: string;
    SectionKind: string;
    SourceRange: TDelphiSemanticSourceRange;
  end;

  TDelphiSemanticGraphWithStatement = record
    Id: TDelphiSemanticGraphWithStatementId;
    UnitId: TDelphiSemanticUnitGraphId;
    SelectorText: string;
    SelectorCount: Integer;
    NestingDepth: Integer;
    SourceRange: TDelphiSemanticSourceRange;
    BodyRange: TDelphiSemanticSourceRange;
  end;

  TDelphiSemanticGraphBuildMetrics = record
    UnitCount: Integer;
    SymbolCount: Integer;
    ReferenceCount: Integer;
    WithStatementCount: Integer;
    BuildMilliseconds: Int64;
  end;

  TDelphiSemanticSemanticGraph = class
  private
    fUnitNameWitness: IDelphiSemanticUnitNameWitness;
    fDeclarations: TArray<TDelphiSemanticGraphDeclaration>;
    fLocals: TArray<TDelphiSemanticGraphLocal>;
    fMembers: TArray<TDelphiSemanticGraphMember>;
    fMetrics: TDelphiSemanticGraphBuildMetrics;
    fParameters: TArray<TDelphiSemanticGraphParameter>;
    fProjectId: TDelphiSemanticProjectGraphId;
    fReferences: TArray<TDelphiSemanticGraphReference>;
    fRoutines: TArray<TDelphiSemanticGraphRoutine>;
    fSymbols: TArray<TDelphiSemanticGraphSymbol>;
    fTypes: TArray<TDelphiSemanticGraphType>;
    fUnits: TArray<TDelphiSemanticGraphUnit>;
    fWithStatements: TArray<TDelphiSemanticGraphWithStatement>;
  public
    constructor Create(const aProjectId: TDelphiSemanticProjectGraphId;
      const aUnits: TArray<TDelphiSemanticGraphUnit>;
      const aSymbols: TArray<TDelphiSemanticGraphSymbol>;
      const aDeclarations: TArray<TDelphiSemanticGraphDeclaration>;
      const aTypes: TArray<TDelphiSemanticGraphType>;
      const aMembers: TArray<TDelphiSemanticGraphMember>;
      const aRoutines: TArray<TDelphiSemanticGraphRoutine>;
      const aParameters: TArray<TDelphiSemanticGraphParameter>;
      const aLocals: TArray<TDelphiSemanticGraphLocal>;
      const aMetrics: TDelphiSemanticGraphBuildMetrics); overload;
    constructor Create(const aProjectId: TDelphiSemanticProjectGraphId;
      const aUnits: TArray<TDelphiSemanticGraphUnit>;
      const aSymbols: TArray<TDelphiSemanticGraphSymbol>;
      const aDeclarations: TArray<TDelphiSemanticGraphDeclaration>;
      const aTypes: TArray<TDelphiSemanticGraphType>;
      const aMembers: TArray<TDelphiSemanticGraphMember>;
      const aRoutines: TArray<TDelphiSemanticGraphRoutine>;
      const aParameters: TArray<TDelphiSemanticGraphParameter>;
      const aLocals: TArray<TDelphiSemanticGraphLocal>;
      const aReferences: TArray<TDelphiSemanticGraphReference>;
      const aWithStatements: TArray<TDelphiSemanticGraphWithStatement>;
      const aMetrics: TDelphiSemanticGraphBuildMetrics); overload;
    function Declarations: TArray<TDelphiSemanticGraphDeclaration>;
    function FindRoutineByName(const aName: string; out aRoutine: TDelphiSemanticGraphRoutine):
      Boolean;
    function FindTypeByName(const aName: string; out aType: TDelphiSemanticGraphType):
      Boolean;
    function FindUnitByName(const aUnitName: string; out aUnit: TDelphiSemanticGraphUnit):
      Boolean;
    function Locals: TArray<TDelphiSemanticGraphLocal>;
    function Members: TArray<TDelphiSemanticGraphMember>;
    function Parameters: TArray<TDelphiSemanticGraphParameter>;
    function References: TArray<TDelphiSemanticGraphReference>;
    function Routines: TArray<TDelphiSemanticGraphRoutine>;
    function Symbols: TArray<TDelphiSemanticGraphSymbol>;
    function Types: TArray<TDelphiSemanticGraphType>;
    function Units: TArray<TDelphiSemanticGraphUnit>;
    function WithStatements: TArray<TDelphiSemanticGraphWithStatement>;
    property UnitNameWitness: IDelphiSemanticUnitNameWitness read fUnitNameWitness
      write fUnitNameWitness;
    property Metrics: TDelphiSemanticGraphBuildMetrics read fMetrics;
    property ProjectId: TDelphiSemanticProjectGraphId read fProjectId;
  end;

  TDelphiSemanticSemanticGraphBuilder = record
  public
    class function ProjectImports(const aProject: TDelphiSemanticProjectInfo;
      const aModel: TDelphiSemanticUnitModel; const aModels: TArray<TDelphiSemanticUnitModel>;
      out aInterface, aImplementation: TArray<string>): Boolean; static;
    class function Build(const aProject: TDelphiSemanticProjectInfo;
      const aUnitModels: TArray<TDelphiSemanticUnitModel>): TDelphiSemanticSemanticGraph;
      static;
  end;

implementation

uses
  System.Classes, System.Diagnostics, System.Generics.Collections, System.Generics.Defaults, System.Hash, System.IOUtils, System.RegularExpressions, System.StrUtils, System.SysUtils,
  SimpleParser.Lexer, SimpleParser.Lexer.Types,
  DelphiSemantics.Model.Extract, DelphiSemantics.Preprocess, DelphiSemantics.Resolve.UnitResolver, DelphiSemantics.Source, DelphiSemantics.SourceConditionals;

function StableHash(const aText: string): string;
begin
  Result := THashSHA2.GetHashString(aText);
end;

function NormalizePathForId(const aFileName: string): string;
begin
  Result := LowerCase(TPath.GetFullPath(aFileName));
end;

function MakeProjectId(const aProject: TDelphiSemanticProjectInfo):
  TDelphiSemanticProjectGraphId;
var
  lIdentity: string;
begin
  if aProject.ContextFingerprint <> '' then
    lIdentity := aProject.ContextFingerprint
  else
    lIdentity := aProject.ProjectFileName + '|' + aProject.ProjectName + '|' +
      aProject.Configuration + '|' + aProject.Platform;

  Result.Value := StableHash('project|' + LowerCase(lIdentity));
end;

function MakeUnitId(const aProjectId: TDelphiSemanticProjectGraphId;
  const aModel: TDelphiSemanticUnitModel): TDelphiSemanticUnitGraphId;
begin
  Result.Value := StableHash('unit|' + aProjectId.Value + '|' + LowerCase(aModel.UnitName) +
    '|' + NormalizePathForId(aModel.FileName));
end;

function MakeSymbolId(const aUnitId: TDelphiSemanticUnitGraphId;
  const aKind, aOwnerName, aName: string; const aLine, aColumn, aOrdinal: Integer):
  TDelphiSemanticGraphSymbolId;
begin
  Result.Value := StableHash('symbol|' + aUnitId.Value + '|' + LowerCase(aKind) + '|' +
    LowerCase(aOwnerName) + '|' + LowerCase(aName) + '|' + IntToStr(aLine) + '|' +
    IntToStr(aColumn) + '|' + IntToStr(aOrdinal));
end;

function MakeTypeId(const aUnitId: TDelphiSemanticUnitGraphId; const aRole, aName: string):
  TDelphiSemanticGraphTypeId;
begin
  Result.Value := StableHash('type|' + aUnitId.Value + '|' + LowerCase(aRole) + '|' +
    LowerCase(aName));
end;

function MakeScopedTypeId(const aUnitId: TDelphiSemanticUnitGraphId; const aRole,
  aOwnerScopeId, aSemanticSymbolId: string): TDelphiSemanticGraphTypeId;
begin
  Result := Default(TDelphiSemanticGraphTypeId);
  if (aOwnerScopeId = '') or (aSemanticSymbolId = '') then
    Exit;
  Result.Value := StableHash('local-type|' + aUnitId.Value + '|' + LowerCase(aRole) +
    '|' + LowerCase(aOwnerScopeId) + '|' + LowerCase(aSemanticSymbolId));
end;

function MakeReferenceId(const aUnitId: TDelphiSemanticUnitGraphId;
  const aReference: TDelphiSemanticReference; const aOrdinal: Integer):
  TDelphiSemanticGraphReferenceId;
begin
  Result.Value := StableHash('reference|' + aUnitId.Value + '|' +
    LowerCase(aReference.Name) + '|' + IntToStr(aReference.Line) + '|' +
    IntToStr(aReference.Column) + '|' + IntToStr(aOrdinal));
end;

function MakeWithStatementId(const aUnitId: TDelphiSemanticUnitGraphId;
  const aWithStatement: TDelphiSemanticWithStatement; const aOrdinal: Integer):
  TDelphiSemanticGraphWithStatementId;
begin
  Result.Value := StableHash('with|' + aUnitId.Value + '|' +
    LowerCase(aWithStatement.SelectorText) + '|' + IntToStr(aWithStatement.Line) + '|' +
    IntToStr(aWithStatement.Column) + '|' + IntToStr(aOrdinal));
end;

function CompleteNameRange(const aRange: TDelphiSemanticSourceRange; const aName: string):
  TDelphiSemanticSourceRange;
begin
  Result := aRange;
  if (Result.Line > 0) and (Result.Column > 0) and (Result.EndLine = 0) then
    Result.EndLine := Result.Line;
  if (Result.EndLine = Result.Line) and (Result.EndColumn = 0) then
    Result.EndColumn := Result.Column + Length(aName);
  if (Result.Offset > 0) and (Result.EndOffset = 0) then
    Result.EndOffset := Result.Offset + Length(aName);
end;

function UnitSourceRange(const aModel: TDelphiSemanticUnitModel): TDelphiSemanticSourceRange;
begin
  Result := Default(TDelphiSemanticSourceRange);
  Result.FileName := aModel.FileName;
end;

function HelperScopeIsKnown(const aModel: TDelphiSemanticUnitModel): Boolean;
var
  lLexer: TmwBasePasLex;
  lLineStarts: TArray<Integer>;
  lPathStack: TList<string>;
  lArgument, lScan: string;
  lPrevious, lBeforePrevious, lNameToken: TptTokenKind;
  lNameOffset, lBeforeOffset, lPreviousOffset, lDepth, lStart, lFinish, i: Integer;
  lPlain: Boolean;

  function IsConditional(const aKind: TptTokenKind): Boolean;
  begin
    Result := aKind in [ptIfDirect, ptIfDefDirect, ptIfNDefDirect, ptIfOptDirect,
      ptElseDirect, ptElseIfDirect, ptEndIfDirect, ptIfEndDirect];
  end;

  function IsTrivia(const aLexer: TmwBasePasLex): Boolean;
  begin
    Result := aLexer.TokenID in [ptSpace, ptCRLF, ptCRLFCo, ptAnsiComment,
      ptBorComment, ptSlashesComment];
  end;

  function RawScanSource(const aSource: string): string;
  var
    i, j, lNameStart: Integer;
    lName: string;
  begin
    Result := aSource;
    i := 1;
    while i < Length(aSource) do
    begin
      j := 0;
      if (aSource[i] = '{') and (aSource[i + 1] = '$') then
        j := i + 2
      else if (i + 2 <= Length(aSource)) and (Copy(aSource, i, 3) = '(*$') then
        j := i + 3;
      if j > 0 then
      begin
        while (j <= Length(aSource)) and CharInSet(aSource[j], [#9, ' ']) do
          Inc(j);
        lNameStart := j;
        while (j <= Length(aSource)) and CharInSet(aSource[j], ['A'..'Z', 'a'..'z']) do
          Inc(j);
        lName := Copy(aSource, lNameStart, j - lNameStart);
        // DelphiAST consumes include tokens even with UseDefines=False. Make
        // them generic directives only in this equal-length lexical view.
        // Strings/comments remain strings/comments; evidence uses raw bytes.
        if MatchText(lName, ['I', 'INCLUDE']) then
          Result[lNameStart] := 'Z';
      end;
      Inc(i);
    end;
  end;

  function IncludeArgument(const aSource: string; const aLexer: TmwBasePasLex): string;
  var
    lBody: string;
  begin
    lBody := Copy(aSource, aLexer.TokenPos + 1, aLexer.TokenLen);
    if StartsStr('{$', lBody) then
      lBody := Copy(lBody, 3, Length(lBody) - 3)
    else if StartsStr('(*$', lBody) then
      lBody := Copy(lBody, 4, Length(lBody) - 5);
    Result := TDelphiSemanticPreprocessor.IncludeArgumentFromDirective(lBody);
  end;

  function IncludeIsClosed(const aArgument, aDirectory: string): Boolean;
  var
    lCandidate, lExpected, lSuffix, lFileName, lText, lArgument: string;
    lChildLexer: TmwBasePasLex;
    lSkipped: Boolean;
    lSource: TDelphiSemanticSourceText;
  begin
    Result := False;
    lSuffix := aArgument.Trim.Trim([#39, '"']).Replace('/', PathDelim);
    if lSuffix = '' then
      Exit;
    lExpected := TPath.GetFullPath(TPath.Combine(aDirectory, lSuffix));
    lFileName := '';
    // Selection must already have been observed by preprocessing. Never
    // discover a new file as evidence for a skipped branch here.
    for lCandidate in aModel.IncludeFileNames + aModel.SkippedIncludeFileNames do
      if SameText(lExpected, lCandidate) or EndsText(PathDelim + lSuffix, lCandidate) then
      begin
        if (lFileName <> '') and not SameText(lFileName, lCandidate) then
          Exit;
        lFileName := lCandidate;
      end;
    lSkipped := False;
    for lCandidate in aModel.SkippedIncludeFileNames do
      if SameText(lFileName, lCandidate) then
        lSkipped := True;
    if (lFileName = '') or (lPathStack.Count >= 64) then
      Exit;
    for lCandidate in lPathStack do
      if SameText(lCandidate, lFileName) then
        Exit;
    lPathStack.Add(lFileName);
    try
      try
        if (aModel.SourceObservations <> nil) and
          aModel.SourceObservations.TryFind(lFileName, lSource) then
          lText := lSource.Text
        else
          lText := TFile.ReadAllText(lFileName);
      except
        // Unreadable includes cannot establish helper absence.
        on E: EInOutError do Exit;
        on E: EFOpenError do Exit;
      end;
      if lSkipped and TRegEx.IsMatch(lText, '\bhelper\b', [roIgnoreCase]) then
        Exit;
      lChildLexer := TmwBasePasLex.Create;
      try
        lChildLexer.UseDefines := False;
        lChildLexer.Origin := RawScanSource(lText);
        while lChildLexer.TokenID <> ptNull do
        begin
          if not IsTrivia(lChildLexer) and SameText(lChildLexer.Token, 'helper') then
            Exit;
          if lChildLexer.IsCompilerDirective then
          begin
            lArgument := IncludeArgument(lText, lChildLexer);
            if (lArgument <> '') and not (aModel.DefineEvidenceComplete and
          (aModel.VerifiedActiveSourceText <> '') and
          (Copy(lScan, lLexer.TokenPos + 1, lLexer.TokenLen) =
            StringOfChar(' ', lLexer.TokenLen)) and
          not TDelphiSemanticSourceConditionals.UnknownAtOffset(aModel.SourceText,
            aModel.VerifiedActiveSourceText, lLexer.TokenPos + 1)) and
          not IncludeIsClosed(lArgument,
              ExtractFilePath(lFileName)) then
              Exit;
          end;
          lChildLexer.Next;
        end;
        Result := True;
      finally
        lChildLexer.Free;
      end;
    finally
      lPathStack.Delete(lPathStack.Count - 1);
    end;
  end;

  function PlainHelper(const aHelperOffset: Integer): Boolean;
  var
    lDeclaration: TDelphiSemanticDeclaration;
    lFact: TDelphiSemanticUnindexedHelperFact;
    lName: string;
    lLine, lColumn: Integer;
    lSpanLexer: TmwBasePasLex;
    lMatched: Boolean;
  begin
    Result := False;
    if not (lPrevious in [ptClass, ptRecord]) or (lBeforePrevious <> ptEqual) or
      (lNameToken <> ptIdentifier) or ((lDepth > 0) and not aModel.DefineEvidenceComplete) then
      Exit;
    lMatched := False;
    lStart := lNameOffset;
    lFinish := 0;
    for lDeclaration in aModel.Declarations do
      if (lDeclaration.Offset = lStart) and
        ((lDeclaration.FileName = '') or SameText(lDeclaration.FileName, aModel.FileName)) and
        MatchText(lDeclaration.AstHelperKind, ['class', 'record']) and
        (lDeclaration.TypeBodyEndLine > 0) and
        (lDeclaration.TypeBodyEndLine <= Length(lLineStarts)) and
        (lDeclaration.TypeBodyEndColumn > 0) then
      begin
        lFinish := lLineStarts[lDeclaration.TypeBodyEndLine - 1] +
          lDeclaration.TypeBodyEndColumn - 1;
        lMatched := True;
      end;
    if not lMatched then
    begin
      lName := Copy(aModel.SourceText, lNameOffset, lBeforeOffset - lNameOffset);
      lName := Trim(lName);
      if StartsStr('&', lName) then
        Delete(lName, 1, 1);
      lLine := 1;
      for var j := 1 to Length(lLineStarts) - 1 do
        if lLineStarts[j] <= lNameOffset then
          lLine := j + 1;
      lColumn := lNameOffset - lLineStarts[lLine - 1] + 1;
      for lFact in aModel.UnindexedHelpers do
        if ((lFact.FileName = '') or SameText(lFact.FileName, aModel.FileName)) and
          (lFact.Line = lLine) and SameText(lFact.Name, lName) and
          ((lFact.Column = lColumn) or (lFact.Column = lColumn + 1)) and
          (lFact.TypeBodyEndLine > 0) and
          (lFact.TypeBodyEndLine <= Length(lLineStarts)) and
          (lFact.TypeBodyEndColumn > 0) then
        begin
          lFinish := lLineStarts[lFact.TypeBodyEndLine - 1] + lFact.TypeBodyEndColumn - 1;
          lMatched := True;
        end;
    end;
    if not lMatched or (lFinish < aHelperOffset) or
      (lFinish > Length(aModel.SourceText)) then
      Exit;
    lSpanLexer := TmwBasePasLex.Create;
    try
      lSpanLexer.UseDefines := False;
      lSpanLexer.Origin := RawScanSource(aModel.SourceText);
      while (lSpanLexer.TokenID <> ptNull) and (lSpanLexer.TokenPos < lFinish) do
      begin
        if lSpanLexer.TokenPos + 1 >= lStart then
        begin
          if IsConditional(lSpanLexer.TokenID) or
            (lSpanLexer.IsCompilerDirective and
            (IncludeArgument(aModel.SourceText, lSpanLexer) <> '')) then
            Exit;
          if not IsTrivia(lSpanLexer) then
            for var j := lSpanLexer.TokenPos + 1 to
              lSpanLexer.TokenPos + lSpanLexer.TokenLen do
              if TDelphiSemanticSourceConditionals.UnknownAtOffset(aModel.SourceText,
                aModel.VerifiedActiveSourceText, j) then
                Exit;
        end;
        lSpanLexer.Next;
      end;
      Result := True;
    finally
      lSpanLexer.Free;
    end;
  end;

begin
  Result := aModel.Success and MatchText(aModel.ScopeModelStatus, ['ast', 'ast-interface-only']);
  if not Result then
    Exit;
  lLineStarts := [1];
  for i := 1 to Length(aModel.SourceText) do
    if aModel.SourceText[i] = #10 then
      lLineStarts := lLineStarts + [i + 1];
  lScan := TDelphiSemanticSourceConditionals.SourceForScan(aModel.SourceText,
    aModel.VerifiedActiveSourceText);
  lPathStack := TList<string>.Create;
  lLexer := TmwBasePasLex.Create;
  try
    lLexer.UseDefines := False;
    lLexer.Origin := RawScanSource(aModel.SourceText);
    lPrevious := ptNull;
    lBeforePrevious := ptNull;
    lNameToken := ptNull;
    lNameOffset := 0;
    lPreviousOffset := 0;
    lBeforeOffset := 0;
    lDepth := 0;
    lPlain := False;
    while lLexer.TokenID <> ptNull do
    begin
      if lLexer.TokenID in [ptIfDirect, ptIfDefDirect, ptIfNDefDirect, ptIfOptDirect] then
        Inc(lDepth)
      else if lLexer.TokenID in [ptEndIfDirect, ptIfEndDirect] then
      begin
        if lDepth = 0 then
          Exit(False);
        Dec(lDepth);
      end;
      if lLexer.IsCompilerDirective then
      begin
        lArgument := IncludeArgument(aModel.SourceText, lLexer);
        if (lArgument <> '') and not (aModel.DefineEvidenceComplete and
          (aModel.VerifiedActiveSourceText <> '') and
          (Copy(lScan, lLexer.TokenPos + 1, lLexer.TokenLen) =
            StringOfChar(' ', lLexer.TokenLen)) and
          not TDelphiSemanticSourceConditionals.UnknownAtOffset(aModel.SourceText,
            aModel.VerifiedActiveSourceText, lLexer.TokenPos + 1)) and
          not IncludeIsClosed(lArgument,
          ExtractFilePath(aModel.FileName)) then
          Exit(False);
      end;
      if not IsTrivia(lLexer) and not lLexer.IsCompilerDirective and
        not IsConditional(lLexer.TokenID) then
      begin
        if SameText(lLexer.Token, 'helper') then
        begin
          // Only encoded inactivity from a complete project may discard a
          // branch. An absent symbol or caller list is not that evidence.
          if not (aModel.DefineEvidenceComplete and
            (aModel.VerifiedActiveSourceText <> '') and
            (Copy(lScan, lLexer.TokenPos + 1, lLexer.TokenLen) =
              StringOfChar(' ', lLexer.TokenLen)) and
            not TDelphiSemanticSourceConditionals.UnknownAtOffset(aModel.SourceText,
              aModel.VerifiedActiveSourceText, lLexer.TokenPos + 1)) then
          begin
            if not PlainHelper(lLexer.TokenPos + 1) then
              Exit(False);
            lPlain := True;
          end;
        end;
        // Retain the three significant tokens preceding the helper keyword:
        // the AST endpoint alone cannot establish raw declaration adjacency.
        lNameToken := lBeforePrevious;
        lNameOffset := lBeforeOffset;
        lBeforePrevious := lPrevious;
        lBeforeOffset := lPreviousOffset;
        lPrevious := lLexer.TokenID;
        lPreviousOffset := lLexer.TokenPos + 1;
      end;
      lLexer.Next;
    end;
    if lDepth <> 0 then
      Exit(False);
    if lPlain then
    begin
      // Origin allocates a new lexer buffer; a second assignment would orphan
      // the first. This second pass owns a fresh lexer, including on failure.
      FreeAndNil(lLexer);
      lLexer := TmwBasePasLex.Create;
      lLexer.UseDefines := False;
      lLexer.Origin := RawScanSource(aModel.SourceText);
      while lLexer.TokenID <> ptNull do
      begin
        if (lLexer.TokenID in [ptInterface, ptImplementation]) and
          TDelphiSemanticSourceConditionals.UnknownAtOffset(aModel.SourceText,
            aModel.VerifiedActiveSourceText, lLexer.TokenPos + 1) then
          Exit(False);
        lLexer.Next;
      end;
    end;
  finally
    lLexer.Free;
    lPathStack.Free;
  end;
end;

function CanonicalProjectImport(const aProject: TDelphiSemanticProjectInfo;
  const aModels: TArray<TDelphiSemanticUnitModel>; const aUnitName: string): string; forward;

function CachedProjectImport(const aProject: TDelphiSemanticProjectInfo;
  const aModels: TArray<TDelphiSemanticUnitModel>; const aUnitName: string;
  const aCache: TDictionary<string, string>): string;
begin
  if (aCache <> nil) and aCache.TryGetValue(aUnitName, Result) then
    Exit;
  Result := CanonicalProjectImport(aProject, aModels, aUnitName);
  if aCache <> nil then
    aCache.Add(aUnitName, Result);
end;

function ProjectImportsPrepared(const aProject: TDelphiSemanticProjectInfo;
  const aModel: TDelphiSemanticUnitModel; const aModels: TArray<TDelphiSemanticUnitModel>;
  const aCache: TDictionary<string, string>;
  out aInterface, aImplementation: TArray<string>): Boolean; forward;

function BuildUnit(const aProjectId: TDelphiSemanticProjectGraphId;
  const aProject: TDelphiSemanticProjectInfo; const aModel: TDelphiSemanticUnitModel;
  const aModels: TArray<TDelphiSemanticUnitModel>;
  const aImportCache: TDictionary<string, string>): TDelphiSemanticGraphUnit;
begin
  Result := Default(TDelphiSemanticGraphUnit);
  Result.Id := MakeUnitId(aProjectId, aModel);
  Result.ProjectId := aProjectId;
  Result.UnitName := aModel.UnitName;
  Result.FileName := aModel.FileName;
  Result.SourceKind := 'project';
  Result.SourceText := aModel.SourceText;
  // A conflicted alias cannot be canonicalized into a closed indexed import.
  for var lAlias in aProject.UnitAliases do
  begin
    var lEquals := Pos('=', lAlias);
    if lEquals < 2 then
      Continue;
    for var lOther in aProject.UnitAliases do
    begin
      var lOtherEquals := Pos('=', lOther);
      if (lOtherEquals > 1) and
        SameText(Trim(Copy(lAlias, 1, lEquals - 1)), Trim(Copy(lOther, 1, lOtherEquals - 1))) and
        not SameText(Trim(Copy(lAlias, lEquals + 1, MaxInt)), Trim(Copy(lOther, lOtherEquals + 1, MaxInt))) then
        Result.AliasConflictNames := Result.AliasConflictNames + [Trim(Copy(lAlias, 1, lEquals - 1))];
    end;
  end;
  Result.TypeNamesKnown := aModel.Success and
    (SameText(aModel.ScopeModelStatus, 'ast') or SameText(aModel.ScopeModelStatus, 'ast-interface-only'));
  for var lDiagnostic in aModel.Diagnostics do
    if MatchText(lDiagnostic.Code, ['UNVERIFIED_PREPROCESS_CONDITION',
      'UNSUPPORTED_PREPROCESS_DIRECTIVE', 'UNMATCHED_PREPROCESS_DIRECTIVE']) then
      Result.TypeNamesKnown := False;
  Result.CaptureScopeProof := TDelphiSemanticUnitModelExtractorImpl.CaptureScopeProof(aModel, False);
  Result.CaptureExportProof := TDelphiSemanticUnitModelExtractorImpl.CaptureScopeProof(aModel, True);
  for var i := 0 to High(Result.CaptureScopeProof.Imports) do
  begin
    var lImports := Result.CaptureScopeProof.Imports[i];
    for var j := 0 to High(lImports.InterfaceImports) do
      lImports.InterfaceImports[j] := CachedProjectImport(aProject, aModels, lImports.InterfaceImports[j], aImportCache);
    for var j := 0 to High(lImports.ImplementationImports) do
      lImports.ImplementationImports[j] := CachedProjectImport(aProject, aModels, lImports.ImplementationImports[j], aImportCache);
    for var j := 0 to High(lImports.RootImports) do
      lImports.RootImports[j] := CachedProjectImport(aProject, aModels, lImports.RootImports[j], aImportCache);
    Result.CaptureScopeProof.Imports[i] := lImports;
  end;
  Result.HelperScopeKnown := HelperScopeIsKnown(aModel);
  Result.UnindexedHelpers := aModel.UnindexedHelpers;
  var lHelperDiagnosticCount := 0;
  for var lDiagnostic in aModel.Diagnostics do
    if SameText(lDiagnostic.Code, 'AST_HELPER_DECLARATION_UNINDEXED') then
      Inc(lHelperDiagnosticCount);
  Result.HelperFactsKnown := Length(Result.UnindexedHelpers) >= lHelperDiagnosticCount;
  Result.ScopeModelStatus := aModel.ScopeModelStatus;
  Result.ImportsKnown := ProjectImportsPrepared(aProject, aModel, aModels,
    aImportCache, Result.InterfaceImports, Result.ImplementationImports);
  Result.SourceRange := UnitSourceRange(aModel);
end;

function DeclarationSourceRange(const aModel: TDelphiSemanticUnitModel;
  const aDeclaration: TDelphiSemanticDeclaration): TDelphiSemanticSourceRange;
begin
  Result := Default(TDelphiSemanticSourceRange);
  Result.FileName := aDeclaration.FileName;
  if Result.FileName = '' then
    Result.FileName := aModel.FileName;
  Result.Line := aDeclaration.Line;
  Result.Column := aDeclaration.Column;
  Result.Offset := aDeclaration.Offset;
  Result.EndOffset := aDeclaration.EndOffset;
  Result := CompleteNameRange(Result, aDeclaration.Name);
end;

function MemberSourceRange(const aModel: TDelphiSemanticUnitModel;
  const aMember: TDelphiSemanticMember): TDelphiSemanticSourceRange;
begin
  Result := Default(TDelphiSemanticSourceRange);
  Result.FileName := aMember.FileName;
  if Result.FileName = '' then
    Result.FileName := aModel.FileName;
  Result.Line := aMember.Line;
  Result.Column := aMember.Column;
  Result.Offset := aMember.Offset;
  Result.EndOffset := aMember.EndOffset;
  Result := CompleteNameRange(Result, aMember.Name);
end;

function RoutineSourceRange(const aModel: TDelphiSemanticUnitModel;
  const aRoutine: TDelphiSemanticRoutine): TDelphiSemanticSourceRange;
begin
  Result := Default(TDelphiSemanticSourceRange);
  if aRoutine.FileName <> '' then
    Result.FileName := aRoutine.FileName
  else
    Result.FileName := aModel.FileName;
  Result.Line := aRoutine.Line;
  Result.Column := aRoutine.Column;
  Result.Offset := aRoutine.Offset;
  Result.EndOffset := aRoutine.EndOffset;
  if aRoutine.EndLine > 0 then
    Result.EndLine := aRoutine.EndLine;
  if aRoutine.EndColumn > 0 then
    Result.EndColumn := aRoutine.EndColumn;
  Result := CompleteNameRange(Result, aRoutine.Name);
end;

function LocalSourceRange(const aModel: TDelphiSemanticUnitModel;
  const aLocal: TDelphiSemanticLocal): TDelphiSemanticSourceRange;
begin
  Result := Default(TDelphiSemanticSourceRange);
  Result.FileName := aLocal.FileName;
  if Result.FileName = '' then
    Result.FileName := aModel.FileName;
  Result.Line := aLocal.Line;
  Result.Column := aLocal.Column;
  Result.Offset := aLocal.Offset;
  Result.EndOffset := aLocal.EndOffset;
  Result := CompleteNameRange(Result, aLocal.Name);
end;

function ParameterSourceRange(const aModel: TDelphiSemanticUnitModel;
  const aParameter: TDelphiSemanticParameter): TDelphiSemanticSourceRange;
begin
  Result := Default(TDelphiSemanticSourceRange);
  Result.FileName := aParameter.FileName;
  if Result.FileName = '' then
    Result.FileName := aModel.FileName;
  Result.Line := aParameter.Line;
  Result.Column := aParameter.Column;
  Result.Offset := aParameter.Offset;
  Result.EndOffset := aParameter.EndOffset;
  Result := CompleteNameRange(Result, aParameter.Name);
end;

function ReferenceSourceRange(const aModel: TDelphiSemanticUnitModel;
  const aReference: TDelphiSemanticReference): TDelphiSemanticSourceRange;
begin
  Result := Default(TDelphiSemanticSourceRange);
  Result.FileName := aModel.FileName;
  Result.Line := aReference.Line;
  Result.Column := aReference.Column;
  Result.EndLine := aReference.EndLine;
  Result.EndColumn := aReference.EndColumn;
  Result.Offset := aReference.Offset;
  Result.EndOffset := aReference.EndOffset;
  Result := CompleteNameRange(Result, aReference.Name);
end;

function WithSourceRange(const aModel: TDelphiSemanticUnitModel;
  const aWithStatement: TDelphiSemanticWithStatement): TDelphiSemanticSourceRange;
begin
  Result := Default(TDelphiSemanticSourceRange);
  Result.FileName := aModel.FileName;
  Result.Line := aWithStatement.Line;
  Result.Column := aWithStatement.Column;
  Result.EndLine := aWithStatement.EndLine;
  Result.EndColumn := aWithStatement.EndColumn;
end;

function WithBodyRange(const aModel: TDelphiSemanticUnitModel;
  const aWithStatement: TDelphiSemanticWithStatement): TDelphiSemanticSourceRange;
begin
  Result := Default(TDelphiSemanticSourceRange);
  Result.FileName := aModel.FileName;
  Result.Line := aWithStatement.BodyLine;
  Result.Column := aWithStatement.BodyColumn;
  Result.EndLine := aWithStatement.BodyEndLine;
  Result.EndColumn := aWithStatement.BodyEndColumn;
end;

function HasLaterClassBody(const aModel: TDelphiSemanticUnitModel;
  const aForward: TDelphiSemanticDeclaration): Boolean;
var
  lDeclaration: TDelphiSemanticDeclaration;
begin
  Result := False;
  if not SameText(aForward.Kind, 'type') or not SameText(aForward.TypeName, 'class') or
    (aForward.TypeBodyEndLine <> 0) or (aForward.SymbolId = '') then
    Exit;
  for lDeclaration in aModel.Declarations do
    if SameText(lDeclaration.SymbolId, aForward.SymbolId) and
      SameText(lDeclaration.Kind, 'type') and SameText(lDeclaration.TypeName, 'class') and
      SameText(lDeclaration.SectionKind, aForward.SectionKind) and
      SameText(lDeclaration.OwnerScopeId, aForward.OwnerScopeId) and
      (lDeclaration.Line > aForward.Line) and (lDeclaration.TypeBodyEndLine > 0) then
      Exit(True);
end;

procedure AddDeclarationSymbols(const aSymbols: TList<TDelphiSemanticGraphSymbol>;
  const aDeclarations: TList<TDelphiSemanticGraphDeclaration>;
  const aTypes: TList<TDelphiSemanticGraphType>;
  const aUnit: TDelphiSemanticGraphUnit; const aModel: TDelphiSemanticUnitModel);
var
  lDeclarationDto: TDelphiSemanticGraphDeclaration;
  lDeclaration: TDelphiSemanticDeclaration;
  lSymbol: TDelphiSemanticGraphSymbol;
  lType: TDelphiSemanticGraphType;
  lTypeName: string;
begin
  for lDeclaration in aModel.Declarations do
  begin
    if lDeclaration.Name = '' then
      Continue;

    lSymbol := Default(TDelphiSemanticGraphSymbol);
    lSymbol.Id := MakeSymbolId(aUnit.Id, lDeclaration.Kind, '', lDeclaration.Name,
      lDeclaration.Line, lDeclaration.Column, aSymbols.Count);
    lSymbol.UnitId := aUnit.Id;
    lSymbol.Name := lDeclaration.Name;
    lSymbol.Kind := lDeclaration.Kind;
    lSymbol.SourceRange := DeclarationSourceRange(aModel, lDeclaration);
    aSymbols.Add(lSymbol);

    lDeclarationDto := Default(TDelphiSemanticGraphDeclaration);
    lDeclarationDto.SymbolId := lSymbol.Id;
    lDeclarationDto.UnitId := aUnit.Id;
    lDeclarationDto.Name := lDeclaration.Name;
    lDeclarationDto.Kind := lDeclaration.Kind;
    lDeclarationDto.TypeName := lDeclaration.TypeName;
    lDeclarationDto.SectionKind := lDeclaration.SectionKind;
    lDeclarationDto.ScopeKind := lDeclaration.ScopeKind;
    lDeclarationDto.OwnerScopeId := lDeclaration.OwnerScopeId;
    lDeclarationDto.SemanticSymbolId := lDeclaration.SymbolId;
    lDeclarationDto.SourceRange := lSymbol.SourceRange;
    aDeclarations.Add(lDeclarationDto);

    if (SameText(lDeclaration.Kind, 'type') or SameText(lDeclaration.Kind, 'type-alias')) and
      not HasLaterClassBody(aModel, lDeclaration) then
    begin
      lTypeName := lDeclaration.TypeName;
      if lTypeName = '' then
        lTypeName := lDeclaration.Name;
      lType := Default(TDelphiSemanticGraphType);
      lType.Synthetic := Pos('.', lDeclaration.Name) > 0;
      lType.OwnerName := lDeclaration.OwnerName;
      lType.SymbolId := lSymbol.Id;
      lType.UnitId := aUnit.Id;
      lType.Name := lDeclaration.Name;
      lType.Kind := lDeclaration.Kind;
      lType.CanonicalName := lTypeName;
      lType.UnderlyingName := lTypeName;
      lType.BaseTypeName := lDeclaration.BaseTypeName;
      lType.HelperTargetName := lDeclaration.HelperTargetName;
      lType.HelperParentName := lDeclaration.HelperParentName;
      lType.SectionKind := lDeclaration.SectionKind;
      lType.ScopeKind := lDeclaration.ScopeKind;
      lType.OwnerScopeId := lDeclaration.OwnerScopeId;
      lType.SemanticSymbolId := lDeclaration.SymbolId;
      if SameText(lDeclaration.ScopeKind, 'routine') or SameText(lDeclaration.ScopeKind, 'type') then
      begin
        lType.DeclaredId := MakeScopedTypeId(aUnit.Id, 'declared',
          lDeclaration.OwnerScopeId, lDeclaration.SymbolId);
        lType.CanonicalId := MakeScopedTypeId(aUnit.Id, 'canonical',
          lDeclaration.OwnerScopeId, lDeclaration.SymbolId);
        lType.UnderlyingId := MakeScopedTypeId(aUnit.Id, 'underlying',
          lDeclaration.OwnerScopeId, lDeclaration.SymbolId);
      end else
      begin
        lType.DeclaredId := MakeTypeId(aUnit.Id, 'declared', lDeclaration.Name);
        lType.CanonicalId := MakeTypeId(aUnit.Id, 'canonical', lType.CanonicalName);
        lType.UnderlyingId := MakeTypeId(aUnit.Id, 'underlying', lType.UnderlyingName);
      end;
      lType.SourceRange := lSymbol.SourceRange;
      lType.VisibilityRange := lType.SourceRange;
      for var lEarlier in aModel.Declarations do
        if HasLaterClassBody(aModel, lEarlier) and
          SameText(lEarlier.SymbolId, lDeclaration.SymbolId) and
          SameText(lEarlier.OwnerScopeId, lDeclaration.OwnerScopeId) and
          SameText(lEarlier.SectionKind, lDeclaration.SectionKind) and
          SameText(DeclarationSourceRange(aModel, lEarlier).FileName, lType.SourceRange.FileName) and
          (lEarlier.Line > 0) and (lEarlier.Column > 0) and
          (lEarlier.Line < lType.VisibilityRange.Line) then
          // Visibility begins at the forward; declaration evidence stays at the body.
          lType.VisibilityRange := DeclarationSourceRange(aModel, lEarlier);
      aTypes.Add(lType);
    end;
  end;
end;

procedure AddMemberSymbols(const aSymbols: TList<TDelphiSemanticGraphSymbol>;
  const aMembers: TList<TDelphiSemanticGraphMember>; const aUnit: TDelphiSemanticGraphUnit;
  const aModel: TDelphiSemanticUnitModel);
var
  lMember: TDelphiSemanticMember;
  lMemberDto: TDelphiSemanticGraphMember;
  lSymbol: TDelphiSemanticGraphSymbol;
begin
  for lMember in aModel.Members do
  begin
    if lMember.Name = '' then
      Continue;

    lSymbol := Default(TDelphiSemanticGraphSymbol);
    lSymbol.Id := MakeSymbolId(aUnit.Id, lMember.Kind, lMember.OwnerName, lMember.Name,
      lMember.Line, lMember.Column, aSymbols.Count);
    lSymbol.UnitId := aUnit.Id;
    lSymbol.Name := lMember.Name;
    lSymbol.Kind := lMember.Kind;
    lSymbol.OwnerName := lMember.OwnerName;
    lSymbol.SourceRange := MemberSourceRange(aModel, lMember);
    aSymbols.Add(lSymbol);

    lMemberDto := Default(TDelphiSemanticGraphMember);
    lMemberDto.SymbolId := lSymbol.Id;
    lMemberDto.UnitId := aUnit.Id;
    lMemberDto.OwnerScopeId := lMember.OwnerScopeId;
    lMemberDto.OwnerSemanticSymbolId := lMember.OwnerSymbolId;
    lMemberDto.OwnerName := lMember.OwnerName;
    lMemberDto.Name := lMember.Name;
    lMemberDto.Kind := lMember.Kind;
    lMemberDto.TypeName := lMember.TypeName;
    lMemberDto.Visibility := lMember.Visibility;
    lMemberDto.Signature := lMember.Signature;
    lMemberDto.IsIndexed := lMember.IsIndexed;
    lMemberDto.IsDefault := lMember.IsDefault;
    lMemberDto.SourceRange := lSymbol.SourceRange;
    aMembers.Add(lMemberDto);
  end;
end;

procedure AddRoutineSymbols(const aSymbols: TList<TDelphiSemanticGraphSymbol>;
  const aRoutines: TList<TDelphiSemanticGraphRoutine>;
  const aParameters: TList<TDelphiSemanticGraphParameter>; const aUnit: TDelphiSemanticGraphUnit;
  const aModel: TDelphiSemanticUnitModel);
var
  lParameter: TDelphiSemanticParameter;
  lParameterDto: TDelphiSemanticGraphParameter;
  lRoutine: TDelphiSemanticRoutine;
  lRoutineDto: TDelphiSemanticGraphRoutine;
  lSymbol: TDelphiSemanticGraphSymbol;
begin
  for lRoutine in aModel.Routines do
  begin
    if lRoutine.Name = '' then
      Continue;

    lSymbol := Default(TDelphiSemanticGraphSymbol);
    lSymbol.Id := MakeSymbolId(aUnit.Id, 'routine', lRoutine.OwnerName, lRoutine.Name,
      lRoutine.Line, lRoutine.Column, aSymbols.Count);
    lSymbol.UnitId := aUnit.Id;
    lSymbol.Name := lRoutine.Name;
    lSymbol.Kind := 'routine';
    lSymbol.OwnerName := lRoutine.OwnerName;
    lSymbol.SourceRange := RoutineSourceRange(aModel, lRoutine);
    aSymbols.Add(lSymbol);

    lRoutineDto := Default(TDelphiSemanticGraphRoutine);
    lRoutineDto.SymbolId := lSymbol.Id;
    lRoutineDto.UnitId := aUnit.Id;
    lRoutineDto.Name := lRoutine.Name;
    lRoutineDto.OwnerName := lRoutine.OwnerName;
    lRoutineDto.SectionKind := lRoutine.SectionKind;
    lRoutineDto.Signature := lRoutine.Signature;
    lRoutineDto.ReturnType := lRoutine.ReturnType;
    lRoutineDto.ScopeId := lRoutine.ScopeId;
    lRoutineDto.ParentScopeId := lRoutine.ParentScopeId;
    lRoutineDto.AstScopeKind := lRoutine.AstScopeKind;
    lRoutineDto.AstSemanticSignature := lRoutine.AstSemanticSignature;
    lRoutineDto.AstSourceSignature := lRoutine.AstSourceSignature;
    lRoutineDto.AstSourceSignatureVerified := lRoutine.AstSourceSignatureVerified;
    lRoutineDto.SourceRange := lSymbol.SourceRange;
    aRoutines.Add(lRoutineDto);

    for lParameter in lRoutine.Parameters do
    begin
      lSymbol := Default(TDelphiSemanticGraphSymbol);
      lSymbol.Id := MakeSymbolId(aUnit.Id, 'parameter', lParameter.RoutineName,
        lParameter.Name, 0, 0, aSymbols.Count);
      lSymbol.UnitId := aUnit.Id;
      lSymbol.Name := lParameter.Name;
      lSymbol.Kind := 'parameter';
      lSymbol.OwnerName := lParameter.RoutineName;
      lSymbol.SourceRange := ParameterSourceRange(aModel, lParameter);
      aSymbols.Add(lSymbol);

      lParameterDto := Default(TDelphiSemanticGraphParameter);
      lParameterDto.SymbolId := lSymbol.Id;
      lParameterDto.UnitId := aUnit.Id;
      lParameterDto.RoutineName := lParameter.RoutineName;
      lParameterDto.RoutineScopeId := lRoutine.ScopeId;
      lParameterDto.Name := lParameter.Name;
      lParameterDto.TypeName := lParameter.TypeName;
      lParameterDto.Modifier := lParameter.Modifier;
      lParameterDto.SourceRange := lSymbol.SourceRange;
      aParameters.Add(lParameterDto);
    end;
  end;
end;

procedure AddLocalSymbols(const aSymbols: TList<TDelphiSemanticGraphSymbol>;
  const aLocals: TList<TDelphiSemanticGraphLocal>; const aUnit: TDelphiSemanticGraphUnit;
  const aModel: TDelphiSemanticUnitModel);
var
  lLocal: TDelphiSemanticLocal;
  lLocalDto: TDelphiSemanticGraphLocal;
  lSymbol: TDelphiSemanticGraphSymbol;
begin
  for lLocal in aModel.Locals do
  begin
    if lLocal.Name = '' then
      Continue;

    lSymbol := Default(TDelphiSemanticGraphSymbol);
    lSymbol.Id := MakeSymbolId(aUnit.Id, lLocal.Kind, lLocal.RoutineName, lLocal.Name,
      lLocal.Line, lLocal.Column, aSymbols.Count);
    lSymbol.UnitId := aUnit.Id;
    lSymbol.Name := lLocal.Name;
    lSymbol.Kind := lLocal.Kind;
    lSymbol.OwnerName := lLocal.RoutineName;
    lSymbol.SourceRange := LocalSourceRange(aModel, lLocal);
    aSymbols.Add(lSymbol);

    lLocalDto := Default(TDelphiSemanticGraphLocal);
    lLocalDto.SymbolId := lSymbol.Id;
    lLocalDto.UnitId := aUnit.Id;
    lLocalDto.RoutineName := lLocal.RoutineName;
    lLocalDto.RoutineScopeId := lLocal.RoutineScopeId;
    lLocalDto.Name := lLocal.Name;
    lLocalDto.Kind := lLocal.Kind;
    lLocalDto.TypeName := lLocal.TypeName;
    lLocalDto.SourceRange := lSymbol.SourceRange;
    aLocals.Add(lLocalDto);
  end;
end;

procedure AddReferences(const aReferences: TList<TDelphiSemanticGraphReference>;
  const aUnit: TDelphiSemanticGraphUnit; const aModel: TDelphiSemanticUnitModel);
var
  lReference: TDelphiSemanticReference;
  lReferenceDto: TDelphiSemanticGraphReference;
  lUnitOrdinal: Integer;
begin
  lUnitOrdinal := 0;
  for lReference in aModel.References do
  begin
    if lReference.Name = '' then
      Continue;

    lReferenceDto := Default(TDelphiSemanticGraphReference);
    lReferenceDto.Id := MakeReferenceId(aUnit.Id, lReference, lUnitOrdinal);
    lReferenceDto.UnitId := aUnit.Id;
    lReferenceDto.Name := lReference.Name;
    lReferenceDto.RoutineName := lReference.RoutineName;
    lReferenceDto.RoutineScopeId := lReference.RoutineScopeId;
    lReferenceDto.Role := lReference.Role;
    lReferenceDto.SectionKind := lReference.SectionKind;
    lReferenceDto.SourceRange := ReferenceSourceRange(aModel, lReference);
    aReferences.Add(lReferenceDto);
    Inc(lUnitOrdinal);
  end;
end;

procedure AddWithStatements(const aWithStatements: TList<TDelphiSemanticGraphWithStatement>;
  const aUnit: TDelphiSemanticGraphUnit; const aModel: TDelphiSemanticUnitModel);
var
  lWithDto: TDelphiSemanticGraphWithStatement;
  lWithStatement: TDelphiSemanticWithStatement;
  lUnitOrdinal: Integer;
begin
  lUnitOrdinal := 0;
  for lWithStatement in aModel.WithStatements do
  begin
    lWithDto := Default(TDelphiSemanticGraphWithStatement);
    lWithDto.Id := MakeWithStatementId(aUnit.Id, lWithStatement, lUnitOrdinal);
    lWithDto.UnitId := aUnit.Id;
    lWithDto.SelectorText := lWithStatement.SelectorText;
    lWithDto.SelectorCount := lWithStatement.SelectorCount;
    lWithDto.NestingDepth := lWithStatement.NestingDepth;
    lWithDto.SourceRange := WithSourceRange(aModel, lWithStatement);
    lWithDto.BodyRange := WithBodyRange(aModel, lWithStatement);
    aWithStatements.Add(lWithDto);
    Inc(lUnitOrdinal);
  end;
end;

constructor TDelphiSemanticSemanticGraph.Create(
  const aProjectId: TDelphiSemanticProjectGraphId;
  const aUnits: TArray<TDelphiSemanticGraphUnit>;
  const aSymbols: TArray<TDelphiSemanticGraphSymbol>;
  const aDeclarations: TArray<TDelphiSemanticGraphDeclaration>;
  const aTypes: TArray<TDelphiSemanticGraphType>;
  const aMembers: TArray<TDelphiSemanticGraphMember>;
  const aRoutines: TArray<TDelphiSemanticGraphRoutine>;
  const aParameters: TArray<TDelphiSemanticGraphParameter>;
  const aLocals: TArray<TDelphiSemanticGraphLocal>;
  const aMetrics: TDelphiSemanticGraphBuildMetrics);
begin
  Create(aProjectId, aUnits, aSymbols, aDeclarations, aTypes, aMembers, aRoutines,
    aParameters, aLocals, nil, nil, aMetrics);
end;

constructor TDelphiSemanticSemanticGraph.Create(
  const aProjectId: TDelphiSemanticProjectGraphId;
  const aUnits: TArray<TDelphiSemanticGraphUnit>;
  const aSymbols: TArray<TDelphiSemanticGraphSymbol>;
  const aDeclarations: TArray<TDelphiSemanticGraphDeclaration>;
  const aTypes: TArray<TDelphiSemanticGraphType>;
  const aMembers: TArray<TDelphiSemanticGraphMember>;
  const aRoutines: TArray<TDelphiSemanticGraphRoutine>;
  const aParameters: TArray<TDelphiSemanticGraphParameter>;
  const aLocals: TArray<TDelphiSemanticGraphLocal>;
  const aReferences: TArray<TDelphiSemanticGraphReference>;
  const aWithStatements: TArray<TDelphiSemanticGraphWithStatement>;
  const aMetrics: TDelphiSemanticGraphBuildMetrics);
begin
  inherited Create;
  fProjectId := aProjectId;
  fUnits := Copy(aUnits);
  fSymbols := Copy(aSymbols);
  fDeclarations := Copy(aDeclarations);
  fTypes := Copy(aTypes);
  fMembers := Copy(aMembers);
  fRoutines := Copy(aRoutines);
  fParameters := Copy(aParameters);
  fLocals := Copy(aLocals);
  fReferences := Copy(aReferences);
  fWithStatements := Copy(aWithStatements);
  fMetrics := aMetrics;
end;

function TDelphiSemanticSemanticGraph.Declarations: TArray<TDelphiSemanticGraphDeclaration>;
begin
  Result := Copy(fDeclarations);
end;

function TDelphiSemanticSemanticGraph.FindRoutineByName(const aName: string;
  out aRoutine: TDelphiSemanticGraphRoutine): Boolean;
var
  lRoutine: TDelphiSemanticGraphRoutine;
begin
  for lRoutine in fRoutines do
    if SameText(lRoutine.Name, aName) then
    begin
      aRoutine := lRoutine;
      Exit(True);
    end;

  aRoutine := Default(TDelphiSemanticGraphRoutine);
  Result := False;
end;

function TDelphiSemanticSemanticGraph.FindTypeByName(const aName: string;
  out aType: TDelphiSemanticGraphType): Boolean;
var
  lType: TDelphiSemanticGraphType;
begin
  for lType in fTypes do
    if SameText(lType.Name, aName) then
    begin
      aType := lType;
      Exit(True);
    end;

  aType := Default(TDelphiSemanticGraphType);
  Result := False;
end;

function TDelphiSemanticSemanticGraph.FindUnitByName(const aUnitName: string;
  out aUnit: TDelphiSemanticGraphUnit): Boolean;
var
  lUnit: TDelphiSemanticGraphUnit;
begin
  for lUnit in fUnits do
    if SameText(lUnit.UnitName, aUnitName) then
    begin
      aUnit := lUnit;
      Exit(True);
    end;

  aUnit := Default(TDelphiSemanticGraphUnit);
  Result := False;
end;

function TDelphiSemanticSemanticGraph.Locals: TArray<TDelphiSemanticGraphLocal>;
begin
  Result := Copy(fLocals);
end;

function TDelphiSemanticSemanticGraph.Members: TArray<TDelphiSemanticGraphMember>;
begin
  Result := Copy(fMembers);
end;

function TDelphiSemanticSemanticGraph.Parameters: TArray<TDelphiSemanticGraphParameter>;
begin
  Result := Copy(fParameters);
end;

function TDelphiSemanticSemanticGraph.References: TArray<TDelphiSemanticGraphReference>;
begin
  Result := Copy(fReferences);
end;

function TDelphiSemanticSemanticGraph.Routines: TArray<TDelphiSemanticGraphRoutine>;
begin
  Result := Copy(fRoutines);
end;

function TDelphiSemanticSemanticGraph.Symbols: TArray<TDelphiSemanticGraphSymbol>;
begin
  Result := Copy(fSymbols);
end;

function TDelphiSemanticSemanticGraph.Types: TArray<TDelphiSemanticGraphType>;
begin
  Result := Copy(fTypes);
end;

function TDelphiSemanticSemanticGraph.Units: TArray<TDelphiSemanticGraphUnit>;
begin
  Result := Copy(fUnits);
end;

function TDelphiSemanticSemanticGraph.WithStatements:
  TArray<TDelphiSemanticGraphWithStatement>;
begin
  Result := Copy(fWithStatements);
end;

function CanonicalProjectImport(const aProject: TDelphiSemanticProjectInfo;
  const aModels: TArray<TDelphiSemanticUnitModel>; const aUnitName: string): string;
var
  lCandidate: TUnitCandidateName;
  lModel: TDelphiSemanticUnitModel;
  lResolved: TDelphiSemanticUnitResolutionResult;
begin
  Result := aUnitName;
  // Only a model hit can change ProjectImports' spelling. Avoid filesystem
  // resolution for source/DCU-only names; their result is discarded below.
  for lCandidate in TDelphiSemanticUnitResolver.CandidateNames(aProject, Trim(aUnitName)) do
    for lModel in aModels do
      if SameText(lModel.UnitName, lCandidate.TargetName) then
      begin
        lResolved := TDelphiSemanticUnitResolver.Resolve(aProject, aUnitName, aModels);
        if lResolved.Found and SameText(lResolved.SourceKind, 'project') then
          Result := lResolved.CanonicalUnitName;
        Exit;
      end;
end;

function ProjectImportsPrepared(const aProject: TDelphiSemanticProjectInfo;
  const aModel: TDelphiSemanticUnitModel; const aModels: TArray<TDelphiSemanticUnitModel>;
  const aCache: TDictionary<string, string>;
  out aInterface, aImplementation: TArray<string>): Boolean;
var
  i: Integer;
  lRawImports: TArray<string>;
begin
  if aModel.DependencyFacts.Known then
  begin
    aInterface := Copy(aModel.DependencyFacts.InterfaceImports);
    aImplementation := Copy(aModel.DependencyFacts.ImplementationImports);
    if (Length(aInterface) = 0) and (Length(aModel.DependencyFacts.RootImports) > 0) then
    begin
      aInterface := Copy(aModel.DependencyFacts.RootImports);
      aImplementation := Copy(aModel.DependencyFacts.RootImports);
    end;
  end else begin
    aInterface := Copy(aModel.InterfaceUses);
    aImplementation := Copy(aModel.ImplementationUses);
  end;
  // Concatenation with an empty array may share storage with its nonempty input.
  // Keep the raw spelling independent of the canonicalization below.
  lRawImports := Copy(aInterface + aImplementation);
  for i := 0 to High(aInterface) do
    aInterface[i] := CachedProjectImport(aProject, aModels, aInterface[i], aCache);
  for i := 0 to High(aImplementation) do
    aImplementation[i] := CachedProjectImport(aProject, aModels, aImplementation[i], aCache);
  Result := aModel.DependencyFacts.Known and aModel.Success and
    (SameText(aModel.ScopeModelStatus, 'ast') or
     SameText(aModel.ScopeModelStatus, 'ast-interface-only')) and
    not TDelphiSemanticSourceConditionals.ImportOrderUnknown(aModel.SourceText,
      aModel.VerifiedActiveSourceText, aModel.IncludeFileNames, lRawImports);
end;

class function TDelphiSemanticSemanticGraphBuilder.ProjectImports(
  const aProject: TDelphiSemanticProjectInfo; const aModel: TDelphiSemanticUnitModel;
  const aModels: TArray<TDelphiSemanticUnitModel>;
  out aInterface, aImplementation: TArray<string>): Boolean;
begin
  Result := ProjectImportsPrepared(aProject, aModel, aModels, nil,
    aInterface, aImplementation);
end;

class function TDelphiSemanticSemanticGraphBuilder.Build(
  const aProject: TDelphiSemanticProjectInfo;
  const aUnitModels: TArray<TDelphiSemanticUnitModel>): TDelphiSemanticSemanticGraph;
var
  lImportCache: TDictionary<string, string>;
  lDeclarations: TList<TDelphiSemanticGraphDeclaration>;
  lLocals: TList<TDelphiSemanticGraphLocal>;
  lMembers: TList<TDelphiSemanticGraphMember>;
  lMetrics: TDelphiSemanticGraphBuildMetrics;
  lParameters: TList<TDelphiSemanticGraphParameter>;
  lReferences: TList<TDelphiSemanticGraphReference>;
  lUnit: TDelphiSemanticGraphUnit;
  lProjectId: TDelphiSemanticProjectGraphId;
  lRoutines: TList<TDelphiSemanticGraphRoutine>;
  lStopwatch: TStopwatch;
  lSymbols: TList<TDelphiSemanticGraphSymbol>;
  lTypes: TList<TDelphiSemanticGraphType>;
  lUnits: TList<TDelphiSemanticGraphUnit>;
  lWithStatements: TList<TDelphiSemanticGraphWithStatement>;
  lModel: TDelphiSemanticUnitModel;
begin
  lStopwatch := TStopwatch.StartNew;
  lImportCache := nil;
  lDeclarations := nil;
  lTypes := nil;
  lMembers := nil;
  lRoutines := nil;
  lParameters := nil;
  lLocals := nil;
  lReferences := nil;
  lWithStatements := nil;
  lSymbols := nil;
  lUnits := TList<TDelphiSemanticGraphUnit>.Create;
  try
    // Exact import spelling is the only varying input here. Project aliases,
    // scopes and the ordered model snapshot are fixed for this Build call.
    // This cache never survives a graph build or caches a site-based answer.
    lImportCache := TDictionary<string, string>.Create(TStringComparer.Ordinal);
    lDeclarations := TList<TDelphiSemanticGraphDeclaration>.Create;
    lTypes := TList<TDelphiSemanticGraphType>.Create;
    lMembers := TList<TDelphiSemanticGraphMember>.Create;
    lRoutines := TList<TDelphiSemanticGraphRoutine>.Create;
    lParameters := TList<TDelphiSemanticGraphParameter>.Create;
    lLocals := TList<TDelphiSemanticGraphLocal>.Create;
    lReferences := TList<TDelphiSemanticGraphReference>.Create;
    lWithStatements := TList<TDelphiSemanticGraphWithStatement>.Create;
    lSymbols := TList<TDelphiSemanticGraphSymbol>.Create;
    lProjectId := MakeProjectId(aProject);
    for lModel in aUnitModels do
      if lModel.Success and (lModel.UnitName <> '') then
      begin
        lUnit := BuildUnit(lProjectId, aProject, lModel, aUnitModels, lImportCache);
        lUnits.Add(lUnit);
        AddDeclarationSymbols(lSymbols, lDeclarations, lTypes, lUnit, lModel);
        AddMemberSymbols(lSymbols, lMembers, lUnit, lModel);
        AddRoutineSymbols(lSymbols, lRoutines, lParameters, lUnit, lModel);
        AddLocalSymbols(lSymbols, lLocals, lUnit, lModel);
        AddReferences(lReferences, lUnit, lModel);
        AddWithStatements(lWithStatements, lUnit, lModel);
      end;

    lStopwatch.Stop;
    lMetrics := Default(TDelphiSemanticGraphBuildMetrics);
    lMetrics.UnitCount := lUnits.Count;
    lMetrics.SymbolCount := lSymbols.Count;
    lMetrics.ReferenceCount := lReferences.Count;
    lMetrics.WithStatementCount := lWithStatements.Count;
    lMetrics.BuildMilliseconds := lStopwatch.ElapsedMilliseconds;
    Result := TDelphiSemanticSemanticGraph.Create(lProjectId, lUnits.ToArray,
      lSymbols.ToArray, lDeclarations.ToArray, lTypes.ToArray, lMembers.ToArray,
      lRoutines.ToArray, lParameters.ToArray, lLocals.ToArray, lReferences.ToArray,
      lWithStatements.ToArray, lMetrics);
  finally
    lImportCache.Free;
    lSymbols.Free;
    lWithStatements.Free;
    lReferences.Free;
    lLocals.Free;
    lParameters.Free;
    lRoutines.Free;
    lMembers.Free;
    lTypes.Free;
    lDeclarations.Free;
    lUnits.Free;
  end;
end;

end.
