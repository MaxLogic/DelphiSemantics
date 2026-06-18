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
    procedure AddEntry(const aFileName, aText: string);
    procedure AddModel(const aModel: TDelphiSemanticUnitModel);
    procedure AddSnapshot(const aSnapshot: TDelphiProjectSnapshot);
  public
    constructor Create(const aContext: TDelphiSemanticSymbolQueryContext);
    destructor Destroy; override;
    function TryGetEntry(const aFileName: string; out aEntry: TDeadCodeSourceEntry):
      Boolean;
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
  lSnapshot := ContextProjectSnapshot(aContext);
  AddSnapshot(lSnapshot);
  AddModel(aContext.UnitModel);
  for lModel in aContext.IndexedUnitModels do
    AddModel(lModel);
end;

destructor TDeadCodeSourceIndex.Destroy;
begin
  fEntries.Free;
  inherited;
end;

procedure TDeadCodeSourceIndex.AddEntry(const aFileName, aText: string);
var
  lEntry: TDeadCodeSourceEntry;
begin
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
  lCandidates: TList<TDelphiSemanticDeadCodeCandidate>;
  lIndex: TDelphiSemanticProjectSymbolIndex;
  lProfile: string;
  lSafetyProfile: TDelphiSemanticDeadCodeSafetyProfile;
  lReferenceIndex: TDeadCodeReferenceIndex;
  lReference: TDelphiSemanticIndexedReference;
  lReferenceCount: Integer;
  lSourceIndex: TDeadCodeSourceIndex;
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  lSafetyProfile := aProfile;
  lProfile := TDelphiSemanticDeadCodeProfiles.ToName(lSafetyProfile);

  lIndex := TDelphiSemanticProjectSymbolIndexer.Build(aContext);
  lCandidates := TList<TDelphiSemanticDeadCodeCandidate>.Create;
  lBlockedUnresolvedReferenceKeys := TDictionary<string, Boolean>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  lReferenceIndex := TDeadCodeReferenceIndex.Create(lIndex);
  lSourceIndex := TDeadCodeSourceIndex.Create(aContext);
  try
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
        if lReferenceIndex.HasUnresolvedReferenceInScope(lSymbol) then
          AddBlocker(lBlockers, 'unresolved-reference');

      lReferenceCount := lReferenceIndex.CountResolvedReferences(lSymbol);
      if (lReferenceCount = 0) and not lReferenceIndex.HasAmbiguousReference(lSymbol) and
        not lReferenceIndex.HasUnresolvedReferenceInScope(lSymbol) then
        lReferenceCount := lReferenceIndex.CountSameUnitNameReferences(lSymbol);
        if (lReferenceCount > 0) and (lBlockers.Count = 0) then
        Continue;

        if lBlockers.Count > 0 then
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
    lSourceIndex.Free;
    lReferenceIndex.Free;
    lBlockedUnresolvedReferenceKeys.Free;
    lCandidates.Free;
  end;
end;

end.
