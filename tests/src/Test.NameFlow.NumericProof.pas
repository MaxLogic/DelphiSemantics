unit Test.NameFlow.NumericProof;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TNameFlowNumericProofTests = class
  public
    [TestCase('p01 include', 'p01,True,1')]
    [TestCase('p01 reference', 'p01,False,1')]
    [TestCase('p01b include', 'p01b,True,1')]
    [TestCase('p01b reference', 'p01b,False,1')]
    [TestCase('p02 include', 'p02,True,1')]
    [TestCase('p02 reference', 'p02,False,1')]
    [TestCase('p03 include', 'p03,True,1')]
    [TestCase('p03 reference', 'p03,False,1')]
    [TestCase('p14 include', 'p14,True,1')]
    [TestCase('p14 reference', 'p14,False,1')]
    [TestCase('p11 include', 'p11,True,2')]
    [TestCase('p11 reference', 'p11,False,2')]
    [TestCase('integer include', 'integer,True,0')]
    [TestCase('integer reference', 'integer,False,0')]
    [TestCase('string include', 'string,True,1')]
    [TestCase('string reference', 'string,False,1')]
    [TestCase('unknown include', 'unknown,True,1')]
    [TestCase('unknown reference', 'unknown,False,1')]
    [TestCase('missing include', 'missing,True,1')]
    [TestCase('missing reference', 'missing,False,1')]
    [TestCase('pointer-ansi include', 'pointer-ansi,True,2')]
    [TestCase('pointer-ansi reference', 'pointer-ansi,False,2')]
    [TestCase('pointer-wide include', 'pointer-wide,True,2')]
    [TestCase('pointer-wide reference', 'pointer-wide,False,2')]
    [TestCase('pointer-byte include', 'pointer-byte,True,2')]
    [TestCase('pointer-byte reference', 'pointer-byte,False,2')]
    [Test] procedure ScopeCorrectOperandTypeProof(const aCase: string; const aInclude: Boolean;
      const aExpected: Integer);
  end;

implementation

uses
  System.IOUtils, System.SysUtils,
  DelphiSemantics.Model, DelphiSemantics.Query, DelphiSemantics.Snapshot,
  DelphiSemantics.Snapshot.Builder, DelphiSemantics.Snapshot.PositionResolver,
  DelphiSemantics.Symbols, DelphiSemantics.Usage, DelphiSemantics.WithBinding,
  Test.Support;

function ProbeSource(const aCase: string): string;
begin
  if aCase = 'p01' then
    Result := 'unit NumericProbe;'#13#10 +
      ''#13#10 +
      'interface'#13#10 +
      ''#13#10 +
      '{$I flags.inc}'#13#10 +
      'procedure Soundex;'#13#10 +
      ''#13#10 +
      'var'#13#10 +
      '  gText: string;'#13#10 +
      '  gNum: Int64;'#13#10 +
      ''#13#10 +
      'implementation'#13#10 +
      ''#13#10 +
      'type'#13#10 +
      '  TRec = record'#13#10 +
      '    lName: string;'#13#10 +
      '  end;'#13#10 +
      'var'#13#10 +
      '  gRec: TRec;'#13#10 +
      ''#13#10 +
      'procedure Soundex;'#13#10 +
      'var'#13#10 +
      '  lName: Integer;'#13#10 +
      'begin'#13#10 +
      '  lName := 3;'#13#10 +
      '  gRec.lName := ''Sound'';'#13#10 +
      '  with gRec do'#13#10 +
      '    gText := lName + ''ex'';'#13#10 +
      '  gNum := lName;'#13#10 +
      'end;'#13#10 +
      ''#13#10 +
      'end.'#13#10
  else if aCase = 'p01b' then
    Result := 'unit NumericProbe;'#13#10 +
      ''#13#10 +
      'interface'#13#10 +
      ''#13#10 +
      '{$I flags.inc}'#13#10 +
      'procedure Soundex;'#13#10 +
      ''#13#10 +
      'var'#13#10 +
      '  gText: string;'#13#10 +
      '  gNum: Int64;'#13#10 +
      ''#13#10 +
      'implementation'#13#10 +
      ''#13#10 +
      'uses'#13#10 +
      '  System.Classes;'#13#10 +
      ''#13#10 +
      'procedure Soundex;'#13#10 +
      'var'#13#10 +
      '  Name: Integer;'#13#10 +
      '  lComp: TComponent;'#13#10 +
      'begin'#13#10 +
      '  Name := 3;'#13#10 +
      '  lComp := TComponent.Create(nil);'#13#10 +
      '  try'#13#10 +
      '    lComp.Name := ''Sound'';'#13#10 +
      '    with lComp do'#13#10 +
      '      gText := Name + ''ex'';'#13#10 +
      '  finally'#13#10 +
      '    lComp.Free;'#13#10 +
      '  end;'#13#10 +
      '  gNum := Name;'#13#10 +
      'end;'#13#10 +
      ''#13#10 +
      'end.'#13#10
  else if aCase = 'p02' then
    Result := 'unit NumericProbe;'#13#10 +
      ''#13#10 +
      'interface'#13#10 +
      ''#13#10 +
      '{$I flags.inc}'#13#10 +
      'procedure Soundex;'#13#10 +
      ''#13#10 +
      'var'#13#10 +
      '  gText: string;'#13#10 +
      '  gNum: Int64;'#13#10 +
      ''#13#10 +
      'implementation'#13#10 +
      ''#13#10 +
      'type'#13#10 +
      '  TRec = record'#13#10 +
      '    lName: string;'#13#10 +
      '  end;'#13#10 +
      'var'#13#10 +
      '  gRec: TRec;'#13#10 +
      ''#13#10 +
      'procedure Soundex;'#13#10 +
      'var'#13#10 +
      '  lName: Integer;'#13#10 +
      'begin'#13#10 +
      '  lName := 3;'#13#10 +
      '  gRec.lName := ''Sound'';'#13#10 +
      '  gText := gRec.lName + ''ex'';'#13#10 +
      '  gNum := lName;'#13#10 +
      'end;'#13#10 +
      ''#13#10 +
      'end.'#13#10
  else if aCase = 'p03' then
    Result := 'unit NumericProbe;'#13#10 +
      ''#13#10 +
      'interface'#13#10 +
      ''#13#10 +
      '{$I flags.inc}'#13#10 +
      'procedure Soundex;'#13#10 +
      ''#13#10 +
      'var'#13#10 +
      '  gText: string;'#13#10 +
      '  gNum: Int64;'#13#10 +
      ''#13#10 +
      'implementation'#13#10 +
      ''#13#10 +
      'uses'#13#10 +
      '  System.SysUtils;'#13#10 +
      ''#13#10 +
      'procedure Soundex;'#13#10 +
      'var'#13#10 +
      '  lName: Integer;'#13#10 +
      '  lProc: TProc;'#13#10 +
      'begin'#13#10 +
      '  lName := 3;'#13#10 +
      '  lProc := procedure'#13#10 +
      '    var'#13#10 +
      '      lName: string;'#13#10 +
      '    begin'#13#10 +
      '      lName := ''Sound'';'#13#10 +
      '      gText := lName + ''ex'';'#13#10 +
      '    end;'#13#10 +
      '  lProc();'#13#10 +
      '  gNum := lName;'#13#10 +
      'end;'#13#10 +
      ''#13#10 +
      'end.'#13#10
  else if aCase = 'p14' then
    Result := 'unit NumericProbe;'#13#10 +
      ''#13#10 +
      'interface'#13#10 +
      ''#13#10 +
      '{$I flags.inc}'#13#10 +
      'procedure Soundex;'#13#10 +
      ''#13#10 +
      'var'#13#10 +
      '  gText: string;'#13#10 +
      '  gNum: Int64;'#13#10 +
      ''#13#10 +
      'implementation'#13#10 +
      ''#13#10 +
      'type'#13#10 +
      '  TInner = record'#13#10 +
      '    lName: string;'#13#10 +
      '  end;'#13#10 +
      '  TOuter = record'#13#10 +
      '    Inner: TInner;'#13#10 +
      '  end;'#13#10 +
      'var'#13#10 +
      '  gOuter: TOuter;'#13#10 +
      ''#13#10 +
      'procedure Soundex;'#13#10 +
      'var'#13#10 +
      '  lName: Integer;'#13#10 +
      'begin'#13#10 +
      '  lName := 3;'#13#10 +
      '  gOuter.Inner.lName := ''Sound'';'#13#10 +
      '  with gOuter do'#13#10 +
      '    with Inner do'#13#10 +
      '      gText := lName + ''ex'';'#13#10 +
      '  gNum := lName;'#13#10 +
      'end;'#13#10 +
      ''#13#10 +
      'end.'#13#10
  else if aCase = 'p11' then
    Result := 'unit NumericProbe;'#13#10 +
      ''#13#10 +
      'interface'#13#10 +
      ''#13#10 +
      '{$I flags.inc}'#13#10 +
      'procedure Soundex;'#13#10 +
      ''#13#10 +
      'var'#13#10 +
      '  gText: string;'#13#10 +
      '  gNum: Int64;'#13#10 +
      ''#13#10 +
      'implementation'#13#10 +
      ''#13#10 +
      '{$POINTERMATH ON}'#13#10 +
      ''#13#10 +
      'procedure Soundex;'#13#10 +
      'var'#13#10 +
      '  lP: ^Char;'#13#10 +
      'begin'#13#10 +
      '  lP := Pointer(PChar(''xxSoundex''));'#13#10 +
      '  gText := PChar(lP + 2);'#13#10 +
      'end;'#13#10 +
      ''#13#10 +
      'end.'#13#10
  else if aCase = 'integer' then
    Result := 'unit NumericProbe;'#13#10 +
      'interface'#13#10 +
      '{$I flags.inc}'#13#10 +
      'procedure Soundex;'#13#10 +
      'implementation'#13#10 +
      'procedure Soundex;'#13#10 +
      'var'#13#10 +
      '  lCount: Integer;'#13#10 +
      'begin'#13#10 +
      '  lCount := 3;'#13#10 +
      '  lCount := lCount + 1;'#13#10 +
      'end;'#13#10 +
      'end.'#13#10
  else if aCase = 'string' then
    Result := 'unit NumericProbe;'#13#10 +
      'interface'#13#10 +
      '{$I flags.inc}'#13#10 +
      'procedure Soundex;'#13#10 +
      'implementation'#13#10 +
      'procedure Soundex;'#13#10 +
      'var'#13#10 +
      '  lCount: string;'#13#10 +
      'begin'#13#10 +
      '  lCount := 3;'#13#10 +
      '  lCount := lCount + 1;'#13#10 +
      'end;'#13#10 +
      'end.'#13#10
  else if aCase = 'unknown' then
    Result := 'unit NumericProbe;'#13#10 +
      'interface'#13#10 +
      '{$I flags.inc}'#13#10 +
      'procedure Soundex;'#13#10 +
      'implementation'#13#10 +
      'procedure Soundex;'#13#10 +
      'var'#13#10 +
      '  lCount: UnknownNumber;'#13#10 +
      'begin'#13#10 +
      '  lCount := 3;'#13#10 +
      '  lCount := lCount + 1;'#13#10 +
      'end;'#13#10 +
      'end.'#13#10
  else if aCase = 'missing' then
    Result := 'unit NumericProbe;'#13#10 +
      'interface'#13#10 +
      '{$I flags.inc}'#13#10 +
      'procedure Soundex;'#13#10 +
      'implementation'#13#10 +
      'procedure Soundex;'#13#10 +
      'var'#13#10 +
      '  lCount: Integer;'#13#10 +
      'begin'#13#10 +
      '  lCount := 3;'#13#10 +
      '  lCount := lCount + 1;'#13#10 +
      'end;'#13#10 +
      'end.'#13#10
  else if aCase = 'pointer-ansi' then
    Result := 'unit NumericProbe;'#13#10 +
      ''#13#10 +
      'interface'#13#10 +
      ''#13#10 +
      '{$I flags.inc}'#13#10 +
      'procedure Soundex;'#13#10 +
      ''#13#10 +
      'var'#13#10 +
      '  gText: string;'#13#10 +
      '  gNum: Int64;'#13#10 +
      ''#13#10 +
      'implementation'#13#10 +
      ''#13#10 +
      '{$POINTERMATH ON}'#13#10 +
      ''#13#10 +
      'procedure Soundex;'#13#10 +
      'var'#13#10 +
      '  lP: ^AnsiChar;'#13#10 +
      'begin'#13#10 +
      '  lP := Pointer(PChar(''xxSoundex''));'#13#10 +
      '  gText := PChar(lP + 2);'#13#10 +
      'end;'#13#10 +
      ''#13#10 +
      'end.'#13#10
  else if aCase = 'pointer-wide' then
    Result := 'unit NumericProbe;'#13#10 +
      ''#13#10 +
      'interface'#13#10 +
      ''#13#10 +
      '{$I flags.inc}'#13#10 +
      'procedure Soundex;'#13#10 +
      ''#13#10 +
      'var'#13#10 +
      '  gText: string;'#13#10 +
      '  gNum: Int64;'#13#10 +
      ''#13#10 +
      'implementation'#13#10 +
      ''#13#10 +
      '{$POINTERMATH ON}'#13#10 +
      ''#13#10 +
      'procedure Soundex;'#13#10 +
      'var'#13#10 +
      '  lP: ^WideChar;'#13#10 +
      'begin'#13#10 +
      '  lP := Pointer(PChar(''xxSoundex''));'#13#10 +
      '  gText := PChar(lP + 2);'#13#10 +
      'end;'#13#10 +
      ''#13#10 +
      'end.'#13#10
  else if aCase = 'pointer-byte' then
    Result := 'unit NumericProbe;'#13#10 +
      ''#13#10 +
      'interface'#13#10 +
      ''#13#10 +
      '{$I flags.inc}'#13#10 +
      'procedure Soundex;'#13#10 +
      ''#13#10 +
      'var'#13#10 +
      '  gText: string;'#13#10 +
      '  gNum: Int64;'#13#10 +
      ''#13#10 +
      'implementation'#13#10 +
      ''#13#10 +
      '{$POINTERMATH ON}'#13#10 +
      ''#13#10 +
      'procedure Soundex;'#13#10 +
      'var'#13#10 +
      '  lP: ^Byte;'#13#10 +
      'begin'#13#10 +
      '  lP := Pointer(PChar(''xxSoundex''));'#13#10 +
      '  gText := PChar(lP + 2);'#13#10 +
      'end;'#13#10 +
      ''#13#10 +
      'end.'#13#10
  else
    raise EArgumentException.Create('Unknown numeric proof fixture.');
end;

procedure TNameFlowNumericProofTests.ScopeCorrectOperandTypeProof(const aCase: string;
  const aInclude: Boolean; const aExpected: Integer);
var
  lRoot, lFile, lSource: string;
  lOptions: TDelphiSemanticModelOptions;
  lBuildOptions: TDelphiSnapshotBuildOptions;
  lModel: TDelphiSemanticUnitModel;
  lSnapshot: TDelphiProjectSnapshot;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lContext: TDelphiSemanticSymbolQueryContext;
  lSymbol: TDelphiSemanticIndexedSymbol;
  lResolution: TDelphiSemanticSnapshotPositionResolution;
  lGap: TDelphiSemanticUsage;
  lCount, lOffset, lLine, lColumn, i: Integer;
begin
  lRoot := CreateTestTempRoot('numeric-scope-proof-temp');
  lFile := TPath.Combine(lRoot, 'NumericProbe.pas');
  TFile.WriteAllText(TPath.Combine(lRoot, 'flags.inc'), '{$DEFINE HAS_FLAG}', TEncoding.ASCII);
  lSource := ProbeSource(aCase);
  if not aInclude then
    lSource := StringReplace(lSource, '{$I flags.inc}', '', []);
  TFile.WriteAllText(lFile, lSource, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lFile;
  lOptions.SearchPaths := [lRoot];
  lOptions.DefineEvidenceComplete := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success, 'The fixture must parse successfully.');
  if aCase = 'missing' then
    for i := 0 to High(lModel.Locals) do
      if SameText(lModel.Locals[i].Name, 'lCount') then
        lModel.Locals[i].TypeName := '';
  lBuildOptions := Default(TDelphiSnapshotBuildOptions);
  lBuildOptions.ResolveReferenceTargets := True;
  lSnapshot := BuildProjectSnapshotFromModels([lModel],
    Default(TDelphiSemanticProjectWithBindingFacts), lBuildOptions, lMetrics);
  lContext := Default(TDelphiSemanticSymbolQueryContext);
  try
    if aInclude and ((aCase = 'integer') or (aCase = 'string') or
      (aCase = 'unknown') or (aCase = 'missing')) then
    begin
      lOffset := Pos('lCount + 1', lSource);
      lLine := 1;
      lColumn := 1;
      for i := 1 to lOffset - 1 do
        if lSource[i] = #10 then
        begin
          Inc(lLine);
          lColumn := 1;
        end else if lSource[i] <> #13 then
          Inc(lColumn);
      Assert.IsTrue(TryResolveSnapshotPosition(lSnapshot, lFile, lLine, lColumn, 'lCount', lResolution));
      Assert.AreEqual('snapshot-physical-position-match', lResolution.Status);
      Assert.IsTrue(lResolution.SymbolFound);
      Assert.IsFalse(lResolution.ReferenceFound);
      if aCase = 'missing' then
        Assert.AreEqual('', lSnapshot.TextOf(lResolution.Symbol.TypeId),
          'The match is verified, but retained type evidence is absent.');
    end;
    lContext.ProjectSnapshot := BorrowProjectSnapshot(lSnapshot);
    lSymbol := Default(TDelphiSemanticIndexedSymbol);
    lSymbol.Name := 'Soundex';
    lSymbol.Kind := 'routine';
    lSymbol.UnitName := 'NumericProbe';
    lSymbol.FileName := lFile;
    lCount := 0;
    for lGap in TDelphiSemanticUsageFinder.PossibleImportGaps(lContext, lSymbol, ['Soundex', 'RenamedSoundex']) do
      if lGap.Reason = 'string-constant-value-unproved' then
        Inc(lCount);
    Assert.AreEqual(aExpected, lCount, 'Only scope-correct, verified numeric evidence may remove a witness.');
  finally
    lContext.ProjectSnapshot := nil;
    lSnapshot.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TNameFlowNumericProofTests);

end.
