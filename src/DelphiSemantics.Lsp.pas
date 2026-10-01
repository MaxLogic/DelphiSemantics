unit DelphiSemantics.Lsp;

interface

uses
  System.Generics.Collections, System.JSON,
  DelphiSemantics.Resolve;

const
  cDelphiSemanticLspEnrichmentUnsupportedCode = 'lsp.enrichment.unsupported';
  cDelphiSemanticLspEnrichmentUnsupportedMessage =
    'LSP enrichment is explicitly unsupported in this DelphiSemantics build.';

type
  TDelphiSemanticLspOptions = record
    Enabled: Boolean;
  end;

  TDelphiSemanticLspLocation = record
    FileName: string;
    Line: Integer;
    Column: Integer;
  end;

  TDelphiSemanticLspProtocolPosition = record
    Line: Integer;
    Character: Integer;
  end;

  TDelphiSemanticLspRange = record
    StartLine: Integer;
    StartColumn: Integer;
    EndLine: Integer;
    EndColumn: Integer;
  end;

  TDelphiSemanticLspResult = record
    Found: Boolean;
    Authoritative: Boolean;
    Status: string;
    Provenance: string;
    Name: string;
    Kind: string;
    TypeName: string;
    OwnerName: string;
    FileName: string;
    Line: Integer;
    Column: Integer;
    EndLine: Integer;
    EndColumn: Integer;
    ErrorMessage: string;
  end;

  TDelphiSemanticLspHoverResult = record
    Found: Boolean;
    Status: string;
    Provenance: string;
    Contents: string;
    FileName: string;
    Range: TDelphiSemanticLspRange;
  end;

  TDelphiSemanticLspSymbol = record
    Name: string;
    Kind: Integer;
    ContainerName: string;
    FileName: string;
    Line: Integer;
    Column: Integer;
    EndLine: Integer;
    EndColumn: Integer;
    Provenance: string;
  end;

  TDelphiSemanticLspSymbolNode = class
  private
    fChildren: TObjectList<TDelphiSemanticLspSymbolNode>;
  public
    Symbol: TDelphiSemanticLspSymbol;
    constructor Create;
    destructor Destroy; override;
    property Children: TObjectList<TDelphiSemanticLspSymbolNode> read fChildren;
  end;

  TDelphiSemanticLspLifecycle = record
    Initialized: Boolean;
    Shutdown: Boolean;
    Status: string;
    ErrorMessage: string;
  public
    class function StartInitialized: TDelphiSemanticLspLifecycle; static;
    class function ShutdownSession(const aSession: TDelphiSemanticLspLifecycle):
      TDelphiSemanticLspLifecycle; static;
    class function ErrorSession(const aMessage: string): TDelphiSemanticLspLifecycle; static;
  end;

  TDelphiSemanticLspSettings = record
    MainSourcePath: string;
    Defines: TArray<string>;
    UnitSearchPath: TArray<string>;
    LibraryPath: TArray<string>;
    UnitScopes: TArray<string>;
    UnitAliases: TArray<string>;
    // DelphiLSP "dllname": the platform compiler DLL (for example dcc64290.dll).
    // Without it DelphiLSP returns null for hover and most definitions.
    CompilerDllName: string;
  end;

  TDelphiSemanticLspBoundary = record
  public
    class function BuildSettings(const aMainSourcePath: string; const aDefines,
      aUnitSearchPath, aLibraryPath, aUnitScopes, aUnitAliases: TArray<string>):
      TDelphiSemanticLspSettings; static;
    class function BuildDccOptions(const aSettings: TDelphiSemanticLspSettings): string; static;
    class function BuildOfficialSettingsJson(const aSettings: TDelphiSemanticLspSettings): string; static;
    class function EnrichDefinition(const aOptions: TDelphiSemanticLspOptions;
      const aName: string; const aLocation: TDelphiSemanticLspLocation):
      TDelphiSemanticLspResult; static;
    class function FilterSymbols(const aSymbols: TArray<TDelphiSemanticLspSymbol>;
      const aQuery: string; const aLimit: Integer): TArray<TDelphiSemanticLspSymbol>; static;
    class function FlattenSymbolNodes(const aNodes: TArray<TDelphiSemanticLspSymbolNode>;
      const aQuery: string; const aLimit: Integer): TArray<TDelphiSemanticLspSymbol>; static;
    class function FromSemanticResult(const aResult: TDelphiSemanticResolveResult):
      TDelphiSemanticLspResult; static;
    class function FromLocationLink(const aName, aUri: string; const aStartLine,
      aStartCharacter, aEndLine, aEndCharacter: Integer): TDelphiSemanticLspResult; static;
    class function FromProtocolPosition(const aFileName: string;
      const aPosition: TDelphiSemanticLspProtocolPosition): TDelphiSemanticLspLocation; static;
    class function MakeEmptyHover: TDelphiSemanticLspHoverResult; static;
    class function MakeErrorResult(const aMessage: string): TDelphiSemanticLspResult; static;
    class function MakeUnsupportedResult: TDelphiSemanticLspResult; static;
    class function MakeHover(const aContents, aUri: string; const aStartLine, aStartCharacter,
      aEndLine, aEndCharacter: Integer): TDelphiSemanticLspHoverResult; static;
    class function FilePathToUri(const aPath: string): string; static;
    class function NormalizeFileUri(const aUri: string): string; static;
    class function ToProtocolPosition(const aLine, aColumn: Integer):
      TDelphiSemanticLspProtocolPosition; static;
  end;

implementation

uses
  System.StrUtils, System.SysUtils,
  maxLogic.ioUtils;

constructor TDelphiSemanticLspSymbolNode.Create;
begin
  inherited Create;
  fChildren := TObjectList<TDelphiSemanticLspSymbolNode>.Create(True);
end;

destructor TDelphiSemanticLspSymbolNode.Destroy;
begin
  fChildren.Free;
  inherited;
end;

class function TDelphiSemanticLspLifecycle.ErrorSession(
  const aMessage: string): TDelphiSemanticLspLifecycle;
begin
  Result := Default(TDelphiSemanticLspLifecycle);
  Result.Status := 'error';
  Result.ErrorMessage := aMessage;
end;

class function TDelphiSemanticLspLifecycle.ShutdownSession(
  const aSession: TDelphiSemanticLspLifecycle): TDelphiSemanticLspLifecycle;
begin
  Result := aSession;
  Result.Shutdown := True;
  Result.Status := 'shutdown';
end;

class function TDelphiSemanticLspLifecycle.StartInitialized: TDelphiSemanticLspLifecycle;
begin
  Result := Default(TDelphiSemanticLspLifecycle);
  Result.Initialized := True;
  Result.Status := 'initialized';
end;

procedure AddStringArray(aObject: TJSONObject; const aName: string; const aValues: TArray<string>);
var
  lArray: TJSONArray;
  lValue: string;
begin
  lArray := TJSONArray.Create;
  for lValue in aValues do
    lArray.Add(lValue);
  aObject.AddPair(aName, lArray);
end;

function QuoteCompilerPath(const aPath: string): string;
begin
  Result := aPath;
  if (Pos(' ', Result) > 0) and (not Result.StartsWith('"')) then
    Result := '"' + Result + '"';
end;

function JoinCompilerPaths(const aValues: TArray<string>): string;
var
  i: Integer;
  lValues: TArray<string>;
begin
  SetLength(lValues, Length(aValues));
  for i := 0 to High(aValues) do
    lValues[i] := QuoteCompilerPath(aValues[i]);
  Result := String.Join(';', lValues);
end;

class function TDelphiSemanticLspBoundary.BuildSettings(const aMainSourcePath: string;
  const aDefines, aUnitSearchPath, aLibraryPath, aUnitScopes, aUnitAliases: TArray<string>):
  TDelphiSemanticLspSettings;
begin
  Result := Default(TDelphiSemanticLspSettings);
  Result.MainSourcePath := aMainSourcePath;
  Result.Defines := aDefines;
  Result.UnitSearchPath := aUnitSearchPath;
  Result.LibraryPath := aLibraryPath;
  Result.UnitScopes := aUnitScopes;
  Result.UnitAliases := aUnitAliases;
end;

class function TDelphiSemanticLspBoundary.BuildDccOptions(
  const aSettings: TDelphiSemanticLspSettings): string;
var
  lParts: TList<string>;
begin
  lParts := TList<string>.Create;
  try
    if Length(aSettings.Defines) > 0 then
      lParts.Add('-D' + String.Join(';', aSettings.Defines));
    if Length(aSettings.UnitSearchPath) > 0 then
      lParts.Add('-U' + JoinCompilerPaths(aSettings.UnitSearchPath));
    if Length(aSettings.LibraryPath) > 0 then
      lParts.Add('-I' + JoinCompilerPaths(aSettings.LibraryPath));
    if Length(aSettings.UnitScopes) > 0 then
      lParts.Add('-NS' + String.Join(';', aSettings.UnitScopes));
    if Length(aSettings.UnitAliases) > 0 then
      lParts.Add('-A' + String.Join(';', aSettings.UnitAliases));
    Result := String.Join(' ', lParts.ToArray);
  finally
    lParts.Free;
  end;
end;

class function TDelphiSemanticLspBoundary.BuildOfficialSettingsJson(
  const aSettings: TDelphiSemanticLspSettings): string;
var
  lBrowsingPaths: TList<string>;
  lRoot: TJSONObject;
  lSettings: TJSONObject;
  lValue: string;
begin
  lRoot := TJSONObject.Create;
  try
    lSettings := TJSONObject.Create;
    lSettings.AddPair('project', FilePathToUri(aSettings.MainSourcePath));
    if aSettings.CompilerDllName <> '' then
      lSettings.AddPair('dllname', aSettings.CompilerDllName);
    lSettings.AddPair('dccOptions', BuildDccOptions(aSettings));
    lSettings.AddPair('projectFiles', TJSONArray.Create);
    lSettings.AddPair('includeDCUsInUsesCompletion', TJSONBool.Create(True));
    lSettings.AddPair('enableKeyWordCompletion', TJSONBool.Create(False));

    lBrowsingPaths := TList<string>.Create;
    try
      for lValue in aSettings.UnitSearchPath do
        if not lBrowsingPaths.Contains(lValue) then
          lBrowsingPaths.Add(lValue);
      for lValue in aSettings.LibraryPath do
        if not lBrowsingPaths.Contains(lValue) then
          lBrowsingPaths.Add(lValue);
      for var i := 0 to lBrowsingPaths.Count - 1 do
        lBrowsingPaths[i] := FilePathToUri(lBrowsingPaths[i]);
      AddStringArray(lSettings, 'browsingPaths', lBrowsingPaths.ToArray);
    finally
      lBrowsingPaths.Free;
    end;

    lRoot.AddPair('settings', lSettings);
    Result := lRoot.ToJSON;
  finally
    lRoot.Free;
  end;
end;

class function TDelphiSemanticLspBoundary.EnrichDefinition(
  const aOptions: TDelphiSemanticLspOptions; const aName: string;
  const aLocation: TDelphiSemanticLspLocation): TDelphiSemanticLspResult;
begin
  Result := Default(TDelphiSemanticLspResult);
  if not aOptions.Enabled then
  begin
    Result.Status := 'disabled';
    Exit;
  end;

  Result := MakeUnsupportedResult;
end;

procedure AddFlattenedSymbol(const aList: TList<TDelphiSemanticLspSymbol>;
  const aSymbol: TDelphiSemanticLspSymbol; const aQuery: string; const aLimit: Integer);
var
  lSymbol: TDelphiSemanticLspSymbol;
begin
  if ((aQuery = '') or ContainsText(aSymbol.Name, aQuery)) and
    ((aLimit <= 0) or (aList.Count < aLimit)) then
  begin
    lSymbol := aSymbol;
    lSymbol.Provenance := 'lsp';
    aList.Add(lSymbol);
  end;
end;

class function TDelphiSemanticLspBoundary.FilterSymbols(
  const aSymbols: TArray<TDelphiSemanticLspSymbol>; const aQuery: string;
  const aLimit: Integer): TArray<TDelphiSemanticLspSymbol>;
var
  lList: TList<TDelphiSemanticLspSymbol>;
  lOutputSymbol: TDelphiSemanticLspSymbol;
  lSymbol: TDelphiSemanticLspSymbol;
begin
  lList := TList<TDelphiSemanticLspSymbol>.Create;
  try
    for lSymbol in aSymbols do
      if (aQuery = '') or ContainsText(lSymbol.Name, aQuery) then
      begin
        lOutputSymbol := lSymbol;
        lOutputSymbol.Provenance := 'lsp';
        lList.Add(lOutputSymbol);
        if (aLimit > 0) and (lList.Count >= aLimit) then
          Break;
      end;
    Result := lList.ToArray;
  finally
    lList.Free;
  end;
end;

class function TDelphiSemanticLspBoundary.FlattenSymbolNodes(
  const aNodes: TArray<TDelphiSemanticLspSymbolNode>; const aQuery: string;
  const aLimit: Integer): TArray<TDelphiSemanticLspSymbol>;
var
  lList: TList<TDelphiSemanticLspSymbol>;
  lNode: TDelphiSemanticLspSymbolNode;

  procedure VisitNode(const aNode: TDelphiSemanticLspSymbolNode; const aParentName: string);
  var
    lChild: TDelphiSemanticLspSymbolNode;
    lSymbol: TDelphiSemanticLspSymbol;
  begin
    if (aNode = nil) or ((aLimit > 0) and (lList.Count >= aLimit)) then
      Exit;

    lSymbol := aNode.Symbol;
    lSymbol.ContainerName := aParentName;
    AddFlattenedSymbol(lList, lSymbol, aQuery, aLimit);

    for lChild in aNode.Children do
      VisitNode(lChild, aNode.Symbol.Name);
  end;
begin
  lList := TList<TDelphiSemanticLspSymbol>.Create;
  try
    for lNode in aNodes do
      VisitNode(lNode, lNode.Symbol.ContainerName);
    Result := lList.ToArray;
  finally
    lList.Free;
  end;
end;

class function TDelphiSemanticLspBoundary.FromLocationLink(const aName, aUri: string;
  const aStartLine, aStartCharacter, aEndLine, aEndCharacter: Integer):
  TDelphiSemanticLspResult;
begin
  Result := Default(TDelphiSemanticLspResult);
  Result.Found := True;
  Result.Authoritative := False;
  Result.Status := 'resolved';
  Result.Provenance := 'lsp';
  Result.Name := aName;
  Result.Kind := 'definition';
  Result.FileName := NormalizeFileUri(aUri);
  Result.Line := aStartLine + 1;
  Result.Column := aStartCharacter + 1;
  Result.EndLine := aEndLine + 1;
  Result.EndColumn := aEndCharacter + 1;
end;

class function TDelphiSemanticLspBoundary.FromProtocolPosition(const aFileName: string;
  const aPosition: TDelphiSemanticLspProtocolPosition): TDelphiSemanticLspLocation;
begin
  Result.FileName := aFileName;
  Result.Line := aPosition.Line + 1;
  Result.Column := aPosition.Character + 1;
end;

class function TDelphiSemanticLspBoundary.FromSemanticResult(
  const aResult: TDelphiSemanticResolveResult): TDelphiSemanticLspResult;
begin
  Result := Default(TDelphiSemanticLspResult);
  Result.Found := aResult.Found;
  Result.Authoritative := aResult.Authoritative;
  Result.Status := aResult.Status;
  Result.Provenance := 'semantic-model';
  Result.Name := aResult.Name;
  Result.Kind := aResult.Kind;
  Result.TypeName := aResult.TypeName;
  Result.OwnerName := aResult.OwnerName;
  Result.Line := aResult.Line;
  Result.Column := aResult.Column;
end;

class function TDelphiSemanticLspBoundary.MakeEmptyHover: TDelphiSemanticLspHoverResult;
begin
  Result := Default(TDelphiSemanticLspHoverResult);
  Result.Status := 'empty';
end;

class function TDelphiSemanticLspBoundary.MakeErrorResult(
  const aMessage: string): TDelphiSemanticLspResult;
begin
  Result := Default(TDelphiSemanticLspResult);
  Result.Found := False;
  Result.Authoritative := False;
  Result.Status := 'error';
  Result.Provenance := 'lsp';
  Result.ErrorMessage := aMessage;
end;

class function TDelphiSemanticLspBoundary.MakeUnsupportedResult:
  TDelphiSemanticLspResult;
begin
  Result := Default(TDelphiSemanticLspResult);
  Result.Found := False;
  Result.Authoritative := False;
  Result.Status := 'unsupported';
  Result.Provenance := 'lsp';
  Result.ErrorMessage := cDelphiSemanticLspEnrichmentUnsupportedCode;
end;

class function TDelphiSemanticLspBoundary.MakeHover(const aContents, aUri: string;
  const aStartLine, aStartCharacter, aEndLine, aEndCharacter: Integer):
  TDelphiSemanticLspHoverResult;
begin
  Result := Default(TDelphiSemanticLspHoverResult);
  Result.Found := aContents <> '';
  if Result.Found then
    Result.Status := 'resolved'
  else
    Result.Status := 'empty';
  Result.Provenance := 'lsp';
  Result.Contents := aContents;
  Result.FileName := NormalizeFileUri(aUri);
  Result.Range.StartLine := aStartLine + 1;
  Result.Range.StartColumn := aStartCharacter + 1;
  Result.Range.EndLine := aEndLine + 1;
  Result.Range.EndColumn := aEndCharacter + 1;
end;

class function TDelphiSemanticLspBoundary.FilePathToUri(const aPath: string): string;
begin
  Result := FilePathToURL(aPath);
end;

class function TDelphiSemanticLspBoundary.NormalizeFileUri(const aUri: string): string;
var
  lDrivePos: Integer;
  i: Integer;
  lPath: string;

  function HexValue(const aChar: Char): Integer;
  begin
    if CharInSet(aChar, ['0'..'9']) then
      Result := Ord(aChar) - Ord('0')
    else if CharInSet(aChar, ['A'..'F']) then
      Result := Ord(aChar) - Ord('A') + 10
    else if CharInSet(aChar, ['a'..'f']) then
      Result := Ord(aChar) - Ord('a') + 10
    else
      Result := -1;
  end;

  function DecodePercentEscapes(const aValue: string): string;
  var
    lByteCount: Integer;
    lBytes: TBytes;
    lHigh: Integer;
    lIndex: Integer;
    lLow: Integer;

    procedure AddByte(const aByte: Byte);
    begin
      if lByteCount = Length(lBytes) then
        SetLength(lBytes, lByteCount + 16);
      lBytes[lByteCount] := aByte;
      Inc(lByteCount);
    end;

    procedure FlushBytes;
    var
      lChunk: TBytes;
    begin
      if lByteCount = 0 then
        Exit;
      SetLength(lChunk, lByteCount);
      Move(lBytes[0], lChunk[0], lByteCount);
      Result := Result + TEncoding.UTF8.GetString(lChunk);
      lByteCount := 0;
    end;
  begin
    Result := '';
    lByteCount := 0;
    lIndex := 1;
    while lIndex <= Length(aValue) do
    begin
      if (aValue[lIndex] = '%') and (lIndex + 2 <= Length(aValue)) then
      begin
        lHigh := HexValue(aValue[lIndex + 1]);
        lLow := HexValue(aValue[lIndex + 2]);
        if (lHigh >= 0) and (lLow >= 0) then
        begin
          AddByte(Byte((lHigh shl 4) + lLow));
          Inc(lIndex, 3);
          Continue;
        end;
      end;
      FlushBytes;
      Result := Result + aValue[lIndex];
      Inc(lIndex);
    end;
    FlushBytes;
  end;
begin
  lPath := aUri;
  if StartsText('file://', lPath) then
    Delete(lPath, 1, Length('file://'));

  lDrivePos := 0;
  for i := 1 to Length(lPath) - 2 do
    if (lPath[i + 1] = ':') and (lPath[i + 2] = '/') then
    begin
      lDrivePos := i;
      Break;
    end;

  if lDrivePos > 0 then
    lPath := Copy(lPath, lDrivePos, MaxInt)
  else if (lPath <> '') and (lPath[1] <> '/') then
    lPath := '//' + lPath;

  if (Length(lPath) >= 3) and (lPath[1] = '/') and (lPath[3] = ':') then
    Delete(lPath, 1, 1);

  lPath := DecodePercentEscapes(lPath);
  lPath := StringReplace(lPath, '/', '\', [rfReplaceAll]);
  Result := lPath;
end;

class function TDelphiSemanticLspBoundary.ToProtocolPosition(const aLine, aColumn: Integer):
  TDelphiSemanticLspProtocolPosition;
begin
  Result.Line := aLine - 1;
  Result.Character := aColumn - 1;
  if Result.Line < 0 then
    Result.Line := 0;
  if Result.Character < 0 then
    Result.Character := 0;
end;

end.
