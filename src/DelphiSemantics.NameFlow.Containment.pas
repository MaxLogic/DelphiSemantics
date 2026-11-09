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
  const aTargetKind: TNameEffectTargetKind; const aSdk: TNameSdkCatalog): TNameFlowAnalysis;

function NameFlowDeclarationKind(const aSnapshot: TDelphiProjectSnapshot;
  const aFileName, aName: string; const aLine: Integer): string;

function TryBindNameFlowConstant(const aSnapshot: TDelphiProjectSnapshot;
  const aFileName, aName: string; const aLine, aColumn: Integer;
  out aUnit: TUnitSnapshot; out aSymbol: TSemanticSymbolFact): Boolean;

implementation

uses
  System.Generics.Collections, System.StrUtils, System.SysUtils,
  AutoFree,
  DelphiSemantics.NameFlow.Facts, DelphiSemantics.Snapshot.PositionResolver;

function TryBindNameFlowConstant(const aSnapshot: TDelphiProjectSnapshot;
  const aFileName, aName: string; const aLine, aColumn: Integer;
  out aUnit: TUnitSnapshot; out aSymbol: TSemanticSymbolFact): Boolean;
var
  lUnit: TUnitSnapshot;
  lSymbol: TSemanticSymbolFact;
  lFacts: IDelphiNameFlowFacts;
  lNode: TDelphiNameFlowNode;
  lScope, lCandidateScope, lSource: string;
  i, j, lScore, lBest, lMatches: Integer;
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
    lSource := aSnapshot.ExactTextOf(lUnit.SourceTextId);
    // Selected-pair text cannot discharge inactive nearer declarations or
    // conditionally declared dependencies. No imported spelling union is used.
    if ContainsText(lSource, '{$IF') or ContainsText(lSource, '(*$IF') or
      ContainsText(lSource, '{$I ') or ContainsText(lSource, '{$INCLUDE') then
      Exit;
    lFacts := NameFlowFactsFromJson(aSnapshot.ExactTextOf(lUnit.NameFlowFactsJsonId));
    lScope := '';
    for j := 1 to lFacts.NodeCount do
    begin
      lNode := lFacts.NodeById(j);
      if (lNode.Line = aLine) and (lNode.Column = aColumn) and
        SameText(lNode.Name, aName) then
        lScope := lNode.ScopeId;
    end;
    lBest := -1;
    lMatches := 0;
    for j := 1 to lUnit.SymbolCount do
    begin
      lSymbol := lUnit.SymbolById(j);
      if not SameText(aSnapshot.TextOf(lSymbol.NameId), aName) or
        not MatchText(aSnapshot.TextOf(lSymbol.KindId), ['const', 'resourcestring']) or
        (lSymbol.FileId <> 0) or (lSymbol.OwnerTypeId <> 0) or
        (lSymbol.Line > aLine) or
        ((lSymbol.Line = aLine) and (lSymbol.Column >= aColumn)) then
        Continue;
      lCandidateScope := aSnapshot.TextOf(lSymbol.RoutineScopeId);
      if (lCandidateScope <> '') and not SameText(lCandidateScope, lScope) then
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
    Result := lMatches = 1;
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
var
  g: TGarbos;
  i, j, lIndex: Integer;
  lUnit: TUnitSnapshot;
  lFacts: IDelphiNameFlowFacts;
  lNode, lParent: TDelphiNameFlowNode;
  lResolution: TDelphiSemanticSnapshotPositionResolution;
  lEntry: TNameSdkEffectEntry;
  lEntries: TArray<TNameSdkEffectEntry>;
  lByName: TObjectDictionary<string, TList<Integer>>;
  lCandidates: TList<Integer>;
  lEffects: TList<TNameSdkEffect>;
  lGaps: TList<TDelphiSemanticUsage>;
  lSeen, lCallSites, lOpaqueSdk, lOpaqueProject: TDictionary<string, Boolean>;
  lEffect: TNameSdkEffect;
  lFileName, lKind, lName, lSource, lJson, lKey: string;
  lResolved, lCallable, lExactSdk, lSdkCurrent, lExplicitCall: Boolean;

  procedure Report(const aFileName, aName, aReason: string;
    const aLine, aColumn: Integer);
  var
    lGap: TDelphiSemanticUsage;
    lReportKey: string;
  begin
    lReportKey := aFileName + '|' + aReason + '|' + aName + '|' +
      IntToStr(aLine) + ':' + IntToStr(aColumn);
    if lSeen.ContainsKey(lReportKey) then
      Exit;
    lSeen.Add(lReportKey, True);
    lGap := Default(TDelphiSemanticUsage);
    lGap.FileName := aFileName;
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

begin
  Result := Default(TNameFlowAnalysis);
  GC(lGaps, TList<TDelphiSemanticUsage>.Create, g);
  GC(lSeen, TDictionary<string, Boolean>.Create, g);
  GC(lCallSites, TDictionary<string, Boolean>.Create, g);
  GC(lOpaqueSdk, TDictionary<string, Boolean>.Create, g);
  GC(lOpaqueProject, TDictionary<string, Boolean>.Create, g);
  GC(lByName, TObjectDictionary<string, TList<Integer>>.Create([doOwnsValues]), g);
  GC(lEffects, TList<TNameSdkEffect>.Create, g);
  try
    if aSnapshot = nil then
    begin
      Report('', '', 'runtime-name-flow-coverage-unproved', 0, 0);
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
      if Length(lJson) > 128 * 1024 * 1024 then
      begin
        Report(lFileName, '', 'runtime-name-flow-budget-exceeded', 0, 0);
        Break;
      end;
      lFacts := NameFlowFactsFromJson(lJson);
      if not lFacts.Complete then
      begin
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
        Break;
      end;
      lSource := aSnapshot.ExactTextOf(lUnit.SourceTextId);
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
            Report(lNode.FileName, lNode.SyntaxKind, 'runtime-name-metadata-consumer',
              lNode.Line, lNode.Column);
          end;
          Continue;
        end;
        if not (lNode.Kind in [TDelphiNameFlowNodeKind.Call,
          TDelphiNameFlowNodeKind.PotentialCall]) or not IsExecutable(lNode) then
          Continue;
        // The identifier operand supplies the declaration coordinates. A call
        // without such a witness is deliberately retained as unbound.
        lExplicitCall := lNode.Kind = TDelphiNameFlowNodeKind.Call;
        if lExplicitCall then
          if CalleeNode(lNode, lParent) then
            lNode := lParent;
        lName := lNode.Name;
        if MatchText(lName, ['Self', 'Result', 'True', 'False', 'nil']) then
          Continue;
        lKey := lNode.FileName + ':' + IntToStr(lNode.Line) + ':' +
          IntToStr(lNode.Column) + ':' + LowerCase(lName);
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
        Inc(Result.Statistics.CallCount);
        if not lSdkCurrent and (aSdk <> nil) then
          lEffect := TNameSdkEffect.OpaqueEffect('sdk-identity-mismatch');
        if not lEffect.Observes(aTargetKind) then
          Continue;
        if (TNameEffectChannel.ReceiverMetadata in lEffect.Channels) or
          (TNameEffectChannel.ArgumentMetadata in lEffect.Channels) or
          (TNameEffectChannel.GlobalMetadata in lEffect.Channels) or
          (TNameEffectChannel.ProducedName in lEffect.Channels) then
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
        if (TNameEffectChannel.Opaque in lEffect.Channels) or
          (TNameEffectChannel.Store in lEffect.Channels) or
          (TNameEffectChannel.Callback in lEffect.Channels) then
          Report(lNode.FileName, lName, 'runtime-name-call-effect-unproved', lNode.Line, lNode.Column);
        // Until the DS-797 matrix closes dependency bindings in every pair,
        // a conditional anywhere in a demanded unit prevents an absence proof.
        // This also covers inactive nearer shadows and include alternatives.
        if ContainsText(lSource, '{$IF') or ContainsText(lSource, '(*$IF') or
          ContainsText(lSource, '{$I ') or ContainsText(lSource, '{$INCLUDE') or
          not lFacts.ConfigurationComplete then
        begin
          Inc(Result.Statistics.ConfigurationGaps);
          Report(lNode.FileName, lName, 'runtime-name-flow-configuration-unproved',
            lNode.Line, lNode.Column);
        end;
      end;
    end;
  finally
    Result.Gaps := lGaps.ToArray;
    Result.Statistics.DistinctUncoveredSdkCallees := lOpaqueSdk.Count;
    Result.Statistics.DistinctUncoveredProjectCallees := lOpaqueProject.Count;

  end;
end;

end.
