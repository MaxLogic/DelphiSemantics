unit DelphiSemantics.Snapshot.PositionResolver;

interface

uses
  DelphiSemantics.NameFlow.Facts, DelphiSemantics.Snapshot;

type
  TDelphiSemanticSnapshotPositionResolution = record
    Status: string;
    ReferenceFound: Boolean;
    SymbolFound: Boolean;
    ReferenceRef: TSemanticReferenceRef;
    Reference: TSemanticReferenceFact;
    SourceUnit: TUnitSnapshot;
    SymbolRef: TSemanticSymbolRef;
    Symbol: TSemanticSymbolFact;
    SymbolUnit: TUnitSnapshot;
  end;

function TryResolveSnapshotPosition(const aSnapshot: TDelphiProjectSnapshot;
  const aFileName: string; const aLine, aColumn: Integer; const aToken: string;
  out aResolution: TDelphiSemanticSnapshotPositionResolution): Boolean;

function SnapshotVisibleRuntimeDefinition(const aDefinitions: TArray<TDelphiNameFlowNode>;
  const aName, aScope, aOwner: string; const aLine, aColumn: Integer;
  out aDefinition: TDelphiNameFlowNode; out aComplete: Boolean): Boolean;

// Conservative Delphi lexical lookup. External unit candidates participate in
// uses ordering even when SDK declarations are intentionally outside the snapshot.
function SnapshotVisibleDeclarations(const aSnapshot: TDelphiProjectSnapshot;
  const aSourceUnit: TUnitSnapshot; const aName, aScope, aOwner, aSection: string;
  const aLine, aColumn: Integer; const aExternalUnits: TArray<string>;
  out aComplete: Boolean; const aSourceFacts: IDelphiNameFlowFacts = nil; const aPhysicalFileName: string = ''): TArray<TSemanticSymbolRef>;

function SnapshotProjectRoutineBindingIsComplete(const aSnapshot: TDelphiProjectSnapshot;
  const aSourceUnit: TUnitSnapshot; const aCall: TDelphiNameFlowNode;
  const aFacts: IDelphiNameFlowFacts; const aBinding: TDelphiSemanticSnapshotPositionResolution;
  const aCatalogOwners: TArray<string>): Boolean;

function SnapshotProjectRoutineFamilyIsComplete(const aSnapshot: TDelphiProjectSnapshot;
  const aSourceUnit: TUnitSnapshot; const aCallee: TDelphiNameFlowNode;
  const aFacts: IDelphiNameFlowFacts; const aCatalogOwners: TArray<string>): Boolean;

implementation

uses
  System.StrUtils, System.SysUtils,
  DelphiSemantics.ImportFacts, DelphiSemantics.Snapshot.QuerySupport;

function TryResolveSnapshotPosition(const aSnapshot: TDelphiProjectSnapshot;
  const aFileName: string; const aLine, aColumn: Integer; const aToken: string;
  out aResolution: TDelphiSemanticSnapshotPositionResolution): Boolean;
var
  lReference: TSemanticReferenceFact;
  lReferenceRef: TSemanticReferenceRef;
  lSymbol: TSemanticSymbolFact;
  lSymbolRef: TSemanticSymbolRef;
  lTargetSymbol: TSemanticSymbolFact;
  lTargetUnit: TUnitSnapshot;
  lUnit: TUnitSnapshot;
begin
  Result := False;
  aResolution := Default(TDelphiSemanticSnapshotPositionResolution);
  if aSnapshot = nil then
    Exit;

  if aSnapshot.TryReferenceAt(aFileName, aLine, aColumn, lReferenceRef) and
    aSnapshot.TryFindUnitById(lReferenceRef.UnitId, lUnit) then
  begin
    lReference := lUnit.ReferenceById(lReferenceRef.ReferenceId);
    if ((aToken = '') or SameText(SnapshotText(aSnapshot, lReference.NameId), aToken)) and
      (lReference.TargetUnitId <> 0) and (lReference.TargetSymbolId <> 0) and
      aSnapshot.TryFindUnitById(lReference.TargetUnitId, lTargetUnit) then
    begin
      lTargetSymbol := lTargetUnit.SymbolById(lReference.TargetSymbolId);
      if lTargetSymbol.NameId <> 0 then
      begin
        aResolution.Status := 'snapshot-reference-target';
        aResolution.ReferenceFound := True;
        aResolution.SymbolFound := True;
        aResolution.ReferenceRef := lReferenceRef;
        aResolution.Reference := lReference;
        aResolution.SourceUnit := lUnit;
        aResolution.SymbolRef.UnitId := lReference.TargetUnitId;
        aResolution.SymbolRef.SymbolId := lReference.TargetSymbolId;
        aResolution.Symbol := lTargetSymbol;
        aResolution.SymbolUnit := lTargetUnit;
        Exit(True);
      end;
    end;
  end;

  if aSnapshot.TrySymbolAt(aFileName, aLine, aColumn, lSymbolRef) and
    aSnapshot.TryFindUnitById(lSymbolRef.UnitId, lUnit) then
  begin
    lSymbol := lUnit.SymbolById(lSymbolRef.SymbolId);
    if lSymbol.NameId = 0 then
      Exit(False);
    aResolution.Status := 'snapshot-position-match';
    aResolution.SymbolFound := True;
    aResolution.SymbolRef := lSymbolRef;
    aResolution.Symbol := lSymbol;
    aResolution.SymbolUnit := lUnit;
    Exit(True);
  end;
end;

function SnapshotVisibleDeclarations(const aSnapshot: TDelphiProjectSnapshot;
  const aSourceUnit: TUnitSnapshot; const aName, aScope, aOwner, aSection: string;
  const aLine, aColumn: Integer; const aExternalUnits: TArray<string>;
  out aComplete: Boolean; const aSourceFacts: IDelphiNameFlowFacts; const aPhysicalFileName: string): TArray<TSemanticSymbolRef>;
var
  lUnit: TUnitSnapshot;
  lSymbol: TSemanticSymbolFact;
  lRef, lExisting, lQualifiedType: TSemanticSymbolRef;
  lQualifierRefs: TArray<TSemanticSymbolRef>;
  lQualifierUnit: TUnitSnapshot;
  lQualifierComplete, lTypeQualified: Boolean;
  lExistingSymbol: TSemanticSymbolFact;
  lImport: TDelphiSemanticImportFact;
  lOwnerFacts: IDelphiNameFlowFacts;
  lOwnerNode, lOwnerClass: TDelphiNameFlowNode;
  lScope, lOwner, lUnitName, lName, lQualifier, lDeclarationFile, lUseFile: string;
  lBest, lScore, lOrder, lDot, i, j, lChild, lLowIndex, lHighIndex: Integer;
  lNameId: TSemanticStringId;
  lVisible, lUncertain, lBestUncertain, lDuplicate: Boolean;
begin
  Result := nil;
  aComplete := False;
  if (aSnapshot = nil) or (aSourceUnit = nil) then
    Exit;
  lName := aName;
  lQualifier := '';
  lDot := LastDelimiter('.', aName);
  if lDot > 0 then
  begin
    lQualifier := Copy(aName, 1, lDot - 1);
    lName := Copy(aName, lDot + 1, MaxInt);
  end;
  lTypeQualified := False;
  lQualifiedType := Default(TSemanticSymbolRef);
  if lQualifier <> '' then
  begin
    lQualifierRefs := SnapshotVisibleDeclarations(aSnapshot, aSourceUnit, lQualifier,
      aScope, aOwner, aSection, aLine, aColumn, nil, lQualifierComplete, aSourceFacts, aPhysicalFileName);
    if not lQualifierComplete then
      Exit;
    if Length(lQualifierRefs) > 0 then
    begin
      if (Length(lQualifierRefs) <> 1) or
        not aSnapshot.TryFindUnitById(lQualifierRefs[0].UnitId, lQualifierUnit) then
        Exit;
      lExistingSymbol := lQualifierUnit.SymbolById(lQualifierRefs[0].SymbolId);
      if not SameText(aSnapshot.TextOf(lExistingSymbol.KindId), 'type') then
        Exit; // A variable or ambiguous qualifier cannot name a constant owner.
      lQualifiedType := lQualifierRefs[0];
      lQualifier := aSnapshot.TextOf(lExistingSymbol.NameId);
      lTypeQualified := True;
    end;
  end;
  lBest := -1;
  lBestUncertain := False;
  lLowIndex := 0;
  lHighIndex := -1;
  if aSnapshot.TryFindStringId(lName, lNameId) then
    if not aSnapshot.TrySymbolsByName(lNameId, lLowIndex, lHighIndex) then
      lHighIndex := -1;
  // The immutable name index supplies the same candidate set without scanning
  // every declaration in every unit for each constant operand.
  for i := lLowIndex to lHighIndex do
  begin
    lRef := aSnapshot.SymbolRefByNameIndex(i);
    if not aSnapshot.TryFindUnitById(lRef.UnitId, lUnit) then
      Continue;
    lUnitName := aSnapshot.TextOf(lUnit.UnitNameId);
    lOrder := -1;
    lUncertain := False;
    if lUnit = aSourceUnit then
      lOrder := 1000000
    else
      for lImport in aSourceUnit.ImportFacts do
        if ((lImport.OwnerFileName = '') or SameText(lImport.OwnerFileName,
          aSnapshot.TextOf(aSourceUnit.FileNameId))) and
          (SameText(lImport.Name, lUnitName) or ((lImport.TargetFileName <> '') and
           SameText(lImport.TargetFileName, aSnapshot.TextOf(lUnit.FileNameId)))) and
          (SameText(lImport.SectionKind, 'interface') or
           not SameText(aSection, 'interface')) then
        begin
          lScore := lImport.OrderIndex;
          if SameText(lImport.SectionKind, 'implementation') then
            Inc(lScore, 100000);
          if lScore > lOrder then
          begin
            lOrder := lScore;
            lUncertain := lImport.ResolutionVaries or (lImport.Cause <> '');
          end;
        end;
    if (lOrder < 0) or (lTypeQualified and (lUnit.UnitId <> lQualifiedType.UnitId)) or
      ((lQualifier <> '') and not lTypeQualified and not SameText(lQualifier, lUnitName) and
      not ((lUnit = aSourceUnit) and SameText(lQualifier, aOwner))) then
      Continue;
    begin
      lSymbol := lUnit.SymbolById(lRef.SymbolId);
      if not SameText(aSnapshot.TextOf(lSymbol.NameId), lName) then
        Continue;
      lScope := aSnapshot.TextOf(lSymbol.RoutineScopeId);
      if SameText(aSnapshot.TextOf(lSymbol.ScopeKindId), 'routine') or
        MatchText(aSnapshot.TextOf(lSymbol.KindId), ['routine', 'method', 'constructor', 'destructor']) then
        lScope := aSnapshot.TextOf(lSymbol.OwnerScopeId);
      lOwner := aSnapshot.TextOf(lSymbol.OwnerTypeId);
      lVisible := True;
      lScore := lOrder;
      if lTypeQualified then
        lVisible := (lScope = '') and SameText(lOwner, lQualifier)
      else if lUnit = aSourceUnit then
      begin
        if (lScope <> '') then
        begin
          lVisible := (lQualifier = '') and ((aScope = lScope) or StartsText(lScope + '/', aScope));
          Inc(lScore, 2000000 + Length(lScope));
        end else if lOwner <> '' then
        begin
          lVisible := ((lQualifier = '') or SameText(lQualifier, lOwner)) and SameText(aOwner, lOwner);
          Inc(lScore, 1000000);
        end;
        // Interface headers establish visibility before implementation bodies.
        if not SameText(aSnapshot.TextOf(lSymbol.SectionKindId), 'interface') then
        begin
          lDeclarationFile := aSnapshot.TextOf(lUnit.FileNameId);
          if lSymbol.FileId <> 0 then
            lDeclarationFile := aSnapshot.TextOf(lSymbol.FileId);
          lUseFile := aPhysicalFileName;
          if lUseFile = '' then
            lUseFile := aSnapshot.TextOf(aSourceUnit.FileNameId);
          if SameText(lDeclarationFile, lUseFile) then
            lVisible := lVisible and (aLine > 0) and ((lSymbol.Line < aLine) or
              ((lSymbol.Line = aLine) and (lSymbol.Column < aColumn)))
          else
            lUncertain := True; // Different include files have no comparable physical order.
        end;
      end else
        lVisible := (lOwner = '') and (lScope = '') and
          SameText(aSnapshot.TextOf(lSymbol.SectionKindId), 'interface');
      if not lVisible or (lScore < lBest) then
        Continue;
      if lScore > lBest then
      begin
        Result := nil;
        lBest := lScore;
        lBestUncertain := False;
      end;
      // Interface include declarations have unit-wide visibility. Implementation
      // include coordinates alone cannot establish declaration order.
      lBestUncertain := lBestUncertain or lUncertain or ((lSymbol.FileId <> 0) and
        not SameText(aSnapshot.TextOf(lSymbol.SectionKindId), 'interface') and
        not SameText(aSnapshot.TextOf(lSymbol.FileId), aPhysicalFileName));
      lRef.UnitId := lUnit.UnitId;
      lRef.SymbolId := lSymbol.Id;
      lDuplicate := False;
      if MatchText(aSnapshot.TextOf(lSymbol.KindId), ['routine', 'method', 'parameter']) and
        (lSymbol.RoutineScopeId <> 0) then
        for lExisting in Result do
          if lExisting.UnitId = lRef.UnitId then
          begin
            lExistingSymbol := lUnit.SymbolById(lExisting.SymbolId);
            lDuplicate := lDuplicate or
              ((lExistingSymbol.RoutineScopeId = lSymbol.RoutineScopeId) and
               (lExistingSymbol.OwnerTypeId = lSymbol.OwnerTypeId) and
               (lExistingSymbol.KindId = lSymbol.KindId) and
               ((aSnapshot.TextOf(lSymbol.KindId) <> 'parameter') or
                (lExistingSymbol.TypeId = lSymbol.TypeId)));
          end;
      if not lDuplicate then
        Result := Result + [lRef];
    end;
  end;
  // An uncaptured inherited member can precede the own-unit constant. Do not
  // jump across that class scope to fold a unit/imported homonym.
  if not lTypeQualified and (aOwner <> '') and (lQualifier = '') and (lBest < 2000000) then
  begin
    lOwnerFacts := aSourceFacts;
    if lOwnerFacts = nil then
      lOwnerFacts := NameFlowFactsFromJson(aSnapshot.ExactTextOf(aSourceUnit.NameFlowFactsJsonId));
    lUncertain := True;
    for i := 1 to lOwnerFacts.NodeCount do
    begin
      lOwnerNode := lOwnerFacts.NodeById(i);
      if (lOwnerNode.SyntaxKind <> 'typedecl') or not SameText(lOwnerNode.Name, aOwner) then
        Continue;
      for j in lOwnerNode.Children do
      begin
        lOwnerClass := lOwnerFacts.NodeById(j);
        if (lOwnerClass.SyntaxKind <> 'type') or not SameText(lOwnerClass.TypeName, 'class') then
          Continue;
        lUncertain := False;
        for lChild in lOwnerClass.Children do
          if lOwnerFacts.NodeById(lChild).SyntaxKind = 'type' then
            lUncertain := True;
      end;
    end;
    if lUncertain then
    begin
      Result := nil;
      lBestUncertain := True;
    end;
  end;
  // A known SDK export later in effective uses order wins over project units.
  // An unresolved import can also contain the name; it cannot prove exemption.
  for lImport in aSourceUnit.ImportFacts do
    if ((lImport.OwnerFileName = '') or SameText(lImport.OwnerFileName,
      aSnapshot.TextOf(aSourceUnit.FileNameId))) and
      (SameText(lImport.SectionKind, 'interface') or not SameText(aSection, 'interface')) and
      ((lQualifier = '') or SameText(lQualifier, lImport.Name)) then
    begin
      lScore := lImport.OrderIndex;
      if SameText(lImport.SectionKind, 'implementation') then
        Inc(lScore, 100000);
      if (lScore >= lBest) and (MatchText(lImport.Name, aExternalUnits) or
        MatchText('System.' + lImport.Name, aExternalUnits) or
        MatchText('Winapi.' + lImport.Name, aExternalUnits) or lImport.ResolutionVaries or ((lImport.Cause <> '') and not lImport.SdkBoundary)) then
      begin
        Result := nil;
        lBestUncertain := True;
        lBest := lScore;
      end;
    end;
  aComplete := not lBestUncertain;
end;

function SnapshotNameFlowDottedName(const aFacts: IDelphiNameFlowFacts;
  const aNode: TDelphiNameFlowNode; const aDepth: Integer): string; forward;

function SnapshotProjectReceiverBindingIsComplete(const aSnapshot: TDelphiProjectSnapshot;
  const aSourceUnit: TUnitSnapshot; const aCall: TDelphiNameFlowNode;
  const aFacts: IDelphiNameFlowFacts; const aBinding: TDelphiSemanticSnapshotPositionResolution): Boolean;
var
  lReceiver, lNode, lDefinition, lClass, lChild: TDelphiNameFlowNode;
  lDefinitions: TArray<TDelphiNameFlowNode>;
  lRefs: TArray<TSemanticSymbolRef>;
  lTypeRef: TSemanticSymbolRef;
  lTypeUnit: TUnitSnapshot;
  lTypeFacts: IDelphiNameFlowFacts;
  lSymbol: TSemanticSymbolFact;
  lExternalUnits: TArray<string>;
  lImport: TDelphiSemanticImportFact;
  lOwner, lTypeName, lScope, lSection, lPhysicalFile: string;
  lComplete, lHaveType, lFound: Boolean;
  lLine, lColumn, lDepth, i, j, k: Integer;
begin
  Result := False;
  lOwner := '';
  lSection := 'implementation';
  lNode := aCall;
  for lDepth := 0 to 63 do
  begin
    if (lOwner = '') and (lNode.Kind = TDelphiNameFlowNodeKind.Routine) then
      lOwner := Copy(lNode.Name, 1, LastDelimiter('.', lNode.Name) - 1);
    if lNode.SyntaxKind = 'interface' then
      lSection := 'interface';
    if lNode.ParentId = 0 then
      Break;
    lNode := aFacts.NodeById(lNode.ParentId);
  end;
  if lDepth >= 63 then
    Exit;
  lReceiver := Default(TDelphiNameFlowNode);
  if aCall.ParentId > 0 then
  begin
    lNode := aFacts.NodeById(aCall.ParentId);
    if (lNode.SyntaxKind = 'dot') and (Length(lNode.Children) = 2) then
      lReceiver := aFacts.NodeById(lNode.Children[0]);
  end;
  lTypeUnit := aSourceUnit;
  lTypeFacts := aFacts;
  lScope := aCall.ScopeId;
  lTypeName := lOwner;
  lLine := aCall.Line;
  lColumn := aCall.Column;
  lPhysicalFile := aCall.FileName;
  lHaveType := False;
  if (lReceiver.Id = 0) or SameText(lReceiver.Name, 'Self') then
  begin
    if lOwner = '' then
      Exit;
    // Self belongs to the structurally enclosing class. Resolve that class
    // in its unit, rather than as a possibly inherited member at the call.
    lTypeName := aSnapshot.TextOf(aSourceUnit.UnitNameId) + '.' + lOwner;
    lScope := '';
    lOwner := '';
  end;
  if (lReceiver.Id <> 0) and not SameText(lReceiver.Name, 'Self') then
  begin
    if lReceiver.SyntaxKind <> 'identifier' then
      Exit;
    for i := 1 to aFacts.NodeCount do
    begin
      lNode := aFacts.NodeById(i);
      if (lNode.Kind in [TDelphiNameFlowNodeKind.Definition, TDelphiNameFlowNodeKind.Formal]) and
        SameText(lNode.Name, lReceiver.Name) then
        lDefinitions := lDefinitions + [lNode];
    end;
    if SnapshotVisibleRuntimeDefinition(lDefinitions, lReceiver.Name, aCall.ScopeId,
      lOwner, aCall.Line, aCall.Column, lDefinition, lComplete) then
    begin
      if not lComplete then
        Exit;
      lTypeName := lDefinition.TypeName;
      lScope := lDefinition.ScopeId;
      lOwner := lDefinition.OwnerType;
      lLine := lDefinition.Line;
      lColumn := lDefinition.Column;
      lPhysicalFile := lDefinition.FileName;
    end else begin
      lExternalUnits := nil;
      for lImport in aSourceUnit.ImportFacts do
        if lImport.SdkBoundary then
          lExternalUnits := lExternalUnits + [lImport.Name];
      lRefs := SnapshotVisibleDeclarations(aSnapshot, aSourceUnit, lReceiver.Name,
        aCall.ScopeId, lOwner, lSection, aCall.Line, aCall.Column,
        lExternalUnits, lComplete, aFacts, aCall.FileName);
      if not lComplete or (Length(lRefs) <> 1) or
        not aSnapshot.TryFindUnitById(lRefs[0].UnitId, lTypeUnit) then
        Exit;
      lSymbol := lTypeUnit.SymbolById(lRefs[0].SymbolId);
      lTypeRef := lRefs[0];
      lHaveType := SameText(aSnapshot.TextOf(lSymbol.KindId), 'type');
      lTypeName := aSnapshot.TextOf(lSymbol.TypeId);
      lScope := aSnapshot.TextOf(lSymbol.RoutineScopeId);
      lOwner := aSnapshot.TextOf(lSymbol.OwnerTypeId);
      lSection := aSnapshot.TextOf(lSymbol.SectionKindId);
      lLine := lSymbol.Line;
      lColumn := lSymbol.Column;
      lPhysicalFile := aSnapshot.TextOf(lSymbol.FileId);
      lTypeFacts := NameFlowFactsFromJson(aSnapshot.ExactTextOf(lTypeUnit.NameFlowFactsJsonId));
    end;
  end;
  for lDepth := 0 to 31 do
  begin
    if not lHaveType then
    begin
      if lTypeName = '' then
        Exit;
      // A project type homonym is no stronger than a routine homonym. Its
      // declaration's uses order must rule out later uncaptured SDK exports.
      lExternalUnits := nil;
      for lImport in lTypeUnit.ImportFacts do
        if lImport.SdkBoundary then
          lExternalUnits := lExternalUnits + [lImport.Name];
      lRefs := SnapshotVisibleDeclarations(aSnapshot, lTypeUnit, lTypeName,
        lScope, lOwner, lSection, lLine, lColumn, lExternalUnits, lComplete,
        lTypeFacts, lPhysicalFile);
      if not lComplete or (Length(lRefs) <> 1) or
        not aSnapshot.TryFindUnitById(lRefs[0].UnitId, lTypeUnit) then
        Exit;
      lTypeRef := lRefs[0];
      lSymbol := lTypeUnit.SymbolById(lTypeRef.SymbolId);
      if not SameText(aSnapshot.TextOf(lSymbol.KindId), 'type') then
        Exit;
    end;
    lHaveType := False;
    lTypeName := aSnapshot.TextOf(lSymbol.NameId);
    if (lTypeRef.UnitId = aBinding.SymbolRef.UnitId) and
      SameText(lTypeName, aSnapshot.TextOf(aBinding.Symbol.OwnerTypeId)) then
      Exit(True);
    // An inherited project declaration is eligible only through a closed,
    // scope-bound project ancestor chain. SDK or unknown ancestors stop it.
    lTypeFacts := NameFlowFactsFromJson(aSnapshot.ExactTextOf(lTypeUnit.NameFlowFactsJsonId));
    lFound := False;
    for i := 1 to lTypeFacts.NodeCount do
    begin
      lDefinition := lTypeFacts.NodeById(i);
      if (lDefinition.SyntaxKind <> 'typedecl') or not SameText(lDefinition.Name, lTypeName) then
        Continue;
      for j in lDefinition.Children do
      begin
        lClass := lTypeFacts.NodeById(j);
        if (lClass.SyntaxKind <> 'type') or not SameText(lClass.TypeName, 'class') then
          Continue;
        lTypeName := '';
        for k in lClass.Children do
        begin
          lChild := lTypeFacts.NodeById(k);
          if lChild.SyntaxKind = 'type' then
            lTypeName := lChild.Name;
        end;
        lScope := lDefinition.ScopeId;
        lOwner := lDefinition.OwnerType;
        lLine := lDefinition.Line;
        lColumn := lDefinition.Column;
        lPhysicalFile := lDefinition.FileName;
        lSection := 'implementation';
        lNode := lDefinition;
        for k := 0 to 63 do
        begin
          if lNode.SyntaxKind = 'interface' then
            lSection := 'interface';
          if lNode.ParentId = 0 then
            Break;
          lNode := lTypeFacts.NodeById(lNode.ParentId);
        end;
        if k >= 63 then
          Exit;
        lFound := True;
        Break;
      end;
      Break;
    end;
    if not lFound then
      Exit;
  end;
end;

function SnapshotProjectRoutineBindingIsComplete(const aSnapshot: TDelphiProjectSnapshot;
  const aSourceUnit: TUnitSnapshot; const aCall: TDelphiNameFlowNode;
  const aFacts: IDelphiNameFlowFacts; const aBinding: TDelphiSemanticSnapshotPositionResolution;
  const aCatalogOwners: TArray<string>): Boolean;
var
  lNode, lDefinition, lChild: TDelphiNameFlowNode;
  lFacts: IDelphiNameFlowFacts;
  lCandidates: TArray<TSemanticSymbolRef>;
  lRef: TSemanticSymbolRef;
  lUnit: TUnitSnapshot;
  lScope, lOwner, lQualifier, lSection, lBase: string;
  lComplete, lOverload, lFound: Boolean;
  lDepth, i, j, k: Integer;
  lAttribute: TDelphiNameFlowAttribute;
  lImport: TDelphiSemanticImportFact;
  lExternalTypeUnits: TArray<string>;
  lBaseSymbol: TSemanticSymbolFact;
begin
  Result := False;
  if not aBinding.ReferenceFound or (aBinding.SymbolUnit = nil) or not aCall.SpanKnown or
    not MatchText(aSnapshot.TextOf(aBinding.Symbol.KindId), ['routine', 'method', 'constructor', 'destructor', 'operator']) then
    Exit;
  // Complete runtime facts can retain nearer locals omitted by lean symbols.
  // A position resolver's outer routine target cannot override that evidence.
  for i := 1 to aFacts.NodeCount do
  begin
    lDefinition := aFacts.NodeById(i);
    if (lDefinition.Kind in [TDelphiNameFlowNodeKind.Definition, TDelphiNameFlowNodeKind.Formal]) and
      (lDefinition.ScopeId <> '') and StartsText(lDefinition.ScopeId, aCall.ScopeId) and
      SameText(lDefinition.Name, aCall.Name) then
      Exit;
  end;
  lNode := aCall;
  lOwner := '';
  lSection := 'implementation';
  for lDepth := 0 to 63 do
  begin
    if MatchText(lNode.SyntaxKind, ['inherited', 'with']) then
      Exit;
    // Inherited may be a sibling of the callee inside its expression.
    for k in lNode.Children do
      if aFacts.NodeById(k).SyntaxKind = 'inherited' then
        Exit;
    if (lOwner = '') and (lNode.Kind = TDelphiNameFlowNodeKind.Routine) then
      lOwner := Copy(lNode.Name, 1, LastDelimiter('.', lNode.Name) - 1);
    if lNode.SyntaxKind = 'interface' then
      lSection := 'interface';
    if lNode.ParentId = 0 then
      Break;
    lNode := aFacts.NodeById(lNode.ParentId);
  end;
  if lDepth >= 63 then
    Exit;
  lScope := aCall.ScopeId;
  lQualifier := aCall.Name;
  if aSnapshot.TextOf(aBinding.Symbol.OwnerTypeId) = '' then
  begin
    // Only the callee's own selector is a qualifier. A dot applied to the
    // call result does not turn an unqualified call into a project namespace.
    if aCall.ParentId > 0 then
    begin
      lNode := aFacts.NodeById(aCall.ParentId);
      if (lNode.SyntaxKind = 'dot') and (Length(lNode.Children) = 2) and
        (lNode.Children[1] = aCall.Id) then
      begin
        lQualifier := SnapshotNameFlowDottedName(aFacts, aFacts.NodeById(lNode.Children[0]), 0);
        for lDepth := 0 to 15 do
        begin
          if lNode.ParentId = 0 then
            Break;
          lChild := aFacts.NodeById(lNode.ParentId);
          if (lChild.SyntaxKind <> 'dot') or (Length(lChild.Children) <> 2) or
            (lChild.Children[1] <> lNode.Id) then
            Break;
          lBase := SnapshotNameFlowDottedName(aFacts, aFacts.NodeById(lChild.Children[0]), 0);
          if lBase = '' then
            Exit;
          lQualifier := lBase + '.' + lQualifier;
          lNode := lChild;
        end;
        if (lDepth >= 15) or
          not SameText(lQualifier, aSnapshot.TextOf(aBinding.SymbolUnit.UnitNameId)) then
          Exit;
        lQualifier := lQualifier + '.' + aCall.Name;
      end;
    end;
    lCandidates := SnapshotVisibleDeclarations(aSnapshot, aSourceUnit, lQualifier,
      lScope, lOwner, lSection, aCall.Line, aCall.Column, aCatalogOwners, lComplete);
    if not lComplete or (Length(lCandidates) = 0) then
      Exit;
    for lRef in lCandidates do
      if (lRef.UnitId <> aBinding.SymbolRef.UnitId) or
        (lRef.SymbolId <> aBinding.SymbolRef.SymbolId) then
        Exit;
    Exit(True);
  end;
  if not SnapshotProjectReceiverBindingIsComplete(aSnapshot, aSourceUnit, aCall, aFacts, aBinding) then
    Exit;
  lUnit := aBinding.SymbolUnit;
  lFacts := NameFlowFactsFromJson(aSnapshot.ExactTextOf(lUnit.NameFlowFactsJsonId));
  lOwner := aSnapshot.TextOf(aBinding.Symbol.OwnerTypeId);
  lOverload := False;
  lFound := False;
  for i := 1 to lFacts.NodeCount do
  begin
    lDefinition := lFacts.NodeById(i);
    if (lDefinition.Kind = TDelphiNameFlowNodeKind.Routine) and
      (SameText(lDefinition.Name, aCall.Name) or
       SameText(lDefinition.Name, lOwner + '.' + aCall.Name)) then
    begin
      lFound := True;
      for lAttribute in lDefinition.Attributes do
        if SameText(lAttribute.Name, 'overload') and not SameText(lAttribute.Value, 'false') then
          lOverload := True;
    end;
  end;
  if not lFound then
    Exit;
  if not lOverload then
    Exit(True);
  // An overload keeps the ancestor set. Follow only captured project ancestry;
  // an SDK/catalog member or an unknown ancestor leaves this set open.
  for lDepth := 0 to 31 do
  begin
    lBase := '';
    for i := 1 to lFacts.NodeCount do
    begin
      lDefinition := lFacts.NodeById(i);
      if (lDefinition.SyntaxKind <> 'typedecl') or not SameText(lDefinition.Name, lOwner) then
        Continue;
      for j in lDefinition.Children do
      begin
        lNode := lFacts.NodeById(j);
        if (lNode.SyntaxKind <> 'type') or not SameText(lNode.TypeName, 'class') then
          Continue;
        lBase := 'System.TObject';
        for k in lNode.Children do
        begin
          lChild := lFacts.NodeById(k);
          if lChild.SyntaxKind = 'type' then
            lBase := lChild.Name;
        end;
        Break;
      end;
      Break;
    end;
    if lBase = '' then
      Exit;
    for lQualifier in aCatalogOwners do
      if SameText(lQualifier, lBase) or EndsText('.' + lBase, lQualifier) then
        Exit;
    if SameText(lBase, 'System.TObject') then
      Exit(True);
    // The base name has the declaring unit's lexical/import scope. An
    // unrelated project homonym cannot close an inherited SDK overload set.
    // SDK imports have uncaptured type exports, so a later one keeps the
    // binding uncertain rather than allowing an earlier project candidate.
    lExternalTypeUnits := nil;
    for lImport in lUnit.ImportFacts do
      if lImport.SdkBoundary then
        lExternalTypeUnits := lExternalTypeUnits + [lImport.Name];
    lSection := 'implementation';
    lNode := lDefinition;
    for j := 0 to 63 do
    begin
      if lNode.SyntaxKind = 'interface' then
        lSection := 'interface';
      if lNode.ParentId = 0 then
        Break;
      lNode := lFacts.NodeById(lNode.ParentId);
    end;
    if j >= 63 then
      Exit;
    lCandidates := SnapshotVisibleDeclarations(aSnapshot, lUnit, lBase,
      lDefinition.ScopeId, lDefinition.OwnerType, lSection,
      lDefinition.Line, lDefinition.Column, lExternalTypeUnits, lComplete,
      lFacts, lDefinition.FileName);
    if not lComplete or (Length(lCandidates) <> 1) or
      not aSnapshot.TryFindUnitById(lCandidates[0].UnitId, lUnit) then
      Exit;
    lBaseSymbol := lUnit.SymbolById(lCandidates[0].SymbolId);
    if not SameText(aSnapshot.TextOf(lBaseSymbol.KindId), 'type') or
      not SameText(aSnapshot.TextOf(lBaseSymbol.TypeId), 'class') then
      Exit;
    lOwner := aSnapshot.TextOf(lBaseSymbol.NameId);
    lFacts := NameFlowFactsFromJson(aSnapshot.ExactTextOf(lUnit.NameFlowFactsJsonId));
  end;
end;

function SnapshotVisibleRuntimeDefinition(const aDefinitions: TArray<TDelphiNameFlowNode>;
  const aName, aScope, aOwner: string; const aLine, aColumn: Integer;
  out aDefinition: TDelphiNameFlowNode; out aComplete: Boolean): Boolean;
var
  lNode: TDelphiNameFlowNode;
  lBest, lScore: Integer;
begin
  Result := False;
  aComplete := True;
  aDefinition := Default(TDelphiNameFlowNode);
  lBest := -1;
  for lNode in aDefinitions do
  begin
    if not (lNode.Kind in [TDelphiNameFlowNodeKind.Definition, TDelphiNameFlowNodeKind.Formal]) or
      not SameText(lNode.Name, aName) then
      Continue;
    lScore := -1;
    if (lNode.ScopeId <> '') and (SameText(lNode.ScopeId, aScope) or
      StartsText(lNode.ScopeId + '/', aScope)) then
      lScore := 2000000 + Length(lNode.ScopeId)
    else if (lNode.ScopeId = '') and (aOwner <> '') and SameText(lNode.OwnerType, aOwner) then
      lScore := 1000000;
    if (lScore < 0) or (lNode.SpanKnown and ((lNode.Line > aLine) or
      ((lNode.Line = aLine) and (lNode.Column >= aColumn)))) then
      Continue;
    if lScore < lBest then
      Continue;
    if lScore > lBest then
    begin
      aComplete := lNode.SpanKnown;
      aDefinition := lNode;
      lBest := lScore;
    end else if (lNode.ScopeId <> aDefinition.ScopeId) or
      (lNode.OutputStartOffset <> aDefinition.OutputStartOffset) then
      aComplete := False;
    Result := True;
  end;
end;

function SnapshotNameFlowDottedName(const aFacts: IDelphiNameFlowFacts;
  const aNode: TDelphiNameFlowNode; const aDepth: Integer): string;
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
    lLeft := SnapshotNameFlowDottedName(aFacts, aFacts.NodeById(aNode.Children[0]), aDepth + 1);
    lRight := SnapshotNameFlowDottedName(aFacts, aFacts.NodeById(aNode.Children[1]), aDepth + 1);
    if (lLeft <> '') and (lRight <> '') then
      Result := lLeft + '.' + lRight;
  end;
end;

// Only disjoint primitive argument types can close an otherwise unresolved
// project overload family. Unknown types keep every candidate in the set.
function SnapshotUniqueProjectOverload(const aSnapshot: TDelphiProjectSnapshot;
  const aSourceUnit, aTargetUnit: TUnitSnapshot; const aCallee: TDelphiNameFlowNode;
  const aFacts: IDelphiNameFlowFacts; const aOwner: string): Boolean;
var
  lCall, lArgument, lNode, lParameters, lFormal: TDelphiNameFlowNode;
  lTargetFacts: IDelphiNameFlowFacts;
  lScopes: TArray<string>;
  lRefs: TArray<TSemanticSymbolRef>;
  lActualType, lFormalType, lSignature: string;
  lComplete, lCompatible: Boolean;
  lDepth, i, j, lCount: Integer;

  function PrimitiveType(const aName: string): string;
  begin
    Result := '';
    if MatchText(aName, ['Integer', 'LongInt', 'SmallInt', 'ShortInt', 'Byte', 'Word',
      'Cardinal', 'LongWord', 'Int64', 'UInt64', 'NativeInt', 'NativeUInt']) then
      Result := 'integer'
    else if MatchText(aName, ['string', 'UnicodeString', 'WideString', 'AnsiString']) then
      Result := 'string';
  end;
begin
  Result := False;
  lCall := aCallee;
  for lDepth := 0 to 31 do
  begin
    if (lCall.SyntaxKind = 'call') and (Length(lCall.Children) = 2) then
      Break;
    if lCall.ParentId = 0 then
      Exit;
    lCall := aFacts.NodeById(lCall.ParentId);
  end;
  if (lDepth >= 31) or (Length(lCall.Children) <> 2) then
    Exit;
  lArgument := aFacts.NodeById(lCall.Children[1]);
  if Length(lArgument.Children) <> 1 then
    Exit;
  lActualType := '';
  lArgument := aFacts.NodeById(lArgument.Children[0]);
  for lDepth := 0 to 31 do
  begin
    if Length(lArgument.Children) <> 1 then
      Break;
    lArgument := aFacts.NodeById(lArgument.Children[0]);
  end;
  if (lArgument.SyntaxKind = 'literal') and SameText(lArgument.TypeName, 'numeric') and
    (StrToInt64Def(lArgument.Value, Low(Int64)) <> Low(Int64)) then
    lActualType := 'integer'
  else if (lArgument.SyntaxKind = 'literal') and SameText(lArgument.TypeName, 'string') then
    lActualType := 'string'
  else if (lArgument.SyntaxKind = 'call') and (Length(lArgument.Children) = 2) and
    SameText(aFacts.NodeById(lArgument.Children[0]).Name, 'ParamStr') then
  begin
    lRefs := SnapshotVisibleDeclarations(aSnapshot, aSourceUnit, 'ParamStr', aCallee.ScopeId,
      aOwner, 'implementation', aCallee.Line, aCallee.Column, nil, lComplete);
    if lComplete and (Length(lRefs) = 0) then
      lActualType := 'string';
    for i := 1 to aFacts.NodeCount do
    begin
      lNode := aFacts.NodeById(i);
      if (lNode.Kind in [TDelphiNameFlowNodeKind.Definition, TDelphiNameFlowNodeKind.Formal]) and
        SameText(lNode.Name, 'ParamStr') and (lNode.ScopeId <> '') and
        StartsText(lNode.ScopeId, aCallee.ScopeId) then
        lActualType := '';
    end;
  end;
  if lActualType = '' then
    Exit;
  lTargetFacts := NameFlowFactsFromJson(aSnapshot.ExactTextOf(aTargetUnit.NameFlowFactsJsonId));
  lCount := 0;
  for i := 1 to lTargetFacts.NodeCount do
  begin
    lNode := lTargetFacts.NodeById(i);
    if (lNode.Kind <> TDelphiNameFlowNodeKind.Routine) or
      not (SameText(lNode.Name, aCallee.Name) or
        ((aOwner <> '') and SameText(lNode.Name, aOwner + '.' + aCallee.Name))) or
      ((lNode.OwnerType <> '') and not SameText(lNode.OwnerType, aOwner)) then
      Continue;
    // Class headers carry the owner separately; bodies qualify the name.
    // Their parameter signature still denotes one compiler declaration.
    j := Pos('(', lNode.ScopeId);
    if j = 0 then
      Exit;
    lSignature := Copy(lNode.ScopeId, j, MaxInt);
    if MatchText(lSignature, lScopes) then
      Continue;
    lScopes := lScopes + [lSignature];
    lCompatible := True;
    for j in lNode.Children do
    begin
      lParameters := lTargetFacts.NodeById(j);
      if (lParameters.SyntaxKind <> 'parameters') or (Length(lParameters.Children) <> 1) then
        Continue;
      lFormal := lTargetFacts.NodeById(lParameters.Children[0]);
      lRefs := SnapshotVisibleDeclarations(aSnapshot, aTargetUnit, lFormal.TypeName,
        lFormal.ScopeId, aOwner, 'implementation', lFormal.Line, lFormal.Column, nil, lComplete);
      lFormalType := '';
      if lComplete and (Length(lRefs) = 0) then
        lFormalType := PrimitiveType(lFormal.TypeName);
      if lFormalType <> '' then
        lCompatible := lFormalType = lActualType;
    end;
    if lCompatible then
      Inc(lCount);
  end;
  Result := lCount = 1;
end;

function SnapshotProjectRoutineFamilyIsComplete(const aSnapshot: TDelphiProjectSnapshot;
  const aSourceUnit: TUnitSnapshot; const aCallee: TDelphiNameFlowNode;
  const aFacts: IDelphiNameFlowFacts; const aCatalogOwners: TArray<string>): Boolean;
  var
    lAncestor, lSelector, lReceiver, lDefinition, lClass, lChild: TDelphiNameFlowNode;
    lTargetUnit, lCandidateUnit: TUnitSnapshot;
    lSymbol, lReceiverSymbol: TSemanticSymbolFact;
    lReceiverResolution: TDelphiSemanticSnapshotPositionResolution;
    lTargetFacts: IDelphiNameFlowFacts;
    lImport: TDelphiSemanticImportFact;
    lReceiverName, lOwner, lTypeName, lQualifier, lFirst, lUnitName, lSignature: string;
    lDepth, lIndex, lChildId, lMatches, lFamilies: Integer;
    lVisible, lRootClass, lComplete: Boolean;
    lRefs: TArray<TSemanticSymbolRef>;
    lExternalTypeUnits: TArray<string>;
  begin
    Result := False;
    if aCallee.Id = 0 then
      Exit;
    lAncestor := aCallee;
    lOwner := '';
    for lDepth := 0 to 63 do
    begin
      if MatchText(lAncestor.SyntaxKind, ['with', 'inherited']) then
        Exit;
      for lChildId in lAncestor.Children do
        if aFacts.NodeById(lChildId).SyntaxKind = 'inherited' then
          Exit;
      if (lOwner = '') and (lAncestor.Kind = TDelphiNameFlowNodeKind.Routine) then
      begin
        lIndex := lAncestor.Name.LastIndexOf('.');
        if lIndex >= 0 then
          lOwner := Copy(lAncestor.Name, 1, lIndex);
      end;
      if lAncestor.ParentId = 0 then
        Break;
      lAncestor := aFacts.NodeById(lAncestor.ParentId);
    end;
    if lAncestor.ParentId <> 0 then
      Exit;
    lReceiver := Default(TDelphiNameFlowNode);
    if aCallee.ParentId > 0 then
    begin
      lSelector := aFacts.NodeById(aCallee.ParentId);
      if (lSelector.SyntaxKind = 'dot') and (Length(lSelector.Children) = 2) then
        lReceiver := aFacts.NodeById(lSelector.Children[0]);
    end;
    lReceiverName := SnapshotNameFlowDottedName(aFacts, lReceiver, 0);
    // DelphiAST nests a namespaced qualifier to the right: Easy.(TableFunctions.GetField).
    // Keep the entire unit namespace rather than rebinding its last component.
    if (lReceiver.Id <> 0) and (lReceiverName <> '') then
      for lDepth := 0 to 15 do
      begin
        if lSelector.ParentId = 0 then
          Break;
        lAncestor := aFacts.NodeById(lSelector.ParentId);
        if (lAncestor.SyntaxKind <> 'dot') or (Length(lAncestor.Children) <> 2) or
          (lAncestor.Children[1] <> lSelector.Id) then
          Break;
        lQualifier := SnapshotNameFlowDottedName(aFacts, aFacts.NodeById(lAncestor.Children[0]), 0);
        if lQualifier = '' then
          Exit;
        lReceiverName := lQualifier + '.' + lReceiverName;
        lSelector := lAncestor;
      end;
    if (lReceiver.Id <> 0) and (lSelector.ParentId > 0) then
    begin
      lAncestor := aFacts.NodeById(lSelector.ParentId);
      if (lAncestor.SyntaxKind = 'dot') and (Length(lAncestor.Children) = 2) and
        (lAncestor.Children[1] = lSelector.Id) then
        Exit; // The namespace exceeded the bound; a suffix is not a binding.
    end;
    if ((lReceiver.Id <> 0) and (lReceiverName = '')) or
      (SameText(lReceiverName, 'Self') and (lOwner = '')) then
      Exit;
    lFirst := Copy(lReceiverName, 1, Pos('.', lReceiverName + '.') - 1);
    // A nearer declaration omitted by a lean symbol model must never expose a
    // unit qualifier or an outer routine family. WITH was excluded above.
    for lIndex := 1 to aFacts.NodeCount do
    begin
      lDefinition := aFacts.NodeById(lIndex);
      if (lDefinition.Kind in [TDelphiNameFlowNodeKind.Definition, TDelphiNameFlowNodeKind.Formal]) and
        (lDefinition.ScopeId <> '') and
        StartsText(lDefinition.ScopeId, aCallee.ScopeId) and
        (SameText(lDefinition.Name, aCallee.Name) or
          ((lFirst <> '') and SameText(lDefinition.Name, lFirst))) then
        Exit;
    end;
    lTargetUnit := aSourceUnit;
    lQualifier := '';
    if (lReceiverName <> '') and not SameText(lReceiverName, 'Self') then
    begin
      // An imported, fully qualified project unit is a declaration namespace.
      // Reject any project declaration that could shadow its first component.
      for lIndex := 0 to aSnapshot.UnitCount - 1 do
      begin
        lCandidateUnit := aSnapshot.UnitByIndex(lIndex);
        if not SameText(aSnapshot.TextOf(lCandidateUnit.UnitNameId), lReceiverName) then
          Continue;
        lVisible := lCandidateUnit = aSourceUnit;
        for lImport in aSourceUnit.ImportFacts do
          if ((lImport.OwnerFileName = '') or SameText(lImport.OwnerFileName,
            aSnapshot.TextOf(aSourceUnit.FileNameId))) and SameText(lImport.Name, lReceiverName) and not lImport.SdkBoundary and
            (lImport.Cause = '') and not lImport.ResolutionVaries then
            lVisible := True;
        if lVisible then
        begin
          lTargetUnit := lCandidateUnit;
          lQualifier := lReceiverName;
          lOwner := '';
          Break;
        end;
      end;
      if lQualifier <> '' then
      begin
        // A unit-level declaration in an unrelated unit cannot shadow this
        // namespace. Keep imported declarations and possible inherited/helper
        // members conservative until a more precise owner binding is available.
        for lIndex := 0 to aSnapshot.UnitCount - 1 do
        begin
          lCandidateUnit := aSnapshot.UnitByIndex(lIndex);
          lUnitName := aSnapshot.TextOf(lCandidateUnit.UnitNameId);
          lVisible := lCandidateUnit = aSourceUnit;
          for lImport in aSourceUnit.ImportFacts do
            if ((lImport.OwnerFileName = '') or SameText(lImport.OwnerFileName,
            aSnapshot.TextOf(aSourceUnit.FileNameId))) and SameText(lImport.Name, lUnitName) then
              lVisible := True;
          for lChildId := 1 to lCandidateUnit.SymbolCount do
          begin
            lSymbol := lCandidateUnit.SymbolById(lChildId);
            if SameText(aSnapshot.TextOf(lSymbol.NameId), lFirst) and
              (lVisible or (aSnapshot.TextOf(lSymbol.OwnerTypeId) <> '')) then
              Exit;
          end;
        end;
      end else begin
        if (Pos('.', lReceiverName) > 0) or (lReceiver.SyntaxKind <> 'identifier') then
          Exit;
        lReceiverSymbol := Default(TSemanticSymbolFact);
        if TryResolveSnapshotPosition(aSnapshot, lReceiver.FileName, lReceiver.Line,
          lReceiver.Column, lReceiver.Name, lReceiverResolution) and lReceiverResolution.ReferenceFound then
        begin
          // A foreign declaration's type has its own import/alias scope. This
          // bounded fallback does not reinterpret it in the caller's unit.
          if lReceiverResolution.SymbolUnit <> aSourceUnit then
            Exit;
          lReceiverSymbol := lReceiverResolution.Symbol;
        end else begin
          lMatches := 0;
          for lIndex := 1 to aSourceUnit.SymbolCount do
          begin
            lSymbol := aSourceUnit.SymbolById(lIndex);
            if SameText(aSnapshot.TextOf(lSymbol.NameId), lReceiverName) and
              SameText(aSnapshot.TextOf(lSymbol.KindId), 'field') and
              (lOwner <> '') and SameText(aSnapshot.TextOf(lSymbol.OwnerTypeId), lOwner) then
            begin
              Inc(lMatches);
              lReceiverSymbol := lSymbol;
            end;
          end;
          if lMatches <> 1 then
            Exit;
        end;
        if lReceiverSymbol.FileId <> 0 then
          Exit;
        lTypeName := aSnapshot.TextOf(lReceiverSymbol.TypeId);
        lExternalTypeUnits := nil;
        for lImport in aSourceUnit.ImportFacts do
          if lImport.SdkBoundary then
            lExternalTypeUnits := lExternalTypeUnits + [lImport.Name];
        lRefs := SnapshotVisibleDeclarations(aSnapshot, aSourceUnit, lTypeName,
          aSnapshot.TextOf(lReceiverSymbol.RoutineScopeId),
          aSnapshot.TextOf(lReceiverSymbol.OwnerTypeId),
          aSnapshot.TextOf(lReceiverSymbol.SectionKindId),
          lReceiverSymbol.Line, lReceiverSymbol.Column, lExternalTypeUnits,
          lComplete, aFacts, aSnapshot.TextOf(lReceiverSymbol.FileId));
        if not lComplete or (Length(lRefs) <> 1) or
          not aSnapshot.TryFindUnitById(lRefs[0].UnitId, lTargetUnit) then
          Exit;
        lSymbol := lTargetUnit.SymbolById(lRefs[0].SymbolId);
        if not SameText(aSnapshot.TextOf(lSymbol.KindId), 'type') or
          not SameText(aSnapshot.TextOf(lSymbol.TypeId), 'class') then
          Exit;
        lOwner := aSnapshot.TextOf(lSymbol.NameId);
      end;
    end;
    if not SameText(aSnapshot.TextOf(lTargetUnit.ScopeModelStatusId), 'ast') then
      Exit;
    if lOwner <> '' then
    begin
      // The family join currently supports root project classes only. An
      // inherited overload from an SDK class must remain a consumer candidate.
      lTargetFacts := NameFlowFactsFromJson(aSnapshot.ExactTextOf(lTargetUnit.NameFlowFactsJsonId));
      lRootClass := False;
      lMatches := 0;
      for lIndex := 1 to lTargetFacts.NodeCount do
      begin
        lDefinition := lTargetFacts.NodeById(lIndex);
        if (lDefinition.SyntaxKind <> 'typedecl') or (lDefinition.ScopeId <> '') or
          not SameText(lDefinition.Name, lOwner) then
          Continue;
        Inc(lMatches);
        for lChildId in lDefinition.Children do
        begin
          lClass := lTargetFacts.NodeById(lChildId);
          if (lClass.SyntaxKind <> 'type') or not SameText(lClass.TypeName, 'class') then
            Continue;
          lRootClass := True;
          for lDepth in lClass.Children do
          begin
            lChild := lTargetFacts.NodeById(lDepth);
            if lChild.SyntaxKind = 'type' then
              lRootClass := False;
          end;
        end;
      end;
      if not lRootClass or (lMatches <> 1) then
        Exit;
    end;
    lFamilies := 0;
    lSignature := '';
    for lIndex := 1 to lTargetUnit.SymbolCount do
    begin
      lSymbol := lTargetUnit.SymbolById(lIndex);
      if not SameText(aSnapshot.TextOf(lSymbol.NameId), aCallee.Name) or
        not SameText(aSnapshot.TextOf(lSymbol.OwnerTypeId), lOwner) then
        Continue;
      // A nested routine in some other body is not a unit-level candidate.
      if ContainsText(aSnapshot.TextOf(lSymbol.RoutineScopeId), '/') then
        Continue;
      if not MatchText(aSnapshot.TextOf(lSymbol.KindId), ['routine', 'method']) or
        (lSymbol.FileId <> 0) then
        Exit;
      if (lSignature <> '') and not SameText(lSignature, aSnapshot.TextOf(lSymbol.SignatureId)) and
        not SnapshotUniqueProjectOverload(aSnapshot, aSourceUnit, lTargetUnit, aCallee, aFacts, lOwner) then
        Exit; // Ambiguous/unknown argument binding cannot prove exemption.
      lSignature := aSnapshot.TextOf(lSymbol.SignatureId);
      Inc(lFamilies);
    end;
    if (lFamilies > 0) and (lOwner = '') then
    begin
      lTypeName := aCallee.Name;
      if lQualifier <> '' then
        lTypeName := lQualifier + '.' + lTypeName;
      lRefs := SnapshotVisibleDeclarations(aSnapshot, aSourceUnit, lTypeName, aCallee.ScopeId,
        '', 'implementation', aCallee.Line, aCallee.Column,
        aCatalogOwners, lComplete);
      if not lComplete or (Length(lRefs) = 0) then
        Exit;
      // A later own-unit routine cannot certify a nearer imported variable
      // or a different routine family. Close the actual visible candidate set.
      for var lRef in lRefs do
      begin
        if lRef.UnitId <> lTargetUnit.UnitId then
          Exit;
        if not MatchText(aSnapshot.TextOf(lTargetUnit.SymbolById(lRef.SymbolId).KindId),
          ['routine', 'method']) then
          Exit;
      end;
      if (Length(lRefs) > 1) and not SnapshotUniqueProjectOverload(aSnapshot,
        aSourceUnit, lTargetUnit, aCallee, aFacts, lOwner) then
        Exit;
    end;
    Result := lFamilies > 0;
  end;


end.
