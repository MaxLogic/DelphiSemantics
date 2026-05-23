unit DelphiSemantics.DeadCode;

interface

uses
  DelphiSemantics.Query, DelphiSemantics.Symbols;

type
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
    Candidates: TArray<TDelphiSemanticDeadCodeCandidate>;
  end;

  TDelphiSemanticDeadCodeReporter = record
  public
    class function Report(const aContext: TDelphiSemanticSymbolQueryContext;
      const aProfile: string): TDelphiSemanticDeadCodeReport; static;
  end;

implementation

uses
  System.Classes, System.Generics.Collections, System.Generics.Defaults,
  System.StrUtils, System.SysUtils,
  MaxLogic.StrUtils,
  DelphiSemantics.Index;

type
  TDeadCodeSourceEntry = record
    Text: string;
    LowerText: string;
  end;

  TDeadCodeSourceCache = class
  private
    fEntries: TDictionary<string, TDeadCodeSourceEntry>;
  public
    constructor Create;
    destructor Destroy; override;
    function TryGetEntry(const aFileName: string; out aEntry: TDeadCodeSourceEntry):
      Boolean;
  end;

  TDeadCodeReferenceIndex = class
  private
    fAmbiguousSymbolIds: TDictionary<string, Boolean>;
    fResolvedCountsBySymbolId: TDictionary<string, Integer>;
    fSameUnitNameCounts: TDictionary<string, Integer>;
    fUnresolvedNames: TDictionary<string, Boolean>;
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
    function HasUnresolvedReferenceByName(const aSymbol: TDelphiSemanticIndexedSymbol):
      Boolean;
  end;

constructor TDeadCodeSourceCache.Create;
begin
  inherited Create;
  fEntries := TDictionary<string, TDeadCodeSourceEntry>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
end;

destructor TDeadCodeSourceCache.Destroy;
begin
  fEntries.Free;
  inherited;
end;

function TDeadCodeSourceCache.TryGetEntry(const aFileName: string;
  out aEntry: TDeadCodeSourceEntry): Boolean;
var
  lLines: TStringList;
begin
  aEntry := Default(TDeadCodeSourceEntry);
  if aFileName = '' then
    Exit(False);

  if fEntries.TryGetValue(aFileName, aEntry) then
    Exit(True);

  lLines := TStringList.Create;
  try
    try
      lLines.LoadFromFile(aFileName);
    except
      Exit(False);
    end;

    aEntry.Text := lLines.Text;
    aEntry.LowerText := LowerCase(aEntry.Text);
    fEntries.Add(aFileName, aEntry);
    Result := True;
  finally
    lLines.Free;
  end;
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
  fUnresolvedNames := TDictionary<string, Boolean>.Create(lComparer);

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
      fUnresolvedNames.AddOrSetValue(lReference.Name, True);
  end;
end;

destructor TDeadCodeReferenceIndex.Destroy;
begin
  fUnresolvedNames.Free;
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

function TDeadCodeReferenceIndex.HasUnresolvedReferenceByName(
  const aSymbol: TDelphiSemanticIndexedSymbol): Boolean;
begin
  Result := fUnresolvedNames.ContainsKey(aSymbol.Name);
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

class function TDeadCodeReferenceIndex.SymbolKey(const aId: TDelphiSemanticSymbolId):
  string;
begin
  Result := aId.Value;
end;

function IsIdentifierChar(const ch: Char): Boolean;
begin
  Result := CharInSet(ch, ['A'..'Z', 'a'..'z', '0'..'9', '_']);
end;

function TextContainsIdentifier(const aLowerText, aLowerName: string): Boolean;
var
  lAfterPos: Integer;
  lPos: Integer;
begin
  Result := False;
  if (aLowerText = '') or (aLowerName = '') then
    Exit;

  lPos := Pos(aLowerName, aLowerText);
  while lPos > 0 do
  begin
    lAfterPos := lPos + Length(aLowerName);
    if ((lPos = 1) or not IsIdentifierChar(aLowerText[lPos - 1])) and
      ((lAfterPos > Length(aLowerText)) or not IsIdentifierChar(aLowerText[lAfterPos])) then
      Exit(True);
    lPos := Pos(aLowerName, aLowerText, lPos + 1);
  end;
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

function HasUnresolvedReferenceByName(const aIndex: TDelphiSemanticProjectSymbolIndex;
  const aSymbol: TDelphiSemanticIndexedSymbol): Boolean;
var
  lReference: TDelphiSemanticIndexedReference;
begin
  for lReference in aIndex.References do
    if SameText(lReference.Status, 'unresolved') and SameText(lReference.Name, aSymbol.Name) then
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

function SourceLineContains(const aSourceCache: TDeadCodeSourceCache; const aFileName: string;
  const aLine: Integer; const aText: string): Boolean;
var
  lEntry: TDeadCodeSourceEntry;
begin
  if (aFileName = '') or (aLine <= 0) then
    Exit(False);

  Result := aSourceCache.TryGetEntry(aFileName, lEntry) and
    ContainsText(SourceLineText(lEntry.Text, aLine), aText);
end;

function SourceSectionContainsIdentifier(const aSourceCache: TDeadCodeSourceCache;
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

  if not aSourceCache.TryGetEntry(aFileName, lEntry) then
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

function SourceExportsSymbol(const aSourceCache: TDeadCodeSourceCache; const aFileName,
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

  if not aSourceCache.TryGetEntry(aFileName, lEntry) then
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

function HasInitializationHook(const aSourceCache: TDeadCodeSourceCache;
  const aSymbol: TDelphiSemanticIndexedSymbol): Boolean;
begin
  Result := SourceSectionContainsIdentifier(aSourceCache, aSymbol.FileName, 'initialization',
    aSymbol.Name) or SourceSectionContainsIdentifier(aSourceCache, aSymbol.FileName,
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
  const aProfile: string): Boolean;
begin
  Result := IsDataSymbol(aSymbol) or SameText(aSymbol.Visibility, 'private') or
    SameText(aSymbol.Visibility, 'strict private') or
    (SameText(aProfile, 'legacy-static') and SameText(aSymbol.Kind, 'routine') and
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
  lBlockers: TList<string>;
  lBlockedUnresolvedNames: TDictionary<string, Boolean>;
  lCandidate: TDelphiSemanticDeadCodeCandidate;
  lCandidates: TList<TDelphiSemanticDeadCodeCandidate>;
  lIndex: TDelphiSemanticProjectSymbolIndex;
  lProfile: string;
  lReferenceIndex: TDeadCodeReferenceIndex;
  lReference: TDelphiSemanticIndexedReference;
  lReferenceCount: Integer;
  lSourceCache: TDeadCodeSourceCache;
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  lProfile := aProfile;
  if lProfile = '' then
    lProfile := 'audit';

  lIndex := TDelphiSemanticProjectSymbolIndexer.Build(aContext);
  lCandidates := TList<TDelphiSemanticDeadCodeCandidate>.Create;
  lBlockedUnresolvedNames := TDictionary<string, Boolean>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  lReferenceIndex := TDeadCodeReferenceIndex.Create(lIndex);
  lSourceCache := TDeadCodeSourceCache.Create;
  try
    for lSymbol in lIndex.Symbols do
    begin
      if not IsProjectSymbol(lSymbol) or not IsCandidateKind(lSymbol) then
        Continue;

      lBlockers := TList<string>.Create;
      try
        if SameText(lSymbol.Visibility, 'published') then
          AddBlocker(lBlockers, 'published-or-dfm-handler');
        if SourceLineContains(lSourceCache, lSymbol.FileName, lSymbol.Line, 'message') then
          AddBlocker(lBlockers, 'message-method');
        if SourceExportsSymbol(lSourceCache, lSymbol.FileName, lSymbol.Name) then
          AddBlocker(lBlockers, 'exported-symbol');
        if HasInitializationHook(lSourceCache, lSymbol) then
          AddBlocker(lBlockers, 'initialization-hook');
        if lReferenceIndex.HasAmbiguousReference(lSymbol) then
          AddBlocker(lBlockers, 'ambiguous-reference');
        if lReferenceIndex.HasUnresolvedReferenceByName(lSymbol) then
          AddBlocker(lBlockers, 'unresolved-reference');

      lReferenceCount := lReferenceIndex.CountResolvedReferences(lSymbol);
      if (lReferenceCount = 0) and not lReferenceIndex.HasAmbiguousReference(lSymbol) and
        not lReferenceIndex.HasUnresolvedReferenceByName(lSymbol) then
        lReferenceCount := lReferenceIndex.CountSameUnitNameReferences(lSymbol);
        if (lReferenceCount > 0) and (lBlockers.Count = 0) then
        Continue;

        if lBlockers.Count > 0 then
          lCandidate := MakeCandidate(lSymbol, 'blocked', 'dynamic-or-unresolved-risk',
            lProfile, lReferenceCount, lBlockers.ToArray)
        else if ExternallyVisible(lSymbol) then
          lCandidate := MakeCandidate(lSymbol, 'externally-visible', 'public-api-surface',
            lProfile, lReferenceCount, [])
        else if DefinitelyUnusedEligible(lSymbol, lProfile) then
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
          lBlockedUnresolvedNames.AddOrSetValue(lCandidate.Name, True);
      finally
        lBlockers.Free;
      end;
    end;

    for lReference in lIndex.References do
      if SameText(lReference.Status, 'unresolved') and not lBlockedUnresolvedNames.ContainsKey(
        lReference.Name) then
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
          lBlockedUnresolvedNames.AddOrSetValue(lReference.Name, True);
        end;
      end;

    Result := Default(TDelphiSemanticDeadCodeReport);
    Result.Profile := lProfile;
    Result.Candidates := lCandidates.ToArray;
  finally
    lSourceCache.Free;
    lReferenceIndex.Free;
    lBlockedUnresolvedNames.Free;
    lCandidates.Free;
  end;
end;

end.
