unit DelphiSemantics.Refactor.Matrix;

interface

uses
  DelphiSemantics.CompilerDefineEvidence;

type
  TSemanticMatrixPair = record
    Configuration, Platform: string;
    function Identity: string;
    function DisplayName: string;
    class function Create(const aConfiguration, aPlatform: string): TSemanticMatrixPair; static;
  end;

  TSemanticMatrixPlatform = record
    Name: string;
    Enabled: Boolean;
    Provenance: string;
  end;

  TSemanticMatrixInventory = record
    Configurations: TArray<string>;
    Platforms: TArray<TSemanticMatrixPlatform>;
    ConfigurationsComplete, PlatformsComplete: Boolean;
    NativeDefault, Caller: TSemanticMatrixPair;
    Diagnostics, Observations: TArray<string>;
  end;

  TSemanticMatrixSelection = record
    Configurations, Platforms: string;
    HasConfigurations, HasPlatforms: Boolean;
  end;

  // This is a source-phase observation, never a rename verdict or apply grant.
  TSemanticMatrixRowState = (Incomplete, Passed, Failed, TargetAbsentProved, NotRequested);
  TSemanticMatrixRow = record
    Pair: TSemanticMatrixPair;
    State: TSemanticMatrixRowState;
    NativeDefault, Caller: Boolean;
    NativeIdentity, SourceIdentity: string;
    Diagnostics: TArray<string>;
    CompilerEvidence: IDelphiSemanticCompilerDefineEvidence;
  end;

  ISemanticMatrixDomain = interface
    ['{2D4007E6-C26C-4E76-932B-7A14435970AD}']
    function DomainDefault: TArray<TSemanticMatrixPair>;
    function RequiredPairs: TArray<TSemanticMatrixPair>;
    function ExcludedPairs: TArray<TSemanticMatrixPair>;
    function DisabledPlatforms: TArray<string>;
    function InventoryDiagnostics: TArray<string>;
    function NativeDefault: TSemanticMatrixPair;
    function Caller: TSemanticMatrixPair;
    function InventoryProved: Boolean;
    function RequiredDomainProved: Boolean;
    function Narrowed: Boolean;
    function Fingerprint: string;
    function ScopeLabel: string;
    function AuthorityText: string;
    function ApplyFingerprint: string;
  end;

function TryCreateSemanticMatrixDomain(const aInventory: TSemanticMatrixInventory;
  const aSelection: TSemanticMatrixSelection; out aDomain: ISemanticMatrixDomain;
  out aError: string): Boolean;

implementation

uses
  System.Classes, System.Generics.Collections, System.Generics.Defaults, System.Hash, System.StrUtils, System.SysUtils,
  AutoFree;

type
  IMatrixDomainBuilder = interface
    ['{95C3A61E-BA5D-4C4C-9F86-CE1949190877}']
    function Initialize(const aInventory: TSemanticMatrixInventory;
      const aSelection: TSemanticMatrixSelection; out aError: string): Boolean;
  end;

  TSemanticMatrixDomain = class(TInterfacedObject, ISemanticMatrixDomain, IMatrixDomainBuilder)
  private
    fDefault, fRequired, fExcluded: TArray<TSemanticMatrixPair>;
    fDisabled, fDiagnostics: TArray<string>;
    fNativeDefault, fCaller: TSemanticMatrixPair;
    fInventoryProved, fRequiredProved, fNarrowed: Boolean;
    fFingerprint: string;
  public
    function Initialize(const aInventory: TSemanticMatrixInventory;
      const aSelection: TSemanticMatrixSelection; out aError: string): Boolean;
    function DomainDefault: TArray<TSemanticMatrixPair>;
    function RequiredPairs: TArray<TSemanticMatrixPair>;
    function ExcludedPairs: TArray<TSemanticMatrixPair>;
    function DisabledPlatforms: TArray<string>;
    function InventoryDiagnostics: TArray<string>;
    function NativeDefault: TSemanticMatrixPair;
    function Caller: TSemanticMatrixPair;
    function InventoryProved: Boolean;
    function RequiredDomainProved: Boolean;
    function Narrowed: Boolean;
    function Fingerprint: string;
    function ScopeLabel: string;
    function AuthorityText: string;
    function ApplyFingerprint: string;
  end;

class function TSemanticMatrixPair.Create(const aConfiguration, aPlatform: string): TSemanticMatrixPair;
begin
  Result.Configuration := aConfiguration;
  Result.Platform := aPlatform;
end;

function TSemanticMatrixPair.Identity: string;
var
  lConfig, lPlatform: string;
begin
  lConfig := Configuration.ToLowerInvariant;
  lPlatform := Platform.ToLowerInvariant;
  Result := IntToStr(Length(lConfig)) + ':' + lConfig + IntToStr(Length(lPlatform)) + ':' + lPlatform;
end;

function TSemanticMatrixPair.DisplayName: string;
begin
  Result := Configuration + '/' + Platform;
end;

function TSemanticMatrixDomain.DomainDefault: TArray<TSemanticMatrixPair>;
begin
  Result := Copy(fDefault);
end;

function TSemanticMatrixDomain.RequiredPairs: TArray<TSemanticMatrixPair>;
begin
  Result := Copy(fRequired);
end;

function TSemanticMatrixDomain.ExcludedPairs: TArray<TSemanticMatrixPair>;
begin
  Result := Copy(fExcluded);
end;

function TSemanticMatrixDomain.DisabledPlatforms: TArray<string>;
begin
  Result := Copy(fDisabled);
end;

function TSemanticMatrixDomain.InventoryDiagnostics: TArray<string>;
begin
  Result := Copy(fDiagnostics);
end;

function TSemanticMatrixDomain.NativeDefault: TSemanticMatrixPair;
begin
  Result := fNativeDefault;
end;

function TSemanticMatrixDomain.Caller: TSemanticMatrixPair;
begin
  Result := fCaller;
end;

function TSemanticMatrixDomain.InventoryProved: Boolean;
begin
  Result := fInventoryProved;
end;

function TSemanticMatrixDomain.RequiredDomainProved: Boolean;
begin
  Result := fRequiredProved;
end;

function TSemanticMatrixDomain.Narrowed: Boolean;
begin
  Result := fNarrowed;
end;

function TSemanticMatrixDomain.Fingerprint: string;
begin
  Result := fFingerprint;
end;

function TSemanticMatrixDomain.ApplyFingerprint: string;
begin
  Result := '';
end;

function TSemanticMatrixDomain.ScopeLabel: string;
begin
  if not fInventoryProved then
  begin
    if fNarrowed then
      Exit('inventory unproved / explicitly narrowed');
    Exit('inventory unproved');
  end;
  if fNarrowed then
    Exit('narrowed');
  Result := 'full-matrix';
end;

function TSemanticMatrixDomain.AuthorityText: string;
var
  lPair: TSemanticMatrixPair;
  lNames: TArray<string>;
begin
  lNames := nil;
  for lPair in fDefault do
    lNames := lNames + [lPair.DisplayName];
  for lPair in fRequired do
    if not MatchText(lPair.DisplayName, lNames) then
      lNames := lNames + [lPair.DisplayName];
  if not fInventoryProved then
    lNames := lNames + ['additional pairs unknown'];
  Result := 'advisory; certified for {}; not certified: {' + String.Join('; ', lNames) + '}';
end;

function ContainsName(const aNames: TArray<string>; const aName: string): Boolean;
var
  lName: string;
begin
  for lName in aNames do
    if SameText(lName, aName) then
      Exit(True);
  Result := False;
end;

function TrySelectNames(const aValue, aSwitch: string; const aNames: TArray<string>;
  out aSelected: TArray<string>; out aError: string): Boolean;
var
  lToken, lName, lRawToken: string;
  lFound: Boolean;
begin
  aSelected := nil;
  aError := '';
  if Trim(aValue) = '' then
  begin
    aError := 'invalid-matrix-selector: ' + aSwitch + ' requires nonempty exact declared names';
    Exit(False);
  end;
  for lRawToken in aValue.Split([',']) do
  begin
    lToken := Trim(lRawToken);
    lFound := False;
    if (lToken <> '') and not SameText(lToken, 'Base') then
      for lName in aNames do
        if SameText(lToken, lName) then
        begin
          if not ContainsName(aSelected, lName) then
            aSelected := aSelected + [lName];
          lFound := True;
          Break;
        end;
    if not lFound then
    begin
      aError := 'invalid-matrix-selector: ' + aSwitch + ' value "' + lToken +
        '"; use nonempty exact declared names: ' + String.Join(', ', aNames);
      Exit(False);
    end;
  end;
  Result := Length(aSelected) > 0;
end;

procedure AddPair(var aPairs: TArray<TSemanticMatrixPair>; const aPair: TSemanticMatrixPair);
var
  lExisting: TSemanticMatrixPair;
begin
  for lExisting in aPairs do
    if lExisting.Identity = aPair.Identity then
      Exit;
  aPairs := aPairs + [aPair];
end;

procedure SortPairs(var aPairs: TArray<TSemanticMatrixPair>);
var
  lComparer: IComparer<string>;
begin
  lComparer := TStringComparer.Ordinal;
  TArray.Sort<TSemanticMatrixPair>(aPairs, TComparer<TSemanticMatrixPair>.Construct(
    function(const aLeft, aRight: TSemanticMatrixPair): Integer
    begin
      Result := lComparer.Compare(aLeft.Configuration.ToLowerInvariant,
        aRight.Configuration.ToLowerInvariant);
      if Result = 0 then
        Result := lComparer.Compare(aLeft.Platform.ToLowerInvariant,
          aRight.Platform.ToLowerInvariant);
    end));
end;

function TSemanticMatrixDomain.Initialize(const aInventory: TSemanticMatrixInventory;
  const aSelection: TSemanticMatrixSelection; out aError: string): Boolean;
var
  lConfig, lPlatform: string;
  lConfigs, lPlatforms, lSelectedConfigs, lSelectedPlatforms: TArray<string>;
  lPlatformInfo: TSemanticMatrixPlatform;
  lPair: TSemanticMatrixPair;
  lIdentity: string;
  lCallerIncluded: Boolean;
begin
  aError := '';
  lConfigs := nil;
  for lConfig in aInventory.Configurations do
    if not SameText(lConfig, 'Base') and not ContainsName(lConfigs, lConfig) then
      lConfigs := lConfigs + [lConfig];
  lPlatforms := nil;
  for lPlatformInfo in aInventory.Platforms do
  begin
    if not ContainsName(lPlatforms, lPlatformInfo.Name) then
      lPlatforms := lPlatforms + [lPlatformInfo.Name];
    if not lPlatformInfo.Enabled and not ContainsName(fDisabled, lPlatformInfo.Name) then
      fDisabled := fDisabled + [lPlatformInfo.Name];
  end;
  fDiagnostics := Copy(aInventory.Diagnostics);
  fNativeDefault := aInventory.NativeDefault;
  fCaller := aInventory.Caller;
  for lPair in [aInventory.NativeDefault, aInventory.Caller] do
    if (lPair.Configuration = '') or (lPair.Platform = '') or
      SameText(lPair.Configuration, 'Base') then
    begin
      aError := 'unsupported-concrete-selection: native default and caller require a non-Base Config/Platform';
          Exit(False);
    end;
  for lConfig in lConfigs do
    for lPlatformInfo in aInventory.Platforms do
      if lPlatformInfo.Enabled then
        AddPair(fDefault, TSemanticMatrixPair.Create(lConfig, lPlatformInfo.Name));
  AddPair(fDefault, aInventory.NativeDefault);
  AddPair(fDefault, aInventory.Caller);
  lSelectedConfigs := lConfigs;
  lSelectedPlatforms := lPlatforms;
  if aSelection.HasConfigurations and not TrySelectNames(aSelection.Configurations, '--configs',
    lConfigs, lSelectedConfigs, aError) then
  begin
      Exit(False);
  end;
  if aSelection.HasPlatforms and not TrySelectNames(aSelection.Platforms, '--platforms',
    lPlatforms, lSelectedPlatforms, aError) then
  begin
      Exit(False);
  end;
  fNarrowed := aSelection.HasConfigurations or aSelection.HasPlatforms;
  fInventoryProved := aInventory.ConfigurationsComplete and aInventory.PlatformsComplete and
    (Length(aInventory.Diagnostics) = 0);
  fRequiredProved := fInventoryProved or
    (fNarrowed and (aSelection.HasConfigurations or aInventory.ConfigurationsComplete) and
    (aSelection.HasPlatforms or aInventory.PlatformsComplete));
  if not fInventoryProved and fNarrowed and not fRequiredProved then
  begin
    aError := 'configuration-inventory-unproved: specify both --configs and --platforms, or prove the omitted axis';
      Exit(False);
  end;
  fRequired := Copy(fDefault);
  if aSelection.HasPlatforms then
    for lConfig in lSelectedConfigs do
      for lPlatform in lSelectedPlatforms do
        AddPair(fRequired, TSemanticMatrixPair.Create(lConfig, lPlatform));
  lCallerIncluded := False;
  for lPair in Copy(fRequired) do
    if (aSelection.HasConfigurations and not ContainsName(lSelectedConfigs, lPair.Configuration)) or
      (aSelection.HasPlatforms and not ContainsName(lSelectedPlatforms, lPair.Platform)) then
      AddPair(fExcluded, lPair)
    else if lPair.Identity = aInventory.Caller.Identity then
      lCallerIncluded := True;
  fRequired := nil;
  for lPair in fDefault do
    if (not aSelection.HasConfigurations or ContainsName(lSelectedConfigs, lPair.Configuration)) and
      (not aSelection.HasPlatforms or ContainsName(lSelectedPlatforms, lPair.Platform)) then
      AddPair(fRequired, lPair);
  if aSelection.HasPlatforms then
    for lConfig in lSelectedConfigs do
      for lPlatform in lSelectedPlatforms do
        AddPair(fRequired, TSemanticMatrixPair.Create(lConfig, lPlatform));
  if not lCallerIncluded then
  begin
    aError := 'caller-pair-excluded: resolved caller ' + aInventory.Caller.DisplayName +
      '; --configs="' + aSelection.Configurations + '" --platforms="' + aSelection.Platforms +
      '". Include that pair with --configs="' + String.Join(',', lSelectedConfigs +
      [aInventory.Caller.Configuration]) + '" --platforms="' + String.Join(',', lSelectedPlatforms +
      [aInventory.Caller.Platform]) + '" or set --config="' + lSelectedConfigs[0] +
      '" --platform="' + lSelectedPlatforms[0] + '"';
      Exit(False);
  end;
  if Length(fRequired) = 0 then
  begin
    aError := 'empty-matrix-selection: selectors must retain at least the resolved caller pair';
      Exit(False);
  end;
  SortPairs(fDefault);
  SortPairs(fRequired);
  SortPairs(fExcluded);
  TArray.Sort<string>(fDisabled);
  lIdentity := 'ds797-matrix-domain-v1|' + aInventory.NativeDefault.Identity + '|' + aInventory.Caller.Identity +
    '|' + BoolToStr(fNarrowed, True) + '|' + BoolToStr(fInventoryProved, True);
  for lPair in fDefault do
    lIdentity := lIdentity + '|D' + lPair.Identity;
  for lPair in fRequired do
    lIdentity := lIdentity + '|R' + lPair.Identity;
  for lConfig in aInventory.Observations + aInventory.Diagnostics do
    lIdentity := lIdentity + '|' + IntToStr(Length(lConfig)) + ':' + lConfig;
  fFingerprint := THashSHA2.GetHashString(lIdentity);
  Result := True;
end;

function TryCreateSemanticMatrixDomain(const aInventory: TSemanticMatrixInventory;
  const aSelection: TSemanticMatrixSelection; out aDomain: ISemanticMatrixDomain;
  out aError: string): Boolean;
var
  lBuilder: IMatrixDomainBuilder;
begin
  aDomain := nil;
  lBuilder := TSemanticMatrixDomain.Create;
  Result := lBuilder.Initialize(aInventory, aSelection, aError);
  if Result then
    Supports(lBuilder, ISemanticMatrixDomain, aDomain);
end;

end.
