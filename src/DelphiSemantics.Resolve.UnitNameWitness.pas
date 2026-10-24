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
  System.SysUtils,
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
    fLocationsKnown: Boolean;
    fSdkSourceRoot, fSdkLibraryRoot: string;
    procedure IndexDirectory(const aDirectory: string; const aRecursive: Boolean);
    class function IsIdentifierStart(const aChar: Char): Boolean; static;
    class function IsIdentifierPart(const aChar: Char): Boolean; static;
    function ResolveSource(const aUnitName: string; out aFileName, aReason,
      aResolvedName: string): Boolean;
    function ScanFile(const aUnitName, aFileName: string; const aEntry: TWitnessEntry;
      const aSeen: TDictionary<string, Byte>; const aIsInclude: Boolean;
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
  for lModel in aModels do
  begin
    TDelphiSemanticSemanticGraphBuilder.ProjectImports(aProject, lModel, aModels,
      lImports, lImplementation);
    for lName in lImports + lImplementation do
      for lCandidate in TDelphiSemanticUnitResolver.CandidateNames(aProject, lName) do
        fNeededNames.AddOrSetValue(lCandidate.TargetName, 0);
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

function TUnitNameWitness.ResolveSource(const aUnitName: string;
  out aFileName, aReason, aResolvedName: string): Boolean;
var
  lName: TUnitCandidateName;
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
  lHasDcu := False;
  // Any second Pascal source is an extra candidate, including a second SDK copy.
  for lName in TDelphiSemanticUnitResolver.CandidateNames(fProject, aUnitName) do
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
  for lName in TDelphiSemanticUnitResolver.CandidateNames(fProject, aUnitName) do
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
  Result := True;
end;

function TUnitNameWitness.ScanFile(const aUnitName, aFileName: string;
  const aEntry: TWitnessEntry; const aSeen: TDictionary<string, Byte>;
  const aIsInclude: Boolean; out aReason: string): Boolean;
var
  i, j, lStart, lEnd, lBrace, lParen: Integer;
  lCanonical, lPrefix, lText, lArgument, lIncludeFile: string;
  lLoaded: TDelphiSemanticSourceLoadResult;
  lOptions: TDelphiSemanticPreprocessOptions;
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
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SearchPaths := fProject.IncludePaths + fProject.SourceLookupPaths;
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
      if not TDelphiSemanticPreprocessor.ResolveIncludeFileName(lArgument,
        ExtractFilePath(aFileName), lOptions, lIncludeFile) then
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
    if not ScanFile(aUnitName, lIncludeFile, aEntry, aSeen, True, aReason) then
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
    lEntry.Known := ScanFile(aUnitName, lFileName, lEntry, lSeen, False, lReason);
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
