unit DelphiSemantics.DeadCode;

interface

uses
  DelphiSemantics.Index, DelphiSemantics.Query, DelphiSemantics.Symbols;

type
  TDelphiSemanticDeadCodeSafetyProfile = (dcspAudit, dcspConservative,
    dcspLegacyStatic);

  TDelphiSemanticDeadCodeProfiles = record
  public
    class function AllowedNamesText: string; static;
    class function DefaultRemovalProfile: TDelphiSemanticDeadCodeSafetyProfile; static;
    class function DefaultReportProfile: TDelphiSemanticDeadCodeSafetyProfile; static;
    class function InvalidProfileDiagnostic(const aProfileName: string): string; static;
    class function ToName(const aProfile: TDelphiSemanticDeadCodeSafetyProfile): string;
      static;
    class function TryParse(const aProfileName: string;
      out aProfile: TDelphiSemanticDeadCodeSafetyProfile): Boolean; static;
  end;

  TDelphiSemanticDeadCodeCandidate = record
    SymbolId: TDelphiSemanticSymbolId;
    Name: string;
    Kind: string;
    OwnerName: string;
    UnitName: string;
    FileName: string;
    Line: Integer;
    Column: Integer;
    Status: string;
    Reason: string;
    SafetyProfile: string;
    ReferenceCount: Integer;
    Blockers: TArray<string>;
  end;

  TDelphiSemanticDeadCodeReport = record
    Profile: string;
    Diagnostic: string;
    Candidates: TArray<TDelphiSemanticDeadCodeCandidate>;
    IndexMetrics: TDelphiSemanticProjectSymbolIndexMetrics;
  end;

  TDelphiSemanticDeadCodeReporter = record
  public
    class function Report(const aContext: TDelphiSemanticSymbolQueryContext;
      const aProfile: TDelphiSemanticDeadCodeSafetyProfile):
      TDelphiSemanticDeadCodeReport; overload; static;
    class function Report(const aContext: TDelphiSemanticSymbolQueryContext;
      const aProfile: string): TDelphiSemanticDeadCodeReport; overload; static;
  end;

implementation

uses
  System.Generics.Collections, System.Generics.Defaults, System.StrUtils, System.SysUtils,
  DelphiSemantics.Model, DelphiSemantics.Model.Text, DelphiSemantics.Snapshot, DelphiSemantics.Snapshot.QuerySupport,
  DelphiSemantics.Usage,
  MaxLogic.StrUtils;

const
  cDeadCodeProfileAudit = 'audit';
  cDeadCodeProfileConservative = 'conservative';
  cDeadCodeProfileLegacyStatic = 'legacy-static';

type
  TDeadCodeSourceEntry = record
    Text: string;
    LowerText: string;
  end;

  TDeadCodeSourceIndex = class
  private
    fEntries: TDictionary<string, TDeadCodeSourceEntry>;
    // Every unit and program file, with or without known text (DS-659).
    fUnitFiles: TDictionary<string, Boolean>;
    procedure AddEntry(const aFileName, aText: string);
    procedure AddModel(const aModel: TDelphiSemanticUnitModel);
    procedure AddSnapshot(const aSnapshot: TDelphiProjectSnapshot);
  public
    constructor Create(const aContext: TDelphiSemanticSymbolQueryContext);
    destructor Destroy; override;
    function TryGetEntry(const aFileName: string; out aEntry: TDeadCodeSourceEntry):
      Boolean;
    function IsUnitFile(const aFileName: string): Boolean;
  end;

  TDeadCodeReferenceIndex = class
  private
    fAmbiguousSymbolIds: TDictionary<string, Boolean>;
    fResolvedCountsBySymbolId: TDictionary<string, Integer>;
    fSameUnitNameCounts: TDictionary<string, Integer>;
    fUnresolvedReferenceKeys: TDictionary<string, Boolean>;
    class function ReferenceScopeKey(const aSourceKind, aUnitName, aName: string): string; static;
    class function SameUnitNameKey(const aUnitName, aName: string): string; static;
    class function SymbolKey(const aId: TDelphiSemanticSymbolId): string; static;
    procedure IncrementCount(const aMap: TDictionary<string, Integer>; const aKey: string);
  public
    constructor Create(const aIndex: TDelphiSemanticProjectSymbolIndex);
    destructor Destroy; override;
    function CountResolvedReferences(const aSymbol: TDelphiSemanticIndexedSymbol):
      Integer;
    function CountSameUnitNameReferences(const aSymbol: TDelphiSemanticIndexedSymbol):
      Integer;
    function HasAmbiguousReference(const aSymbol: TDelphiSemanticIndexedSymbol): Boolean;
    function HasUnresolvedReferenceInScope(const aSymbol: TDelphiSemanticIndexedSymbol):
      Boolean;
  end;

  // Finds whole-word source occurrences of a name that no declaration or reference fact covers.
  // Such an occurrence (inactive code, assembler, an extraction gap) may be a use, so a symbol
  // with one is never reported unused (DS-653).
  TDeadCodeOccurrenceScanner = class
  private
    fCovered: TDictionary<string, Boolean>;
    fResults: TDictionary<string, Boolean>;
    fTexts: TList<TPair<string, string>>;
    class function PositionKey(const aFileName: string; const aLine, aColumn: Integer): string;
      static;
  public
    constructor Create(const aIndex: TDelphiSemanticProjectSymbolIndex;
      const aSourceIndex: TDeadCodeSourceIndex);
    destructor Destroy; override;
    function HasUnclassifiedOccurrence(const aName: string): Boolean;
  end;

class function TDelphiSemanticDeadCodeProfiles.AllowedNamesText: string;
begin
  Result := cDeadCodeProfileAudit + ', ' + cDeadCodeProfileConservative + ', or ' +
    cDeadCodeProfileLegacyStatic;
end;

class function TDelphiSemanticDeadCodeProfiles.DefaultRemovalProfile:
  TDelphiSemanticDeadCodeSafetyProfile;
begin
  Result := TDelphiSemanticDeadCodeSafetyProfile.dcspConservative;
end;

class function TDelphiSemanticDeadCodeProfiles.DefaultReportProfile:
  TDelphiSemanticDeadCodeSafetyProfile;
begin
  Result := TDelphiSemanticDeadCodeSafetyProfile.dcspAudit;
end;

class function TDelphiSemanticDeadCodeProfiles.InvalidProfileDiagnostic(
  const aProfileName: string): string;
begin
  Result := Format('Invalid dead-code profile: %s (expected %s).', [aProfileName,
    AllowedNamesText]);
end;

class function TDelphiSemanticDeadCodeProfiles.ToName(
  const aProfile: TDelphiSemanticDeadCodeSafetyProfile): string;
begin
  case aProfile of
    TDelphiSemanticDeadCodeSafetyProfile.dcspAudit:
      Result := cDeadCodeProfileAudit;
    TDelphiSemanticDeadCodeSafetyProfile.dcspConservative:
      Result := cDeadCodeProfileConservative;
    TDelphiSemanticDeadCodeSafetyProfile.dcspLegacyStatic:
      Result := cDeadCodeProfileLegacyStatic;
  else
    Result := cDeadCodeProfileAudit;
  end;
end;

class function TDelphiSemanticDeadCodeProfiles.TryParse(const aProfileName: string;
  out aProfile: TDelphiSemanticDeadCodeSafetyProfile): Boolean;
var
  lProfileName: string;
begin
  lProfileName := Trim(aProfileName);
  if SameText(lProfileName, cDeadCodeProfileAudit) then
    aProfile := TDelphiSemanticDeadCodeSafetyProfile.dcspAudit
  else if SameText(lProfileName, cDeadCodeProfileConservative) then
    aProfile := TDelphiSemanticDeadCodeSafetyProfile.dcspConservative
  else if SameText(lProfileName, cDeadCodeProfileLegacyStatic) then
    aProfile := TDelphiSemanticDeadCodeSafetyProfile.dcspLegacyStatic
  else
  begin
    aProfile := DefaultReportProfile;
    Exit(False);
  end;

  Result := True;
end;

constructor TDeadCodeSourceIndex.Create(const aContext: TDelphiSemanticSymbolQueryContext);
var
  lModel: TDelphiSemanticUnitModel;
  lSnapshot: TDelphiProjectSnapshot;
begin
  inherited Create;
  fEntries := TDictionary<string, TDeadCodeSourceEntry>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  fUnitFiles := TDictionary<string, Boolean>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  lSnapshot := ContextProjectSnapshot(aContext);
  AddSnapshot(lSnapshot);
  AddModel(aContext.UnitModel);
  for lModel in aContext.IndexedUnitModels do
    AddModel(lModel);
end;

destructor TDeadCodeSourceIndex.Destroy;
begin
  fUnitFiles.Free;
  fEntries.Free;
  inherited;
end;

function TDeadCodeSourceIndex.IsUnitFile(const aFileName: string): Boolean;
begin
  Result := (aFileName <> '') and fUnitFiles.ContainsKey(aFileName);
end;

procedure TDeadCodeSourceIndex.AddEntry(const aFileName, aText: string);
var
  lEntry: TDeadCodeSourceEntry;
begin
  if aFileName <> '' then
    fUnitFiles.AddOrSetValue(aFileName, True);
  if (aFileName = '') or (aText = '') then
    Exit;

  lEntry.Text := aText;
  lEntry.LowerText := LowerCase(lEntry.Text);
  fEntries.AddOrSetValue(aFileName, lEntry);
end;

procedure TDeadCodeSourceIndex.AddModel(const aModel: TDelphiSemanticUnitModel);
begin
  AddEntry(aModel.FileName, aModel.SourceText);
end;

procedure TDeadCodeSourceIndex.AddSnapshot(const aSnapshot: TDelphiProjectSnapshot);
var
  i: Integer;
  lUnit: TUnitSnapshot;
begin
  if aSnapshot = nil then
    Exit;

  for i := 0 to aSnapshot.UnitCount - 1 do
  begin
    lUnit := aSnapshot.UnitByIndex(i);
    AddEntry(SnapshotText(aSnapshot, lUnit.FileNameId),
      aSnapshot.ExactTextOf(lUnit.SourceTextId));
  end;
end;

function TDeadCodeSourceIndex.TryGetEntry(const aFileName: string;
  out aEntry: TDeadCodeSourceEntry): Boolean;
begin
  aEntry := Default(TDeadCodeSourceEntry);
  if aFileName = '' then
    Exit(False);

  Result := fEntries.TryGetValue(aFileName, aEntry);
end;

constructor TDeadCodeReferenceIndex.Create(const aIndex: TDelphiSemanticProjectSymbolIndex);
var
  lCandidateId: TDelphiSemanticSymbolId;
  lComparer: IEqualityComparer<string>;
  lReference: TDelphiSemanticIndexedReference;
begin
  inherited Create;
  lComparer := TFastCaseAwareComparer.OrdinalIgnoreCase;
  fAmbiguousSymbolIds := TDictionary<string, Boolean>.Create(lComparer);
  fResolvedCountsBySymbolId := TDictionary<string, Integer>.Create(lComparer);
  fSameUnitNameCounts := TDictionary<string, Integer>.Create(lComparer);
  fUnresolvedReferenceKeys := TDictionary<string, Boolean>.Create(lComparer);

  for lReference in aIndex.References do
  begin
    if SameText(lReference.SourceKind, 'project-source') then
      IncrementCount(fSameUnitNameCounts, SameUnitNameKey(lReference.UnitName,
        lReference.Name));
    if SameText(lReference.Status, 'resolved') then
      IncrementCount(fResolvedCountsBySymbolId, SymbolKey(lReference.SymbolId))
    else if SameText(lReference.Status, 'ambiguous') then
    begin
      for lCandidateId in lReference.CandidateSymbolIds do
        fAmbiguousSymbolIds.AddOrSetValue(SymbolKey(lCandidateId), True);
    end else if SameText(lReference.Status, 'unresolved') then
      fUnresolvedReferenceKeys.AddOrSetValue(ReferenceScopeKey(lReference.SourceKind,
        lReference.UnitName, lReference.Name), True);
  end;
end;

destructor TDeadCodeReferenceIndex.Destroy;
begin
  fUnresolvedReferenceKeys.Free;
  fSameUnitNameCounts.Free;
  fResolvedCountsBySymbolId.Free;
  fAmbiguousSymbolIds.Free;
  inherited;
end;

function TDeadCodeReferenceIndex.CountResolvedReferences(
  const aSymbol: TDelphiSemanticIndexedSymbol): Integer;
begin
  if not fResolvedCountsBySymbolId.TryGetValue(SymbolKey(aSymbol.Id), Result) then
    Result := 0;
end;

function TDeadCodeReferenceIndex.CountSameUnitNameReferences(
  const aSymbol: TDelphiSemanticIndexedSymbol): Integer;
begin
  if aSymbol.OwnerName <> '' then
    Exit(0);
  if not fSameUnitNameCounts.TryGetValue(SameUnitNameKey(aSymbol.UnitName, aSymbol.Name),
    Result) then
    Result := 0;
end;

function TDeadCodeReferenceIndex.HasAmbiguousReference(
  const aSymbol: TDelphiSemanticIndexedSymbol): Boolean;
begin
  Result := fAmbiguousSymbolIds.ContainsKey(SymbolKey(aSymbol.Id));
end;

function TDeadCodeReferenceIndex.HasUnresolvedReferenceInScope(
  const aSymbol: TDelphiSemanticIndexedSymbol): Boolean;
begin
  Result := fUnresolvedReferenceKeys.ContainsKey(ReferenceScopeKey(aSymbol.SourceKind,
    aSymbol.UnitName, aSymbol.Name));
end;

procedure TDeadCodeReferenceIndex.IncrementCount(const aMap: TDictionary<string, Integer>;
  const aKey: string);
var
  lCount: Integer;
begin
  if not aMap.TryGetValue(aKey, lCount) then
    lCount := 0;
  aMap.AddOrSetValue(aKey, lCount + 1);
end;

class function TDeadCodeReferenceIndex.SameUnitNameKey(const aUnitName,
  aName: string): string;
begin
  Result := aUnitName + #1 + aName;
end;

class function TDeadCodeReferenceIndex.ReferenceScopeKey(const aSourceKind, aUnitName,
  aName: string): string;
begin
  Result := aSourceKind + #1 + aUnitName + #1 + aName;
end;

class function TDeadCodeReferenceIndex.SymbolKey(const aId: TDelphiSemanticSymbolId):
  string;
begin
  Result := aId.Value;
end;

constructor TDeadCodeOccurrenceScanner.Create(const aIndex: TDelphiSemanticProjectSymbolIndex;
  const aSourceIndex: TDeadCodeSourceIndex);
var
  lEntry: TPair<string, TDeadCodeSourceEntry>;
  lReference: TDelphiSemanticIndexedReference;
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  inherited Create;
  fCovered := TDictionary<string, Boolean>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  fResults := TDictionary<string, Boolean>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  fTexts := TList<TPair<string, string>>.Create;
  for lSymbol in aIndex.Symbols do
    fCovered.AddOrSetValue(PositionKey(lSymbol.FileName, lSymbol.Line, lSymbol.Column), True);
  for lReference in aIndex.References do
    fCovered.AddOrSetValue(PositionKey(lReference.FileName, lReference.Line, lReference.Column),
      True);
  // Comments and strings never use a symbol; the scan runs on the sanitized text.
  for lEntry in aSourceIndex.fEntries do
    fTexts.Add(TPair<string, string>.Create(lEntry.Key,
      LowerCase(SanitizeCodeText(lEntry.Value.Text))));
end;

destructor TDeadCodeOccurrenceScanner.Destroy;
begin
  fTexts.Free;
  fResults.Free;
  fCovered.Free;
  inherited;
end;

class function TDeadCodeOccurrenceScanner.PositionKey(const aFileName: string; const aLine,
  aColumn: Integer): string;
begin
  Result := aFileName + #1 + IntToStr(aLine) + #1 + IntToStr(aColumn);
end;

function TDeadCodeOccurrenceScanner.HasUnclassifiedOccurrence(const aName: string): Boolean;
var
  lAfter: Integer;
  lColumnStart: Integer;
  lLine: Integer;
  lName: string;
  lPosition: Integer;
  lScanned: Integer;
  lText: TPair<string, string>;
begin
  if fResults.TryGetValue(aName, Result) then
    Exit;
  Result := False;
  lName := LowerCase(aName);
  for lText in fTexts do
  begin
    lLine := 1;
    lColumnStart := 1;
    lScanned := 1;
    lPosition := Pos(lName, lText.Value);
    while (lPosition > 0) and not Result do
    begin
      while lScanned < lPosition do
      begin
        if lText.Value[lScanned] = #10 then
        begin
          Inc(lLine);
          lColumnStart := lScanned + 1;
        end;
        Inc(lScanned);
      end;
      lAfter := lPosition + Length(lName);
      if ((lPosition = 1) or not IsIdentifierChar(lText.Value[lPosition - 1])) and
        ((lAfter > Length(lText.Value)) or not IsIdentifierChar(lText.Value[lAfter])) and
        not fCovered.ContainsKey(PositionKey(lText.Key, lLine, lPosition - lColumnStart + 1)) then
        Result := True;
      lPosition := Pos(lName, lText.Value, lPosition + 1);
    end;
    if Result then
      Break;
  end;
  fResults.Add(aName, Result);
end;

function SameSymbolId(const aLeft, aRight: TDelphiSemanticSymbolId): Boolean;
begin
  Result := aLeft.Value = aRight.Value;
end;

function IsProjectSymbol(const aSymbol: TDelphiSemanticIndexedSymbol): Boolean;
begin
  Result := SameText(aSymbol.SourceKind, 'project-source');
end;

function IsDataSymbol(const aSymbol: TDelphiSemanticIndexedSymbol): Boolean;
begin
  Result := SameText(aSymbol.Kind, 'var') or SameText(aSymbol.Kind, 'const') or
    SameText(aSymbol.Kind, 'typed-const') or SameText(aSymbol.Kind, 'resourcestring');
end;

function IsCandidateKind(const aSymbol: TDelphiSemanticIndexedSymbol): Boolean;
begin
  Result := not SameText(aSymbol.Kind, 'unit') and not SameText(aSymbol.Kind, 'local') and
    not (SameText(aSymbol.Kind, 'routine') and (aSymbol.OwnerName <> '')) and
    not (IsDataSymbol(aSymbol) and (aSymbol.OwnerName <> ''));
end;

function HasSymbolCandidate(const aReference: TDelphiSemanticIndexedReference;
  const aSymbol: TDelphiSemanticIndexedSymbol): Boolean;
var
  lCandidateId: TDelphiSemanticSymbolId;
begin
  for lCandidateId in aReference.CandidateSymbolIds do
    if SameSymbolId(lCandidateId, aSymbol.Id) then
      Exit(True);

  Result := False;
end;

function CountResolvedReferences(const aIndex: TDelphiSemanticProjectSymbolIndex;
  const aSymbol: TDelphiSemanticIndexedSymbol): Integer;
var
  lReference: TDelphiSemanticIndexedReference;
begin
  Result := 0;
  for lReference in aIndex.References do
    if SameText(lReference.Status, 'resolved') and SameSymbolId(lReference.SymbolId,
      aSymbol.Id) then
      Inc(Result);
end;

function CountSameUnitNameReferences(const aIndex: TDelphiSemanticProjectSymbolIndex;
  const aSymbol: TDelphiSemanticIndexedSymbol): Integer;
var
  lReference: TDelphiSemanticIndexedReference;
begin
  Result := 0;
  if aSymbol.OwnerName <> '' then
    Exit;
  for lReference in aIndex.References do
    if SameText(lReference.Name, aSymbol.Name) and SameText(lReference.UnitName,
      aSymbol.UnitName) and SameText(lReference.SourceKind, 'project-source') then
      Inc(Result);
end;

function HasAmbiguousReference(const aIndex: TDelphiSemanticProjectSymbolIndex;
  const aSymbol: TDelphiSemanticIndexedSymbol): Boolean;
var
  lReference: TDelphiSemanticIndexedReference;
begin
  for lReference in aIndex.References do
    if SameText(lReference.Status, 'ambiguous') and HasSymbolCandidate(lReference, aSymbol) then
      Exit(True);

  Result := False;
end;

function CandidateWithBlockerExists(const aCandidates: TList<TDelphiSemanticDeadCodeCandidate>;
  const aName, aBlocker: string): Boolean;
var
  lBlocker: string;
  lCandidate: TDelphiSemanticDeadCodeCandidate;
begin
  for lCandidate in aCandidates do
    if SameText(lCandidate.Name, aName) then
      for lBlocker in lCandidate.Blockers do
        if SameText(lBlocker, aBlocker) then
          Exit(True);

  Result := False;
end;

function CandidateHasBlocker(const aCandidate: TDelphiSemanticDeadCodeCandidate;
  const aBlocker: string): Boolean;
var
  lBlocker: string;
begin
  for lBlocker in aCandidate.Blockers do
    if SameText(lBlocker, aBlocker) then
      Exit(True);

  Result := False;
end;

function SourceLineText(const aText: string; const aLine: Integer): string;
var
  i: Integer;
  lLine: Integer;
  lLineStart: Integer;
begin
  Result := '';
  if aLine <= 0 then
    Exit;

  lLine := 1;
  lLineStart := 1;
  for i := 1 to Length(aText) do
  begin
    if aText[i] = #10 then
    begin
      if lLine = aLine then
      begin
        Result := Copy(aText, lLineStart, i - lLineStart);
        Result := StringReplace(Result, #13, '', [rfReplaceAll]);
        Exit;
      end;
      Inc(lLine);
      lLineStart := i + 1;
    end;
  end;

  if lLine = aLine then
  begin
    Result := Copy(aText, lLineStart, MaxInt);
    Result := StringReplace(Result, #13, '', [rfReplaceAll]);
  end;
end;

function SourceLineContains(const aSourceIndex: TDeadCodeSourceIndex; const aFileName: string;
  const aLine: Integer; const aText: string): Boolean;
var
  lEntry: TDeadCodeSourceEntry;
begin
  if (aFileName = '') or (aLine <= 0) then
    Exit(False);

  Result := aSourceIndex.TryGetEntry(aFileName, lEntry) and
    ContainsText(SourceLineText(lEntry.Text, aLine), aText);
end;

function SourceSectionContainsIdentifier(const aSourceIndex: TDeadCodeSourceIndex;
  const aFileName, aSectionName, aName: string): Boolean;
var
  lAfterSectionLower: string;
  lEndPos: Integer;
  lEntry: TDeadCodeSourceEntry;
  lLowerName: string;
  lStartPos: Integer;
begin
  if (aFileName = '') or (aSectionName = '') or (aName = '') then
    Exit(False);

  if not aSourceIndex.TryGetEntry(aFileName, lEntry) then
    Exit(False);

  lStartPos := Pos(LowerCase(aSectionName), lEntry.LowerText);
  if lStartPos <= 0 then
    Exit(False);

  lAfterSectionLower := Copy(lEntry.LowerText, lStartPos + Length(aSectionName), MaxInt);
  lEndPos := Pos('end.', lAfterSectionLower);
  if lEndPos > 0 then
    lAfterSectionLower := Copy(lAfterSectionLower, 1, lEndPos - 1);

  lLowerName := LowerCase(aName);
  Result := TextContainsIdentifier(lAfterSectionLower, lLowerName);
end;

function SourceExportsSymbol(const aSourceIndex: TDeadCodeSourceIndex; const aFileName,
  aName: string): Boolean;
var
  lBlock: string;
  lEndPos: Integer;
  lEntry: TDeadCodeSourceEntry;
  lLowerName: string;
  lSearchFrom: Integer;
  lStartPos: Integer;
begin
  if (aFileName = '') or (aName = '') then
    Exit(False);

  if not aSourceIndex.TryGetEntry(aFileName, lEntry) then
    Exit(False);

  lLowerName := LowerCase(aName);
  lSearchFrom := 1;
  repeat
    lStartPos := Pos('exports', lEntry.LowerText, lSearchFrom);
    if lStartPos <= 0 then
      Break;
    if ((lStartPos = 1) or not IsIdentifierChar(lEntry.LowerText[lStartPos - 1])) and
      ((lStartPos + 7 > Length(lEntry.LowerText)) or not IsIdentifierChar(lEntry.LowerText[
      lStartPos + 7])) then
    begin
      lEndPos := Pos(';', lEntry.LowerText, lStartPos + 7);
      if lEndPos <= 0 then
        lEndPos := Length(lEntry.LowerText) + 1;
      lBlock := Copy(lEntry.LowerText, lStartPos + 7, lEndPos - lStartPos - 7);
      if TextContainsIdentifier(lBlock, lLowerName) then
        Exit(True);
      lSearchFrom := lEndPos + 1;
    end else
      lSearchFrom := lStartPos + 1;
  until False;

  Result := False;
end;

function HasInitializationHook(const aSourceIndex: TDeadCodeSourceIndex;
  const aSymbol: TDelphiSemanticIndexedSymbol): Boolean;
begin
  Result := SourceSectionContainsIdentifier(aSourceIndex, aSymbol.FileName, 'initialization',
    aSymbol.Name) or SourceSectionContainsIdentifier(aSourceIndex, aSymbol.FileName,
    'finalization', aSymbol.Name);
end;

procedure AddBlocker(const aBlockers: TList<string>; const aBlocker: string);
begin
  if aBlocker <> '' then
    aBlockers.Add(aBlocker);
end;

function MakeCandidate(const aSymbol: TDelphiSemanticIndexedSymbol; const aStatus, aReason,
  aProfile: string; const aReferenceCount: Integer; const aBlockers: TArray<string>):
  TDelphiSemanticDeadCodeCandidate;
begin
  Result := Default(TDelphiSemanticDeadCodeCandidate);
  Result.SymbolId := aSymbol.Id;
  Result.Name := aSymbol.Name;
  Result.Kind := aSymbol.Kind;
  Result.OwnerName := aSymbol.OwnerName;
  Result.UnitName := aSymbol.UnitName;
  Result.FileName := aSymbol.FileName;
  Result.Line := aSymbol.Line;
  Result.Column := aSymbol.Column;
  Result.Status := aStatus;
  Result.Reason := aReason;
  Result.SafetyProfile := aProfile;
  Result.ReferenceCount := aReferenceCount;
  Result.Blockers := aBlockers;
end;

function ExternallyVisible(const aSymbol: TDelphiSemanticIndexedSymbol): Boolean;
begin
  Result := SameText(aSymbol.SectionKind, 'interface') or SameText(aSymbol.Visibility, 'public');
end;

function DefinitelyUnusedEligible(const aSymbol: TDelphiSemanticIndexedSymbol;
  const aProfile: TDelphiSemanticDeadCodeSafetyProfile): Boolean;
begin
  Result := IsDataSymbol(aSymbol) or SameText(aSymbol.Visibility, 'private') or
    SameText(aSymbol.Visibility, 'strict private') or
    ((aProfile = TDelphiSemanticDeadCodeSafetyProfile.dcspLegacyStatic) and
    SameText(aSymbol.Kind, 'routine') and
    SameText(aSymbol.SectionKind, 'implementation') and (aSymbol.OwnerName = ''));
end;

function MaybeUnusedEligible(const aSymbol: TDelphiSemanticIndexedSymbol): Boolean;
begin
  Result :=
    SameText(aSymbol.Visibility, 'private') or SameText(aSymbol.Visibility, 'strict private');
end;

type
  TDeadCodeRoutineGroups = TObjectDictionary<string, TList<TDelphiSemanticIndexedSymbol>>;

function RoutineGroupKey(const aSymbol: TDelphiSemanticIndexedSymbol): string;
begin
  Result := aSymbol.UnitName + #1 + aSymbol.Name;
end;

// A nested routine's scope id continues its parent's: "unit|outer(...)/inner(...)".
function IsNestedRoutine(const aSymbol: TDelphiSemanticIndexedSymbol): Boolean;
begin
  Result := Pos(')/', aSymbol.ScopeId) > 0;
end;

// Unit-level routines only: a nested routine of the same name is another symbol.
function IsOwnerlessProjectRoutine(const aSymbol: TDelphiSemanticIndexedSymbol): Boolean;
begin
  Result := IsProjectSymbol(aSymbol) and SameText(aSymbol.Kind, 'routine') and
    (aSymbol.OwnerName = '') and not IsNestedRoutine(aSymbol);
end;

function CountInSection(const aGroup: TList<TDelphiSemanticIndexedSymbol>;
  const aSectionKind: string): Integer;
var
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  Result := 0;
  for lSymbol in aGroup do
    if SameText(lSymbol.SectionKind, aSectionKind) then
      Inc(Result);
end;

// Splits aText at aSeparator outside parentheses and brackets.
function SplitTopLevel(const aText: string; const aSeparator: Char): TArray<string>;
var
  i: Integer;
  lDepth: Integer;
  lStart: Integer;
begin
  Result := [];
  lDepth := 0;
  lStart := 1;
  for i := 1 to Length(aText) do
    if CharInSet(aText[i], ['(', '[']) then
      Inc(lDepth)
    else if CharInSet(aText[i], [')', ']']) then
      Dec(lDepth)
    else if (aText[i] = aSeparator) and (lDepth = 0) then
    begin
      Result := Result + [Copy(aText, lStart, i - lStart)];
      lStart := i + 1;
    end;
  Result := Result + [Copy(aText, lStart, MaxInt)];
end;

function WithoutWhitespace(const aText: string): string;
var
  c: Char;
begin
  Result := '';
  for c in aText do
    if not CharInSet(c, [#9, #10, #13, ' ']) then
      Result := Result + c;
end;

// DS-660 review round 2: a parameter list by meaning. Grouped names are expanded ("a, b: T" is
// "a: T; b: T"); names, default values, case and spacing are ignored; the modifier and the type
// of every parameter are kept. A list that cannot be read keeps its normalized text.
function RoutineParameterKey(const aSignature: string): string;
var
  lColon: Integer;
  lDefault: TArray<string>;
  lGroup: string;
  lModifier: string;
  lName: string;
  lNames: string;
  lText: string;
  lType: string;
  lWords: TArray<string>;
begin
  lText := Trim(SanitizeCodeText(aSignature));
  if (lText <> '') and (lText[1] = '(') and (lText[Length(lText)] = ')') then
    lText := Copy(lText, 2, Length(lText) - 2);
  Result := '';
  for lGroup in SplitTopLevel(lText, ';') do
  begin
    if Trim(lGroup) = '' then
      Continue;
    lDefault := SplitTopLevel(lGroup, '=');
    lText := Trim(lDefault[0]);
    lColon := Pos(':', lText);
    if lColon > 0 then
    begin
      lNames := Trim(Copy(lText, 1, lColon - 1));
      lType := LowerCase(WithoutWhitespace(Copy(lText, lColon + 1, MaxInt)));
    end else begin
      lNames := lText;
      lType := '';
    end;
    lModifier := '';
    lWords := lNames.Split([' ', #9, #10, #13], TStringSplitOptions.ExcludeEmpty);
    if (Length(lWords) > 1) and MatchText(lWords[0], ['const', 'var', 'out', 'constref']) then
    begin
      lModifier := LowerCase(lWords[0]);
      lNames := Trim(Copy(lNames, Length(lWords[0]) + 1, MaxInt));
    end;
    if lNames = '' then
      Exit('text:' + NormalizeRoutineSignature(aSignature));
    for lName in lNames.Split([',']) do
    begin
      if Trim(lName) = '' then
        Exit('text:' + NormalizeRoutineSignature(aSignature));
      Result := Result + lModifier + ':' + lType + ';';
    end;
  end;
end;

// Two declarations of one routine: equal parameter lists (overloads repeat them), a lone pair, or
// the only declaration of each section (an interface header and its short-form body).
function RoutineDeclarationsPair(const aGroup: TList<TDelphiSemanticIndexedSymbol>;
  const aLeft, aRight: TDelphiSemanticIndexedSymbol): Boolean;
begin
  Result := (aGroup.Count = 2) or (RoutineParameterKey(aLeft.Signature) =
    RoutineParameterKey(aRight.Signature)) or
    (not SameText(aLeft.SectionKind, aRight.SectionKind) and
    (CountInSection(aGroup, aLeft.SectionKind) = 1) and
    (CountInSection(aGroup, aRight.SectionKind) = 1));
end;

// DS-660 review: a call that stays unresolved (an overload set without argument types) may bind
// any visible routine of its name, also in another unit, so a routine with an interface
// declaration is never unused while such a call exists anywhere in the project.
// DS-660 review round 2: an implementation body that pairs with no interface declaration of
// its name, while one of them is used, may be that declaration's body with a header the pairing
// cannot read. It is never reported unused.
function IsUnpairedBodyOfUsedInterfaceRoutine(const aGroups: TObjectDictionary<string,
  TList<TDelphiSemanticIndexedSymbol>>; const aReferenceIndex: TDeadCodeReferenceIndex;
  const aSymbol: TDelphiSemanticIndexedSymbol): Boolean;
var
  lGroup: TList<TDelphiSemanticIndexedSymbol>;
  lOther: TDelphiSemanticIndexedSymbol;
  lUsed: Boolean;
begin
  Result := False;
  if not IsOwnerlessProjectRoutine(aSymbol) or SameText(aSymbol.SectionKind, 'interface') or
    not aGroups.TryGetValue(RoutineGroupKey(aSymbol), lGroup) then
    Exit;
  lUsed := False;
  for lOther in lGroup do
    if SameText(lOther.SectionKind, 'interface') then
    begin
      if RoutineDeclarationsPair(lGroup, aSymbol, lOther) then
        Exit(False);
      if aReferenceIndex.CountResolvedReferences(lOther) > 0 then
        lUsed := True;
    end;
  Result := lUsed;
end;

function HasUnresolvedCallOfInterfaceRoutine(const aGroups: TObjectDictionary<string,
  TList<TDelphiSemanticIndexedSymbol>>; const aUnresolvedNames: TDictionary<string, Boolean>;
  const aSymbol: TDelphiSemanticIndexedSymbol): Boolean;
var
  lGroup: TList<TDelphiSemanticIndexedSymbol>;
begin
  Result := IsOwnerlessProjectRoutine(aSymbol) and aUnresolvedNames.ContainsKey(aSymbol.Name) and
    aGroups.TryGetValue(RoutineGroupKey(aSymbol), lGroup) and
    (CountInSection(lGroup, 'interface') > 0);
end;

// DS-660: the interface or forward declaration of a routine and its implementation are
// separate symbols. A call from another unit or a program main block binds the declaration,
// so each one's references count for the other.
function BuildRoutineGroups(const aIndex: TDelphiSemanticProjectSymbolIndex):
  TDeadCodeRoutineGroups;
var
  lGroup: TList<TDelphiSemanticIndexedSymbol>;
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  Result := TDeadCodeRoutineGroups.Create([doOwnsValues],
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  for lSymbol in aIndex.Symbols do
    if IsOwnerlessProjectRoutine(lSymbol) then
    begin
      if not Result.TryGetValue(RoutineGroupKey(lSymbol), lGroup) then
      begin
        lGroup := TList<TDelphiSemanticIndexedSymbol>.Create;
        Result.Add(RoutineGroupKey(lSymbol), lGroup);
      end;
      lGroup.Add(lSymbol);
    end;
end;

// References to the other declarations of the same routine (RoutineDeclarationsPair).
function PairedRoutineReferenceCount(const aGroups: TDeadCodeRoutineGroups;
  const aReferenceIndex: TDeadCodeReferenceIndex;
  const aSymbol: TDelphiSemanticIndexedSymbol): Integer;
var
  lGroup: TList<TDelphiSemanticIndexedSymbol>;
  lOther: TDelphiSemanticIndexedSymbol;
begin
  Result := 0;
  if not IsOwnerlessProjectRoutine(aSymbol) or
    not aGroups.TryGetValue(RoutineGroupKey(aSymbol), lGroup) then
    Exit;
  for lOther in lGroup do
    if not SameSymbolId(lOther.Id, aSymbol.Id) and
      RoutineDeclarationsPair(lGroup, aSymbol, lOther) then
      Inc(Result, aReferenceIndex.CountResolvedReferences(lOther));
end;

class function TDelphiSemanticDeadCodeReporter.Report(
  const aContext: TDelphiSemanticSymbolQueryContext; const aProfile: string):
  TDelphiSemanticDeadCodeReport;
var
  lProfile: TDelphiSemanticDeadCodeSafetyProfile;
  lProfileName: string;
begin
  lProfileName := Trim(aProfile);
  if lProfileName = '' then
    Exit(Report(aContext, TDelphiSemanticDeadCodeProfiles.DefaultReportProfile));

  if not TDelphiSemanticDeadCodeProfiles.TryParse(lProfileName, lProfile) then
  begin
    Result := Default(TDelphiSemanticDeadCodeReport);
    Result.Profile := lProfileName;
    Result.Diagnostic := TDelphiSemanticDeadCodeProfiles.InvalidProfileDiagnostic(
      lProfileName);
    Exit;
  end;

  Result := Report(aContext, lProfile);
end;

class function TDelphiSemanticDeadCodeReporter.Report(
  const aContext: TDelphiSemanticSymbolQueryContext;
  const aProfile: TDelphiSemanticDeadCodeSafetyProfile): TDelphiSemanticDeadCodeReport;
var
  lBlockers: TList<string>;
  lBlockedUnresolvedReferenceKeys: TDictionary<string, Boolean>;
  lCandidate: TDelphiSemanticDeadCodeCandidate;
  lRoutineGroups: TDeadCodeRoutineGroups;
  lUnresolvedNames: TDictionary<string, Boolean>;
  lCandidates: TList<TDelphiSemanticDeadCodeCandidate>;
  lIndex: TDelphiSemanticProjectSymbolIndex;
  lOccurrences: TDeadCodeOccurrenceScanner;
  lProfile: string;
  lSafetyProfile: TDelphiSemanticDeadCodeSafetyProfile;
  lReferenceIndex: TDeadCodeReferenceIndex;
  lReference: TDelphiSemanticIndexedReference;
  lReferenceCount: Integer;
  lSourceIndex: TDeadCodeSourceIndex;
  lSymbol: TDelphiSemanticIndexedSymbol;
  lUnverifiedScopeStatus: string;
  lUnverifiedUnitName: string;
begin
  lSafetyProfile := aProfile;
  lProfile := TDelphiSemanticDeadCodeProfiles.ToName(lSafetyProfile);

  lIndex := TDelphiSemanticProjectSymbolIndexer.Build(aContext);
  lCandidates := TList<TDelphiSemanticDeadCodeCandidate>.Create;
  lBlockedUnresolvedReferenceKeys := TDictionary<string, Boolean>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  lReferenceIndex := TDeadCodeReferenceIndex.Create(lIndex);
  lSourceIndex := TDeadCodeSourceIndex.Create(aContext);
  lOccurrences := TDeadCodeOccurrenceScanner.Create(lIndex, lSourceIndex);
  lRoutineGroups := BuildRoutineGroups(lIndex);
  lUnresolvedNames := TDictionary<string, Boolean>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  try
    for lReference in lIndex.References do
      if SameText(lReference.Status, 'unresolved') and
        SameText(lReference.SourceKind, 'project-source') then
        lUnresolvedNames.AddOrSetValue(lReference.Name, True);
    for lSymbol in lIndex.Symbols do
    begin
      if not IsProjectSymbol(lSymbol) or not IsCandidateKind(lSymbol) then
        Continue;

      lBlockers := TList<string>.Create;
      try
        if SameText(lSymbol.Visibility, 'published') then
          AddBlocker(lBlockers, 'published-or-dfm-handler');
        if SourceLineContains(lSourceIndex, lSymbol.FileName, lSymbol.Line, 'message') then
          AddBlocker(lBlockers, 'message-method');
        if SourceExportsSymbol(lSourceIndex, lSymbol.FileName, lSymbol.Name) then
          AddBlocker(lBlockers, 'exported-symbol');
        if HasInitializationHook(lSourceIndex, lSymbol) then
          AddBlocker(lBlockers, 'initialization-hook');
        if lReferenceIndex.HasAmbiguousReference(lSymbol) then
          AddBlocker(lBlockers, 'ambiguous-reference');
        if lReferenceIndex.HasUnresolvedReferenceInScope(lSymbol) or
          HasUnresolvedCallOfInterfaceRoutine(lRoutineGroups, lUnresolvedNames, lSymbol) then
          AddBlocker(lBlockers, 'unresolved-reference');

      lReferenceCount := lReferenceIndex.CountResolvedReferences(lSymbol) +
        PairedRoutineReferenceCount(lRoutineGroups, lReferenceIndex, lSymbol);
      if (lReferenceCount = 0) and not lReferenceIndex.HasAmbiguousReference(lSymbol) and
        not lReferenceIndex.HasUnresolvedReferenceInScope(lSymbol) then
        lReferenceCount := lReferenceIndex.CountSameUnitNameReferences(lSymbol);
        if (lReferenceCount > 0) and (lBlockers.Count = 0) then
        Continue;
        // DS-659: an unused declaration from an include file is never removed through its unit,
        // also when an include expanded inside a line puts it on the unit's directive.
        if lSymbol.FromInclude or ((lSymbol.FileName <> '') and
          not lSourceIndex.IsUnitFile(lSymbol.FileName)) then
          AddBlocker(lBlockers, 'declared-in-include');
        if IsUnpairedBodyOfUsedInterfaceRoutine(lRoutineGroups, lReferenceIndex, lSymbol) then
          AddBlocker(lBlockers, 'unpaired-implementation');
        if (lReferenceCount = 0) and lOccurrences.HasUnclassifiedOccurrence(lSymbol.Name) then
          AddBlocker(lBlockers, 'unclassified-occurrence');

        // Members and references of a unit without verified syntax facts may be missing or
        // misowned, so a zero reference count proves nothing there.
        if TDelphiSemanticUsageFinder.TryFindUnverifiedDeclaringUnit(aContext, lSymbol,
          lUnverifiedUnitName, lUnverifiedScopeStatus) then
        begin
          AddBlocker(lBlockers, 'unverified-scope-facts');
          lCandidate := MakeCandidate(lSymbol, 'blocked', 'unverified-scope-facts', lProfile,
            lReferenceCount, lBlockers.ToArray);
        end else if lBlockers.Count > 0 then
          lCandidate := MakeCandidate(lSymbol, 'blocked', 'dynamic-or-unresolved-risk',
            lProfile, lReferenceCount, lBlockers.ToArray)
        else if ExternallyVisible(lSymbol) then
          lCandidate := MakeCandidate(lSymbol, 'externally-visible', 'public-api-surface',
            lProfile, lReferenceCount, [])
        else if DefinitelyUnusedEligible(lSymbol, lSafetyProfile) then
          lCandidate := MakeCandidate(lSymbol, 'definitely-unused', 'no-resolved-references',
            lProfile, lReferenceCount, [])
        else if MaybeUnusedEligible(lSymbol) then
          lCandidate := MakeCandidate(lSymbol, 'definitely-unused', 'no-resolved-references',
            lProfile, lReferenceCount, [])
        else
          lCandidate := MakeCandidate(lSymbol, 'maybe-unused', 'conservative-audit',
            lProfile, lReferenceCount, []);

        lCandidates.Add(lCandidate);
        if CandidateHasBlocker(lCandidate, 'unresolved-reference') then
          lBlockedUnresolvedReferenceKeys.AddOrSetValue(TDeadCodeReferenceIndex.ReferenceScopeKey(
            'project-source', lCandidate.UnitName, lCandidate.Name), True);
      finally
        lBlockers.Free;
      end;
    end;

    for lReference in lIndex.References do
      if SameText(lReference.Status, 'unresolved') and not lBlockedUnresolvedReferenceKeys.ContainsKey(
        TDeadCodeReferenceIndex.ReferenceScopeKey(lReference.SourceKind, lReference.UnitName,
        lReference.Name)) then
      begin
        lSymbol := Default(TDelphiSemanticIndexedSymbol);
        lSymbol.Id.Value := LowerCase(lReference.UnitName) + ':unresolved:' +
          LowerCase(lReference.Name) + ':' + IntToStr(lReference.Line) + ':' +
          IntToStr(lReference.Column);
        lSymbol.Name := lReference.Name;
        lSymbol.Kind := 'unresolved-reference';
        lSymbol.UnitName := lReference.UnitName;
        lSymbol.SectionKind := lReference.SectionKind;
        lSymbol.SourceKind := lReference.SourceKind;
        lSymbol.FileName := lReference.FileName;
        lSymbol.Line := lReference.Line;
        lSymbol.Column := lReference.Column;
        if IsProjectSymbol(lSymbol) then
        begin
          lCandidates.Add(MakeCandidate(lSymbol, 'blocked', 'unresolved-reference-risk',
            lProfile, 0, ['unresolved-reference']));
          lBlockedUnresolvedReferenceKeys.AddOrSetValue(TDeadCodeReferenceIndex.ReferenceScopeKey(
            lReference.SourceKind, lReference.UnitName, lReference.Name), True);
        end;
      end;

    Result := Default(TDelphiSemanticDeadCodeReport);
    Result.Profile := lProfile;
    Result.Candidates := lCandidates.ToArray;
    Result.IndexMetrics := lIndex.Metrics;
  finally
    lUnresolvedNames.Free;
    lRoutineGroups.Free;
    lOccurrences.Free;
    lSourceIndex.Free;
    lReferenceIndex.Free;
    lBlockedUnresolvedReferenceKeys.Free;
    lCandidates.Free;
  end;
end;

end.
