unit Test.Refactor.Matrix.Inventory;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Refactor.Matrix;

type
  [TestFixture]
  [Category('Fast')]
  TMatrixInventoryTests = class
  private
    function Inventory: TSemanticMatrixInventory;
  public
    [Test] procedure OwnsDomainAndNeverGrantsApply;
    [Test] procedure SelectorCannotChooseImplicitCaller;
    [Test] procedure ExplicitCallerCanExcludeNativeDefault;
    [Test] procedure ExplicitDisabledPlatformAddsRequiredRows;
    [Test] procedure FiniteNarrowingRetainsUnprovedInventory;
    [Test] procedure UnknownOmittedAxisCannotBeNarrowed;
    [TestCase('Empty', '')]
    [TestCase('Base', 'Base')]
    [TestCase('Unknown', 'Other')]
    [TestCase('Trailing comma', 'Debug,', ';')]
    [TestCase('Wildcard', '*')]
    procedure InvalidSelectorIsActionable(const aValue: string);
    [Test] procedure SelectorCaseAndDuplicatesDoNotChangePairs;
    [Test] procedure PairIdentityIsLengthDelimited;
  end;

implementation

uses
  System.SysUtils;

function TMatrixInventoryTests.Inventory: TSemanticMatrixInventory;
begin
  Result := Default(TSemanticMatrixInventory);
  Result.Configurations := ['Debug', 'Release'];
  SetLength(Result.Platforms, 4);
  Result.Platforms[0].Name := 'Win32';
  Result.Platforms[1].Name := 'Win64';
  Result.Platforms[2].Name := 'Linux64';
  Result.Platforms[3].Name := 'Win64x';
  Result.Platforms[0].Enabled := True;
  Result.Platforms[1].Enabled := True;
  Result.Platforms[2].Enabled := True;
  Result.ConfigurationsComplete := True;
  Result.PlatformsComplete := True;
  Result.NativeDefault := TSemanticMatrixPair.Create('Release', 'Linux64');
  Result.Caller := Result.NativeDefault;
end;

procedure TMatrixInventoryTests.OwnsDomainAndNeverGrantsApply;
var
  lInventory: TSemanticMatrixInventory;
  lDomain: ISemanticMatrixDomain;
  lPairs: TArray<TSemanticMatrixPair>;
  lError, lFingerprint: string;
begin
  lInventory := Inventory;
  Assert.IsTrue(TryCreateSemanticMatrixDomain(lInventory, Default(TSemanticMatrixSelection), lDomain, lError), lError);
  lFingerprint := lDomain.Fingerprint;
  lInventory.Configurations[0] := 'Changed';
  lPairs := lDomain.RequiredPairs;
  lPairs[0].Configuration := 'Changed';
  Assert.AreEqual<NativeInt>(6, Length(lDomain.RequiredPairs));
  Assert.AreEqual('Debug', lDomain.RequiredPairs[0].Configuration);
  Assert.AreEqual(lFingerprint, lDomain.Fingerprint);
  Assert.AreEqual('', lDomain.ApplyFingerprint);
  Assert.IsTrue(lDomain.AuthorityText.StartsWith('advisory; certified for {}'));
end;

procedure TMatrixInventoryTests.SelectorCannotChooseImplicitCaller;
var
  lDomain: ISemanticMatrixDomain;
  lSelection: TSemanticMatrixSelection;
  lError: string;
begin
  lSelection := Default(TSemanticMatrixSelection);
  lSelection.HasPlatforms := True;
  lSelection.Platforms := 'Win32';
  Assert.IsFalse(TryCreateSemanticMatrixDomain(Inventory, lSelection, lDomain, lError));
  Assert.IsTrue(lError.Contains('caller-pair-excluded'));
  Assert.IsTrue(lError.Contains('Release/Linux64'));
  Assert.IsTrue(lError.Contains('--config'));
  Assert.IsTrue(lError.Contains('--platform'));
  Assert.IsTrue(lError.Contains('--platforms="Win32,Linux64"'), lError);
  Assert.IsTrue(lError.Contains('--config="Debug" --platform="Win32"'), lError);
end;

procedure TMatrixInventoryTests.ExplicitCallerCanExcludeNativeDefault;
var
  lInventory: TSemanticMatrixInventory;
  lDomain: ISemanticMatrixDomain;
  lSelection: TSemanticMatrixSelection;
  lError: string;
begin
  lInventory := Inventory;
  lInventory.Caller.Platform := 'Win32';
  lSelection := Default(TSemanticMatrixSelection);
  lSelection.HasPlatforms := True;
  lSelection.Platforms := 'Win32';
  Assert.IsTrue(TryCreateSemanticMatrixDomain(lInventory, lSelection, lDomain, lError), lError);
  Assert.AreEqual('narrowed', lDomain.ScopeLabel);
  Assert.AreEqual<NativeInt>(2, Length(lDomain.RequiredPairs));
  Assert.AreEqual<NativeInt>(4, Length(lDomain.ExcludedPairs));
  Assert.AreEqual('Release/Linux64', lDomain.NativeDefault.DisplayName);
end;

procedure TMatrixInventoryTests.ExplicitDisabledPlatformAddsRequiredRows;
var
  lInventory: TSemanticMatrixInventory;
  lDomain: ISemanticMatrixDomain;
  lSelection: TSemanticMatrixSelection;
  lError: string;
begin
  lInventory := Inventory;
  lInventory.Caller.Platform := 'Win64x';
  lSelection := Default(TSemanticMatrixSelection);
  lSelection.HasPlatforms := True;
  lSelection.Platforms := 'Win64x';
  Assert.IsTrue(TryCreateSemanticMatrixDomain(lInventory, lSelection, lDomain, lError), lError);
  Assert.AreEqual<NativeInt>(2, Length(lDomain.RequiredPairs));
  Assert.AreEqual('Debug/Win64x', lDomain.RequiredPairs[0].DisplayName);
  Assert.AreEqual('', lDomain.ApplyFingerprint);
end;

procedure TMatrixInventoryTests.FiniteNarrowingRetainsUnprovedInventory;
var
  lInventory: TSemanticMatrixInventory;
  lDomain: ISemanticMatrixDomain;
  lSelection: TSemanticMatrixSelection;
  lError: string;
begin
  lInventory := Inventory;
  lInventory.ConfigurationsComplete := False;
  lInventory.PlatformsComplete := False;
  lInventory.Diagnostics := ['configuration-inventory-unproved: computed config'];
  lSelection := Default(TSemanticMatrixSelection);
  lSelection.HasConfigurations := True;
  lSelection.Configurations := 'Release';
  lSelection.HasPlatforms := True;
  lSelection.Platforms := 'Linux64';
  Assert.IsTrue(TryCreateSemanticMatrixDomain(lInventory, lSelection, lDomain, lError), lError);
  Assert.IsFalse(lDomain.InventoryProved);
  Assert.IsTrue(lDomain.RequiredDomainProved);
  Assert.AreEqual<NativeInt>(1, Length(lDomain.RequiredPairs));
  Assert.AreEqual<NativeInt>(1, Length(lDomain.InventoryDiagnostics));
  Assert.AreEqual('inventory unproved / explicitly narrowed', lDomain.ScopeLabel);
  Assert.IsTrue(lDomain.AuthorityText.Contains('additional pairs unknown'));
  Assert.AreEqual('', lDomain.ApplyFingerprint);
end;

procedure TMatrixInventoryTests.UnknownOmittedAxisCannotBeNarrowed;
var
  lInventory: TSemanticMatrixInventory;
  lDomain: ISemanticMatrixDomain;
  lSelection: TSemanticMatrixSelection;
  lError: string;
begin
  lInventory := Inventory;
  lInventory.ConfigurationsComplete := False;
  lSelection := Default(TSemanticMatrixSelection);
  lSelection.HasPlatforms := True;
  lSelection.Platforms := 'Linux64';
  Assert.IsFalse(TryCreateSemanticMatrixDomain(lInventory, lSelection, lDomain, lError));
  Assert.IsTrue(lError.Contains('omitted axis'));
end;

procedure TMatrixInventoryTests.InvalidSelectorIsActionable(const aValue: string);
var
  lDomain: ISemanticMatrixDomain;
  lSelection: TSemanticMatrixSelection;
  lError: string;
begin
  lSelection := Default(TSemanticMatrixSelection);
  lSelection.HasConfigurations := True;
  lSelection.Configurations := aValue;
  Assert.IsFalse(TryCreateSemanticMatrixDomain(Inventory, lSelection, lDomain, lError));
  Assert.IsTrue(lError.Contains('invalid-matrix-selector'));
  Assert.IsTrue(lError.Contains('--configs'));
end;

procedure TMatrixInventoryTests.SelectorCaseAndDuplicatesDoNotChangePairs;
var
  lDomain: ISemanticMatrixDomain;
  lSelection: TSemanticMatrixSelection;
  lError: string;
begin
  lSelection := Default(TSemanticMatrixSelection);
  lSelection.HasConfigurations := True;
  lSelection.Configurations := 'release,RELEASE';
  Assert.IsTrue(TryCreateSemanticMatrixDomain(Inventory, lSelection, lDomain, lError), lError);
  Assert.AreEqual<NativeInt>(3, Length(lDomain.RequiredPairs));
end;

procedure TMatrixInventoryTests.PairIdentityIsLengthDelimited;
begin
  Assert.AreNotEqual(TSemanticMatrixPair.Create('ab', 'c').Identity,
    TSemanticMatrixPair.Create('a', 'bc').Identity);
  Assert.AreEqual(TSemanticMatrixPair.Create('Release', 'LINUX64').Identity,
    TSemanticMatrixPair.Create('release', 'Linux64').Identity);
end;

initialization
  TDUnitX.RegisterTestFixture(TMatrixInventoryTests);

end.
