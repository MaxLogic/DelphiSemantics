unit DelphiSemantics.Resolve.UnitNameWitness;

interface

uses
  DelphiSemantics.Model, DelphiSemantics.ProjectContext;

type
  IDelphiSemanticUnitNameWitness = interface
    ['{40DA7787-E5D3-4995-A535-6892C585AD7D}']
    function MayDeclare(const aUnitName, aName: string): Boolean;
    function IdentityText: string;
  end;

  TDelphiSemanticUnitNameWitnessBuilder = record
  public
    class function Build(const aProject: TDelphiSemanticProjectInfo;
      const aModels: TArray<TDelphiSemanticUnitModel>;
      const aRtlSourceRoot: string): IDelphiSemanticUnitNameWitness; static;
  end;

implementation

uses
  System.Generics.Collections, System.Generics.Defaults, System.IOUtils, System.StrUtils,
  System.SysUtils, Xml.omnixmldom, Xml.XMLDoc, Xml.xmldom, Xml.XMLIntf,
  AutoFree, MaxLogic.StrUtils,
  DelphiSemantics.Cache, DelphiSemantics.Preprocess, DelphiSemantics.Resolve.UnitResolver,
  DelphiSemantics.SemanticGraph, DelphiSemantics.Source;

type
  TWitnessEntry = class
    Known: Boolean;
    Tokens: TDictionary<string, Byte>;
    constructor Create;
    destructor Destroy; override;
  end;

  TUnitNameWitness = class(TInterfacedObject, IDelphiSemanticUnitNameWitness)
  private
    fEntries: TObjectDictionary<string, TWitnessEntry>;
    fNeededNames: TDictionary<string, Byte>;
    fIdentityLines: TList<string>;
    fProject: TDelphiSemanticProjectInfo;
    fRtlFiles: TObjectDictionary<string, TList<string>>;
    fLocationsKnown, fDefaultAliasesKnown: Boolean;
    fSdkSourceRoot, fSdkLibraryRoot: string;
    procedure LoadDefaultAliases;
    function CandidateNames(const aUnitName: string): TArray<TUnitCandidateName>;
    function ResolveSdkInclude(const aArgument, aIncludingFile, aRootFile: string;
      out aFileName: string): Boolean;
    procedure IndexDirectory(const aDirectory: string; const aRecursive: Boolean);
    class function IsIdentifierStart(const aChar: Char): Boolean; static;
    class function IsIdentifierPart(const aChar: Char): Boolean; static;
    function ResolveSource(const aUnitName: string; out aFileName, aReason,
      aResolvedName: string): Boolean;
    function ScanFile(const aUnitName, aFileName: string; const aEntry: TWitnessEntry;
      const aSeen: TDictionary<string, Byte>; const aRootFile: string;
      const aIsInclude: Boolean;
      out aReason: string): Boolean;
    procedure AddEntry(const aUnitName: string);
  public
    constructor Create(const aProject: TDelphiSemanticProjectInfo;
      const aModels: TArray<TDelphiSemanticUnitModel>; const aRtlSourceRoot: string);
    destructor Destroy; override;
    function MayDeclare(const aUnitName, aName: string): Boolean;
    function IdentityText: string;
  end;

constructor TWitnessEntry.Create;
begin
  inherited;
  Tokens := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
end;

destructor TWitnessEntry.Destroy;
begin
  Tokens.Free;
  inherited;
end;

constructor TUnitNameWitness.Create(const aProject: TDelphiSemanticProjectInfo;
  const aModels: TArray<TDelphiSemanticUnitModel>; const aRtlSourceRoot: string);
var
  g: TGarbos;
  lIndexed: TDictionary<string, Byte>;
  lImports, lImplementation: TArray<string>;
  lModel: TDelphiSemanticUnitModel;
  lCandidate: TUnitCandidateName;
  lPath, lName, lDirectory, lProfilePaths: string;
begin
  inherited Create;
  fProject := aProject;
  // The active compiler profile supplies this installation's source root.
  // Only its installed lib/source pairing may collapse a DCU into source proof.
  if SameText(TPath.GetFileName(ExcludeTrailingPathDelimiter(aRtlSourceRoot)), 'source') then
  begin
    fSdkSourceRoot := IncludeTrailingPathDelimiter(
      TDelphiSemanticCacheIdentityBuilder.CanonicalPath(aRtlSourceRoot));
    fSdkLibraryRoot := IncludeTrailingPathDelimiter(
      TDelphiSemanticCacheIdentityBuilder.CanonicalPath(TPath.Combine(
        TPath.GetDirectoryName(ExcludeTrailingPathDelimiter(aRtlSourceRoot)), 'lib')));
  end;

  fEntries := TObjectDictionary<string, TWitnessEntry>.Create([doOwnsValues],
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  fIdentityLines := TList<string>.Create;
  fRtlFiles := TObjectDictionary<string, TList<string>>.Create([doOwnsValues],
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  fNeededNames := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  LoadDefaultAliases;
  for lModel in aModels do
  begin
    TDelphiSemanticSemanticGraphBuilder.ProjectImports(aProject, lModel, aModels,
      lImports, lImplementation);
    for lName in lImports + lImplementation do
      for lCandidate in CandidateNames(lName) do
        fNeededNames.AddOrSetValue(lCandidate.TargetName, 0);
    for lName in lImports + lImplementation do
    begin
      fNeededNames.AddOrSetValue(lName, 0);
      for lPath in fProject.UnitScopeNames do
        fNeededNames.AddOrSetValue(lPath + '.' + lName, 0);
    end;
  end;
  fLocationsKnown := not SameText(aProject.PropertyValue('DSWitnessProfileKnown'), 'False');
  GC(lIndexed, TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase), g);
  lProfilePaths := aProject.PropertyValue('DSWitnessProfilePaths') + ';' +
    aProject.PropertyValue('DelphiLibraryPath') + ';' +
    aProject.PropertyValue('DelphiBrowsingPath') + ';' +
    aProject.PropertyValue('DelphiDebugDCUPath');
  if aProject.PropertyValue('LANGDIR').Trim <> '' then
    lProfilePaths := lProfilePaths + ';' +
      aProject.PropertyValue('DelphiTranslatedLibraryPath') + ';' +
      aProject.PropertyValue('DelphiTranslatedDebugLibraryPath');
  for lPath in aProject.SourceLookupPaths + [aProject.ProjectDirectory] +
    lProfilePaths.Split([';']) do
    if lPath.Trim <> '' then
    begin
      if Pos('$(', lPath) > 0 then
      begin
        fLocationsKnown := False;
        Continue;
      end;
      lDirectory := lPath;
      if (aProject.ProjectDirectory <> '') and not TPath.IsPathRooted(lDirectory) then
        lDirectory := TPath.Combine(aProject.ProjectDirectory, lDirectory);
      lName := TDelphiSemanticCacheIdentityBuilder.CanonicalPath(lDirectory);
      if not lIndexed.ContainsKey(lName) then
      begin
        lIndexed.Add(lName, 0);
        IndexDirectory(lDirectory, False);
      end;
    end;
  IndexDirectory(aRtlSourceRoot, True);
  lIndexed.Clear;
  for lModel in aModels do
    if lModel.UnitName <> '' then
      lIndexed.AddOrSetValue(lModel.UnitName, 0);
  for lModel in aModels do
  begin
    TDelphiSemanticSemanticGraphBuilder.ProjectImports(aProject, lModel, aModels,
      lImports, lImplementation);
    for lName in lImports + lImplementation do
      if (lName <> '') and not lIndexed.ContainsKey(lName) and
        not fEntries.ContainsKey(lName) then
        AddEntry(lName);
  end;
end;

destructor TUnitNameWitness.Destroy;
begin
  fNeededNames.Free;
  fRtlFiles.Free;
  fIdentityLines.Free;
  fEntries.Free;
  inherited;
end;

class function TUnitNameWitness.IsIdentifierStart(const aChar: Char): Boolean;
begin
  Result := CharInSet(aChar, ['_', 'A'..'Z', 'a'..'z']) or (Ord(aChar) > 127);
end;

class function TUnitNameWitness.IsIdentifierPart(const aChar: Char): Boolean;
begin
  Result := IsIdentifierStart(aChar) or CharInSet(aChar, ['0'..'9']);
end;

procedure TUnitNameWitness.IndexDirectory(const aDirectory: string; const aRecursive: Boolean);
var
  lPath, lName, lExtension, lCanonical: string;
  lPaths: TList<string>;
  lSearch: TSearchOption;
begin
  if aDirectory = '' then
    Exit;
  lSearch := TSearchOption.soTopDirectoryOnly;
  if aRecursive then
    lSearch := TSearchOption.soAllDirectories;
  try
    if not TDirectory.Exists(aDirectory) then
      Exit;
    for lExtension in ['.pas', '.dcu'] do
      for lPath in TDirectory.GetFiles(aDirectory, '*' + lExtension, lSearch) do
      begin
        lName := TPath.GetFileNameWithoutExtension(lPath);
        if not fNeededNames.ContainsKey(lName) then
          Continue;
        lCanonical := TDelphiSemanticCacheIdentityBuilder.CanonicalPath(lPath);
        if not fRtlFiles.TryGetValue(lName, lPaths) then
        begin
          lPaths := TList<string>.Create;
          fRtlFiles.Add(lName, lPaths);
        end;
        if lPaths.IndexOf(lCanonical) < 0 then
          lPaths.Add(lCanonical);
      end;
  except
    on E: Exception do
    begin
      // A partial listing cannot prove that no second candidate exists.
      fLocationsKnown := False;
      fIdentityLines.Add('witness-location-unknown=' + aDirectory + '|' + E.ClassName);
    end;
  end;
end;

function LoadWitnessXml(const aText: string): IXMLDocument;
var
  lDocument: TXMLDocument;
begin
  lDocument := TXMLDocument.Create(nil);
  try
    lDocument.DOMVendor := GetDOMVendor(sOmniXmlVendor);
    lDocument.LoadFromXML(aText);
    Result := lDocument as IXMLDocument;
  except
    lDocument.Free;
    raise;
  end;
end;

function WitnessCondition(const aNode: IXMLNode): string;
begin
  Result := '';
  if aNode.HasAttribute('Condition') then
    Result := aNode.Attributes['Condition'];
end;

procedure TUnitNameWitness.LoadDefaultAliases;
var
  lTargets, lValue, lError, lCondition: string;
  lLoaded: TDelphiSemanticSourceLoadResult;
  lDocument: IXMLDocument;
  lGroup, lNode: IXMLNode;
  lProperties: TArray<TDelphiSemanticProperty>;
  lDiagnostics: TArray<TDelphiSemanticDiagnostic>;
  lAliases: TArray<string>;
  lMatches, lFound: Boolean;
  i, j, k: Integer;
begin
  fDefaultAliasesKnown := False;
  if fSdkSourceRoot = '' then
    Exit;
  lTargets := TPath.Combine(TPath.GetDirectoryName(
    ExcludeTrailingPathDelimiter(fSdkSourceRoot)), 'bin\CodeGear.Common.Targets');
  lLoaded := TDelphiSemanticSourceLoader.LoadFile(lTargets);
  if not lLoaded.Success then
    Exit;
  fIdentityLines.Add('witness-default-aliases=' + lTargets + '|' + lLoaded.Source.ContentHash);
  SetLength(lProperties, 2);
  lProperties[0].Name := 'Platform';
  lProperties[0].Value := fProject.Platform;
  lProperties[1].Name := 'UnitAliases';
  lFound := False;
  try
    lDocument := LoadWitnessXml(lLoaded.Source.Text);
    for i := 0 to lDocument.DocumentElement.ChildNodes.Count - 1 do
    begin
      lGroup := lDocument.DocumentElement.ChildNodes[i];
      if not SameText(lGroup.LocalName, 'PropertyGroup') then
        Continue;
      for j := 0 to lGroup.ChildNodes.Count - 1 do
      begin
        lNode := lGroup.ChildNodes[j];
        if not SameText(lNode.LocalName, 'UnitAliases') and
          not (StartsText('c', lNode.LocalName) and EndsText('Platform', lNode.LocalName)) then
          Continue;
        // The final assignment combines project aliases; conflict checks use their union.
        if Pos('$(DCC_UnitAlias)', lNode.Text) > 0 then
          Continue;
        for lCondition in [WitnessCondition(lGroup), WitnessCondition(lNode)] do
        begin
          if not TDelphiSemanticMsBuild.TryEvaluateCondition(lCondition,
            ExtractFilePath(lTargets), lProperties, nil, lMatches, lError, lDiagnostics) or
            (Length(lDiagnostics) <> 0) then
            Exit;
          if not lMatches then
            Break;
        end;
        if not lMatches then
          Continue;
        lValue := TDelphiSemanticMsBuild.ExpandMacros(lNode.Text, lProperties, nil,
          False, lDiagnostics);
        if (Length(lDiagnostics) <> 0) or (Pos('$(', lValue) > 0) then
          Exit;
        if SameText(lNode.LocalName, 'UnitAliases') then
        begin
          lProperties[1].Value := lValue;
          lFound := True;
        end else begin
          k := Length(lProperties);
          SetLength(lProperties, k + 1);
          lProperties[k].Name := lNode.LocalName;
          lProperties[k].Value := lValue;
        end;
      end;
    end;
    if not lFound then
      Exit;
    lAliases := lProperties[1].Value.Split([';'], TStringSplitOptions.ExcludeEmpty);
    // Distinct targets for one key are unknown; exact duplicates are harmless.
    fProject.UnitAliases := fProject.UnitAliases + lAliases;
    fDefaultAliasesKnown := True;
  except
    on E: Exception do
      // Malformed or unreadable targets cannot authorize an alias-key absence.
      fIdentityLines.Add('witness-default-aliases-unknown=' + E.ClassName);
  end;
end;

function TUnitNameWitness.CandidateNames(const aUnitName: string): TArray<TUnitCandidateName>;
begin
  Result := TDelphiSemanticUnitResolver.CandidateNames(fProject, aUnitName);
end;

function TUnitNameWitness.ResolveSdkInclude(const aArgument, aIncludingFile,
  aRootFile: string; out aFileName: string): Boolean;
var
  lDirectory, lCandidate: string;
begin
  aFileName := '';
  // SDK DCUs never consume project -I paths. Both allowed SDK locations must agree.
  for lDirectory in [ExtractFilePath(aIncludingFile), ExtractFilePath(aRootFile)] do
  begin
    lCandidate := TDelphiSemanticCacheIdentityBuilder.CanonicalPath(
      TPath.Combine(lDirectory, aArgument));
    if not StartsText(fSdkSourceRoot, lCandidate) then
      Exit(False);
    if not TFile.Exists(lCandidate) then
      Continue;
    if (aFileName <> '') and not SameText(aFileName, lCandidate) then
      Exit(False);
    aFileName := lCandidate;
  end;
  Result := aFileName <> '';
end;

function TUnitNameWitness.ResolveSource(const aUnitName: string;
  out aFileName, aReason, aResolvedName: string): Boolean;
var
  lName: TUnitCandidateName;
  lNames: TArray<TUnitCandidateName>;
  lKeyProject: TDelphiSemanticProjectInfo;
  lPath: string;
  lPaths: TList<string>;
  lHasDcu: Boolean;
begin
  Result := False;
  aFileName := '';
  aResolvedName := '';
  aReason := 'no-source';
  if not fLocationsKnown then
  begin
    aReason := 'profile-locations-unproved';
    Exit;
  end;
  if not fDefaultAliasesKnown and MatchText(aUnitName, ['Generics.Collections',
    'Generics.Defaults', 'WinTypes', 'WinProcs', 'DbiTypes', 'DbiProcs', 'DbiErrs']) then
  begin
    aReason := 'default-aliases-unproved';
    Exit;
  end;
  lNames := CandidateNames(aUnitName);
  if Length(lNames) = 0 then
  begin
    aReason := 'alias-conflict';
    Exit;
  end;
  // Scan the alias target and original spelling union. The same physical
  // source reached by scope expansion is one candidate, never an ambiguity.
  if not SameText(lNames[0].TargetName, aUnitName) then
  begin
    lKeyProject := fProject;
    lKeyProject.UnitAliases := nil;
    lNames := lNames + TDelphiSemanticUnitResolver.CandidateNames(lKeyProject, aUnitName);
  end;
  lHasDcu := False;
  // Any second Pascal source is an extra candidate, including a second SDK copy.
  for lName in lNames do
    if fRtlFiles.TryGetValue(lName.TargetName, lPaths) then
      for lPath in lPaths do
      begin
        if SameText(TPath.GetExtension(lPath), '.dcu') then
        begin
          lHasDcu := True;
          Continue;
        end;
        if (aFileName <> '') and not SameText(aFileName, lPath) then
        begin
          aReason := 'ambiguous-source';
          Exit;
        end;
        aFileName := lPath;
        aResolvedName := lName.TargetName;
      end;
  if aFileName = '' then
  begin
    if lHasDcu then
      aReason := 'dcu-only';
    Exit;
  end;
  for lName in lNames do
    if fRtlFiles.TryGetValue(lName.TargetName, lPaths) then
      for lPath in lPaths do
        if SameText(TPath.GetExtension(lPath), '.dcu') then
        begin
          if (fSdkSourceRoot = '') or not StartsText(fSdkSourceRoot, aFileName) or
            not StartsText(fSdkLibraryRoot, lPath) or
            not SameText(TPath.GetFileNameWithoutExtension(lPath),
              TPath.GetFileNameWithoutExtension(aFileName)) then
          begin
            aReason := 'ambiguous-source';
            Exit;
          end;
          // Coordinator N1 amendment: installed SDK DCU/source is one candidate.
          fIdentityLines.Add('witness-sdk-pair=' + aUnitName + '|' + lPath + '|' + aFileName);
        end;
  if not lHasDcu or (fSdkSourceRoot = '') or
    not StartsText(fSdkSourceRoot, aFileName) then
  begin
    aReason := 'not-sdk-paired';
    Exit;
  end;
  Result := True;
end;

function TUnitNameWitness.ScanFile(const aUnitName, aFileName: string;
  const aEntry: TWitnessEntry; const aSeen: TDictionary<string, Byte>; const aRootFile: string;
  const aIsInclude: Boolean; out aReason: string): Boolean;
var
  i, j, lStart, lEnd, lBrace, lParen: Integer;
  lCanonical, lPrefix, lText, lArgument, lIncludeFile: string;
  lLoaded: TDelphiSemanticSourceLoadResult;
begin
  aReason := '';
  lCanonical := TDelphiSemanticCacheIdentityBuilder.CanonicalPath(aFileName);
  if aSeen.ContainsKey(lCanonical) then
    Exit(True);
  aSeen.Add(lCanonical, 0);
  lLoaded := TDelphiSemanticSourceLoader.LoadFile(aFileName);
  if not lLoaded.Success then
  begin
    aReason := 'unreadable';
    Exit(False);
  end;
  lPrefix := 'witness=';
  if aIsInclude then
    lPrefix := 'witness-include=';
  fIdentityLines.Add(lPrefix + aUnitName + '|' + lCanonical + '|' + lLoaded.Source.ContentHash);
  lText := lLoaded.Source.Text;
  i := 1;
  while i <= Length(lText) do
    if IsIdentifierStart(lText[i]) then
    begin
      j := i + 1;
      while (j <= Length(lText)) and IsIdentifierPart(lText[j]) do
        Inc(j);
      aEntry.Tokens.AddOrSetValue(Copy(lText, i, j - i), 0);
      i := j;
    end else
      Inc(i);
  i := 1;
  // Advance each directive search independently; an absent form stays exhausted.
  lBrace := Pos('{$', lText, i);
  lParen := Pos('(*$', lText, i);
  while i <= Length(lText) do
  begin
    if (lBrace = 0) and (lParen = 0) then
      Break;
    if (lBrace > 0) and ((lParen = 0) or (lBrace < lParen)) then
    begin
      lStart := lBrace + 2;
      lEnd := Pos('}', lText, lStart);
      lBrace := Pos('{$', lText, lStart);
    end else begin
      lStart := lParen + 3;
      lEnd := Pos('*)', lText, lStart);
      lParen := Pos('(*$', lText, lStart);
    end;
    // Every opener is independent, including inert text overlapping a real include.
    // An unterminated non-include is harmless; an include tail remains unproved.
    if lEnd = 0 then
      lEnd := Length(lText) + 1;
    lArgument := TDelphiSemanticPreprocessor.IncludeArgumentFromDirective(
      Copy(lText, lStart, lEnd - lStart));
    if (lArgument = '') or StartsStr('%', lArgument) then
      Continue;
    try
      if not ResolveSdkInclude(lArgument, aFileName, aRootFile, lIncludeFile) then
      begin
        aReason := 'include-unresolved';
        Exit(False);
      end;
    except
      on E: EArgumentException do
      begin
        // Include-looking inert text may contain characters invalid in a path.
        aReason := 'include-unresolved';
        Exit(False);
      end;
    end;
    if not ScanFile(aUnitName, lIncludeFile, aEntry, aSeen, aRootFile, True, aReason) then
      Exit(False);
  end;
  Result := True;
end;

procedure TUnitNameWitness.AddEntry(const aUnitName: string);
var
  g: TGarbos;
  lEntry: TWitnessEntry;
  lSeen: TDictionary<string, Byte>;
  lFileName, lReason, lResolvedName, lDeclaredName: string;
begin
  lEntry := TWitnessEntry.Create;
  fEntries.Add(aUnitName, lEntry);
  GC(lSeen, TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase), g);
  if ResolveSource(aUnitName, lFileName, lReason, lResolvedName) then
  begin
    lEntry.Known := ScanFile(aUnitName, lFileName, lEntry, lSeen, lFileName, False, lReason);
    if lEntry.Known then
    begin
      try
        lEntry.Known := TDelphiSemanticUnitResolver.TryReadDeclaredUnitName(lFileName,
          lDeclaredName) and SameText(lDeclaredName, lResolvedName);
        if not lEntry.Known then
          lReason := 'unit-name-mismatch';
      except
        on E: Exception do
        begin
          // A failed source read can never establish an absence proof.
          lEntry.Known := False;
          lReason := 'unreadable';
        end;
      end;
    end;
  end;
  if not lEntry.Known then
    fIdentityLines.Add('witness=' + aUnitName + '|unknown|' + lReason);
end;

function TUnitNameWitness.MayDeclare(const aUnitName, aName: string): Boolean;
var
  i: Integer;
  lEntry: TWitnessEntry;
begin
  Result := True;
  if (aName = '') or not IsIdentifierStart(aName[1]) then
    Exit;
  for i := 2 to Length(aName) do
    if not IsIdentifierPart(aName[i]) then
      Exit;
  if not fEntries.TryGetValue(aUnitName, lEntry) or not lEntry.Known then
    Exit;
  Result := lEntry.Tokens.ContainsKey(aName);
end;

function TUnitNameWitness.IdentityText: string;
var
  lLines: TArray<string>;
begin
  lLines := fIdentityLines.ToArray;
  TArray.Sort<string>(lLines, TStringComparer.Ordinal);
  Result := string.Join(sLineBreak, lLines);
end;

class function TDelphiSemanticUnitNameWitnessBuilder.Build(
  const aProject: TDelphiSemanticProjectInfo; const aModels: TArray<TDelphiSemanticUnitModel>;
  const aRtlSourceRoot: string): IDelphiSemanticUnitNameWitness;
begin
  Result := TUnitNameWitness.Create(aProject, aModels, aRtlSourceRoot);
end;

end.
