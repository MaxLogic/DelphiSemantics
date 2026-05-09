unit Test.LspBoundary;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Lsp, DelphiSemantics.Resolve;

type
  [TestFixture]
  TLspBoundaryTests = class
  public
    [Test]
    procedure LspEnrichmentIsDisabledByDefault;
    [Test]
    procedure LspDerivedResultsCarryLspProvenance;
    [Test]
    procedure SemanticResultsRemainAuthoritativeByDefault;
    [Test]
    procedure ConvertsOneBasedCliPositionsToZeroBasedProtocol;
    [Test]
    procedure NormalizesFileUrisAndLocationLinks;
    [Test]
    procedure HoverResultsCarryContentsRangeAndEmptyStatus;
    [Test]
    procedure SymbolsRespectQueryLimitFlatteningAndProvenance;
    [Test]
    procedure SymbolFlatteningHandlesHierarchyAndEmptyResults;
    [Test]
    procedure ErrorResultsAreExplicitAndCarryLspProvenance;
    [Test]
    procedure LifecycleReportsInitializeShutdownAndErrors;
  end;

implementation

procedure TLspBoundaryTests.LspEnrichmentIsDisabledByDefault;
var
  lLocation: TDelphiSemanticLspLocation;
  lOptions: TDelphiSemanticLspOptions;
  lResult: TDelphiSemanticLspResult;
begin
  lOptions := Default(TDelphiSemanticLspOptions);
  lLocation.FileName := 'Unit1.pas';
  lLocation.Line := 10;
  lLocation.Column := 5;

  lResult := TDelphiSemanticLspBoundary.EnrichDefinition(lOptions, 'Value', lLocation);

  Assert.IsFalse(lResult.Found);
  Assert.IsFalse(lResult.Authoritative);
  Assert.AreEqual('disabled', lResult.Status);
  Assert.AreEqual('', lResult.Provenance);
end;

procedure TLspBoundaryTests.LspDerivedResultsCarryLspProvenance;
var
  lLocation: TDelphiSemanticLspLocation;
  lOptions: TDelphiSemanticLspOptions;
  lResult: TDelphiSemanticLspResult;
begin
  lOptions := Default(TDelphiSemanticLspOptions);
  lOptions.Enabled := True;
  lLocation.FileName := 'Unit1.pas';
  lLocation.Line := 10;
  lLocation.Column := 5;

  lResult := TDelphiSemanticLspBoundary.EnrichDefinition(lOptions, 'Value', lLocation);

  Assert.IsTrue(lResult.Found);
  Assert.IsFalse(lResult.Authoritative);
  Assert.AreEqual('lsp', lResult.Provenance);
  Assert.AreEqual('Value', lResult.Name);
  Assert.AreEqual('Unit1.pas', lResult.FileName);
  Assert.AreEqual(10, lResult.Line);
  Assert.AreEqual(5, lResult.Column);
end;

procedure TLspBoundaryTests.SemanticResultsRemainAuthoritativeByDefault;
var
  lResolveResult: TDelphiSemanticResolveResult;
  lResult: TDelphiSemanticLspResult;
begin
  lResolveResult := Default(TDelphiSemanticResolveResult);
  lResolveResult.Found := True;
  lResolveResult.Authoritative := True;
  lResolveResult.Status := 'resolved';
  lResolveResult.Name := 'Value';
  lResolveResult.Kind := 'field';
  lResolveResult.TypeName := 'Integer';
  lResolveResult.OwnerName := 'TRecord';

  lResult := TDelphiSemanticLspBoundary.FromSemanticResult(lResolveResult);

  Assert.IsTrue(lResult.Found);
  Assert.IsTrue(lResult.Authoritative);
  Assert.AreEqual('semantic-model', lResult.Provenance);
  Assert.AreEqual('field', lResult.Kind);
  Assert.AreEqual('Integer', lResult.TypeName);
end;

procedure TLspBoundaryTests.ConvertsOneBasedCliPositionsToZeroBasedProtocol;
var
  lCliLocation: TDelphiSemanticLspLocation;
  lProtocolPosition: TDelphiSemanticLspProtocolPosition;
begin
  lProtocolPosition := TDelphiSemanticLspBoundary.ToProtocolPosition(8, 21);

  Assert.AreEqual(7, lProtocolPosition.Line);
  Assert.AreEqual(20, lProtocolPosition.Character);

  lCliLocation := TDelphiSemanticLspBoundary.FromProtocolPosition('Unit1.pas',
    lProtocolPosition);

  Assert.AreEqual('Unit1.pas', lCliLocation.FileName);
  Assert.AreEqual(8, lCliLocation.Line);
  Assert.AreEqual(21, lCliLocation.Column);
end;

procedure TLspBoundaryTests.NormalizesFileUrisAndLocationLinks;
var
  lResult: TDelphiSemanticLspResult;
begin
  Assert.AreEqual('C:\Repo\Unit1.pas',
    TDelphiSemanticLspBoundary.NormalizeFileUri('file:///C:/Repo/Unit1.pas'));
  Assert.AreEqual('C:\Repo\Unit1.pas',
    TDelphiSemanticLspBoundary.NormalizeFileUri('file://DESKTOP/C:/Repo/Unit1.pas'));
  Assert.AreEqual('C:\Repo\Foo+Bar.pas',
    TDelphiSemanticLspBoundary.NormalizeFileUri('file://C:/Repo/Foo%2BBar.pas'));
  Assert.AreEqual('C:\Repo\M' + #$00FC + 'ller.pas',
    TDelphiSemanticLspBoundary.NormalizeFileUri('file:///C:/Repo/M%C3%BCller.pas'));
  Assert.AreEqual('\\fileserver\share\Foo+Bar.pas',
    TDelphiSemanticLspBoundary.NormalizeFileUri('file://fileserver/share/Foo%2BBar.pas'));

  lResult := TDelphiSemanticLspBoundary.FromLocationLink('Run',
    'file:///C:/Repo/Unit1.pas', 12, 0, 12, 5);

  Assert.IsTrue(lResult.Found);
  Assert.AreEqual('lsp', lResult.Provenance);
  Assert.AreEqual('C:\Repo\Unit1.pas', lResult.FileName);
  Assert.AreEqual(13, lResult.Line);
  Assert.AreEqual(1, lResult.Column);
  Assert.AreEqual(13, lResult.EndLine);
  Assert.AreEqual(6, lResult.EndColumn);
end;

procedure TLspBoundaryTests.HoverResultsCarryContentsRangeAndEmptyStatus;
var
  lHover: TDelphiSemanticLspHoverResult;
begin
  lHover := TDelphiSemanticLspBoundary.MakeHover('function Run: Boolean',
    'file:///C:/Repo/Unit1.pas', 7, 2, 7, 5);

  Assert.IsTrue(lHover.Found);
  Assert.AreEqual('lsp', lHover.Provenance);
  Assert.AreEqual('function Run: Boolean', lHover.Contents);
  Assert.AreEqual(8, lHover.Range.StartLine);
  Assert.AreEqual(3, lHover.Range.StartColumn);

  lHover := TDelphiSemanticLspBoundary.MakeEmptyHover;

  Assert.IsFalse(lHover.Found);
  Assert.AreEqual('empty', lHover.Status);
end;

procedure TLspBoundaryTests.SymbolsRespectQueryLimitFlatteningAndProvenance;
var
  lInput: TArray<TDelphiSemanticLspSymbol>;
  lSymbols: TArray<TDelphiSemanticLspSymbol>;
begin
  SetLength(lInput, 3);
  lInput[0].Name := 'TFixtureType';
  lInput[0].Kind := 5;
  lInput[0].ContainerName := 'interface';
  lInput[0].FileName := 'Unit1.pas';
  lInput[0].Line := 6;
  lInput[0].Column := 18;
  lInput[1].Name := 'TFixtureType.Run';
  lInput[1].Kind := 6;
  lInput[1].ContainerName := 'TFixtureType';
  lInput[1].FileName := 'Unit1.pas';
  lInput[1].Line := 13;
  lInput[1].Column := 1;
  lInput[2].Name := 'OtherSymbol';
  lInput[2].Kind := 12;
  lInput[2].FileName := 'Unit1.pas';
  lInput[2].Line := 20;
  lInput[2].Column := 1;

  lSymbols := TDelphiSemanticLspBoundary.FilterSymbols(lInput, 'Fixture', 2);

  Assert.AreEqual(2, Length(lSymbols));
  Assert.AreEqual('TFixtureType', lSymbols[0].Name);
  Assert.AreEqual('TFixtureType.Run', lSymbols[1].Name);
  Assert.AreEqual('lsp', lSymbols[0].Provenance);
  Assert.AreEqual('lsp', lSymbols[1].Provenance);
end;

procedure TLspBoundaryTests.SymbolFlatteningHandlesHierarchyAndEmptyResults;
var
  lChild: TDelphiSemanticLspSymbolNode;
  lRoot: TDelphiSemanticLspSymbolNode;
  lSymbols: TArray<TDelphiSemanticLspSymbol>;
begin
  lRoot := TDelphiSemanticLspSymbolNode.Create;
  try
    lRoot.Symbol.Name := 'TFixtureType';
    lRoot.Symbol.Kind := 5;
    lRoot.Symbol.FileName := 'Unit1.pas';
    lRoot.Symbol.Line := 6;
    lRoot.Symbol.Column := 18;
    lChild := TDelphiSemanticLspSymbolNode.Create;
    lChild.Symbol.Name := 'Run';
    lChild.Symbol.Kind := 6;
    lChild.Symbol.FileName := 'Unit1.pas';
    lChild.Symbol.Line := 13;
    lChild.Symbol.Column := 1;
    lRoot.Children.Add(lChild);

    lSymbols := TDelphiSemanticLspBoundary.FlattenSymbolNodes([lRoot], '', 10);

    Assert.AreEqual(2, Length(lSymbols));
    Assert.AreEqual('TFixtureType', lSymbols[0].Name);
    Assert.AreEqual('Run', lSymbols[1].Name);
    Assert.AreEqual('TFixtureType', lSymbols[1].ContainerName);
    Assert.AreEqual('lsp', lSymbols[1].Provenance);
    lSymbols := TDelphiSemanticLspBoundary.FlattenSymbolNodes([lRoot], 'Fixture', 10);
    Assert.AreEqual(1, Length(lSymbols));
    Assert.AreEqual('TFixtureType', lSymbols[0].Name);
    lSymbols := TDelphiSemanticLspBoundary.FlattenSymbolNodes([lRoot], 'Run', 10);
    Assert.AreEqual(1, Length(lSymbols));
    Assert.AreEqual('Run', lSymbols[0].Name);
    lSymbols := TDelphiSemanticLspBoundary.FlattenSymbolNodes([], 'Missing', 10);
    Assert.AreEqual(0, Length(lSymbols));
  finally
    lRoot.Free;
  end;
end;

procedure TLspBoundaryTests.ErrorResultsAreExplicitAndCarryLspProvenance;
var
  lResult: TDelphiSemanticLspResult;
begin
  lResult := TDelphiSemanticLspBoundary.MakeErrorResult('definition failed');

  Assert.IsFalse(lResult.Found);
  Assert.AreEqual('error', lResult.Status);
  Assert.AreEqual('lsp', lResult.Provenance);
  Assert.AreEqual('definition failed', lResult.ErrorMessage);
end;

procedure TLspBoundaryTests.LifecycleReportsInitializeShutdownAndErrors;
var
  lSession: TDelphiSemanticLspLifecycle;
begin
  lSession := TDelphiSemanticLspLifecycle.StartInitialized;

  Assert.IsTrue(lSession.Initialized);
  Assert.IsFalse(lSession.Shutdown);
  Assert.AreEqual('initialized', lSession.Status);

  lSession := TDelphiSemanticLspLifecycle.ShutdownSession(lSession);

  Assert.IsTrue(lSession.Initialized);
  Assert.IsTrue(lSession.Shutdown);
  Assert.AreEqual('shutdown', lSession.Status);

  lSession := TDelphiSemanticLspLifecycle.ErrorSession('initialize failed');

  Assert.IsFalse(lSession.Initialized);
  Assert.AreEqual('error', lSession.Status);
  Assert.AreEqual('initialize failed', lSession.ErrorMessage);
end;

initialization
  TDUnitX.RegisterTestFixture(TLspBoundaryTests);

end.
