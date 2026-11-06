unit DelphiSemantics.Resolve.UnitNameWitness;

interface

uses
  DelphiSemantics.Model, DelphiSemantics.ProjectContext;

type
{$IFDEF DS_PROJECT_SESSION_TEST_SUPPORT}
  TWitnessBeforeEntries = reference to procedure;
  TWitnessLookupTestOptions = record
    CaptureNativeQueries: Boolean;
    CaptureDirectoryListings: Boolean;
    BeforeEntries: TWitnessBeforeEntries;
    ForcedPreimages: string;
    LookupErrorDirectory: string;
    LookupError: Cardinal;
  end;
  PWitnessLookupTestOptions = ^TWitnessLookupTestOptions;
{$ENDIF}

  IDelphiSemanticUnitNameWitness = interface
    ['{40DA7787-E5D3-4995-A535-6892C585AD7D}']
    function MayDeclare(const aUnitName, aName: string): Boolean;
    function IdentityText: string;
  end;

  // Optional capability: callers must not infer SDK pairing from token presence.
  IDelphiSemanticSdkUnitPairing = interface
    ['{F2B37AB0-BA06-457A-A61C-61E225617AAE}']
    function IsSdkPaired(const aUnitName: string): Boolean;
  end;

  TDelphiSemanticUnitNameWitnessBuilder = record
  public
    class function Build(const aProject: TDelphiSemanticProjectInfo;
      const aModels: TArray<TDelphiSemanticUnitModel>;
      const aRtlSourceRoot: string): IDelphiSemanticUnitNameWitness; static;
{$IFDEF DS_PROJECT_SESSION_TEST_SUPPORT}
    class function BuildForTest(const aProject: TDelphiSemanticProjectInfo;
      const aModels: TArray<TDelphiSemanticUnitModel>; const aRtlSourceRoot: string;
      const aFullEnumeration: Boolean; out aCandidates: TArray<string>): IDelphiSemanticUnitNameWitness; overload; static;
    class function BuildForTest(const aProject: TDelphiSemanticProjectInfo;
      const aModels: TArray<TDelphiSemanticUnitModel>; const aRtlSourceRoot: string;
      const aFullEnumeration: Boolean; out aCandidates: TArray<string>;
      out aBoundedQueries, aLookupFallbacks: Integer): IDelphiSemanticUnitNameWitness; overload; static;
    class function BuildForTest(const aProject: TDelphiSemanticProjectInfo;
      const aModels: TArray<TDelphiSemanticUnitModel>; const aRtlSourceRoot: string;
      const aFullEnumeration: Boolean; const aOptions: TWitnessLookupTestOptions;
      out aCandidates, aNativeQueries: TArray<string>;
      out aBoundedQueries, aLookupFallbacks: Integer): IDelphiSemanticUnitNameWitness; overload; static;
{$ENDIF}
  end;

implementation

uses
  System.Generics.Collections, System.Generics.Defaults, System.IOUtils, System.Masks, System.StrUtils,
  System.SysUtils,
  Winapi.Windows,
  Xml.omnixmldom, Xml.XMLDoc, Xml.xmldom, Xml.XMLIntf,
  AutoFree, MaxLogic.StrUtils,
  DelphiSemantics.Cache, DelphiSemantics.Preprocess, DelphiSemantics.Resolve.UnitResolver,
  DelphiSemantics.SemanticGraph, DelphiSemantics.Source;

type
  TWitnessQueryMasks = class sealed
  private
    class var fNonAsciiPreimage: array[0..127] of Boolean;
    class constructor Create;
  public
    class function ForName(const aName: string
{$IFDEF DS_PROJECT_SESSION_TEST_SUPPORT}
      ; const aForcedPreimages: string
{$ENDIF}
      ): string; static;
    class function SeparatorsProved(
{$IFDEF DS_PROJECT_SESSION_TEST_SUPPORT}
      const aForcedPreimages: string
{$ENDIF}
      ): Boolean; static;
  end;

  TWitnessEntry = class
    Known: Boolean;
    Tokens: TDictionary<string, Byte>;
    constructor Create;
    destructor Destroy; override;
  end;

  TUnitNameWitness = class(TInterfacedObject, IDelphiSemanticUnitNameWitness,
    IDelphiSemanticSdkUnitPairing)
  private
    fFullEnumeration: Boolean;
{$IFDEF DS_PROJECT_SESSION_TEST_SUPPORT}
    fBoundedQueries, fLookupFallbacks: Integer;
    fTestOptions: TWitnessLookupTestOptions;
    fNativeQueries: TArray<string>;
{$ENDIF}
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
    function WitnessFilesNamed(const aDirectory, aName, aExtension: string;
      out aFiles: TArray<string>): Boolean;
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
      const aModels: TArray<TDelphiSemanticUnitModel>; const aRtlSourceRoot: string;
      const aFullEnumeration: Boolean = False
{$IFDEF DS_PROJECT_SESSION_TEST_SUPPORT}
      ; const aTestOptions: PWitnessLookupTestOptions = nil
{$ENDIF}
      );
    destructor Destroy; override;
    function IsSdkPaired(const aUnitName: string): Boolean;
    function MayDeclare(const aUnitName, aName: string): Boolean;
    function IdentityText: string;
  end;

class constructor TWitnessQueryMasks.Create;
var
  lComparer: IEqualityComparer<string>;
  lCharacter: Char;
  lCode: Integer;
begin
  // Immutable after unit initialization. CharUpperW is language-neutral; no
  // directory/profile inputs or mutable filesystem inventories are retained.
  lComparer := TFastCaseAwareComparer.Create(False);
  for lCode := 128 to High(Word) do
    for lCharacter in 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.' do
      if lComparer.Equals(string(Char(lCode)), string(lCharacter)) then
        fNonAsciiPreimage[Ord(lCharacter)] := True;
end;

class function TWitnessQueryMasks.ForName(const aName: string
{$IFDEF DS_PROJECT_SESSION_TEST_SUPPORT}
      ; const aForcedPreimages: string
{$ENDIF}
      ): string;
var
  i: Integer;
begin
  Result := aName;
  for i := 1 to Length(Result) do
    if fNonAsciiPreimage[Ord(Result[i])]
{$IFDEF DS_PROJECT_SESSION_TEST_SUPPORT}
      or (Pos(Result[i], aForcedPreimages) > 0)
{$ENDIF}
      then
      Result[i] := '?';
end;

class function TWitnessQueryMasks.SeparatorsProved(
{$IFDEF DS_PROJECT_SESSION_TEST_SUPPORT}
      const aForcedPreimages: string
{$ENDIF}
      ): Boolean;
begin
  // A DOS '?' stops at dots, so an unproved separator requires enumeration.
  Result := not fNonAsciiPreimage[Ord('.')]
{$IFDEF DS_PROJECT_SESSION_TEST_SUPPORT}
    and (Pos('.', aForcedPreimages) = 0)
{$ENDIF}
    ;
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
  const aModels: TArray<TDelphiSemanticUnitModel>; const aRtlSourceRoot: string;
  const aFullEnumeration: Boolean
{$IFDEF DS_PROJECT_SESSION_TEST_SUPPORT}
  ; const aTestOptions: PWitnessLookupTestOptions
{$ENDIF}
  );
var
  g: TGarbos;
  lIndexed: TDictionary<string, Byte>;
  lImports, lImplementation: TArray<string>;
  lModel: TDelphiSemanticUnitModel;
  lCandidate: TUnitCandidateName;
  lPath, lName, lDirectory, lProfilePaths: string;
begin
  inherited Create;
  fFullEnumeration := aFullEnumeration;
{$IFDEF DS_PROJECT_SESSION_TEST_SUPPORT}
  if aTestOptions <> nil then
    fTestOptions := aTestOptions^;
{$ENDIF}
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
{$IFDEF DS_PROJECT_SESSION_TEST_SUPPORT}
  if Assigned(fTestOptions.BeforeEntries) then
    fTestOptions.BeforeEntries();
{$ENDIF}
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

function GetWitnessFileInformation(const aHandle: THandle; const aInfoClass: Integer;
  const aBuffer: Pointer; const aSize: DWORD): BOOL; stdcall;
  external kernel32 name 'GetFileInformationByHandleEx';

function GetWitnessFinalPath(const aHandle: THandle; const aPath: PWideChar;
  const aSize, aFlags: DWORD): DWORD; stdcall;
  external kernel32 name 'GetFinalPathNameByHandleW';

function CanQueryWitnessNames(const aDirectory: string): Boolean;
const
  cFileCaseSensitiveInfo = 23;
var
  lHandle: THandle;
  lFlags, lLength: DWORD;
  lFinalPath, lVolumePath: array[0..MAX_PATH - 1] of Char;
  lFileSystem: array[0..31] of Char;
  lPath: string;
begin
  // Only proven local filesystem semantics qualify, including through junctions.
  Result := False;
  lHandle := CreateFile(PChar(aDirectory), FILE_READ_ATTRIBUTES,
    FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE, nil, OPEN_EXISTING,
    FILE_FLAG_BACKUP_SEMANTICS, 0);
  if lHandle = INVALID_HANDLE_VALUE then
    Exit;
  try
    lLength := GetWitnessFinalPath(lHandle, @lFinalPath[0], Length(lFinalPath), 0);
    if (lLength = 0) or (lLength >= DWORD(Length(lFinalPath))) then
      Exit;
    lPath := string(lFinalPath);
    if not lPath.StartsWith('\\?\') or lPath.StartsWith('\\?\UNC\', True) then
      Exit;
    lPath := Copy(lPath, 5, MaxInt);
    if not GetVolumePathName(PChar(lPath), @lVolumePath[0], Length(lVolumePath)) or
      (GetDriveType(@lVolumePath[0]) <> DRIVE_FIXED) then
      Exit;
    if not GetVolumeInformation(@lVolumePath[0], nil, 0, nil, lFlags, lLength,
      @lFileSystem[0], Length(lFileSystem)) then
      Exit;
    if not SameText(string(lFileSystem), 'NTFS') and not SameText(string(lFileSystem), 'ReFS') then
      Exit;
    lFlags := 0;
    Result := GetWitnessFileInformation(lHandle, cFileCaseSensitiveInfo,
      @lFlags, SizeOf(lFlags)) and (lFlags = 0);
  finally
    CloseHandle(lHandle);
  end;
end;

function TUnitNameWitness.WitnessFilesNamed(const aDirectory, aName, aExtension: string;
  out aFiles: TArray<string>): Boolean;
var
  lHandle: THandle;
  lData: TWin32FindData;
  lFileName, lMask: string;
  lPaths: TList<string>;
  lError: DWORD;
begin
  Result := False;
  aFiles := nil;
  // Admit every comparer-equal non-ASCII preimage independently of filesystem
  // case tables, then filter actual long names. ASCII case matching is proved
  // only for local, case-insensitive NTFS/ReFS directories.
  lMask := TWitnessQueryMasks.ForName(aName
{$IFDEF DS_PROJECT_SESSION_TEST_SUPPORT}
    , fTestOptions.ForcedPreimages
{$ENDIF}
    ) + '.???';
  lPaths := TList<string>.Create;
  try
{$IFDEF DS_PROJECT_SESSION_TEST_SUPPORT}
    if fTestOptions.CaptureNativeQueries then
      fNativeQueries := fNativeQueries + [TPath.Combine(aDirectory, lMask)];
    if (fTestOptions.LookupError <> 0) and
      SameText(aDirectory, fTestOptions.LookupErrorDirectory) then
    begin
      lHandle := INVALID_HANDLE_VALUE;
      SetLastError(fTestOptions.LookupError);
    end else
{$ENDIF}
    lHandle := FindFirstFileEx(PChar(TPath.Combine(aDirectory, lMask)),
      FindExInfoBasic, @lData, FindExSearchNameMatch, nil, 0);
    if lHandle = INVALID_HANDLE_VALUE then
    begin
      // PATH_NOT_FOUND can mean a directory vanished after Exists; let the RTL
      // retain its own exception/unknown-location behavior. Only no match is absent.
      Exit(GetLastError = ERROR_FILE_NOT_FOUND);
    end;
    try
      repeat
        lFileName := string(lData.cFileName);
        // Windows masks can also match 8.3 aliases. Only the long filename counts.
        if (lData.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY = 0) and
          TPath.MatchesPattern(lFileName, '*' + aExtension, False) and
          TFastCaseAwareComparer.OrdinalIgnoreCase.Equals(
            TPath.GetFileNameWithoutExtension(lFileName), aName) then
          lPaths.Add(TPath.Combine(aDirectory, lFileName));
      until not FindNextFile(lHandle, lData);
      lError := GetLastError;
      if lError <> ERROR_NO_MORE_FILES then
        Exit;
    finally
      Winapi.Windows.FindClose(lHandle);
    end;
    aFiles := lPaths.ToArray;
    Result := True;
  finally
    lPaths.Free;
  end;
end;

function IsReservedWitnessName(const aName: string): Boolean;
var
  lSegment: string;
  lDot: Integer;
begin
  // Win32 interprets device names even with an extension or dotted unit suffix.
  lDot := Pos('.', aName);
  lSegment := aName;
  if lDot > 0 then
    lSegment := Copy(aName, 1, lDot - 1);
  Result := MatchText(lSegment, ['CON', 'PRN', 'AUX', 'NUL']);
  if Length(lSegment) = 4 then
    Result := Result or ((SameText(Copy(lSegment, 1, 3), 'COM') or
      SameText(Copy(lSegment, 1, 3), 'LPT')) and CharInSet(lSegment[4], ['0'..'9']));
end;

procedure TUnitNameWitness.IndexDirectory(const aDirectory: string; const aRecursive: Boolean);
const
  // Two extension queries per name, capped at 64 queries per directory.
  // At 32 names our installed SDK measurement used 4.4 ms/build bounded versus
  // 33.8 ms/build listing. Larger sets use one listing to bound metadata work.
  cMaxBoundedNames = 32;
var
  lPath, lName, lExtension, lCanonical: string;
  lPaths: TList<string>;
  lSearch: TSearchOption;
  lNames: TArray<string>;
  lFiles, lInventory: TArray<string>;
  lBounded, lUseInventory: Boolean;
  lCharacter: Char;
begin
  if aDirectory = '' then
    Exit;
  lSearch := TSearchOption.soTopDirectoryOnly;
  if aRecursive then
    lSearch := TSearchOption.soAllDirectories;
  try
    if not TDirectory.Exists(aDirectory) then
      Exit;
    lBounded := (fNeededNames.Count <= cMaxBoundedNames) and
      not aRecursive and not fFullEnumeration and
      TWitnessQueryMasks.SeparatorsProved(
{$IFDEF DS_PROJECT_SESSION_TEST_SUPPORT}
        fTestOptions.ForcedPreimages
{$ENDIF}
        ) and CanQueryWitnessNames(aDirectory);
    lNames := fNeededNames.Keys.ToArray;
    for lName in lNames do
    begin
      if (lName = '') or lName.StartsWith('.') or lName.EndsWith('.') or
        (Pos('..', lName) > 0) or IsReservedWitnessName(lName) then
        lBounded := False;
      for lCharacter in lName do
        if not CharInSet(lCharacter, ['A'..'Z', 'a'..'z', '0'..'9', '_', '.']) then
          lBounded := False;
      if lBounded then
        if Length(TPath.GetFullPath(TPath.Combine(aDirectory, lName + '.dcu'))) >= MAX_PATH - 1 then
          lBounded := False;
    end;
    if not lBounded then
      lNames := [''];
    // Retain the reference recursive walk (including reparse traversal). For
    // ordinary lookup roots the RTL already walks '*', applying its pattern in
    // memory. List once and apply that same matcher, in PAS then DCU order.
    // This inventory lives only for this call; source bytes are still read at
    // AddEntry/ScanFile time, and the next witness always observes a fresh list.
    lUseInventory := not lBounded and not aRecursive and not fFullEnumeration;
    if lUseInventory then
    begin
{$IFDEF DS_PROJECT_SESSION_TEST_SUPPORT}
      if fTestOptions.CaptureDirectoryListings then
        fNativeQueries := fNativeQueries + [aDirectory];
{$ENDIF}
      lInventory := TDirectory.GetFiles(aDirectory, '*', lSearch);
    end;
    for lExtension in ['.pas', '.dcu'] do
      for lName in lNames do
      begin
        if lBounded then
        begin
{$IFDEF DS_PROJECT_SESSION_TEST_SUPPORT}
          Inc(fBoundedQueries);
{$ENDIF}
          if not WitnessFilesNamed(aDirectory, lName, lExtension, lFiles) then
          begin
{$IFDEF DS_PROJECT_SESSION_TEST_SUPPORT}
            Inc(fLookupFallbacks);
{$ENDIF}
            // Discard the incomplete query and preserve the reference enumeration.
            lFiles := TDirectory.GetFiles(aDirectory, '*' + lExtension, lSearch);
          end;
        end else if lUseInventory then
          lFiles := lInventory
        else
          lFiles := TDirectory.GetFiles(aDirectory, '*' + lExtension, lSearch);
        for lPath in lFiles do
        begin
          if lUseInventory and not MatchesMask(ExtractFileName(lPath), '*' + lExtension) then
            Continue;
          lCanonical := TPath.GetFileNameWithoutExtension(lPath);
          if not fNeededNames.ContainsKey(lCanonical) then
            Continue;
          if not fRtlFiles.TryGetValue(lCanonical, lPaths) then
          begin
            lPaths := TList<string>.Create;
            fRtlFiles.Add(lCanonical, lPaths);
          end;
          lCanonical := TDelphiSemanticCacheIdentityBuilder.CanonicalPath(lPath);
          if lPaths.IndexOf(lCanonical) < 0 then
            lPaths.Add(lCanonical);
        end;
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
      TPath.Combine(lDirectory, TDelphiSemanticPreprocessor.CompilerIncludeFileName(aArgument)));
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
  // Package membership is not indexed. Even an SDK pair cannot exclude an
  // alternative unit supplied through a runtime package.
  // CodeGear.Delphi.Targets activates the saved list only for these switches.
  if ((SameText(fProject.PropertyValue('UsePackages'), 'true') or
    SameText(fProject.PropertyValue('DCC_EnabledPackages'), 'true')) and
    (Trim(fProject.PropertyValue('DCC_UsePackage')) <> '')) or
    (Trim(fProject.PropertyValue('_UsePackage')) <> '') or
    (Pos('-LU', UpperCase(fProject.PropertyValue('DCC_AdditionalSwitches'))) > 0) then
  begin
    aReason := 'runtime-packages-unmodelled';
    Exit;
  end;
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

function TUnitNameWitness.IsSdkPaired(const aUnitName: string): Boolean;
var
  lEntry: TWitnessEntry;
begin
  // Known entries exist only after ResolveSource verified SDK DCU/source pairing,
  // scanning and declared-unit identity. DS-768's conservative lookup is unchanged.
  Result := fEntries.TryGetValue(aUnitName, lEntry) and lEntry.Known;
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

{$IFDEF DS_PROJECT_SESSION_TEST_SUPPORT}
class function TDelphiSemanticUnitNameWitnessBuilder.BuildForTest(
  const aProject: TDelphiSemanticProjectInfo; const aModels: TArray<TDelphiSemanticUnitModel>;
  const aRtlSourceRoot: string; const aFullEnumeration: Boolean;
  out aCandidates: TArray<string>): IDelphiSemanticUnitNameWitness;
var
  lBoundedQueries, lLookupFallbacks: Integer;
begin
  Result := BuildForTest(aProject, aModels, aRtlSourceRoot, aFullEnumeration,
    aCandidates, lBoundedQueries, lLookupFallbacks);
end;

class function TDelphiSemanticUnitNameWitnessBuilder.BuildForTest(
  const aProject: TDelphiSemanticProjectInfo; const aModels: TArray<TDelphiSemanticUnitModel>;
  const aRtlSourceRoot: string; const aFullEnumeration: Boolean;
  out aCandidates: TArray<string>; out aBoundedQueries, aLookupFallbacks: Integer): IDelphiSemanticUnitNameWitness;
var
  lOptions: TWitnessLookupTestOptions;
  lNativeQueries: TArray<string>;
begin
  lOptions := Default(TWitnessLookupTestOptions);
  Result := BuildForTest(aProject, aModels, aRtlSourceRoot, aFullEnumeration,
    lOptions, aCandidates, lNativeQueries, aBoundedQueries, aLookupFallbacks);
end;

class function TDelphiSemanticUnitNameWitnessBuilder.BuildForTest(
  const aProject: TDelphiSemanticProjectInfo; const aModels: TArray<TDelphiSemanticUnitModel>;
  const aRtlSourceRoot: string; const aFullEnumeration: Boolean;
  const aOptions: TWitnessLookupTestOptions; out aCandidates, aNativeQueries: TArray<string>;
  out aBoundedQueries, aLookupFallbacks: Integer): IDelphiSemanticUnitNameWitness;
var
  lWitness: TUnitNameWitness;
  lNames: TArray<string>;
  lName, lPath: string;
  lLines: TList<string>;
begin
  lWitness := TUnitNameWitness.Create(aProject, aModels, aRtlSourceRoot, aFullEnumeration, @aOptions);
  Result := lWitness;
  aNativeQueries := lWitness.fNativeQueries;
  aBoundedQueries := lWitness.fBoundedQueries;
  aLookupFallbacks := lWitness.fLookupFallbacks;
  lLines := TList<string>.Create;
  try
    lNames := lWitness.fRtlFiles.Keys.ToArray;
    TArray.Sort<string>(lNames, TStringComparer.Ordinal);
    for lName in lNames do
      for lPath in lWitness.fRtlFiles[lName] do
        lLines.Add(lName + '|' + lPath);
    aCandidates := lLines.ToArray;
  finally
    lLines.Free;
  end;
end;
{$ENDIF}

end.
