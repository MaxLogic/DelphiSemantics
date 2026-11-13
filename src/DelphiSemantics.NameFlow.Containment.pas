unit DelphiSemantics.NameFlow.Containment;

interface

uses
  DelphiSemantics.NameConsumers, DelphiSemantics.NameFlow.SdkEffects,
  DelphiSemantics.Snapshot, DelphiSemantics.Usage;

type
  TNameFlowStatistics = record
    FactCount, CallCount, ExactCalls, JoinedCalls, UnboundCalls: Integer;
    OpaqueSdkCalls, OpaqueProjectCalls, MetadataObservers, LanguageRoots: Integer;
    ConfigurationGaps, CoverageGaps: Integer;
    DistinctUncoveredSdkCallees, DistinctUncoveredProjectCallees: Integer;
    ReceiverMetadataObservers, ArgumentMetadataObservers, GlobalMetadataObservers, NameProducers: Integer;
    SdkIdentity: string;
  end;

  TNameFlowAnalysis = record
    Gaps: TArray<TDelphiSemanticUsage>;
    Statistics: TNameFlowStatistics;
  end;

// Refusal-only slice-2 inventory. It never discharges an existing barrier.
function AnalyzeNameFlowSnapshot(const aSnapshot: TDelphiProjectSnapshot;
  const aTargetKind: TNameEffectTargetKind; const aSdk: TNameSdkCatalog): TNameFlowAnalysis; overload;
function AnalyzeNameFlowSnapshot(const aSnapshot: TDelphiProjectSnapshot;
  const aTargetKind: TNameEffectTargetKind; const aSdk: TNameSdkCatalog;
  const aNames: TArray<string>): TNameFlowAnalysis; overload;

function NameFlowDeclarationKind(const aSnapshot: TDelphiProjectSnapshot;
  const aFileName, aName: string; const aLine: Integer): string;

function TryBindNameFlowConstant(const aSnapshot: TDelphiProjectSnapshot;
  const aFileName, aName: string; const aLine, aColumn: Integer;
  out aUnit: TUnitSnapshot; out aSymbol: TSemanticSymbolFact): Boolean;

implementation

uses
  System.Generics.Collections, System.Generics.Defaults, System.Hash, System.IOUtils, System.StrUtils, System.SysUtils,
  AutoFree,
  DelphiSemantics.ImportFacts, DelphiSemantics.Model.Text, DelphiSemantics.NameFlow.Facts, DelphiSemantics.Snapshot.PositionResolver;

const
  cNameConsumerPrefixes: array[0..11] of string = ('System.Classes', 'System.Classes.TComponent',
    'System.TypInfo', 'System.Rtti.TRttiType', 'System.Rtti.TRttiContext',
    'System.Rtti.TRttiEnumerationType', 'System.TObject', 'Winapi.Windows', 'Winapi.ActiveX',
    'System.Rtti.TRttiNamedObject', 'System.Rtti.TRttiPackage', 'System.TypInfo.TTypeInfoFieldAccessor');

function SourceExcludesKnownConsumers(const aSource: string; const aIncludesOnly: Boolean = False): Boolean;
var
  lChecked: TDictionary<string, Boolean>;
  lEffect: TNameSdkEffect;
  lToken, lPrefix: string;
  lIsConsumer: Boolean;
  i, lStart, lDirective: Integer;
begin
  Result := False;
  if aSource = '' then
    Exit;
  lChecked := TDictionary<string, Boolean>.Create(TStringComparer.Ordinal);
  try
    i := 1;
    while i <= Length(aSource) do
    begin
      // Includes can contain consumers absent from this retained unit text.
      // Read directive names conservatively, including whitespace variants.
      lDirective := 0;
      if aSource[i] = '{' then
        lDirective := i + 1
      else if (aSource[i] = '(') and (Copy(aSource, i, 2) = '(*') then
        lDirective := i + 2;
      if lDirective > 0 then
      begin
        while (lDirective <= Length(aSource)) and
          CharInSet(aSource[lDirective], [#9, #10, #13, ' ']) do
          Inc(lDirective);
        if (lDirective <= Length(aSource)) and (aSource[lDirective] = '$') then
        begin
          Inc(lDirective);
          while (lDirective <= Length(aSource)) and
            CharInSet(aSource[lDirective], [#9, #10, #13, ' ']) do
            Inc(lDirective);
          lStart := lDirective;
          while (lDirective <= Length(aSource)) and IsIdentifierChar(aSource[lDirective]) do
            Inc(lDirective);
          lToken := Copy(aSource, lStart, lDirective - lStart);
          if SameText(lToken, 'INCLUDE') then
            Exit;
          if SameText(lToken, 'I') then
            if (lDirective > Length(aSource)) or
              not CharInSet(aSource[lDirective], ['+', '-']) then
              Exit;
        end;
      end;
      if not IsIdentifierStart(aSource[i]) then
      begin
        Inc(i);
        Continue;
      end;
      lStart := i;
      while (i <= Length(aSource)) and IsIdentifierChar(aSource[i]) do
        Inc(i);
      if aIncludesOnly then
        Continue;
      lToken := LowerCase(Copy(aSource, lStart, i - lStart));
      if not lChecked.TryGetValue(lToken, lIsConsumer) then
      begin
        lIsConsumer := False;
        for lPrefix in cNameConsumerPrefixes do
          if PositivePrimitiveNameConsumer(lPrefix + '.' + lToken, lEffect) then
          begin
            lIsConsumer := True;
            Break;
          end;
        lChecked.Add(lToken, lIsConsumer);
      end;
      // Scan comments, literals and inactive branches too. A false positive
      // retains a refusal; failed parsing must not hide a consumer spelling.
      if lIsConsumer then
        Exit;
    end;
    Result := True;
  finally
    lChecked.Free;
  end;
end;

function TryBindNameFlowConstant(const aSnapshot: TDelphiProjectSnapshot;
  const aFileName, aName: string; const aLine, aColumn: Integer;
  out aUnit: TUnitSnapshot; out aSymbol: TSemanticSymbolFact): Boolean;
var
  lUnit: TUnitSnapshot;
  lSymbol: TSemanticSymbolFact;
  lFacts: IDelphiNameFlowFacts;
  lNode, lUseNode: TDelphiNameFlowNode;
  lAncestryComplete: Boolean;
  lScope, lCandidateScope, lSource: string;
  lWithId: TSemanticWithId;
  i, j, lDepth, lUseMatches, lScore, lBest, lMatches: Integer;
begin
  Result := False;
  aUnit := nil;
  aSymbol := Default(TSemanticSymbolFact);
  if aSnapshot = nil then
    Exit;
  for i := 0 to aSnapshot.UnitCount - 1 do
  begin
    lUnit := aSnapshot.UnitByIndex(i);
    if not SameText(aSnapshot.TextOf(lUnit.FileNameId), aFileName) then
      Continue;
    // WITH can capture a member from a different unit before a unit constant.
    // Our spelling-based constant fallback does not certify that binding.
    if lUnit.TryFindInnermostWithStatementAtLine(aLine, lWithId) then
      Exit;
    lSource := aSnapshot.ExactTextOf(lUnit.SourceTextId);
    // Selected-pair text cannot discharge inactive nearer declarations or
    // conditionally declared dependencies. No imported spelling union is used.
    if ContainsText(lSource, '{$IF') or ContainsText(lSource, '(*$IF') or
      ContainsText(lSource, '{$I ') or ContainsText(lSource, '{$INCLUDE') then
      Exit;
    lFacts := NameFlowFactsFromJson(aSnapshot.ExactTextOf(lUnit.NameFlowFactsJsonId));
    if not lFacts.Complete then
      Exit;
    lUseMatches := 0;
    lUseNode := Default(TDelphiNameFlowNode);
    for j := 1 to lFacts.NodeCount do
    begin
      lNode := lFacts.NodeById(j);
      if (lNode.Line = aLine) and (lNode.Column = aColumn) and
        SameText(lNode.Name, aName) and (lNode.SyntaxKind = 'identifier') then
      begin
        Inc(lUseMatches);
        lUseNode := lNode;
      end;
    end;
    if lUseMatches <> 1 then
      Exit;
    lScope := lUseNode.ScopeId;
    lNode := lUseNode;
    lAncestryComplete := False;
    // Lean models omit body symbol/WITH inventory but retain this full AST.
    // Absence of a snapshot WITH record is therefore not an absence proof.
    for lDepth := 0 to 63 do
    begin
      if not lNode.SpanKnown or not lNode.ActivityKnown or (lNode.SyntaxKind = 'with') then
        Exit;
      if lNode.ParentId = 0 then
      begin
        lAncestryComplete := True;
        Break;
      end;
      if (lNode.ParentId < 1) or (lNode.ParentId > lFacts.NodeCount) then
        Exit;
      lNode := lFacts.NodeById(lNode.ParentId);
    end;
    if not lAncestryComplete then
      Exit;
    lBest := -1;
    lMatches := 0;
    for j := 1 to lUnit.SymbolCount do
    begin
      lSymbol := lUnit.SymbolById(j);
      lCandidateScope := aSnapshot.TextOf(lSymbol.RoutineScopeId);
      // Method lookup can capture fields or inherited members absent from our
      // local constant inventory. Without that closure, keep the value unknown.
      if (lSymbol.OwnerTypeId <> 0) and (lCandidateScope <> '') and
        (SameText(lCandidateScope, lScope) or StartsText(lCandidateScope + '/', lScope)) then
        Exit;
      if not SameText(aSnapshot.TextOf(lSymbol.NameId), aName) then
        Continue;
      // Included and member declarations are plausible nearer bindings; they
      // cannot be skipped to expose a same-spelled unit constant.
      if (lSymbol.FileId <> 0) or (lSymbol.OwnerTypeId <> 0) then
        Exit;
      if (lSymbol.Line > aLine) or
        ((lSymbol.Line = aLine) and (lSymbol.Column >= aColumn)) then
        Continue;
      lCandidateScope := aSnapshot.TextOf(lSymbol.RoutineScopeId);
      if SameText(aSnapshot.TextOf(lSymbol.ScopeKindId), 'routine') then
        lCandidateScope := aSnapshot.TextOf(lSymbol.OwnerScopeId);
      if (lCandidateScope <> '') and not SameText(lCandidateScope, lScope) and
        not StartsText(lCandidateScope + '/', lScope) then
        Continue;
      lScore := Length(lCandidateScope);
      if lScore < lBest then
        Continue;
      if lScore > lBest then
      begin
        lBest := lScore;
        lMatches := 0;
      end;
      Inc(lMatches);
      aUnit := lUnit;
      aSymbol := lSymbol;
    end;
    if lMatches = 1 then
    begin
      lCandidateScope := aSnapshot.TextOf(aSymbol.RoutineScopeId);
      if SameText(aSnapshot.TextOf(aSymbol.ScopeKindId), 'routine') then
        lCandidateScope := aSnapshot.TextOf(aSymbol.OwnerScopeId);
      // Body/line-oriented symbol inventory can omit an inline local constant.
      // A captured nearer AST declaration still blocks an outer constant.
      for j := 1 to lFacts.NodeCount do
      begin
        lNode := lFacts.NodeById(j);
        if not (lNode.Kind in [TDelphiNameFlowNodeKind.Definition, TDelphiNameFlowNodeKind.Formal]) or
          not SameText(lNode.Name, aName) or (lNode.Line > aLine) or
          ((lNode.Line = aLine) and (lNode.Column >= aColumn)) then
          Continue;
        if (lNode.ScopeId <> '') and
          ((Length(lNode.ScopeId) < Length(lCandidateScope)) or
           (not SameText(lNode.ScopeId, lScope) and not StartsText(lNode.ScopeId + '/', lScope))) then
          Continue;
        if lNode.SpanKnown and lNode.ActivityKnown and
          (lNode.Line = aSymbol.Line) and (lNode.Column = aSymbol.Column) and
          SameText(lNode.ScopeId, lCandidateScope) then
          Continue;
        // An unscoped/ambiguous declaration cannot prove that it is farther away.
        aUnit := nil;
        aSymbol := Default(TSemanticSymbolFact);
        Exit;
      end;
    end;
    // Bind the nearest declaration before asking whether it is a constant.
    // A parameter/local/typed constant must never expose an outer constant.
    Result := (lMatches = 1) and
      MatchText(aSnapshot.TextOf(aSymbol.KindId), ['const', 'resourcestring']);
    if not Result then
    begin
      aUnit := nil;
      aSymbol := Default(TSemanticSymbolFact);
    end;
    Exit;
  end;
end;

function NameFlowDeclarationKind(const aSnapshot: TDelphiProjectSnapshot;
  const aFileName, aName: string; const aLine: Integer): string;
var
  lUnit: TUnitSnapshot;
  lFacts: IDelphiNameFlowFacts;
  lNode, lType: TDelphiNameFlowNode;
  i, j, lChild: Integer;
begin
  Result := '';
  if aSnapshot = nil then
    Exit;
  for i := 0 to aSnapshot.UnitCount - 1 do
  begin
    lUnit := aSnapshot.UnitByIndex(i);
    if not SameText(aSnapshot.TextOf(lUnit.FileNameId), aFileName) then
      Continue;
    lFacts := NameFlowFactsFromJson(aSnapshot.ExactTextOf(lUnit.NameFlowFactsJsonId));
    for j := 1 to lFacts.NodeCount do
    begin
      lNode := lFacts.NodeById(j);
      if (lNode.SyntaxKind <> 'typedecl') or not SameText(lNode.Name, aName) or
        (lNode.Line <> aLine) then
        Continue;
      for lChild in lNode.Children do
      begin
        lType := lFacts.NodeById(lChild);
        if lType.SyntaxKind = 'type' then
        begin
          Result := lType.TypeName;
          if Result = '' then
            Result := lType.Name;
          Exit;
        end;
      end;
    end;
  end;
end;

function AnalyzeNameFlowSnapshot(const aSnapshot: TDelphiProjectSnapshot;
  const aTargetKind: TNameEffectTargetKind; const aSdk: TNameSdkCatalog): TNameFlowAnalysis;
begin
  Result := AnalyzeNameFlowSnapshot(aSnapshot, aTargetKind, aSdk, nil);
end;

function AnalyzeNameFlowSnapshot(const aSnapshot: TDelphiProjectSnapshot;
  const aTargetKind: TNameEffectTargetKind; const aSdk: TNameSdkCatalog;
  const aNames: TArray<string>): TNameFlowAnalysis;
var
  g: TGarbos;
  i, j, lIndex: Integer;
  lUnit: TUnitSnapshot;
  lFacts: IDelphiNameFlowFacts;
  lNode, lParent, lCallNode: TDelphiNameFlowNode;
  lResolution: TDelphiSemanticSnapshotPositionResolution;
  lEntry: TNameSdkEffectEntry;
  lEntries: TArray<TNameSdkEffectEntry>;
  lByName: TObjectDictionary<string, TList<Integer>>;
  lCandidates: TList<Integer>;
  lClassLineages: TDictionary<string, TArray<string>>;
  lClassLineageComplete: TDictionary<string, Boolean>;
  lEffects: TList<TNameSdkEffect>;
  lGaps: TList<TDelphiSemanticUsage>;
  lSeen, lCallSites, lOpaqueSdk, lOpaqueProject, lPinnedSources: TDictionary<string, Boolean>;
  lEffect, lKnownEffect: TNameSdkEffect;
  lFileName, lKind, lName, lSource, lJson, lKey: string;
  lObserved, lUnitConfigurationUnproved, lUnitConfigurationReported: Boolean;
  lResolved, lCallable, lExactSdk, lSdkCurrent, lExplicitCall: Boolean;

  procedure Report(const aFileName, aName, aReason: string;
    const aLine, aColumn: Integer);
  var
    lGap: TDelphiSemanticUsage;
    lReportKey: string;
  begin
    lReportKey := aFileName + '|' + aReason + '|' + aName + '|' +
      IntToStr(aLine) + ':' + IntToStr(aColumn);
    if (aFileName = '') and (lNode.Id > 0) then
      lReportKey := lReportKey + '|' + lFileName + ':' +
        IntToStr(lNode.OutputStartOffset) + ':' + IntToStr(lNode.OutputEndOffset);
    if lSeen.ContainsKey(lReportKey) then
      Exit;
    lSeen.Add(lReportKey, True);
    lGap := Default(TDelphiSemanticUsage);
    lGap.FileName := aFileName;
    if lGap.FileName = '' then
      lGap.FileName := lFileName;
    lGap.Name := aName;
    lGap.Line := aLine;
    lGap.Column := aColumn;
    lGap.Role := 'unresolved';
    lGap.SourceKind := 'project';
    lGap.Reason := aReason;
    lGaps.Add(lGap);
  end;

  function IsExecutable(const aNode: TDelphiNameFlowNode): Boolean;
  var
    lAncestor: TDelphiNameFlowNode;
    lDepth: Integer;
  begin
    lAncestor := aNode;
    for lDepth := 0 to 64 do
    begin
      if MatchText(lAncestor.SyntaxKind, ['statements', 'initialization', 'finalization']) then
        Exit(True);
      if lAncestor.ParentId = 0 then
        Exit(aNode.Kind = TDelphiNameFlowNodeKind.Call);
      lAncestor := lFacts.NodeById(lAncestor.ParentId);
    end;
    // Excessive or corrupt ancestry cannot prove an identifier is passive.
    Result := True;
  end;

  function CalleeNode(const aNode: TDelphiNameFlowNode;
    out aCallee: TDelphiNameFlowNode): Boolean;
  var
    lDepth: Integer;
  begin
    aCallee := aNode;
    for lDepth := 0 to 64 do
    begin
      if aCallee.Kind = TDelphiNameFlowNodeKind.PotentialCall then
        Exit(True);
      if Length(aCallee.Children) = 0 then
        Exit(False);
      if aCallee.SyntaxKind = 'dot' then
        aCallee := lFacts.NodeById(aCallee.Children[High(aCallee.Children)])
      else
        aCallee := lFacts.NodeById(aCallee.Children[0]);
    end;
    Result := False;
  end;

  function PinnedSource(const aUnitName: string; const aDeclarationFileName: string = ''): Boolean;
  var
    lExpected, lFileName, lPinKey: string;
  begin
    lPinKey := aUnitName + '|' + aDeclarationFileName;
    if lPinnedSources.TryGetValue(lPinKey, Result) then
      Exit;
    Result := False;
    lExpected := '';
    if SameText(aUnitName, 'System.Rtti') then
      lExpected := '4c9c91ab0a73cb2321bf59e3180763075c2897d25e7e2be9a695a701c38f96b7'
    else if SameText(aUnitName, 'System.TypInfo') then
      lExpected := '2a8d396432af390d61f8e000c7512d70b95a4944d648c72b36f19fb11b17a73a'
    else if SameText(aUnitName, 'System.Classes') then
      lExpected := 'e277681d68b562e958728898e5c8ba68a9a7f0312a1a8dd0171a850bc6626560'
    else if SameText(aUnitName, 'System') then
      lExpected := '35fb7e2d4056c82cdb0fdbfe2bdf3a169f99b5823e8ac08e9b3029fac42b6ce1'
    else if SameText(aUnitName, 'Winapi.Windows') then
      lExpected := '1ae52f578919a6a960be7ada5fd5385ba3a2384273ec29e36e77cb3a4c1c912f';
    // Independently hashed positive signatures survive an unrelated aggregate-pin
    // mismatch. Request paths and this binder never certify body passivity.
    if (aSdk <> nil) and (lExpected <> '') then
      for lFileName in aSdk.RequestedSourceFileNames do
        if SameText(ExtractFileName(lFileName), aUnitName + '.pas') and
          ((aDeclarationFileName = '') or SameText(lFileName, aDeclarationFileName)) then
        begin
          try
            Result := TFile.Exists(lFileName) and
              SameText(THashSHA2.GetHashStringFromFile(lFileName), lExpected);
          except
            on e: Exception do
              Report(lFileName, e.ClassName, 'runtime-name-flow-coverage-unproved', 0, 0);
          end;
          Break;
        end;
    lPinnedSources.AddOrSetValue(lPinKey, Result);
  end;

  function NoProjectShadow(const aName: string): Boolean;
  var
    lOwnerUnit: TUnitSnapshot;
    lFact: TSemanticSymbolFact;
    lUnitIndex, lSymbolIndex: Integer;
  begin
    Result := False;
    for lUnitIndex := 0 to aSnapshot.UnitCount - 1 do
    begin
      lOwnerUnit := aSnapshot.UnitByIndex(lUnitIndex);
      if MatchText(aSnapshot.TextOf(lOwnerUnit.UnitNameId),
        ['System', 'System.Rtti', 'System.Classes', 'System.TypInfo', 'Winapi.Windows']) then
        Continue;
      for lSymbolIndex := 1 to lOwnerUnit.SymbolCount do
      begin
        lFact := lOwnerUnit.SymbolById(lSymbolIndex);
        if SameText(aSnapshot.TextOf(lFact.NameId), aName) then
          Exit;
      end;
    end;
    Result := True;
  end;

  function ImportedSdk(const aUnitName: string): Boolean;
  var
    lImport: TDelphiSemanticImportFact;
  begin
    Result := False;
    for lImport in lUnit.ImportFacts do
      if (SameText(lImport.Name, aUnitName) or
        SameText('System.' + lImport.Name, aUnitName) or
        SameText('Winapi.' + lImport.Name, aUnitName)) and lImport.SdkBoundary and
        (lImport.Cause = '') and not lImport.ResolutionVaries then
        Exit(True);
  end;

  function ImportedPinned(const aUnitName: string): Boolean;
  var
    lImport: TDelphiSemanticImportFact;
  begin
    Result := False;
    for lImport in lUnit.ImportFacts do
      if (SameText(lImport.Name, aUnitName) or
        SameText('System.' + lImport.Name, aUnitName) or
        SameText('Winapi.' + lImport.Name, aUnitName)) and lImport.SdkBoundary and
        (lImport.Cause = '') and not lImport.ResolutionVaries then
        Exit(PinnedSource(aUnitName));
  end;

  function DottedName(const aNode: TDelphiNameFlowNode; const aDepth: Integer): string;
  var
    lLeft, lRight: string;
  begin
    Result := '';
    if aDepth >= 16 then
      Exit;
    if aNode.SyntaxKind = 'identifier' then
      Exit(aNode.Name);
    if (aNode.SyntaxKind = 'dot') and (Length(aNode.Children) = 2) then
    begin
      lLeft := DottedName(lFacts.NodeById(aNode.Children[0]), aDepth + 1);
      lRight := DottedName(lFacts.NodeById(aNode.Children[1]), aDepth + 1);
      if (lLeft <> '') and (lRight <> '') then
        Result := lLeft + '.' + lRight;
    end;
  end;

  function ClassSdkRoot(const aTypeName: string; const aDepth: Integer): string;
  var
    lDeclaration, lClass, lChild: TDelphiNameFlowNode;
    lBaseName: string;
    lIndex, lChildId, lMatches, lBases: Integer;
  begin
    Result := '';
    if aDepth >= 16 then
      Exit;
    if MatchText(aTypeName, ['TObject', 'System.TObject']) and
      PinnedSource('System') and NoProjectShadow('TObject') then
      Exit('TObject');
    if MatchText(aTypeName, ['TComponent', 'System.Classes.TComponent']) and
      ImportedPinned('System.Classes') and NoProjectShadow('TComponent') then
      Exit('TComponent');
    // Only a unique, captured same-unit class declaration contributes ancestry.
    // Helpers, aliases, generic declarations and imported spelling matches do not.
    lMatches := 0;
    lDeclaration := Default(TDelphiNameFlowNode);
    for lIndex := 1 to lFacts.NodeCount do
    begin
      lChild := lFacts.NodeById(lIndex);
      if (lChild.SyntaxKind = 'typedecl') and SameText(lChild.Name, aTypeName) then
      begin
        Inc(lMatches);
        lDeclaration := lChild;
      end;
    end;
    if (lMatches <> 1) or not lDeclaration.SpanKnown or not lDeclaration.ActivityKnown then
      Exit;
    lClass := Default(TDelphiNameFlowNode);
    for lChildId in lDeclaration.Children do
    begin
      lChild := lFacts.NodeById(lChildId);
      if MatchText(lChild.SyntaxKind, ['typeparams', 'typeparam', 'generic']) then
        Exit;
      if (lChild.SyntaxKind = 'type') and SameText(lChild.TypeName, 'class') then
        lClass := lChild;
    end;
    if (lClass.Id = 0) or not lClass.ActivityKnown then
      Exit;
    lBaseName := 'TObject';
    lBases := 0;
    for lChildId in lClass.Children do
    begin
      lChild := lFacts.NodeById(lChildId);
      if lChild.SyntaxKind = 'type' then
      begin
        Inc(lBases);
        lBaseName := lChild.Name;
      end;
    end;
    if lBases > 1 then
      Exit;
    Result := ClassSdkRoot(lBaseName, aDepth + 1);
  end;

  function ReceiverType(const aNode: TDelphiNameFlowNode; const aDepth: Integer): string;
  var
    lReceiver, lCallee, lPart: TDelphiNameFlowNode;
    lResolvedType: TDelphiSemanticSnapshotPositionResolution;
    lFact: TSemanticSymbolFact;
    lMatches, lSymbolIndex: Integer;
    lTypeName: string;
  begin
    Result := '';
    if aDepth >= 16 then
      Exit;
    if (Length(aNode.Children) = 1) and (aNode.SyntaxKind <> 'identifier') then
      Exit(ReceiverType(lFacts.NodeById(aNode.Children[0]), aDepth + 1));
    if (aNode.SyntaxKind = 'call') and (Length(aNode.Children) = 2) then
    begin
      lPart := lFacts.NodeById(aNode.Children[0]);
      if (lPart.SyntaxKind <> 'dot') or (Length(lPart.Children) <> 2) then
        Exit;
      lReceiver := lFacts.NodeById(lPart.Children[0]);
      lCallee := lFacts.NodeById(lPart.Children[1]);
      lTypeName := ReceiverType(lReceiver, aDepth + 1);
      // The exact pinned System.Rtti declarations return TRttiType for both
      // GetType overloads and FindType; no arbitrary method body is followed.
      if SameText(lTypeName, 'TRttiContext') and
        MatchText(lCallee.Name, ['GetType', 'FindType']) and
        NoProjectShadow(lCallee.Name) then
        Result := 'TRttiType';
      Exit;
    end;
    if aNode.SyntaxKind <> 'identifier' then
      Exit;
    if SameText(aNode.Name, 'TObject') and PinnedSource('System') and
      NoProjectShadow('TObject') then
      Exit('TObject');
    lTypeName := '';
    if TryResolveSnapshotPosition(aSnapshot, aNode.FileName, aNode.Line, aNode.Column,
      aNode.Name, lResolvedType) and lResolvedType.ReferenceFound and
      SameText(aSnapshot.TextOf(lResolvedType.Symbol.NameId), aNode.Name) then
      lTypeName := aSnapshot.TextOf(lResolvedType.Symbol.TypeId)
    else
    begin
      // Declaration fallback is local and unique in the captured routine. It
      // cannot bind an imported same-spelled variable or an enclosing routine.
      lMatches := 0;
      for lSymbolIndex := 1 to lUnit.SymbolCount do
      begin
        lFact := lUnit.SymbolById(lSymbolIndex);
        if SameText(aSnapshot.TextOf(lFact.NameId), aNode.Name) and
          MatchText(aSnapshot.TextOf(lFact.KindId), ['var', 'variable', 'parameter', 'local']) and
          SameText(aSnapshot.TextOf(lFact.RoutineScopeId), aNode.ScopeId) and
          (lFact.Line <= aNode.Line) then
        begin
          Inc(lMatches);
          lTypeName := aSnapshot.TextOf(lFact.TypeId);
        end;
      end;
      if lMatches = 0 then
      begin
        // Lean snapshots omit local declarations, but the complete runtime
        // facts retain their declared type and routine identity.
        for lSymbolIndex := 1 to lFacts.NodeCount do
        begin
          lPart := lFacts.NodeById(lSymbolIndex);
          if (lPart.Kind = TDelphiNameFlowNodeKind.Definition) and
            (lPart.SyntaxKind = 'variable') and SameText(lPart.Name, aNode.Name) and
            SameText(lPart.ScopeId, aNode.ScopeId) and (lPart.Line <= aNode.Line) then
          begin
            Inc(lMatches);
            lTypeName := lPart.TypeName;
          end;
        end;
        if lMatches = 0 then
          Exit(ClassSdkRoot(aNode.Name, 0));
      end;
      if lMatches <> 1 then
        Exit;
    end;
    if StartsText('System.Rtti.', lTypeName) then
      Delete(lTypeName, 1, Length('System.Rtti.'))
    else if StartsText('System.Classes.', lTypeName) then
      Delete(lTypeName, 1, Length('System.Classes.'))
    else if StartsText('System.', lTypeName) then
      Delete(lTypeName, 1, Length('System.'));
    if MatchText(lTypeName, ['TRttiContext', 'TRttiType']) and
      ImportedPinned('System.Rtti') and NoProjectShadow(lTypeName) then
      Result := lTypeName
    else if SameText(lTypeName, 'TObject') and PinnedSource('System') and
      NoProjectShadow(lTypeName) then
      Result := 'TObject'
    else if SameText(lTypeName, 'TComponent') and ImportedPinned('System.Classes') and
      NoProjectShadow(lTypeName) then
      Result := 'TComponent'
    else
      Result := ClassSdkRoot(lTypeName, 0);
  end;

  function ProvedPropertyInfoArgument(const aCall: TDelphiNameFlowNode;
    const aRoutineName: string): Boolean;
  var
    lArguments, lArgument: TDelphiNameFlowNode;
    lFact: TSemanticSymbolFact;
    lTypeName: string;
    lMatches, lIndex: Integer;
  begin
    Result := False;
    // These reviewed groups have a PPropInfo overload. GetPropInfo and
    // IsPublishedProp always take a name at ordinal two and are excluded.
    if not MatchText(aRoutineName, ['IsStoredProp', 'GetPropValue', 'SetPropValue',
      'GetOrdProp', 'SetOrdProp', 'GetEnumProp', 'SetEnumProp',
      'GetSetProp', 'SetSetProp', 'GetObjectProp', 'SetObjectProp', 'GetObjectPropClass',
      'GetStrProp', 'SetStrProp', 'GetAnsiStrProp', 'SetAnsiStrProp',
      'GetWideStrProp', 'SetWideStrProp', 'GetUnicodeStrProp', 'SetUnicodeStrProp',
      'GetRawByteStrProp', 'SetRawByteStrProp', 'GetFloatProp', 'SetFloatProp',
      'GetVariantProp', 'SetVariantProp', 'GetMethodProp', 'SetMethodProp',
      'GetInt64Prop', 'SetInt64Prop', 'GetInterfaceProp', 'SetInterfaceProp',
      'GetDynArrayProp', 'SetDynArrayProp']) or (Length(aCall.Children) <> 2) then
      Exit;
    lArguments := lFacts.NodeById(aCall.Children[1]);
    if (lArguments.SyntaxKind <> 'expressions') or (Length(lArguments.Children) < 2) then
      Exit;
    lArgument := lFacts.NodeById(lArguments.Children[1]);
    if (lArgument.SyntaxKind = 'expression') and (Length(lArgument.Children) = 1) then
      lArgument := lFacts.NodeById(lArgument.Children[0]);
    if lArgument.SyntaxKind <> 'identifier' then
      Exit;
    lMatches := 0;
    lTypeName := '';
    for lIndex := 1 to lUnit.SymbolCount do
    begin
      lFact := lUnit.SymbolById(lIndex);
      if SameText(aSnapshot.TextOf(lFact.NameId), lArgument.Name) and
        MatchText(aSnapshot.TextOf(lFact.KindId), ['var', 'variable', 'parameter', 'local']) and
        SameText(aSnapshot.TextOf(lFact.RoutineScopeId), lArgument.ScopeId) and
        (lFact.Line <= lArgument.Line) then
      begin
        Inc(lMatches);
        lTypeName := aSnapshot.TextOf(lFact.TypeId);
      end;
    end;
    Result := (lMatches = 1) and MatchText(lTypeName, ['PPropInfo', 'System.TypInfo.PPropInfo']) and
      NoProjectShadow('PPropInfo');
  end;

  function DescribeKnownConsumer(const aQualifiedName: string;
    out aDescription: TNameSdkEffect): Boolean;
  begin
    Result := PositivePrimitiveNameConsumer(aQualifiedName, aDescription);
    if Result and MatchText(aQualifiedName, ['System.TypInfo.SetEnumProp',
      'System.TypInfo.SetSetProp']) and
      (aTargetKind in [TNameEffectTargetKind.EnumType, TNameEffectTargetKind.EnumElement]) then
    begin
      aDescription.Precision.FormalOrdinal := 3;
      aDescription.Targets := [TNameEffectTargetKind.EnumType, TNameEffectTargetKind.EnumElement];
    end;
  end;

  function KnownConsumer(const aCall: TDelphiNameFlowNode;
    out aDescription: TNameSdkEffect): Boolean;
  var
    lQualified, lOwner, lPrefix: string;
    lCallee: TDelphiNameFlowNode;
    lResolution: TDelphiSemanticSnapshotPositionResolution;
    lCandidate: TNameSdkEffect;
    lDescriptions: TArray<TNameSdkEffect>;
    lCatalogOwners: TArray<string>;
  begin
    // A catalog spelling seeds a conservative candidate join. SDK byte pins
    // guard passivity, never the lower bound required to retain a refusal.
    // Only a positive project routine binding can exclude that candidate.
    if not CalleeNode(aCall, lCallee) then
      lCallee := aCall;
    if TryResolveSnapshotPosition(aSnapshot, lCallee.FileName, lCallee.Line,
      lCallee.Column, lCallee.Name, lResolution) and lResolution.ReferenceFound and
      SameText(aSnapshot.TextOf(lResolution.Symbol.NameId), lCallee.Name) and
      MatchText(aSnapshot.TextOf(lResolution.Symbol.KindId),
        ['routine', 'method', 'constructor', 'destructor', 'operator']) then
    begin
      lQualified := aSnapshot.TextOf(lResolution.SymbolUnit.UnitNameId);
      lOwner := aSnapshot.TextOf(lResolution.Symbol.OwnerTypeId);
      if lOwner <> '' then
        lQualified := lQualified + '.' + lOwner;
      lQualified := lQualified + '.' + lCallee.Name;
      if DescribeKnownConsumer(lQualified, aDescription) then
        Exit(aTargetKind in aDescription.Targets);
    end;
    for lPrefix in cNameConsumerPrefixes do
      if DescribeKnownConsumer(lPrefix + '.' + lCallee.Name, lCandidate) and
        (aTargetKind in lCandidate.Targets) then
      begin
        if SameText(lPrefix, 'System.TypInfo') and
          (aTargetKind = TNameEffectTargetKind.Member) and
          ProvedPropertyInfoArgument(aCall, lCallee.Name) then
          Continue;
        lDescriptions := lDescriptions + [lCandidate];
        lCatalogOwners := lCatalogOwners + [lPrefix];
      end;
    Result := Length(lDescriptions) > 0;
    if Result and (SnapshotProjectRoutineBindingIsComplete(aSnapshot, lUnit, lCallee,
      lFacts, lResolution, lCatalogOwners) or SnapshotProjectRoutineFamilyIsComplete(
      aSnapshot, lUnit, lCallee, lFacts, lCatalogOwners)) then
      Exit(False);
    if Result then
      aDescription := TNameSdkEffect.Join(lDescriptions, True);
  end;

  function StaticExpressionType(const aExpression: TDelphiNameFlowNode;
    const aDepth: Integer): string;
  var
    lPart, lDefinition: TDelphiNameFlowNode;
    lRefs: TArray<TSemanticSymbolRef>;
    lTypeUnit: TUnitSnapshot;
    lComplete: Boolean;
    lIndex, lMatches: Integer;
  begin
    Result := '';
    if aDepth >= 32 then
      Exit;
    if (aExpression.SyntaxKind = 'call') and (Length(aExpression.Children) > 0) then
    begin
      lPart := lFacts.NodeById(aExpression.Children[0]);
      if (lPart.SyntaxKind = 'dot') and (Length(lPart.Children) = 2) and
        SameText(lFacts.NodeById(lPart.Children[1]).Name, 'Create') then
        Exit(StaticExpressionType(lFacts.NodeById(lPart.Children[0]), aDepth + 1));
    end;
    if Length(aExpression.Children) = 1 then
      Exit(StaticExpressionType(lFacts.NodeById(aExpression.Children[0]), aDepth + 1));
    if aExpression.SyntaxKind <> 'identifier' then
      Exit;
    lRefs := SnapshotVisibleDeclarations(aSnapshot, lUnit, aExpression.Name,
      aExpression.ScopeId, '', 'implementation', aExpression.Line, aExpression.Column, nil, lComplete);
    if lComplete and (Length(lRefs) = 1) and aSnapshot.TryFindUnitById(lRefs[0].UnitId, lTypeUnit) then
    begin
      Result := aSnapshot.TextOf(lTypeUnit.SymbolById(lRefs[0].SymbolId).TypeId);
      if SameText(Result, 'class') then
        Result := aExpression.Name;
      Exit;
    end;
    // Lean symbol models still retain all local declared types in runtime facts.
    lMatches := 0;
    for lIndex := 1 to lFacts.NodeCount do
    begin
      lDefinition := lFacts.NodeById(lIndex);
      if (lDefinition.Kind in [TDelphiNameFlowNodeKind.Definition, TDelphiNameFlowNodeKind.Formal]) and
        SameText(lDefinition.Name, aExpression.Name) and
        SameText(lDefinition.ScopeId, aExpression.ScopeId) and
        (lDefinition.OutputStartOffset < aExpression.OutputStartOffset) then
      begin
        Inc(lMatches);
        Result := lDefinition.TypeName;
      end;
    end;
    if lMatches = 1 then
      Exit;
    Result := '';
    if (lMatches = 0) and MatchText(aExpression.Name,
      ['Exception', 'TObject', 'TComponent', 'TPersistent']) then
      Result := aExpression.Name;
  end;

  function BuildClassLineage(const aType: string; out aComplete: Boolean): TArray<string>;
  var
    lType, lBase: string;
    lTypeUnit: TUnitSnapshot;
    lTypeFacts: IDelphiNameFlowFacts;
    lDefinition, lClass, lChild: TDelphiNameFlowNode;
    lDepth, lIndex, lUnitIndex, lChildId, lBaseId, lMatches: Integer;
  begin
    Result := nil;
    aComplete := False;
    lType := aType;
    for lDepth := 0 to 31 do
    begin
      lType := Copy(lType, LastDelimiter('.', lType) + 1, MaxInt);
      if lType = '' then
        Exit;
      Result := Result + [lType];
      if SameText(lType, 'TObject') then
      begin
        aComplete := True;
        Exit;
      end;
      lMatches := 0;
      lBase := '';
      for lUnitIndex := 0 to aSnapshot.UnitCount - 1 do
      begin
        lTypeUnit := aSnapshot.UnitByIndex(lUnitIndex);
        lTypeFacts := NameFlowFactsFromJson(aSnapshot.ExactTextOf(lTypeUnit.NameFlowFactsJsonId));
        for lIndex := 1 to lTypeFacts.NodeCount do
        begin
          lDefinition := lTypeFacts.NodeById(lIndex);
          if (lDefinition.SyntaxKind <> 'typedecl') or not SameText(lDefinition.Name, lType) then
            Continue;
          for lChildId in lDefinition.Children do
          begin
            lClass := lTypeFacts.NodeById(lChildId);
            if (lClass.SyntaxKind <> 'type') or not SameText(lClass.TypeName, 'class') then
              Continue;
            Inc(lMatches);
            lBase := 'TObject';
            for lBaseId in lClass.Children do
            begin
              lChild := lTypeFacts.NodeById(lBaseId);
              if lChild.SyntaxKind = 'type' then
                lBase := lChild.Name;
            end;
          end;
        end;
      end;
      if lMatches > 1 then
        Exit;
      if lMatches = 0 then
      begin
        // SDK classes cannot derive from a project declaration. These
        // reviewed parent edges close the common exception/component roots.
        if SameText(lType, 'Exception') and ImportedSdk('System.SysUtils') and NoProjectShadow('Exception') then
          lBase := 'TObject'
        else if SameText(lType, 'TComponent') and ImportedSdk('System.Classes') and NoProjectShadow('TComponent') then
          lBase := 'TPersistent'
        else if SameText(lType, 'TPersistent') and ImportedSdk('System.Classes') and NoProjectShadow('TPersistent') then
          lBase := 'TObject'
        else
          Exit;
      end;
      lType := lBase;
    end;
  end;

  function ClassLineage(const aType: string; out aComplete: Boolean): TArray<string>;
  var
    lKey: string;
  begin
    lKey := LowerCase(aType);
    if lClassLineages.TryGetValue(lKey, Result) then
    begin
      aComplete := lClassLineageComplete[lKey];
      Exit;
    end;
    Result := BuildClassLineage(aType, aComplete);
    lClassLineages.Add(lKey, Result);
    lClassLineageComplete.Add(lKey, aComplete);
  end;

  function TypeCanExposeRenamedClass(const aType: string): Boolean;
  var
    lTarget, lType: string;
    lTargetLineage, lExpressionLineage: TArray<string>;
    lTargetComplete, lExpressionComplete: Boolean;
  begin
    Result := True;
    if (aType = '') or (Length(aNames) = 0) then
      Exit;
    lType := Copy(aType, LastDelimiter('.', aType) + 1, MaxInt);
    lTarget := aNames[0];
    lTargetLineage := ClassLineage(lTarget, lTargetComplete);
    lExpressionLineage := ClassLineage(lType, lExpressionComplete);
    if MatchText(lType, lTargetLineage) or MatchText(lTarget, lExpressionLineage) then
      Exit;
    Result := not lTargetComplete or not lExpressionComplete;
  end;

  function ExposesNames(const aCall: TDelphiNameFlowNode): Boolean;
  var
    lSelector, lReceiver, lChild: TDelphiNameFlowNode;
    lOwner: string;
    lPending: TArray<Integer>;
    lIndex, lChildId: Integer;
  begin
    Result := False;
    // A positive project binding keeps homonyms out of the producer catalog.
    if lResolved and lResolution.ReferenceFound then
      Exit;
    if not MatchText(lName, ['ClassName', 'QualifiedClassName', 'UnitName', 'UnitScope',
      'ToString', 'ObjectToJsonString', 'ObjectToJsonObject']) then
      Exit;
    lSelector := aCall;
    if (aCall.SyntaxKind = 'call') and (Length(aCall.Children) > 0) then
      lSelector := lFacts.NodeById(aCall.Children[0]);
    if (lSelector.SyntaxKind = 'identifier') and (lSelector.ParentId > 0) then
      lSelector := lFacts.NodeById(lSelector.ParentId);
    if (lSelector.SyntaxKind <> 'dot') or (Length(lSelector.Children) <> 2) then
      Exit;
    lReceiver := lFacts.NodeById(lSelector.Children[0]);
    lOwner := ReceiverType(lReceiver, 0);
    if (aTargetKind = TNameEffectTargetKind.ClassType) and
      MatchText(lName, ['ClassName', 'QualifiedClassName', 'UnitName', 'UnitScope', 'ToString']) then
      Exit(TypeCanExposeRenamedClass(StaticExpressionType(lReceiver, 0)));
    if (aTargetKind = TNameEffectTargetKind.Member) and
      MatchText(lName, ['ObjectToJsonString', 'ObjectToJsonObject']) and
      SameText(DottedName(lReceiver, 0), 'TJson') and ImportedSdk('REST.Json') and
      NoProjectShadow('TJson') then
      Exit(True);
    // TValue.From<T>(...).ToString exposes an enum value's name. Its nested
    // generic call is retained in the complete runtime AST even in lean models.
    if not SameText(lName, 'ToString') or
      not (aTargetKind in [TNameEffectTargetKind.EnumType, TNameEffectTargetKind.EnumElement]) or
      not ImportedSdk('System.Rtti') or not NoProjectShadow('TValue') then
      Exit;
    lPending := [lReceiver.Id];
    lIndex := 0;
    while (lIndex < Length(lPending)) and (lIndex < 256) do
    begin
      lChild := lFacts.NodeById(lPending[lIndex]);
      if SameText(lChild.Name, 'TValue') then
        Exit(True);
      for lChildId in lChild.Children do
        lPending := lPending + [lChildId];
      Inc(lIndex);
    end;
  end;

  function KnownValue(const aNode: TDelphiNameFlowNode; const aDepth: Integer;
    out aValue: string): Boolean;
  var
    lFirst, lSecond, lBoundScope: string;
    lBoundUnit: TUnitSnapshot;
    lBoundSymbol: TSemanticSymbolFact;
    lDefinition, lMatchedDefinition, lChild: TDelphiNameFlowNode;
    lNodeIndex, lChildId, lMatches: Integer;
  begin
    Result := False;
    aValue := '';
    if (aDepth >= 32) or not aNode.SpanKnown or not aNode.ActivityKnown then
      Exit;
    if aNode.SyntaxKind = 'literal' then
    begin
      aValue := aNode.Value;
      Exit(True);
    end;
    if (aNode.SyntaxKind = 'add') and (Length(aNode.Children) = 2) then
    begin
      Result := KnownValue(lFacts.NodeById(aNode.Children[0]), aDepth + 1, lFirst) and
        KnownValue(lFacts.NodeById(aNode.Children[1]), aDepth + 1, lSecond);
      if Result then
        aValue := lFirst + lSecond;
      Exit;
    end;
    if MatchText(aNode.SyntaxKind, ['expression', 'value', 'parenthesis']) and
      (Length(aNode.Children) = 1) then
      Exit(KnownValue(lFacts.NodeById(aNode.Children[0]), aDepth + 1, aValue));
    if (aNode.SyntaxKind <> 'identifier') or not
      TryBindNameFlowConstant(aSnapshot, aNode.FileName, aNode.Name, aNode.Line,
        aNode.Column, lBoundUnit, lBoundSymbol) or (lBoundUnit <> lUnit) then
      Exit;
    lBoundScope := aSnapshot.TextOf(lBoundSymbol.RoutineScopeId);
    if SameText(aSnapshot.TextOf(lBoundSymbol.ScopeKindId), 'routine') then
      lBoundScope := aSnapshot.TextOf(lBoundSymbol.OwnerScopeId);
    lMatches := 0;
    lMatchedDefinition := Default(TDelphiNameFlowNode);
    for lNodeIndex := 1 to lFacts.NodeCount do
    begin
      lDefinition := lFacts.NodeById(lNodeIndex);
      // Physical line and spelling do not identify a declaration: separate
      // routines may declare different constants on the same source line.
      if (lDefinition.Kind <> TDelphiNameFlowNodeKind.Definition) or
        not lDefinition.SpanKnown or not lDefinition.ActivityKnown or
        (lDefinition.Line <> lBoundSymbol.Line) or
        (lDefinition.Column <> lBoundSymbol.Column) or
        not SameText(lDefinition.FileName, aNode.FileName) or
        not SameText(lDefinition.ScopeId, lBoundScope) or
        not SameText(lDefinition.Name, aNode.Name) then
        Continue;
      Inc(lMatches);
      lMatchedDefinition := lDefinition;
    end;
    if lMatches <> 1 then
      Exit;
    for lChildId in lMatchedDefinition.Children do
    begin
      lChild := lFacts.NodeById(lChildId);
      if lChild.SyntaxKind = 'value' then
        Exit(KnownValue(lChild, aDepth + 1, aValue));
    end;
  end;

  function SupportedNameParts(const aValue: string; const aGrammar: TNameConsumerGrammar;
    out aParts: TArray<string>): Boolean;
  var
    lPart: string;
    i: Integer;
  begin
    aParts := nil;
    if aGrammar = TNameConsumerGrammar.Identifier then
      aParts := [aValue]
    else if aGrammar = TNameConsumerGrammar.QualifiedIdentifier then
      aParts := aValue.Split(['.'])
    else
      Exit(False);
    if Length(aParts) = 0 then
      Exit(False);
    for lPart in aParts do
    begin
      if (lPart = '') or not IsIdentifierStart(lPart[1]) then
        Exit(False);
      for i := 2 to Length(lPart) do
        if not IsIdentifierChar(lPart[i]) then
          Exit(False);
    end;
    Result := True;
  end;

  procedure CheckKnownArgument(const aCall: TDelphiNameFlowNode;
    const aDescription: TNameSdkEffect);
  var
    lArguments, lArgument: TDelphiNameFlowNode;
    lValue, lTargetName: string;
    lParts: TArray<string>;
    lOrdinal: Integer;
  begin
    lOrdinal := aDescription.Precision.FormalOrdinal;
    if (lOrdinal < 1) or (Length(aCall.Children) <> 2) then
    begin
      Report(lNode.FileName, lNode.Name, 'runtime-name-known-consumer-unknown', lNode.Line, lNode.Column);
      Exit;
    end;
    lArguments := lFacts.NodeById(aCall.Children[1]);
    if (lArguments.SyntaxKind <> 'expressions') or
      (Length(lArguments.Children) < lOrdinal) then
    begin
      Report(lNode.FileName, lNode.Name, 'runtime-name-known-consumer-unknown', lNode.Line, lNode.Column);
      Exit;
    end;
    lArgument := lFacts.NodeById(lArguments.Children[lOrdinal - 1]);
    if not KnownValue(lArgument, 0, lValue) then
    begin
      Report(lNode.FileName, lNode.Name, 'runtime-name-known-consumer-unknown', lNode.Line, lNode.Column);
      Exit;
    end;
    if aDescription.Precision.Grammar in [TNameConsumerGrammar.Identifier,
      TNameConsumerGrammar.QualifiedIdentifier] then
    begin
      // Generic type syntax, compound enum sets and other unsupported grammars
      // cannot prove a known consumer's value unrelated to the renamed name.
      if not SupportedNameParts(lValue, aDescription.Precision.Grammar, lParts) then
      begin
        Report(lNode.FileName, lNode.Name, 'runtime-name-known-consumer-unknown', lNode.Line, lNode.Column);
        Exit;
      end;
      for lTargetName in aNames do
        if MatchText(lTargetName, lParts) then
        begin
          Report(lNode.FileName, lNode.Name, 'runtime-name-known-consumer-match', lNode.Line, lNode.Column);
          Exit;
        end;
    end else begin
      // Export/resource/unknown grammars have no component-matching proof.
      // Exact whole-name evidence is hard; every other value stays unknown.
      for lTargetName in aNames do
        if SameText(lTargetName, lValue) then
        begin
          Report(lNode.FileName, lNode.Name, 'runtime-name-known-consumer-match', lNode.Line, lNode.Column);
          Exit;
        end;
      Report(lNode.FileName, lNode.Name, 'runtime-name-known-consumer-unknown', lNode.Line, lNode.Column);
    end;
  end;

begin
  Result := Default(TNameFlowAnalysis);
  GC(lGaps, TList<TDelphiSemanticUsage>.Create, g);
  GC(lClassLineages, TDictionary<string, TArray<string>>.Create, g);
  GC(lClassLineageComplete, TDictionary<string, Boolean>.Create, g);
  GC(lSeen, TDictionary<string, Boolean>.Create, g);
  GC(lCallSites, TDictionary<string, Boolean>.Create, g);
  GC(lOpaqueSdk, TDictionary<string, Boolean>.Create, g);
  GC(lOpaqueProject, TDictionary<string, Boolean>.Create, g);
  GC(lByName, TObjectDictionary<string, TList<Integer>>.Create([doOwnsValues]), g);
  GC(lEffects, TList<TNameSdkEffect>.Create, g);
  GC(lPinnedSources, TDictionary<string, Boolean>.Create, g);
  try
    if aSnapshot = nil then
    begin
      Report('', '', 'runtime-name-known-consumer-coverage-unproved', 0, 0);
      Inc(Result.Statistics.CoverageGaps);
      Exit;
    end;
    // Generate/TryLoad validated this query-owned catalog. The caller must
    // revalidate before publishing an admission or writing/committing edits.
    lSdkCurrent := (aSdk <> nil) and aSdk.Validated;
    if aSdk <> nil then
    begin
      Result.Statistics.SdkIdentity := aSdk.Identity;
      lEntries := aSdk.Entries;
      for i := 0 to High(lEntries) do
      begin
        lKey := LowerCase(lEntries[i].RoutineName);
        if not lByName.TryGetValue(lKey, lCandidates) then
        begin
          lCandidates := TList<Integer>.Create;
          lByName.Add(lKey, lCandidates);
        end;
        lCandidates.Add(i);
      end;
    end;
    for i := 0 to aSnapshot.UnitCount - 1 do
    begin
      lUnit := aSnapshot.UnitByIndex(i);
      lFileName := aSnapshot.TextOf(lUnit.FileNameId);
      lJson := aSnapshot.ExactTextOf(lUnit.NameFlowFactsJsonId);
      lSource := aSnapshot.ExactTextOf(lUnit.SourceTextId);
      // Every omitted/incomplete scope carries a hard consumer-coverage refusal.
      // Continue across units so no budget boundary hides the later consumers.
      if Length(lJson) > 128 * 1024 * 1024 then
      begin
        Report(lFileName, '', 'runtime-name-flow-budget-exceeded', 0, 0);
        Report(lFileName, '', 'runtime-name-known-consumer-coverage-unproved', 0, 0);
        Inc(Result.Statistics.CoverageGaps);
        Continue;
      end;
      lFacts := NameFlowFactsFromJson(lJson);
      if not lFacts.Complete then
      begin
        // Captured unmapped nodes still reach the consumer scan by their output
        // identities. Only missing nodes, unscanned includes and incomplete
        // preprocessing require a separate hard consumer-coverage refusal.
        if (lFacts.CoverageReason <> 'name-flow-physical-span-unproved') or
          (lFacts.NodeCount = 0) or not SourceExcludesKnownConsumers(lSource, True) then
          Report(lFileName, lFacts.CoverageReason, 'runtime-name-known-consumer-coverage-unproved', 0, 0);
        if ContainsText(lFacts.CoverageReason, 'budget-exceeded') then
          Report(lFileName, lFacts.CoverageReason, 'runtime-name-flow-budget-exceeded', 0, 0)
        else
          Report(lFileName, lFacts.CoverageReason, 'runtime-name-flow-coverage-unproved', 0, 0);
        Inc(Result.Statistics.CoverageGaps);
      end;
      Inc(Result.Statistics.FactCount, lFacts.NodeCount);
      if Result.Statistics.FactCount > 1000000 then
      begin
        Report(lFileName, '', 'runtime-name-flow-budget-exceeded', 0, 0);
        Report(lFileName, '', 'runtime-name-known-consumer-coverage-unproved', 0, 0);
        Inc(Result.Statistics.CoverageGaps);
        Continue;
      end;
      lSource := aSnapshot.ExactTextOf(lUnit.SourceTextId);
      // Configuration uncertainty belongs to an observed effect in the unit.
      // A unit with no demanded call effect must not gain a new refusal merely
      // because its define evidence is absent. Independent token guards remain.
      lUnitConfigurationUnproved := ContainsText(lSource, '{$IF') or ContainsText(lSource, '(*$IF') or
        ContainsText(lSource, '{$I ') or ContainsText(lSource, '{$INCLUDE') or
        not lFacts.ConfigurationComplete;
      lUnitConfigurationReported := False;
      for j := 1 to lFacts.NodeCount do
      begin
        lNode := lFacts.NodeById(j);
        if lNode.Kind = TDelphiNameFlowNodeKind.RaiseValue then
        begin
          // Handler closure is a later slice. A possible class observation
          // includes re-raise and diagnostics for handlers and checked casts.
          if aTargetKind = TNameEffectTargetKind.ClassType then
          begin
            Inc(Result.Statistics.LanguageRoots);
            if lNode.SyntaxKind = 'raise' then
            begin
              if TypeCanExposeRenamedClass(StaticExpressionType(lNode, 0)) then
                Report(lNode.FileName, lNode.SyntaxKind, 'runtime-name-observed', lNode.Line, lNode.Column);
            end
            else
              Report(lNode.FileName, lNode.SyntaxKind, 'runtime-name-metadata-consumer',
                lNode.Line, lNode.Column);
          end;
          Continue;
        end;
        if not (lNode.Kind in [TDelphiNameFlowNodeKind.Call,
          TDelphiNameFlowNodeKind.PotentialCall]) or not IsExecutable(lNode) then
          Continue;
        // An ignored-result statement wraps its real call in a one-child call.
        // Canonicalize it before deduplication so the wrapper cannot hide the
        // argument-bearing consumer at the same source position.
        for lIndex := 0 to 63 do
        begin
          if (lNode.SyntaxKind <> 'call') or (Length(lNode.Children) <> 1) then
            Break;
          lParent := lFacts.NodeById(lNode.Children[0]);
          if lParent.SyntaxKind <> 'call' then
            Break;
          lNode := lParent;
        end;
        // The identifier operand supplies the declaration coordinates. A call
        // without such a witness is deliberately retained as unbound.
        lCallNode := lNode;
        lExplicitCall := lNode.Kind = TDelphiNameFlowNodeKind.Call;
        if lExplicitCall then
          if CalleeNode(lNode, lParent) then
            lNode := lParent;
        lName := lNode.Name;
        if MatchText(lName, ['Self', 'Result', 'True', 'False', 'nil']) then
          Continue;
        if lName = '' then
          lName := '<indirect call>';
        if lNode.SpanKnown then
          lKey := lNode.FileName + ':' + IntToStr(lNode.Line) + ':' + IntToStr(lNode.Column)
        else
          // Physical mapping can fail for a captured node. Its output identity
          // remains unique within this unit and must still reach consumer checks.
          lKey := lFileName + ':output:' + IntToStr(lNode.OutputStartOffset) + ':' +
            IntToStr(lNode.OutputEndOffset) + ':' + IntToStr(lNode.Id);
        lKey := lKey + ':' + LowerCase(lName);
        if lCallSites.ContainsKey(lKey) then
          Continue;
        lCallSites.Add(lKey, True);
        lResolved := (lName <> '') and TryResolveSnapshotPosition(aSnapshot, lNode.FileName,
          lNode.Line, lNode.Column, lName, lResolution);
        // Position lookup may return an enclosing declaration when the token
        // itself is unbound. That is never a callable identity for this site.
        lResolved := lResolved and SameText(aSnapshot.TextOf(lResolution.Symbol.NameId), lName);
        lCallable := True;
        lExactSdk := False;
        lEffect := TNameSdkEffect.OpaqueEffect('unbound-call');
        if lResolved then
        begin
          lKind := aSnapshot.TextOf(lResolution.Symbol.KindId);
          lCallable := MatchText(lKind, ['routine', 'method', 'property', 'constructor',
            'destructor', 'operator']);
          if not lCallable and not lExplicitCall then
            Continue;
          // An explicit invocation through a variable/event is an opaque
          // dispatch even though its declaration kind is not routine.
          lCallable := lCallable or lExplicitCall;
          Inc(Result.Statistics.ExactCalls);
          lEffect := TNameSdkEffect.OpaqueEffect('project-call-closure-unproved');
          if lSdkCurrent then
            for lEntry in lEntries do
              if SameText(lEntry.FileName, aSnapshot.TextOf(lResolution.SymbolUnit.FileNameId)) and
                (lEntry.Line = lResolution.Symbol.Line) and
                (lEntry.Column = lResolution.Symbol.Column) then
              begin
                // Snapshot position identity does not certify overload/helper/
                // virtual dispatch closure. Preserve the known observation,
                // but an incomplete candidate set can never prove passivity.
                lEffect := TNameSdkEffect.Join([aSdk.Lookup(lEntry.DeclarationId)], False);
                lExactSdk := True;
                Break;
              end;
          if not lExactSdk then
          begin
            Inc(Result.Statistics.OpaqueProjectCalls);
            lOpaqueProject.AddOrSetValue(aSnapshot.TextOf(lResolution.SymbolUnit.FileNameId) +
              ':' + IntToStr(lResolution.Symbol.Line) + ':' + IntToStr(lResolution.Symbol.Column), True);
          end;
        end else begin
          lEffects.Clear;
          if lByName.TryGetValue(LowerCase(lName), lCandidates) then
          begin
            for lIndex in lCandidates do
              lEffects.Add(aSdk.Lookup(lEntries[lIndex].DeclarationId));
            // Without a closed receiver/overload/dispatch set, even a spelling
            // union is incomplete. It can add roots but never prove passivity.
            lEffect := TNameSdkEffect.Join(lEffects.ToArray, False);
            Inc(Result.Statistics.JoinedCalls);
          end else
            Inc(Result.Statistics.UnboundCalls);
          if TNameEffectChannel.Opaque in lEffect.Channels then
          begin
            Inc(Result.Statistics.OpaqueSdkCalls);
            lOpaqueSdk.AddOrSetValue(LowerCase(lName), True);
          end;
        end;
        if (Length(aNames) > 0) and KnownConsumer(lCallNode, lKnownEffect) then
          CheckKnownArgument(lCallNode, lKnownEffect);
        Inc(Result.Statistics.CallCount);
        if not lSdkCurrent and (aSdk <> nil) then
          lEffect := TNameSdkEffect.OpaqueEffect('sdk-identity-mismatch');
        lObserved := ExposesNames(lCallNode);
        if lObserved then
          Report(lNode.FileName, lName, 'runtime-name-observed', lNode.Line, lNode.Column);
        if not lEffect.Observes(aTargetKind) then
          Continue;
        if lUnitConfigurationUnproved and not lUnitConfigurationReported then
        begin
          Inc(Result.Statistics.ConfigurationGaps);
          Report(lFileName, aSnapshot.TextOf(lUnit.UnitNameId),
            'runtime-name-flow-configuration-unproved', 0, 0);
          lUnitConfigurationReported := True;
        end;
        if not lObserved and ((TNameEffectChannel.ReceiverMetadata in lEffect.Channels) or
          (TNameEffectChannel.ArgumentMetadata in lEffect.Channels) or
          (TNameEffectChannel.GlobalMetadata in lEffect.Channels) or
          (TNameEffectChannel.ProducedName in lEffect.Channels)) then
        begin
          Inc(Result.Statistics.MetadataObservers);
          if TNameEffectChannel.ReceiverMetadata in lEffect.Channels then
            Inc(Result.Statistics.ReceiverMetadataObservers);
          if TNameEffectChannel.ArgumentMetadata in lEffect.Channels then
            Inc(Result.Statistics.ArgumentMetadataObservers);
          if TNameEffectChannel.GlobalMetadata in lEffect.Channels then
            Inc(Result.Statistics.GlobalMetadataObservers);
          if TNameEffectChannel.ProducedName in lEffect.Channels then
            Inc(Result.Statistics.NameProducers);
          Report(lNode.FileName, lName, 'runtime-name-metadata-consumer', lNode.Line, lNode.Column);
        end;
        if TNameEffectChannel.NameFormal in lEffect.Channels then
          Report(lNode.FileName, lName, 'runtime-name-value-unproved', lNode.Line, lNode.Column);
        if not lObserved and ((TNameEffectChannel.Opaque in lEffect.Channels) or
          (TNameEffectChannel.Store in lEffect.Channels) or
          (TNameEffectChannel.Callback in lEffect.Channels)) then
          Report(lNode.FileName, lName, 'runtime-name-call-effect-unproved', lNode.Line, lNode.Column);
      end;
    end;
  finally
    Result.Gaps := lGaps.ToArray;
    Result.Statistics.DistinctUncoveredSdkCallees := lOpaqueSdk.Count;
    Result.Statistics.DistinctUncoveredProjectCallees := lOpaqueProject.Count;

  end;
end;

end.
