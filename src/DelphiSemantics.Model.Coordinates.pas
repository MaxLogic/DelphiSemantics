unit DelphiSemantics.Model.Coordinates;

interface

uses
  System.Generics.Collections,
  DelphiSemantics.Model;

procedure ReconcileDeclarationCoordinates(const aSourceText: string;
  const aDeclarations: TList<TDelphiSemanticDeclaration>);
function BuildOutputToSourceOffsetMap(const aSourceText, aOutputText: string): TArray<Integer>;
procedure ApplyReferenceSourceOffsetMap(const aSourceText: string; const aOffsetMap:
  TArray<Integer>; const aReferences: TList<TDelphiSemanticReference>);
procedure ApplyRoutineSourceOffsetMap(const aSourceText: string; const aOffsetMap:
  TArray<Integer>; const aRoutines: TList<TDelphiSemanticRoutine>);
procedure ApplyDeclarationSourceOffsetMap(const aSourceText: string; const aOffsetMap:
  TArray<Integer>; const aDeclarations: TList<TDelphiSemanticDeclaration>);
procedure ApplyMemberSourceOffsetMap(const aSourceText: string; const aOffsetMap:
  TArray<Integer>; const aMembers: TList<TDelphiSemanticMember>);
procedure ApplyLocalSourceOffsetMap(const aSourceText: string; const aOffsetMap:
  TArray<Integer>; const aLocals: TList<TDelphiSemanticLocal>);
procedure ReconcileReferencesCoordinates(const aSourceText: string;
  const aReferences: TList<TDelphiSemanticReference>; var aMetrics:
  TDelphiSemanticUnitModelMetrics);
procedure ReconcileMemberCoordinates(const aSourceText: string;
  const aMembers: TList<TDelphiSemanticMember>);
procedure ReconcileRoutineCoordinates(const aSourceText: string;
  const aRoutines: TList<TDelphiSemanticRoutine>);
procedure ReconcileLocalCoordinates(const aSourceText: string;
  const aLocals: TList<TDelphiSemanticLocal>);

implementation

uses
  System.Classes, System.RegularExpressions, System.StrUtils, System.SysUtils,
  DelphiSemantics.Model.Text;

type
  TSourceCoordinateIndex = record
  private
    fSourceText: string;
    fLineStarts: TArray<Integer>;
    function LineIndexForOffset(const aOffset: Integer): Integer;
  public
    procedure Initialize(const aSourceText: string);
    procedure CoordinatesAtOffset(const aOffset: Integer; out aLine, aColumn: Integer);
    function LineOfOffset(const aOffset: Integer): Integer;
    function ColumnOfOffset(const aOffset: Integer): Integer;
    function OffsetOfLineColumn(const aLine, aColumn: Integer): Integer;
  end;

  TReferenceCoordinateCandidate = record
    Offset: Integer;
    Line: Integer;
    Column: Integer;
  end;

  TReferenceCandidateList = TList<TReferenceCoordinateCandidate>;
  TReferenceOccurrenceIndex = TObjectDictionary<string, TReferenceCandidateList>;

procedure TSourceCoordinateIndex.Initialize(const aSourceText: string);
var
  i: Integer;
  lCount: Integer;
begin
  fSourceText := aSourceText;
  lCount := 1;
  for i := 1 to Length(fSourceText) do
    if fSourceText[i] = #10 then
      Inc(lCount);
  SetLength(fLineStarts, lCount);
  fLineStarts[0] := 1;
  lCount := 1;
  for i := 1 to Length(fSourceText) do
    if fSourceText[i] = #10 then
    begin
      fLineStarts[lCount] := i + 1;
      Inc(lCount);
    end;
end;

function TSourceCoordinateIndex.LineIndexForOffset(const aOffset: Integer): Integer;
var
  lHigh: Integer;
  lMiddle: Integer;
begin
  Result := 0;
  lHigh := High(fLineStarts);
  while Result < lHigh do
  begin
    lMiddle := Result + (lHigh - Result + 1) div 2;
    if fLineStarts[lMiddle] <= aOffset then
      Result := lMiddle
    else
      lHigh := lMiddle - 1;
  end;
end;

function TSourceCoordinateIndex.LineOfOffset(const aOffset: Integer): Integer;
var
  lOffset: Integer;
begin
  lOffset := aOffset;
  if lOffset < 1 then
    lOffset := 1;
  if lOffset > Length(fSourceText) then
    lOffset := Length(fSourceText);
  Result := LineIndexForOffset(lOffset) + 1;
  // Keep the existing LF boundary contract: LF belongs to the next line.
  if (lOffset > 0) and (fSourceText[lOffset] = #10) then
    Inc(Result);
end;

function TSourceCoordinateIndex.ColumnOfOffset(const aOffset: Integer): Integer;
begin
  Result := aOffset - fLineStarts[LineIndexForOffset(aOffset)] + 1;
  if Result < 1 then
    Result := 1;
end;

procedure TSourceCoordinateIndex.CoordinatesAtOffset(const aOffset: Integer;
  out aLine, aColumn: Integer);
var
  lLineIndex: Integer;
begin
  lLineIndex := LineIndexForOffset(aOffset);
  aColumn := aOffset - fLineStarts[lLineIndex] + 1;
  if aColumn < 1 then
    aColumn := 1;
  aLine := lLineIndex + 1;
  if (aOffset < 1) or (aOffset > Length(fSourceText)) then
    aLine := LineOfOffset(aOffset)
  else if fSourceText[aOffset] = #10 then
    Inc(aLine);
end;

function TSourceCoordinateIndex.OffsetOfLineColumn(const aLine, aColumn: Integer): Integer;
var
  lStartOffset: Integer;
begin
  Result := 0;
  if (aLine <= 0) or (aLine > Length(fLineStarts)) or (aColumn <= 0) then
    Exit;
  lStartOffset := fLineStarts[aLine - 1];
  // Columns may cross a line boundary, but never the end of the source.
  if aColumn <= Length(fSourceText) - lStartOffset + 1 then
    Result := lStartOffset + aColumn - 1;
end;

function FindSectionKeywordOffset(const aLowerText, aKeyword: string): Integer;
var
  lAfter: Integer;
  lOffset: Integer;
begin
  lOffset := PosEx(aKeyword, aLowerText, 1);
  while lOffset > 0 do
  begin
    lAfter := lOffset + Length(aKeyword);
    if ((lOffset = 1) or not IsIdentifierChar(aLowerText[lOffset - 1])) and
      ((lAfter > Length(aLowerText)) or not IsIdentifierChar(aLowerText[lAfter])) then
      Exit(lOffset);

    lOffset := PosEx(aKeyword, aLowerText, lAfter);
  end;

  Result := 0;
end;

function BuildSourceSections(const aText: string): TDelphiSemanticSourceSections;
var
  lLowerText: string;
  lText: string;
begin
  Result := Default(TDelphiSemanticSourceSections);
  lText := aText;
  if (lText <> '') and (lText[1] = #$FEFF) then
    Delete(lText, 1, 1);
  lLowerText := LowerCase(SanitizeCodeText(lText));
  Result.InterfaceOffset := FindSectionKeywordOffset(lLowerText, 'interface');
  Result.ImplementationOffset := FindSectionKeywordOffset(lLowerText, 'implementation');
  Result.InitializationOffset := FindSectionKeywordOffset(lLowerText, 'initialization');
  Result.FinalizationOffset := FindSectionKeywordOffset(lLowerText, 'finalization');
end;

function SectionForOffset(const aSections: TDelphiSemanticSourceSections;
  const aOffset: Integer): string;
begin
  if (aSections.FinalizationOffset > 0) and (aOffset >= aSections.FinalizationOffset) then
    Exit('finalization');
  if (aSections.InitializationOffset > 0) and (aOffset >= aSections.InitializationOffset) then
    Exit('initialization');
  if (aSections.ImplementationOffset > 0) and (aOffset >= aSections.ImplementationOffset) then
    Exit('implementation');

  Result := 'interface';
end;

procedure ReconcileDeclarationCoordinates(const aSourceText: string;
  const aDeclarations: TList<TDelphiSemanticDeclaration>);
var
  lCoordinates: TSourceCoordinateIndex;
  i: Integer;
  lBestColumn: Integer;
  lBestDistance: Integer;
  lBestLine: Integer;
  lCandidateColumn: Integer;
  lCandidateDistance: Integer;
  lCandidateLine: Integer;
  lCandidateOffset: Integer;
  lDeclaration: TDelphiSemanticDeclaration;
  lMatch: TMatch;
begin
  if aDeclarations.Count = 0 then
    Exit;
  lCoordinates.Initialize(aSourceText);
  for i := 0 to Pred(aDeclarations.Count) do
  begin
    lDeclaration := aDeclarations[i];
    if (lDeclaration.Offset >= 1) and (lDeclaration.Offset + Length(lDeclaration.Name) - 1 <=
      Length(aSourceText)) and SameText(Copy(aSourceText, lDeclaration.Offset,
      Length(lDeclaration.Name)), lDeclaration.Name) then
    begin
      lDeclaration.Line := lCoordinates.LineOfOffset(lDeclaration.Offset);
      lDeclaration.Column := lCoordinates.ColumnOfOffset(lDeclaration.Offset);
      aDeclarations[i] := lDeclaration;
      Continue;
    end;

    lBestColumn := 0;
    lBestDistance := MaxInt;
    lBestLine := 0;
    lMatch := TRegEx.Match(aSourceText, '^(\s*)' + TRegEx.Escape(lDeclaration.Name) + '\b',
      [roIgnoreCase, roMultiLine]);
    while lMatch.Success do
    begin
      lCandidateOffset := lMatch.Index + Length(lMatch.Groups[1].Value);
      lCandidateLine := lCoordinates.LineOfOffset(lCandidateOffset);
      lCandidateColumn := lCoordinates.ColumnOfOffset(lCandidateOffset);
      lCandidateDistance := Abs(lCandidateLine - lDeclaration.Line);
      if lCandidateDistance < lBestDistance then
      begin
        lBestDistance := lCandidateDistance;
        lBestLine := lCandidateLine;
        lBestColumn := lCandidateColumn;
        lDeclaration.Offset := lCandidateOffset;
        lDeclaration.EndOffset := lCandidateOffset + Length(lDeclaration.Name);
      end;
      lMatch := lMatch.NextMatch;
    end;
    if lBestLine > 0 then
    begin
      lDeclaration.Line := lBestLine;
      lDeclaration.Column := lBestColumn;
      aDeclarations[i] := lDeclaration;
    end;
  end;
end;

function BuildOutputToSourceOffsetMap(const aSourceText, aOutputText: string): TArray<Integer>;
var
  i: Integer;
  j: Integer;
  lOutputLines: TStringList;
  lOutputOffset: Integer;
  lOutputLine: string;
  lSourceLines: TStringList;
  lSourceOffset: Integer;
  lSourceLine: string;
begin
  SetLength(Result, Length(aOutputText) + 1);
  lSourceLines := TStringList.Create;
  lOutputLines := TStringList.Create;
  try
    lSourceLines.Text := aSourceText;
    lOutputLines.Text := aOutputText;
    lSourceOffset := 1;
    lOutputOffset := 1;
    for i := 0 to Pred(lOutputLines.Count) do
    begin
      lOutputLine := lOutputLines[i];
      if i < lSourceLines.Count then
        lSourceLine := lSourceLines[i]
      else
        lSourceLine := '';

      if lOutputLine = lSourceLine then
        for j := 0 to Length(lOutputLine) - 1 do
          Result[lOutputOffset + j] := lSourceOffset + j;

      Inc(lSourceOffset, Length(lSourceLine) + Length(sLineBreak));
      Inc(lOutputOffset, Length(lOutputLine) + Length(sLineBreak));
    end;
  finally
    lOutputLines.Free;
    lSourceLines.Free;
  end;
end;

procedure ApplyReferenceSourceOffsetMap(const aSourceText: string; const aOffsetMap:
  TArray<Integer>; const aReferences: TList<TDelphiSemanticReference>);
var
  lCoordinates: TSourceCoordinateIndex;
  i: Integer;
  lMappedOffset: Integer;
  lReference: TDelphiSemanticReference;
  lSections: TDelphiSemanticSourceSections;
begin
  if aReferences.Count = 0 then
    Exit;
  lCoordinates.Initialize(aSourceText);
  lSections := BuildSourceSections(aSourceText);
  for i := 0 to Pred(aReferences.Count) do
  begin
    lReference := aReferences[i];
    lMappedOffset := lCoordinates.OffsetOfLineColumn(lReference.Line, lReference.Column);
    if ((lMappedOffset <= 0) or (lMappedOffset + Length(lReference.Name) - 1 >
      Length(aSourceText)) or not SameText(Copy(aSourceText, lMappedOffset,
      Length(lReference.Name)), lReference.Name)) and (Length(aOffsetMap) > 0) and
      (lReference.Offset > 0) and (lReference.Offset <= High(aOffsetMap)) then
      lMappedOffset := aOffsetMap[lReference.Offset];

    if (lMappedOffset <= 0) or (lMappedOffset + Length(lReference.Name) - 1 >
      Length(aSourceText)) or not SameText(Copy(aSourceText, lMappedOffset,
      Length(lReference.Name)), lReference.Name) then
      Continue;

    lReference.Offset := lMappedOffset;
    lReference.EndOffset := lMappedOffset + Length(lReference.Name);
    lReference.Line := lCoordinates.LineOfOffset(lMappedOffset);
    lReference.Column := lCoordinates.ColumnOfOffset(lMappedOffset);
    lReference.EndLine := lReference.Line;
    lReference.EndColumn := lReference.Column + Length(lReference.Name) - 1;
    lReference.SectionKind := SectionForOffset(lSections, lMappedOffset);
    aReferences[i] := lReference;
  end;
end;

function SourceRangeMatchesRoutine(const aSourceText: string;
  const aRoutine: TDelphiSemanticRoutine): Boolean;
begin
  Result := (aRoutine.Offset >= 1) and (aRoutine.Offset + Length(aRoutine.Name) - 1 <=
    Length(aSourceText)) and SameText(Copy(aSourceText, aRoutine.Offset,
    Length(aRoutine.Name)), aRoutine.Name);
end;

procedure AssignRoutineSourceRange(var aRoutine: TDelphiSemanticRoutine;
  const aCoordinates: TSourceCoordinateIndex; const aOffset: Integer);
begin
  aRoutine.Offset := aOffset;
  aRoutine.EndOffset := aOffset + Length(aRoutine.Name);
  aRoutine.Line := aCoordinates.LineOfOffset(aOffset);
  aRoutine.Column := aCoordinates.ColumnOfOffset(aOffset);
end;

procedure ApplyRoutineSourceOffsetMap(const aSourceText: string; const aOffsetMap:
  TArray<Integer>; const aRoutines: TList<TDelphiSemanticRoutine>);
var
  lCoordinates: TSourceCoordinateIndex;
  i: Integer;
  lMappedOffset: Integer;
  lRoutine: TDelphiSemanticRoutine;
begin
  if aRoutines.Count = 0 then
    Exit;
  lCoordinates.Initialize(aSourceText);
  for i := 0 to Pred(aRoutines.Count) do
  begin
    lRoutine := aRoutines[i];
    lMappedOffset := lCoordinates.OffsetOfLineColumn(lRoutine.Line, lRoutine.Column);
    if ((lMappedOffset <= 0) or (lMappedOffset + Length(lRoutine.Name) - 1 >
      Length(aSourceText)) or not SameText(Copy(aSourceText, lMappedOffset,
      Length(lRoutine.Name)), lRoutine.Name)) and (Length(aOffsetMap) > 0) and
      (lRoutine.Offset > 0) and (lRoutine.Offset <= High(aOffsetMap)) then
      lMappedOffset := aOffsetMap[lRoutine.Offset];

    if (lMappedOffset <= 0) or (lMappedOffset + Length(lRoutine.Name) - 1 >
      Length(aSourceText)) or not SameText(Copy(aSourceText, lMappedOffset,
      Length(lRoutine.Name)), lRoutine.Name) then
      Continue;

    AssignRoutineSourceRange(lRoutine, lCoordinates, lMappedOffset);
    aRoutines[i] := lRoutine;
  end;
end;

procedure ApplyDeclarationSourceOffsetMap(const aSourceText: string; const aOffsetMap:
  TArray<Integer>; const aDeclarations: TList<TDelphiSemanticDeclaration>);
var
  lCoordinates: TSourceCoordinateIndex;
  i: Integer;
  lDeclaration: TDelphiSemanticDeclaration;
  lMappedOffset: Integer;
begin
  if aDeclarations.Count = 0 then
    Exit;
  lCoordinates.Initialize(aSourceText);
  for i := 0 to Pred(aDeclarations.Count) do
  begin
    lDeclaration := aDeclarations[i];
    lMappedOffset := lCoordinates.OffsetOfLineColumn(lDeclaration.Line,
      lDeclaration.Column);
    if ((lMappedOffset <= 0) or (lMappedOffset + Length(lDeclaration.Name) - 1 >
      Length(aSourceText)) or not SameText(Copy(aSourceText, lMappedOffset,
      Length(lDeclaration.Name)), lDeclaration.Name)) and (Length(aOffsetMap) > 0) and
      (lDeclaration.Offset > 0) and (lDeclaration.Offset <= High(aOffsetMap)) then
      lMappedOffset := aOffsetMap[lDeclaration.Offset];

    if (lMappedOffset <= 0) or (lMappedOffset + Length(lDeclaration.Name) - 1 >
      Length(aSourceText)) or not SameText(Copy(aSourceText, lMappedOffset,
      Length(lDeclaration.Name)), lDeclaration.Name) then
      Continue;

    lDeclaration.Offset := lMappedOffset;
    lDeclaration.EndOffset := lMappedOffset + Length(lDeclaration.Name);
    lDeclaration.Line := lCoordinates.LineOfOffset(lMappedOffset);
    lDeclaration.Column := lCoordinates.ColumnOfOffset(lMappedOffset);
    aDeclarations[i] := lDeclaration;
  end;
end;

procedure ApplyMemberSourceOffsetMap(const aSourceText: string; const aOffsetMap:
  TArray<Integer>; const aMembers: TList<TDelphiSemanticMember>);
var
  lCoordinates: TSourceCoordinateIndex;
  i: Integer;
  lMappedOffset: Integer;
  lMember: TDelphiSemanticMember;
begin
  if aMembers.Count = 0 then
    Exit;
  lCoordinates.Initialize(aSourceText);
  for i := 0 to Pred(aMembers.Count) do
  begin
    lMember := aMembers[i];
    lMappedOffset := lCoordinates.OffsetOfLineColumn(lMember.Line, lMember.Column);
    if ((lMappedOffset <= 0) or (lMappedOffset + Length(lMember.Name) - 1 >
      Length(aSourceText)) or not SameText(Copy(aSourceText, lMappedOffset,
      Length(lMember.Name)), lMember.Name)) and (Length(aOffsetMap) > 0) and
      (lMember.Offset > 0) and (lMember.Offset <= High(aOffsetMap)) then
      lMappedOffset := aOffsetMap[lMember.Offset];

    if (lMappedOffset <= 0) or (lMappedOffset + Length(lMember.Name) - 1 >
      Length(aSourceText)) or not SameText(Copy(aSourceText, lMappedOffset,
      Length(lMember.Name)), lMember.Name) then
      Continue;

    lMember.Offset := lMappedOffset;
    lMember.EndOffset := lMappedOffset + Length(lMember.Name);
    lMember.Line := lCoordinates.LineOfOffset(lMappedOffset);
    lMember.Column := lCoordinates.ColumnOfOffset(lMappedOffset);
    aMembers[i] := lMember;
  end;
end;

procedure ApplyLocalSourceOffsetMap(const aSourceText: string; const aOffsetMap:
  TArray<Integer>; const aLocals: TList<TDelphiSemanticLocal>);
var
  lCoordinates: TSourceCoordinateIndex;
  i: Integer;
  lLocal: TDelphiSemanticLocal;
  lMappedOffset: Integer;
begin
  if aLocals.Count = 0 then
    Exit;
  lCoordinates.Initialize(aSourceText);
  for i := 0 to Pred(aLocals.Count) do
  begin
    lLocal := aLocals[i];
    lMappedOffset := lCoordinates.OffsetOfLineColumn(lLocal.Line, lLocal.Column);
    if ((lMappedOffset <= 0) or (lMappedOffset + Length(lLocal.Name) - 1 >
      Length(aSourceText)) or not SameText(Copy(aSourceText, lMappedOffset,
      Length(lLocal.Name)), lLocal.Name)) and (Length(aOffsetMap) > 0) and
      (lLocal.Offset > 0) and (lLocal.Offset <= High(aOffsetMap)) then
      lMappedOffset := aOffsetMap[lLocal.Offset];

    if (lMappedOffset <= 0) or (lMappedOffset + Length(lLocal.Name) - 1 >
      Length(aSourceText)) or not SameText(Copy(aSourceText, lMappedOffset,
      Length(lLocal.Name)), lLocal.Name) then
      Continue;

    lLocal.Offset := lMappedOffset;
    lLocal.EndOffset := lMappedOffset + Length(lLocal.Name);
    lLocal.Line := lCoordinates.LineOfOffset(lMappedOffset);
    lLocal.Column := lCoordinates.ColumnOfOffset(lMappedOffset);
    aLocals[i] := lLocal;
  end;
end;

procedure ReconcileReferencesCoordinates(const aSourceText: string;
  const aReferences: TList<TDelphiSemanticReference>; var aMetrics:
  TDelphiSemanticUnitModelMetrics);
var
  i: Integer;
  lBestColumn: Integer;
  lBestDistance: Integer;
  lBestLine: Integer;
  lBestOffset: Integer;
  lCandidateColumn: Integer;
  lCandidateDistance: Integer;
  lCandidateLine: Integer;
  lCandidateOffset: Integer;
  lCandidate: TReferenceCoordinateCandidate;
  lCandidates: TReferenceCandidateList;
  lCleanText: string;
  lCoordinates: TSourceCoordinateIndex;
  lOccurrenceIndex: TReferenceOccurrenceIndex;
  lReference: TDelphiSemanticReference;

  function SourceTextMatchesReference(const aOffset: Integer;
    const aReference: TDelphiSemanticReference): Boolean;
  begin
    Result := (aOffset >= 1) and (aOffset + Length(aReference.Name) - 1 <=
      Length(aSourceText)) and SameText(Copy(aSourceText, aOffset, Length(aReference.Name)),
      aReference.Name);
  end;

  function SourceRangeMatchesReference(const aOffset: Integer;
    const aReference: TDelphiSemanticReference): Boolean;
  var
    lColumn: Integer;
    lLine: Integer;
  begin
    Result := SourceTextMatchesReference(aOffset, aReference);
    if not Result then
      Exit;
    lCoordinates.CoordinatesAtOffset(aOffset, lLine, lColumn);
    Result := (lLine = aReference.Line) and (lColumn = aReference.Column);
  end;

  function BuildReferenceOccurrenceIndex: TReferenceOccurrenceIndex;
  var
    i: Integer;
    lCandidate: TReferenceCoordinateCandidate;
    lKey: string;
    lList: TReferenceCandidateList;
    lName: string;
    lStartOffset: Integer;
  begin
    Result := TReferenceOccurrenceIndex.Create([doOwnsValues]);
    Inc(aMetrics.ReferenceOccurrenceTableBuildCount);
    i := 1;
    while i <= Length(lCleanText) do
    begin
      if CharInSet(lCleanText[i], ['A'..'Z', 'a'..'z', '_']) then
      begin
        lStartOffset := i;
        Inc(i);
        while (i <= Length(lCleanText)) and IsIdentifierChar(lCleanText[i]) do
          Inc(i);
        lName := Copy(lCleanText, lStartOffset, i - lStartOffset);
        lKey := LowerCase(lName);
        if not Result.TryGetValue(lKey, lList) then
        begin
          lList := TReferenceCandidateList.Create;
          Result.Add(lKey, lList);
        end;
        lCandidate.Offset := lStartOffset;
        lCoordinates.CoordinatesAtOffset(lStartOffset, lCandidate.Line, lCandidate.Column);
        lList.Add(lCandidate);
      end else
        Inc(i);
    end;
  end;

  function CandidatesForName(const aName: string): TReferenceCandidateList;
  var
    lKey: string;
  begin
    if lOccurrenceIndex = nil then
      lOccurrenceIndex := BuildReferenceOccurrenceIndex;

    lKey := LowerCase(aName);
    if lOccurrenceIndex.TryGetValue(lKey, Result) then
      Exit;

    Result := nil;
  end;

  procedure AssignReferenceSourceRange(var aReference: TDelphiSemanticReference;
    const aOffset: Integer);
  begin
    lCoordinates.CoordinatesAtOffset(aOffset, aReference.Line, aReference.Column);
    aReference.Offset := aOffset;
    aReference.EndOffset := aOffset + Length(aReference.Name);
    aReference.EndLine := aReference.Line;
    aReference.EndColumn := aReference.Column + Length(aReference.Name) - 1;
  end;
begin
  if aReferences.Count = 0 then
    Exit;
  lCoordinates.Initialize(aSourceText);
  lCleanText := SanitizeCodeText(aSourceText);
  lOccurrenceIndex := nil;
  try
    for i := 0 to Pred(aReferences.Count) do
    begin
      lReference := aReferences[i];
      if SourceRangeMatchesReference(lReference.Offset, lReference) then
      begin
        AssignReferenceSourceRange(lReference, lReference.Offset);
        aReferences[i] := lReference;
        Continue;
      end;

      Inc(aMetrics.ReferenceReconciliationFallbackCount);
      lBestColumn := 0;
      lBestDistance := MaxInt;
      lBestLine := 0;
      lBestOffset := 0;
      lCandidates := CandidatesForName(lReference.Name);
      if lCandidates <> nil then
        for lCandidate in lCandidates do
        begin
          lCandidateOffset := lCandidate.Offset;
          lCandidateLine := lCandidate.Line;
          lCandidateColumn := lCandidate.Column;
          lCandidateDistance := Abs(lCandidateLine - lReference.Line) * 10000 +
            Abs(lCandidateColumn - lReference.Column);
          if lCandidateDistance < lBestDistance then
          begin
            lBestDistance := lCandidateDistance;
            lBestLine := lCandidateLine;
            lBestColumn := lCandidateColumn;
            lBestOffset := lCandidateOffset;
          end;
        end;
      if lBestLine > 0 then
      begin
        AssignReferenceSourceRange(lReference, lBestOffset);
        aReferences[i] := lReference;
      end;
    end;
  finally
    lOccurrenceIndex.Free;
  end;
end;

procedure ReconcileMemberCoordinates(const aSourceText: string;
  const aMembers: TList<TDelphiSemanticMember>);
var
  lCoordinates: TSourceCoordinateIndex;
  i: Integer;
  lBestColumn: Integer;
  lBestDistance: Integer;
  lBestLine: Integer;
  lCandidateColumn: Integer;
  lCandidateDistance: Integer;
  lCandidateLine: Integer;
  lCandidateOffset: Integer;
  lCleanText: string;
  lMatch: TMatch;
  lMember: TDelphiSemanticMember;
begin
  if aMembers.Count = 0 then
    Exit;
  lCoordinates.Initialize(aSourceText);
  lCleanText := '';
  for i := 0 to Pred(aMembers.Count) do
  begin
    lMember := aMembers[i];
    if (lMember.Offset >= 1) and (lMember.Offset + Length(lMember.Name) - 1 <=
      Length(aSourceText)) and SameText(Copy(aSourceText, lMember.Offset,
      Length(lMember.Name)), lMember.Name) then
    begin
      lMember.Line := lCoordinates.LineOfOffset(lMember.Offset);
      lMember.Column := lCoordinates.ColumnOfOffset(lMember.Offset);
      aMembers[i] := lMember;
      Continue;
    end;

    lBestColumn := 0;
    lBestDistance := MaxInt;
    lBestLine := 0;
    if lCleanText = '' then
      lCleanText := SanitizeCodeText(aSourceText);
    lMatch := TRegEx.Match(lCleanText,
      '^(\s*(?:(?:property|procedure|function|constructor|destructor)\s+)?)' +
      TRegEx.Escape(lMember.Name) + '\b', [roIgnoreCase, roMultiLine]);
    while lMatch.Success do
    begin
      lCandidateOffset := lMatch.Index + Length(lMatch.Groups[1].Value);
      lCandidateLine := lCoordinates.LineOfOffset(lCandidateOffset);
      lCandidateColumn := lCoordinates.ColumnOfOffset(lCandidateOffset);
      lCandidateDistance := Abs(lCandidateLine - lMember.Line);
      if lCandidateDistance < lBestDistance then
      begin
        lBestDistance := lCandidateDistance;
        lBestLine := lCandidateLine;
        lBestColumn := lCandidateColumn;
        lMember.Offset := lCandidateOffset;
        lMember.EndOffset := lCandidateOffset + Length(lMember.Name);
      end;
      lMatch := lMatch.NextMatch;
    end;
    if lBestLine > 0 then
    begin
      lMember.Line := lBestLine;
      lMember.Column := lBestColumn;
      aMembers[i] := lMember;
    end;
  end;
end;

procedure ReconcileRoutineCoordinates(const aSourceText: string;
  const aRoutines: TList<TDelphiSemanticRoutine>);
var
  lCoordinates: TSourceCoordinateIndex;
  i: Integer;
  lBestColumn: Integer;
  lBestDistance: Integer;
  lBestLine: Integer;
  lCandidateColumn: Integer;
  lCandidateDistance: Integer;
  lCandidateLine: Integer;
  lCandidateOffset: Integer;
  lCleanText: string;
  lMatch: TMatch;
  lRoutine: TDelphiSemanticRoutine;
begin
  if aRoutines.Count = 0 then
    Exit;
  lCoordinates.Initialize(aSourceText);
  lCleanText := '';
  for i := 0 to Pred(aRoutines.Count) do
  begin
    lRoutine := aRoutines[i];
    if SourceRangeMatchesRoutine(aSourceText, lRoutine) then
    begin
      AssignRoutineSourceRange(lRoutine, lCoordinates, lRoutine.Offset);
      aRoutines[i] := lRoutine;
      Continue;
    end;

    lBestColumn := 0;
    lBestDistance := MaxInt;
    lBestLine := 0;
    if lCleanText = '' then
      lCleanText := SanitizeCodeText(aSourceText);
    lMatch := TRegEx.Match(lCleanText,
      '^\s*(?:class\s+)?(?:procedure|function)\s+(?:[A-Za-z_][A-Za-z0-9_]*\.)?' +
      TRegEx.Escape(lRoutine.Name) + '\b', [roIgnoreCase, roMultiLine]);
    while lMatch.Success do
    begin
      lCandidateOffset := lMatch.Index + Pos(lRoutine.Name, lMatch.Value) - 1;
      lCandidateLine := lCoordinates.LineOfOffset(lCandidateOffset);
      lCandidateColumn := lCoordinates.ColumnOfOffset(lCandidateOffset);
      lCandidateDistance := Abs(lCandidateLine - lRoutine.Line);
      if lCandidateDistance < lBestDistance then
      begin
        lBestDistance := lCandidateDistance;
        lBestLine := lCandidateLine;
        lBestColumn := lCandidateColumn;
        lRoutine.Offset := lCandidateOffset;
        lRoutine.EndOffset := lCandidateOffset + Length(lRoutine.Name);
      end;
      lMatch := lMatch.NextMatch;
    end;
    if lBestLine > 0 then
    begin
      lRoutine.Line := lBestLine;
      lRoutine.Column := lBestColumn;
      aRoutines[i] := lRoutine;
    end;
  end;
end;

procedure ReconcileLocalCoordinates(const aSourceText: string;
  const aLocals: TList<TDelphiSemanticLocal>);
var
  lCoordinates: TSourceCoordinateIndex;
  i: Integer;
  lBestColumn: Integer;
  lBestDistance: Integer;
  lBestLine: Integer;
  lCandidateColumn: Integer;
  lCandidateDistance: Integer;
  lCandidateLine: Integer;
  lCandidateOffset: Integer;
  lCleanText: string;
  lLocal: TDelphiSemanticLocal;
  lMatch: TMatch;
begin
  if aLocals.Count = 0 then
    Exit;
  lCoordinates.Initialize(aSourceText);
  lCleanText := '';
  for i := 0 to Pred(aLocals.Count) do
  begin
    lLocal := aLocals[i];
    if (lLocal.Offset >= 1) and (lLocal.Offset + Length(lLocal.Name) - 1 <=
      Length(aSourceText)) and SameText(Copy(aSourceText, lLocal.Offset,
      Length(lLocal.Name)), lLocal.Name) then
    begin
      lLocal.Line := lCoordinates.LineOfOffset(lLocal.Offset);
      lLocal.Column := lCoordinates.ColumnOfOffset(lLocal.Offset);
      aLocals[i] := lLocal;
      Continue;
    end;

    lBestColumn := 0;
    lBestDistance := MaxInt;
    lBestLine := 0;
    if lCleanText = '' then
      lCleanText := SanitizeCodeText(aSourceText);
    lMatch := TRegEx.Match(lCleanText, '^(\s*)' + TRegEx.Escape(lLocal.Name) + '\b\s*:',
      [roIgnoreCase, roMultiLine]);
    while lMatch.Success do
    begin
      lCandidateOffset := lMatch.Index + Length(lMatch.Groups[1].Value);
      lCandidateLine := lCoordinates.LineOfOffset(lCandidateOffset);
      lCandidateColumn := lCoordinates.ColumnOfOffset(lCandidateOffset);
      lCandidateDistance := Abs(lCandidateLine - lLocal.Line);
      if lCandidateDistance < lBestDistance then
      begin
        lBestDistance := lCandidateDistance;
        lBestLine := lCandidateLine;
        lBestColumn := lCandidateColumn;
        lLocal.Offset := lCandidateOffset;
        lLocal.EndOffset := lCandidateOffset + Length(lLocal.Name);
      end;
      lMatch := lMatch.NextMatch;
    end;
    if lBestLine > 0 then
    begin
      lLocal.Line := lBestLine;
      lLocal.Column := lBestColumn;
      aLocals[i] := lLocal;
    end;
  end;
end;

end.
