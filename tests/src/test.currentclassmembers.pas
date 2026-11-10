unit Test.CurrentClassMembers;

interface

uses
  DelphiSemantics.Model;

// One extraction feeds the independent eager oracle and compact implementation.
procedure AssertCurrentClassInventoryEqual(const aModels: TArray<TDelphiSemanticUnitModel>;
  const aRecordLimit: Integer; out aQueryCount, aProjectionCount: Int64;
  const aOracleProvider: Integer = -1);

function CompactInventoryAdmissionPeak(const aModels: TArray<TDelphiSemanticUnitModel>): Integer;

implementation

uses
  System.Classes, System.Generics.Collections, System.Generics.Defaults, System.IOUtils, System.StrUtils, System.SysUtils,
  DUnitX.TestFramework,
  MaxLogic.StrUtils,
  DelphiSemantics.Model.Json, DelphiSemantics.Snapshot, DelphiSemantics.Snapshot.Builder,
  DelphiSemantics.Snapshot.RemoveWith, DelphiSemantics.WithBinding, DelphiSemantics.WithBinding.Budget,
  DelphiSemantics.WithBinding.Inventory,
  Test.Support;

type
  [TestFixture]
  TCurrentClassMemberTests = class
  public
    [Test]
    [Category('Fast')]
    procedure GeneratedRulesMatchIndependentOracle;
    [Test]
    [Category('Fast')]
    procedure NonAsciiRoutineCasesUseIndependentAsciiPredicate;
    [Test]
    procedure GeneratedCartesianStressMatchesIndependentOracle;
    [Test]
    procedure GeneratedDeepInheritanceMatchesIndependentOracle;
    [Test]
    procedure FixtureInventoriesMatchIndependentOracle;
    [Test]
    procedure ManifestInventoriesMatchIndependentOracle;
    [Test]
    [Category('Fast')]
    procedure CompactLookupRequiresValidatedModelsAndReturnsIndependentCopies;
    [Test]
    [Category('Fast')]
    procedure CompactSnapshotFallbackRehydratesVirtualLookup;
    [TestCase('Combined rebuild', 'False')]
    [TestCase('SQLite rebuild', 'True')]
    procedure CompactReplayHonorsExplicitRecordLimit(const aRebuild: Boolean);
  end;

function EqualInventorySymbol(const aLeft, aRight: TDelphiSemanticInventorySymbol): Boolean;
begin
  Result := (aLeft.Name = aRight.Name) and
    (aLeft.SymbolClass = aRight.SymbolClass) and
    (aLeft.Kind = aRight.Kind) and
    (aLeft.TypeName = aRight.TypeName) and
    (aLeft.Modifier = aRight.Modifier) and
    (aLeft.OwnerName = aRight.OwnerName) and
    (aLeft.OwnerType = aRight.OwnerType) and
    (aLeft.SourceOwnerType = aRight.SourceOwnerType) and
    (aLeft.RelatedTypeName = aRight.RelatedTypeName) and
    (aLeft.RoutineName = aRight.RoutineName) and
    (aLeft.RoutineScopeId = aRight.RoutineScopeId) and
    (aLeft.ParentScopeId = aRight.ParentScopeId) and
    (aLeft.OwnerScopeId = aRight.OwnerScopeId) and
    (aLeft.OwnerSymbolId = aRight.OwnerSymbolId) and
    (aLeft.UnitName = aRight.UnitName) and
    (aLeft.FileName = aRight.FileName) and
    (aLeft.SectionKind = aRight.SectionKind) and
    (aLeft.Line = aRight.Line) and
    (aLeft.Column = aRight.Column) and
    (aLeft.EndLine = aRight.EndLine) and
    (aLeft.EndColumn = aRight.EndColumn) and
    (aLeft.UnsupportedReason = aRight.UnsupportedReason) and
    (aLeft.IsHelper = aRight.IsHelper) and
    (aLeft.IsOverride = aRight.IsOverride) and
    (aLeft.IsDefault = aRight.IsDefault) and
    (aLeft.IsIndexed = aRight.IsIndexed) and
    (aLeft.IndexParameterCount = aRight.IndexParameterCount) and
    (aLeft.TypeCategory = aRight.TypeCategory) and
    (aLeft.OwnerIdentity.Synthetic = aRight.OwnerIdentity.Synthetic) and
    (aLeft.OwnerIdentity.MembersClosed = aRight.OwnerIdentity.MembersClosed) and
    (aLeft.OwnerIdentity.EnclosingTypeId.Value = aRight.OwnerIdentity.EnclosingTypeId.Value) and
    (aLeft.OwnerIdentity.UnitId.Value = aRight.OwnerIdentity.UnitId.Value) and
    (aLeft.OwnerIdentity.UnitName = aRight.OwnerIdentity.UnitName) and
    (aLeft.OwnerIdentity.Name = aRight.OwnerIdentity.Name) and
    (aLeft.OwnerIdentity.Kind = aRight.OwnerIdentity.Kind) and
    (aLeft.OwnerIdentity.DeclaredId.Value = aRight.OwnerIdentity.DeclaredId.Value) and
    (aLeft.OwnerIdentity.CanonicalId.Value = aRight.OwnerIdentity.CanonicalId.Value) and
    (aLeft.OwnerIdentity.UnderlyingId.Value = aRight.OwnerIdentity.UnderlyingId.Value) and
    (aLeft.OwnerIdentity.CanonicalName = aRight.OwnerIdentity.CanonicalName) and
    (aLeft.OwnerIdentity.UnderlyingName = aRight.OwnerIdentity.UnderlyingName) and
    (aLeft.OwnerIdentity.BaseTypeName = aRight.OwnerIdentity.BaseTypeName) and
    (aLeft.OwnerIdentity.HelperTargetName = aRight.OwnerIdentity.HelperTargetName) and
    (aLeft.OwnerIdentity.HelperParentName = aRight.OwnerIdentity.HelperParentName) and
    (aLeft.OwnerIdentity.SectionKind = aRight.OwnerIdentity.SectionKind) and
    (aLeft.OwnerIdentity.ScopeKind = aRight.OwnerIdentity.ScopeKind) and
    (aLeft.OwnerIdentity.OwnerScopeId = aRight.OwnerIdentity.OwnerScopeId) and
    (aLeft.OwnerIdentity.SemanticSymbolId = aRight.OwnerIdentity.SemanticSymbolId) and
    (aLeft.OwnerIdentity.SourceRange.FileName = aRight.OwnerIdentity.SourceRange.FileName) and
    (aLeft.OwnerIdentity.SourceRange.Line = aRight.OwnerIdentity.SourceRange.Line) and
    (aLeft.OwnerIdentity.SourceRange.Column = aRight.OwnerIdentity.SourceRange.Column) and
    (aLeft.OwnerIdentity.SourceRange.EndLine = aRight.OwnerIdentity.SourceRange.EndLine) and
    (aLeft.OwnerIdentity.SourceRange.EndColumn = aRight.OwnerIdentity.SourceRange.EndColumn) and
    (aLeft.OwnerIdentity.SourceRange.Offset = aRight.OwnerIdentity.SourceRange.Offset) and
    (aLeft.OwnerIdentity.SourceRange.EndOffset = aRight.OwnerIdentity.SourceRange.EndOffset) and
    (aLeft.AccessOwnerIdentity.Synthetic = aRight.AccessOwnerIdentity.Synthetic) and
    (aLeft.AccessOwnerIdentity.MembersClosed = aRight.AccessOwnerIdentity.MembersClosed) and
    (aLeft.AccessOwnerIdentity.EnclosingTypeId.Value = aRight.AccessOwnerIdentity.EnclosingTypeId.Value) and
    (aLeft.AccessOwnerIdentity.UnitId.Value = aRight.AccessOwnerIdentity.UnitId.Value) and
    (aLeft.AccessOwnerIdentity.UnitName = aRight.AccessOwnerIdentity.UnitName) and
    (aLeft.AccessOwnerIdentity.Name = aRight.AccessOwnerIdentity.Name) and
    (aLeft.AccessOwnerIdentity.Kind = aRight.AccessOwnerIdentity.Kind) and
    (aLeft.AccessOwnerIdentity.DeclaredId.Value = aRight.AccessOwnerIdentity.DeclaredId.Value) and
    (aLeft.AccessOwnerIdentity.CanonicalId.Value = aRight.AccessOwnerIdentity.CanonicalId.Value) and
    (aLeft.AccessOwnerIdentity.UnderlyingId.Value = aRight.AccessOwnerIdentity.UnderlyingId.Value) and
    (aLeft.AccessOwnerIdentity.CanonicalName = aRight.AccessOwnerIdentity.CanonicalName) and
    (aLeft.AccessOwnerIdentity.UnderlyingName = aRight.AccessOwnerIdentity.UnderlyingName) and
    (aLeft.AccessOwnerIdentity.BaseTypeName = aRight.AccessOwnerIdentity.BaseTypeName) and
    (aLeft.AccessOwnerIdentity.HelperTargetName = aRight.AccessOwnerIdentity.HelperTargetName) and
    (aLeft.AccessOwnerIdentity.HelperParentName = aRight.AccessOwnerIdentity.HelperParentName) and
    (aLeft.AccessOwnerIdentity.SectionKind = aRight.AccessOwnerIdentity.SectionKind) and
    (aLeft.AccessOwnerIdentity.ScopeKind = aRight.AccessOwnerIdentity.ScopeKind) and
    (aLeft.AccessOwnerIdentity.OwnerScopeId = aRight.AccessOwnerIdentity.OwnerScopeId) and
    (aLeft.AccessOwnerIdentity.SemanticSymbolId = aRight.AccessOwnerIdentity.SemanticSymbolId) and
    (aLeft.AccessOwnerIdentity.SourceRange.FileName = aRight.AccessOwnerIdentity.SourceRange.FileName) and
    (aLeft.AccessOwnerIdentity.SourceRange.Line = aRight.AccessOwnerIdentity.SourceRange.Line) and
    (aLeft.AccessOwnerIdentity.SourceRange.Column = aRight.AccessOwnerIdentity.SourceRange.Column) and
    (aLeft.AccessOwnerIdentity.SourceRange.EndLine = aRight.AccessOwnerIdentity.SourceRange.EndLine) and
    (aLeft.AccessOwnerIdentity.SourceRange.EndColumn = aRight.AccessOwnerIdentity.SourceRange.EndColumn) and
    (aLeft.AccessOwnerIdentity.SourceRange.Offset = aRight.AccessOwnerIdentity.SourceRange.Offset) and
    (aLeft.AccessOwnerIdentity.SourceRange.EndOffset = aRight.AccessOwnerIdentity.SourceRange.EndOffset) and
    (aLeft.AccessOwnerUnitName = aRight.AccessOwnerUnitName) and
    (aLeft.AccessOwnerFileName = aRight.AccessOwnerFileName) and
    (aLeft.AccessOwnerSectionKind = aRight.AccessOwnerSectionKind) and
    (aLeft.AccessOwnerLine = aRight.AccessOwnerLine) and
    (aLeft.AccessOwnerColumn = aRight.AccessOwnerColumn) and
    (aLeft.HeadingLine = aRight.HeadingLine) and
    (aLeft.HeadingColumn = aRight.HeadingColumn) and
    (aLeft.HeadingEndLine = aRight.HeadingEndLine) and
    (aLeft.HeadingEndColumn = aRight.HeadingEndColumn);
end;

procedure AssertSymbolsEqual(const aExpected, aActual: TArray<TDelphiSemanticInventorySymbol>;
  const aContext: string);
var
  i: Integer;
begin
  Assert.AreEqual(Length(aExpected), Length(aActual), aContext + ' count');
  for i := 0 to High(aExpected) do
    if not EqualInventorySymbol(aExpected[i], aActual[i]) then
      Assert.Fail(Format('%s ordinal %d: %s/%s/%s/%s line %d differs from %s/%s/%s/%s line %d',
        [aContext, i, aExpected[i].UnitName, aExpected[i].OwnerType, aExpected[i].RoutineName,
        aExpected[i].Name, aExpected[i].Line, aActual[i].UnitName, aActual[i].OwnerType,
        aActual[i].RoutineName, aActual[i].Name, aActual[i].Line]));
end;

function AsciiCaseKey(const aValue: string): string;
var
  i: Integer;
begin
  // Independent legacy SameText key. Do not reuse the production Unicode comparer.
  Result := aValue;
  for i := 1 to Length(Result) do
    if CharInSet(Result[i], ['a'..'z']) then
      Result[i] := Char(Ord(Result[i]) - Ord('a') + Ord('A'));
end;


procedure AssertCurrentClassInventoryEqual(const aModels: TArray<TDelphiSemanticUnitModel>;
  const aRecordLimit: Integer; out aQueryCount, aProjectionCount: Int64;
  const aOracleProvider: Integer);
var
  i, lCursor, lOrdinal, lModelOrdinal: Integer;
  lCompact, lLegacy, lNonProjected: TArray<TDelphiSemanticInventorySymbol>;
  lExpected: TArray<TDelphiSemanticInventorySymbol>;
  lLegacyList, lCompactList, lExpectedList: TList<TDelphiSemanticInventorySymbol>;
  lByName, lByRoutineAndName: TObjectDictionary<string, TList<Integer>>;
  lPair, lRoutinePair: TPair<string, TList<Integer>>;
  lModel: TDelphiSemanticUnitModel;
  lSymbol: TDelphiSemanticInventorySymbol;
  lIndex: TDelphiSemanticCurrentClassMemberIndex;
  lLookup, lLegacyLookup: TDelphiSemanticRemoveWithLookupIndex;
  lName, lRoutineName: string;
  lOldFound, lNewFound: Boolean;
  lOldSymbol, lNewSymbol: TDelphiSemanticInventorySymbol;


  function ProviderRecords(const aRecords: TArray<TDelphiSemanticInventorySymbol>):
    TArray<TDelphiSemanticInventorySymbol>;
  var
    lItems: TList<TDelphiSemanticInventorySymbol>;
    lRecord: TDelphiSemanticInventorySymbol;
  begin
    if aOracleProvider < 0 then
      Exit(aRecords);
    lItems := TList<TDelphiSemanticInventorySymbol>.Create;
    try
      for lRecord in aRecords do
        if SameText(lRecord.UnitName, aModels[aOracleProvider].UnitName) and
          SameText(lRecord.FileName, aModels[aOracleProvider].FileName) then
          lItems.Add(lRecord);
      Result := lItems.ToArray;
    finally
      lItems.Free;
    end;
  end;

  function RoutineProviderRecords(const aRecords: TArray<TDelphiSemanticInventorySymbol>;
    const aRoutineName: string): TArray<TDelphiSemanticInventorySymbol>;
  var
    lItems: TList<TDelphiSemanticInventorySymbol>;
    lRecord: TDelphiSemanticInventorySymbol;
  begin
    lItems := TList<TDelphiSemanticInventorySymbol>.Create;
    try
      // DAK consumers retain this legacy post-filter over the broader DS buckets.
      for lRecord in ProviderRecords(aRecords) do
        if SameText(lRecord.RoutineName, aRoutineName) then
          lItems.Add(lRecord);
      Result := lItems.ToArray;
    finally
      lItems.Free;
    end;
  end;

  procedure AddOrdinal(const aMap: TObjectDictionary<string, TList<Integer>>;
    const aKey: string; const aOrdinal: Integer);
  var
    lItems: TList<Integer>;
  begin
    if not aMap.TryGetValue(aKey, lItems) then
    begin
      lItems := TList<Integer>.Create;
      aMap.Add(aKey, lItems);
    end;
    lItems.Add(aOrdinal);
  end;

  function RecordsAt(const aOrdinals: TList<Integer>): TArray<TDelphiSemanticInventorySymbol>;
  var
    i: Integer;
  begin
    SetLength(Result, aOrdinals.Count);
    for i := 0 to aOrdinals.Count - 1 do
      Result[i] := lLegacy[aOrdinals[i]];
  end;

begin
  aQueryCount := 0;
  aProjectionCount := 0;
  lLegacyList := TList<TDelphiSemanticInventorySymbol>.Create;
  lCompactList := TList<TDelphiSemanticInventorySymbol>.Create;
  lExpectedList := TList<TDelphiSemanticInventorySymbol>.Create;
  lByName := TObjectDictionary<string, TList<Integer>>.Create([doOwnsValues], TFastCaseAwareComparer.OrdinalIgnoreCase);
  lByRoutineAndName := TObjectDictionary<string, TList<Integer>>.Create([doOwnsValues], TStringComparer.Ordinal);
  lIndex := TDelphiSemanticCurrentClassMemberIndex.Create;
  try
    for lModelOrdinal := 0 to High(aModels) do
    begin
      lModel := aModels[lModelOrdinal];
      // The bounded oracle retains the full project's direct/expanded member
      // universe. Only unrelated providers' Cartesian projections are absent;
      // those cannot enter another provider's unit/file-keyed expansion view.
      if (aOracleProvider < 0) or (aOracleProvider = lModelOrdinal) then
        lLegacyList.AddRange(TDelphiSemanticWithBindingInventory.BuildInventorySymbols(
          lModel, aRecordLimit, lLegacyList.Count))
      else
        lLegacyList.AddRange(TDelphiSemanticWithBindingInventory.BuildCompactInventorySymbols(
          lModel, aRecordLimit, lLegacyList.Count));
      lCompactList.AddRange(TDelphiSemanticWithBindingInventory.BuildCompactInventorySymbols(
        lModel, aRecordLimit, lCompactList.Count, lIndex));
    end;
    TDelphiSemanticWithBindingInventory.AddCompilerProfileCompatibilitySymbols(lLegacyList);
    TDelphiSemanticWithBindingInventory.AddCompilerProfileCompatibilitySymbols(lCompactList);
    TDelphiSemanticWithBindingInventory.AddProjectExternalUnitSymbols(aModels, lLegacyList);
    TDelphiSemanticWithBindingInventory.AddProjectExternalUnitSymbols(aModels, lCompactList);
    lLegacy := lLegacyList.ToArray;
    lLegacyList.Clear;
    lLegacyList.Capacity := 0;
    lCompact := lCompactList.ToArray;
    lCompactList.Clear;
    lCompactList.Capacity := 0;
    lLegacy := TDelphiSemanticWithBindingInventory.ExpandInventorySymbols(lLegacy, aRecordLimit);
    lCompact := TDelphiSemanticWithBindingInventory.ExpandCompactInventorySymbols(lCompact, aRecordLimit);
    lIndex.Complete(lCompact);
    for i := 0 to High(lLegacy) do
    begin
      lSymbol := lLegacy[i];
      if SameText(lSymbol.SymbolClass, 'current-class-member') then
      begin
        Inc(aProjectionCount);
        AddOrdinal(lByName, lSymbol.Name, i);
      end else
        lExpectedList.Add(lSymbol);
    end;
    lNonProjected := lExpectedList.ToArray;
    AssertSymbolsEqual(lNonProjected, lCompact, 'stored non-projection stream');
    // Do not build ordinary indexes over millions of obsolete projections.
    // Their unchanged non-P buckets are independently checked above.
    lLegacyLookup := TDelphiSemanticRemoveWithLookupIndex.Build(aModels, lNonProjected);
    lLookup := TDelphiSemanticRemoveWithLookupIndex.BuildCompact(aModels, lCompact);
    for lPair in lByName do
    begin
      lByRoutineAndName.Clear;
      for lOrdinal in lPair.Value do
      begin
        lSymbol := lLegacy[lOrdinal];
        AddOrdinal(lByRoutineAndName, AsciiCaseKey(lSymbol.RoutineName + #31 + lSymbol.Name), lOrdinal);
      end;
      for lRoutinePair in lByRoutineAndName do
      begin
        lCursor := Pos(#31, lRoutinePair.Key);
        lRoutineName := Copy(lRoutinePair.Key, 1, lCursor - 1);
        lName := Copy(lRoutinePair.Key, lCursor + 1, MaxInt);
        lExpected := RecordsAt(lRoutinePair.Value);
        AssertSymbolsEqual(lExpected, RoutineProviderRecords(lIndex.FindCurrentClassMembers(lRoutineName, lName), lRoutineName), lRoutinePair.Key);
        AssertSymbolsEqual(lExpected, RoutineProviderRecords(lLookup.FindCurrentClassMembers(lRoutineName, lName), lRoutineName), 'rehydrated ' + lRoutinePair.Key);
        AssertSymbolsEqual(lExpected, RoutineProviderRecords(lIndex.FindCurrentClassMembers(LowerCase(lRoutineName), UpperCase(lName)), LowerCase(lRoutineName)), 'case ' + lRoutinePair.Key);
        lOldFound := lLegacyLookup.FindRoutineSymbol(lRoutineName, lName, lOldSymbol);
        lNewFound := lLookup.FindRoutineSymbol(lRoutineName, lName, lNewSymbol);
        Assert.AreEqual(lOldFound, lNewFound, 'routine lookup found');
        if lOldFound then
          Assert.IsTrue(EqualInventorySymbol(lOldSymbol, lNewSymbol), 'routine lookup record');
        Inc(aQueryCount, 3);
      end;
      lExpected := RecordsAt(lPair.Value);
      AssertSymbolsEqual(lExpected, ProviderRecords(lIndex.FindCurrentClassMembersByName(lPair.Key)), 'location ' + lPair.Key);
      AssertSymbolsEqual(lExpected, ProviderRecords(lLookup.FindCurrentClassMembersByName(lPair.Key)), 'rehydrated location ' + lPair.Key);
      Assert.AreEqual<Integer>(0, Length(lIndex.FindCurrentClassMembers('__wrong_routine__', lPair.Key)), 'wrong routine');
      Inc(aQueryCount, 3);
    end;
    Assert.AreEqual<Integer>(0, Length(lIndex.FindCurrentClassMembers('', '__missing_member__')));
    Assert.AreEqual<Integer>(0, Length(lIndex.FindCurrentClassMembersByName('__missing_member__')));
    Inc(aQueryCount, 2);
  finally
    lIndex.Free;
    lByRoutineAndName.Free;
    lByName.Free;
    lExpectedList.Free;
    lCompactList.Free;
    lLegacyList.Free;
  end;
end;

function CompactInventoryAdmissionPeak(const aModels: TArray<TDelphiSemanticUnitModel>): Integer;
var
  lLow, lHigh, lMiddle: Integer;

  function Admitted(const aLimit: Integer): Boolean;
  var
    lModel: TDelphiSemanticUnitModel;
    lSymbols: TDelphiSemanticBudgetedInventoryList;
  begin
    Result := False;
    lSymbols := TDelphiSemanticBudgetedInventoryList.Create(aLimit);
    try
      try
        for lModel in aModels do
          lSymbols.AddRange(TDelphiSemanticWithBindingInventory.BuildCompactInventorySymbols(lModel,
            aLimit, lSymbols.Count));
        TDelphiSemanticWithBindingInventory.AddCompilerProfileCompatibilitySymbols(lSymbols);
        TDelphiSemanticWithBindingInventory.AddProjectExternalUnitSymbols(aModels, lSymbols);
        TDelphiSemanticWithBindingInventory.ExpandCompactInventorySymbols(lSymbols.ToArray, aLimit);
        Result := True;
      except
        on E: EDelphiSemanticWithInventoryBudget do
        begin
          // Refusal is the measured admission boundary, not an ignored failure.
          Assert.IsTrue(ContainsText(E.Message, 'total not measured'), E.Message);
        end;
      end;
    finally
      lSymbols.Free;
    end;
  end;

begin
  lLow := 1;
  lHigh := cDefaultWithInventoryRecordLimit;
  Assert.IsTrue(Admitted(lHigh), 'MaxTdb must remain below the default stored-record budget.');
  while lLow < lHigh do
  begin
    lMiddle := lLow + (lHigh - lLow) div 2;
    if Admitted(lMiddle) then
      lHigh := lMiddle
    else
      lLow := lMiddle + 1;
  end;
  Result := lLow;
  Assert.IsTrue(Admitted(Result));
  Assert.IsFalse(Admitted(Result - 1));
end;

function ScannerModel(const aUnitName, aSource: string): TDelphiSemanticUnitModel;
begin
  Result := Default(TDelphiSemanticUnitModel);
  Result.Success := True;
  Result.UnitName := aUnitName;
  Result.FileName := aUnitName + '.pas';
  Result.SourceText := aSource;
end;

procedure TCurrentClassMemberTests.NonAsciiRoutineCasesUseIndependentAsciiPredicate;
var
  lModels: TArray<TDelphiSemanticUnitModel>;
  lRoutine: string;
  lQueries, lRecords: Int64;
  i: Integer;
begin
  SetLength(lModels, 2);
  for i := 0 to 1 do
  begin
    if i = 0 then
      lRoutine := #$00C4 + 'ndern'
    else
      lRoutine := #$00E4 + 'ndern';
    lModels[i] := ScannerModel('Unicode' + IntToStr(i), string.Join(sLineBreak,
      ['unit Unicode' + IntToStr(i) + ';', 'interface', 'type', '  TForm1 = class',
      '    lWithFoo: Integer;', '    procedure ' + lRoutine + ';', '  end;',
      'implementation', 'procedure TForm1.' + lRoutine + ';', 'begin', 'end;', 'end.']));
  end;
  Assert.IsFalse(SameText(#$00C4, #$00E4));
  AssertCurrentClassInventoryEqual(lModels, 1000000, lQueries, lRecords);
  Assert.IsTrue(AsciiCaseKey('TForm1.' + #$00C4 + 'ndern') <>
    AsciiCaseKey('TForm1.' + #$00E4 + 'ndern'), 'The oracle must not merge non-ASCII case variants.');
  Assert.IsTrue(lRecords >= 2);
  Assert.IsTrue(lQueries >= 11, 'Both non-ASCII routine variants must be queried independently.');
end;

procedure TCurrentClassMemberTests.GeneratedRulesMatchIndependentOracle;
var
  lModels: TArray<TDelphiSemanticUnitModel>;
  lSource: string;
  lQueries, lRecords: Int64;
begin
  lSource := string.Join(sLineBreak, ['unit A;', 'interface', 'type',
    '  TBase = class', '    BaseField: Integer;', '    Hidden: Integer;', '  end;',
    '  TDerived = class(TBase)', '    OwnField: string;', '    Hidden: string;',
    '    procedure Run;', '  end;',
    '  THelp = class helper for TDerived', '    procedure Help;', '  end;',
    '  TNoOwn = class(TBase)', '  end;',
    '  TOuter.TInner = class', '    Nested: Integer;', '  end;',
    'implementation', 'procedure TDerived.Run;', 'var', '  LocalValue: Integer;',
    'begin', 'end;', 'procedure TDerived.RUN;', 'begin', 'end;',
    'procedure TNoOwn.Run;', 'begin', 'end;',
    'procedure TOuter.TInner.Run;', 'begin', 'end;',
    'procedure TDerived<T>.Generic;', 'begin', 'end;', 'end.']);
  SetLength(lModels, 3);
  lModels[0] := ScannerModel('A', lSource);
  lModels[1] := ScannerModel('B', StringReplace(lSource, 'OwnField', 'OtherUnitField', [rfReplaceAll]));
  lModels[2] := ScannerModel('C', string.Join(sLineBreak, ['unit C;', 'interface', 'type',
    '  TDerived = class', '    OnlyZeroWithProvider: Integer;', '  end;', 'implementation',
    'procedure TDerived.Run;', 'begin', 'end;', 'end.']));
  AssertCurrentClassInventoryEqual(lModels, 1000000, lQueries, lRecords);
  Assert.IsTrue(lRecords > 0);
  Assert.IsTrue(lQueries > 20);
end;

procedure TCurrentClassMemberTests.GeneratedDeepInheritanceMatchesIndependentOracle;
var
  i, j: Integer;
  lSource: TStringBuilder;
  lQueries, lRecords: Int64;
begin
  lSource := TStringBuilder.Create;
  try
    lSource.AppendLine('unit DeepChain;').AppendLine('interface').AppendLine('type');
    for i := 0 to 49 do
    begin
      if i = 0 then
        lSource.AppendLine('  TLevel0 = class')
      else
        lSource.AppendLine(Format('  TLevel%d = class(TLevel%d)', [i, i - 1]));
      for j := 0 to 99 do
        lSource.AppendLine(Format('    Member%d_%d: Integer;', [i, j]));
      lSource.AppendLine('  end;');
    end;
    lSource.AppendLine('implementation');
    for i := 0 to 49 do
      lSource.AppendLine(Format('procedure TLevel%d.Run;', [i])).AppendLine('begin').AppendLine('end;');
    lSource.AppendLine('end.');
    AssertCurrentClassInventoryEqual([ScannerModel('DeepChain', lSource.ToString)],
      1000000, lQueries, lRecords);
    Assert.IsTrue(lRecords >= 127500, 'Every ancestor level remains represented.');
    System.Writeln(Format('[DS-805] deep L=50 m=100 queries=%d projections=%d', [lQueries, lRecords]));
  finally
    lSource.Free;
  end;
end;

procedure TCurrentClassMemberTests.GeneratedCartesianStressMatchesIndependentOracle;
const
  cMemberCount = 1000;
  cRoutineCount = 10000;
  cBatchSize = 250;
var
  i, j, lFirst: Integer;
  lHeader, lWhole: string;
  lSource: TStringBuilder;
  lModel: TDelphiSemanticUnitModel;
  lSymbols: TArray<TDelphiSemanticInventorySymbol>;
  lFullLookup, lBatchLookup: TDelphiSemanticRemoveWithLookupIndex;
  lMeasuredIndex: TDelphiSemanticCurrentClassMemberIndex;
  lBeforeQuery: Int64;
  lQueries, lRecords, lTotalQueries, lTotalRecords: Int64;
begin
  lSource := TStringBuilder.Create;
  try
    lSource.AppendLine('unit Cartesian;').AppendLine('interface').AppendLine('type').AppendLine('  TBig = class');
    for j := 0 to cMemberCount - 1 do
      lSource.AppendLine(Format('    Member%d: Integer;', [j]));
    lSource.AppendLine('  end;').AppendLine('implementation');
    lHeader := lSource.ToString;
    for i := 0 to cRoutineCount - 1 do
      lSource.AppendLine(Format('procedure TBig.Run%d;', [i])).AppendLine('begin').AppendLine('end;');
    lSource.AppendLine('end.');
    lWhole := lSource.ToString;
    lModel := ScannerModel('Cartesian', lWhole);
    lMeasuredIndex := TDelphiSemanticCurrentClassMemberIndex.Create;
    try
      lSymbols := TDelphiSemanticWithBindingInventory.BuildCompactInventorySymbols(lModel, 0, 0, lMeasuredIndex);
      lMeasuredIndex.Complete(lSymbols);
      Assert.AreEqual(Int64(2000), lMeasuredIndex.Metrics.StoredMemberCount, 'One own and one expanded backing view per member.');
      Assert.AreEqual(Int64(20000), lMeasuredIndex.Metrics.RoutineContextCount);
      lBeforeQuery := lMeasuredIndex.Metrics.VisitedContextCount;
      Assert.AreEqual<Integer>(1, Length(lMeasuredIndex.FindCurrentClassMembers('TBig.Run9999', 'Member999')));
      Assert.AreEqual(Int64(2), lMeasuredIndex.Metrics.VisitedContextCount - lBeforeQuery,
        'A routine/name query visits only its two indexed contexts.');
    finally
      lMeasuredIndex.Free;
    end;
    Assert.IsTrue(Length(lSymbols) < 12000, 'Compact storage must remain additive in members and routines.');
    lFullLookup := TDelphiSemanticRemoveWithLookupIndex.BuildCompact([lModel], lSymbols);
    lTotalQueries := 0;
    lTotalRecords := 0;
    lFirst := 0;
    while lFirst < cRoutineCount do
    begin
      lSource.Clear;
      lSource.Append(lHeader);
      for i := lFirst to lFirst + cBatchSize - 1 do
        lSource.AppendLine(Format('procedure TBig.Run%d;', [i])).AppendLine('begin').AppendLine('end;');
      lSource.AppendLine('end.');
      lModel := ScannerModel('Cartesian', lSource.ToString);
      // Stream bounded independent eager-oracle batches. The full compact index
      // above still contains all 10,000 contexts; declaration coordinates match
      // because the shared member header is byte-identical in every batch.
      AssertCurrentClassInventoryEqual([lModel], 1000000, lQueries, lRecords);
      lSymbols := TDelphiSemanticWithBindingInventory.BuildCompactInventorySymbols(lModel);
      lBatchLookup := TDelphiSemanticRemoveWithLookupIndex.BuildCompact([lModel], lSymbols);
      for i := lFirst to lFirst + cBatchSize - 1 do
        for j := 0 to cMemberCount - 1 do
          AssertSymbolsEqual(lBatchLookup.FindCurrentClassMembers('TBig.Run' + IntToStr(i), 'Member' + IntToStr(j)),
            lFullLookup.FindCurrentClassMembers('TBig.Run' + IntToStr(i), 'Member' + IntToStr(j)), 'full Cartesian context');
      Inc(lTotalQueries, lQueries);
      Inc(lTotalRecords, lRecords);
      Inc(lFirst, cBatchSize);
    end;
    Assert.AreEqual(Int64(cMemberCount) * cRoutineCount, lTotalRecords);
    System.Writeln(Format('[DS-805] Cartesian routines=%d members=%d oracleRecords=%d queries=%d',
      [cRoutineCount, cMemberCount, lTotalRecords, lTotalQueries]));
  finally
    lSource.Free;
  end;
end;

procedure TCurrentClassMemberTests.FixtureInventoriesMatchIndependentOracle;
var
  lFileName, lRoot: string;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lQueries, lRecords, lTotalQueries, lTotalRecords: Int64;
  lFiles: Integer;
begin
  lFiles := 0;
  lTotalQueries := 0;
  lTotalRecords := 0;
  for lRoot in [FixturePath(''), TPath.GetFullPath(TPath.Combine(RepoRoot, '..\DelphiAiKit\tests\fixtures'))] do
    for lFileName in TDirectory.GetFiles(lRoot, '*.pas', TSearchOption.soAllDirectories) do
    begin
      // External project snapshots have their own captured-model proof. Their
      // vendored libraries are not maintained synthetic fixture units.
      if ContainsText(lFileName, '\.dak\') or ContainsText(lFileName, '\.git\') or
        ContainsText(lFileName, '\test-projects\') then
        Continue;
      lOptions := Default(TDelphiSemanticModelOptions);
      lOptions.SourceFileName := lFileName;
      System.Writeln('[DS-805] fixture ', lFileName);
      Flush(Output);
      lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
      // Malformed parser fixtures still exercise the inventory's source scanner.
      AssertCurrentClassInventoryEqual([lModel], 10000000, lQueries, lRecords);
      Inc(lFiles);
      Inc(lTotalQueries, lQueries);
      Inc(lTotalRecords, lRecords);
    end;
  Assert.IsTrue(lFiles > 500, 'All maintained fixture files must be enumerated.');
  System.Writeln(Format('[DS-805] fixture files=%d queries=%d projections=%d', [lFiles, lTotalQueries, lTotalRecords]));
end;

procedure TCurrentClassMemberTests.ManifestInventoriesMatchIndependentOracle;
var
  lFileName, lManifest: string;
  lModels: TList<TDelphiSemanticUnitModel>;
  lOptions: TDelphiSemanticModelOptions;
  lQueries, lRecords, lTotalQueries, lTotalRecords: Int64;
  i, j: Integer;
begin
  lManifest := GetEnvironmentVariable('DELPHISEMANTICS_INVENTORY_PROOF_MANIFEST');
  lModels := TList<TDelphiSemanticUnitModel>.Create;
  try
    if lManifest = '' then
    begin
      lOptions := Default(TDelphiSemanticModelOptions);
      lOptions.SourceFileName := FixturePath('WithBinder', 'SourceModelGoldenUnit.pas');
      lModels.Add(TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions));
    end else begin
      for lFileName in TFile.ReadAllLines(lManifest) do
        if Trim(lFileName) <> '' then
          lModels.Add(JsonToUnitCacheModel(TFile.ReadAllText(lFileName, TEncoding.UTF8)));
    end;
    Assert.IsTrue(lModels.Count > 0);
    if SameText(GetEnvironmentVariable('DELPHISEMANTICS_INVENTORY_PROOF_PARTITIONED'), '1') then
    begin
      // Every provider is checked record by record against the complete compact
      // project. Distinct unit/file keys make the partitions disjoint. Small
      // generated collision fixtures separately compare the unpartitioned union.
      for i := 0 to lModels.Count - 1 do
        for j := i + 1 to lModels.Count - 1 do
          Assert.IsFalse(SameText(lModels[i].UnitName, lModels[j].UnitName) and
            SameText(lModels[i].FileName, lModels[j].FileName), 'Oracle partitions must be disjoint.');
      lTotalQueries := 0;
      lTotalRecords := 0;
      for i := 0 to lModels.Count - 1 do
      begin
        AssertCurrentClassInventoryEqual(lModels.ToArray, 50000000, lQueries, lRecords, i);
        Inc(lTotalQueries, lQueries);
        Inc(lTotalRecords, lRecords);
        System.Writeln(Format('[DS-805] provider=%d queries=%d projections=%d', [i, lQueries, lRecords]));
        Flush(Output);
      end;
      lQueries := lTotalQueries;
      lRecords := lTotalRecords;
    end else
      AssertCurrentClassInventoryEqual(lModels.ToArray, 50000000, lQueries, lRecords);
    System.Writeln(Format('[DS-805] manifest models=%d queries=%d projections=%d', [lModels.Count, lQueries, lRecords]));
    if SameText(GetEnvironmentVariable('DELPHISEMANTICS_INVENTORY_PROOF_BUDGET'), '1') then
      System.Writeln(Format('[DS-805] compact admission peak=%d', [CompactInventoryAdmissionPeak(lModels.ToArray)]));
  finally
    lModels.Free;
  end;
end;

procedure TCurrentClassMemberTests.CompactLookupRequiresValidatedModelsAndReturnsIndependentCopies;
var
  lLookup: TDelphiSemanticRemoveWithLookupIndex;
  lModel: TDelphiSemanticUnitModel;
  lSymbols, lMembers: TArray<TDelphiSemanticInventorySymbol>;
  lRefused: Boolean;
begin
  lModel := ScannerModel('Copies', string.Join(sLineBreak, ['unit Copies;', 'interface', 'type',
    '  TExample = class', '    Value: Integer;', '  end;', 'implementation',
    'procedure TExample.Run;', 'begin', 'end;', 'end.']));
  lSymbols := TDelphiSemanticWithBindingInventory.BuildCompactInventorySymbols(lModel);
  lLookup := TDelphiSemanticRemoveWithLookupIndex.BuildCompact([], lSymbols);
  lRefused := False;
  try
    lLookup.FindCurrentClassMembers('TExample.Run', 'Value');
  except
    on E: EInvalidOpException do
    begin
      lRefused := True;
      Assert.IsTrue(StartsText('CURRENT_CLASS_CONTEXT_UNAVAILABLE:', E.Message));
    end;
  end;
  Assert.IsTrue(lRefused, 'Missing validated models cannot prove member absence.');
  lLookup.RebuildCurrentClassMembers([lModel]);
  lMembers := lLookup.FindCurrentClassMembers('TExample.Run', 'Value');
  Assert.AreEqual<Integer>(1, Length(lMembers));
  lMembers[0].Name := 'Mutated';
  Assert.AreEqual('Value', lLookup.FindCurrentClassMembers('TExample.Run', 'Value')[0].Name);
  Assert.IsFalse(lLookup.FindRoutineSymbol('TExample.Run', 'Value', lSymbols[0]),
    'A virtual class member must never become a routine local.');
end;

procedure TCurrentClassMemberTests.CompactSnapshotFallbackRehydratesVirtualLookup;
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lMembers: TArray<TDelphiSemanticInventorySymbol>;
  lModel: TDelphiSemanticUnitModel;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lModel := ScannerModel('SnapshotFallback', string.Join(sLineBreak, ['unit SnapshotFallback;',
    'interface', 'type', '  TExample = class', '    Value: Integer;', '  end;', 'implementation',
    'procedure TExample.Run;', 'begin', 'end;', 'end.']));
  lFacts := Default(TDelphiSemanticProjectWithBindingFacts);
  lFacts.UnitModels := [lModel];
  lFacts.Symbols := TDelphiSemanticWithBindingInventory.BuildCompactInventorySymbols(lModel);
  Assert.IsFalse(lFacts.LookupIndex.IsAvailable);
  lSnapshot := BuildCompatibilityRemoveWithPlanningSnapshotFromFacts(lFacts);
  try
    lMembers := lSnapshot.RemoveWithPlanningFacts.LookupIndex.FindCurrentClassMembers('TExample.Run', 'Value');
    Assert.AreEqual<Integer>(1, Length(lMembers), 'A missing compact lookup must be rehydrated, not treated as no members.');
    Assert.AreEqual('SnapshotFallback', lMembers[0].UnitName);
  finally
    lSnapshot.Free;
  end;
end;

procedure TCurrentClassMemberTests.CompactReplayHonorsExplicitRecordLimit(const aRebuild: Boolean);
var
  lLookup: TDelphiSemanticRemoveWithLookupIndex;
  lModel: TDelphiSemanticUnitModel;
  lSymbols: TArray<TDelphiSemanticInventorySymbol>;
  lLimit: Integer;
  lRefused: Boolean;
begin
  lModel := ScannerModel('ReplayBudget', string.Join(sLineBreak, ['unit ReplayBudget;',
    'interface', 'type', '  TExample = class', '    Value: Integer;', '  end;',
    'implementation', 'procedure TExample.Run;', 'begin', 'end;', 'end.']));
  lSymbols := TDelphiSemanticWithBindingInventory.BuildCompactInventorySymbols(lModel);
  lLimit := Length(lSymbols) - 1;
  Assert.IsTrue(lLimit > 0);
  lLookup := TDelphiSemanticRemoveWithLookupIndex.BuildCompact([], lSymbols);
  lRefused := False;
  try
    if aRebuild then
      lLookup.RebuildCurrentClassMembers([lModel], lLimit)
    else
      lLookup := TDelphiSemanticRemoveWithLookupIndex.BuildCompact([lModel], lSymbols, lLimit);
  except
    on E: EDelphiSemanticWithInventoryBudget do
    begin
      lRefused := True;
      Assert.IsTrue(Pos('limit=' + IntToStr(lLimit) + ' records', E.Message) > 0, E.Message);
    end;
  end;
  Assert.IsTrue(lRefused, 'Replay must use the explicit per-unit limit instead of the default.');
  if aRebuild then
    lLookup.RebuildCurrentClassMembers([lModel], Length(lSymbols))
  else
    lLookup := TDelphiSemanticRemoveWithLookupIndex.BuildCompact([lModel], lSymbols, Length(lSymbols));
  Assert.AreEqual<Integer>(1, Length(lLookup.FindCurrentClassMembers('TExample.Run', 'Value')),
    'The exact explicit boundary remains admitted.');
end;

initialization
  TDUnitX.RegisterTestFixture(TCurrentClassMemberTests);

end.
