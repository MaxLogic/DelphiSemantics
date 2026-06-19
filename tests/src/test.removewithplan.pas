unit Test.RemoveWithPlan;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Api, DelphiSemantics.Api.RemoveWith, DelphiSemantics.Api.RemoveWith.Compatibility;

type
  [TestFixture]
  TRemoveWithPlanTests = class
  private
    function DakFixturePath(const aRelativePath: string): string;
    function TempPath(const aRelativePath: string): string;
    function CopyDakFixtureToTemp(const aRelativePath, aTempName: string): string;
    function BuildPlan: TDelphiSemanticRemoveWithPlan;
    function BuildPlanForProject(const aProjectPath: string): TDelphiSemanticRemoveWithPlan;
    function MaxTdbBodyAnalysisSourceFileNames: TArray<string>;
    function FindFinalStatement(const aPlan: TDelphiSemanticRemoveWithPlan;
      const aStatementId: string; out aStatement: TDelphiSemanticRemoveWithFinalStatement): Boolean;
    function FindFinalStatementAt(const aPlan: TDelphiSemanticRemoveWithPlan;
      const aFileName: string; const aLine, aColumn: Integer;
      out aStatement: TDelphiSemanticRemoveWithFinalStatement): Boolean;
  public
    [Test]
    procedure PlansDeterministicDryRunDtoWithVerificationAndProvenance;
    [Test]
    procedure SnapshotPlannerMatchesBindingFactsPlanWithoutProjectFactsSidecar;
    [Test]
    procedure SnapshotPlannerConsumesExistingFactsWithoutProjectSession;
    [Test]
    procedure SnapshotPlannerRebuildsMissingLookupIndexFromFacts;
    [Test]
    procedure SnapshotPlannerUsesPlanningFactsOnlyForExistingFacts;
    [Test]
    procedure SnapshotPlannerAvoidsWholePlanningFactCopies;
    [Test]
    procedure SnapshotBindingSourceCachesDtoConversion;
    [Test]
    procedure CoreSnapshotUnitDoesNotExposeRemoveWithPlanningFacts;
    [Test]
    procedure RemoveWithSnapshotExtensionPreservesExactPlanningText;
    [Test]
    procedure SnapshotPlannerDoesNotDelegateToLegacyFactsPlanner;
    [Test]
    procedure SnapshotPlannerPreservesCaseOnlySelectorText;
    [Test]
    procedure SnapshotPlannerMaxTdbPreservesCountsWithoutProjectFactsSidecar;
    [Test]
    procedure DtoParityHarnessReportsMissingFinalStatements;
    [Test]
    procedure DtoParityHarnessReportsUnexpectedFinalStatements;
    [Test]
    procedure FinalStatementDtoPreservesCandidateFields;
    [Test]
    procedure FinalDtoMatchesFocusedRewriteCases;
    [Test]
    procedure FinalDtoPlansSourceBackedPropertyChainSelectorWithoutLinePatch;
    [Test]
    procedure FinalDtoUsesRewriteRecipeFactsForRepresentativeHardCases;
    [Test]
    procedure FinalDtoMatchesDakBoundRewriteFixture;
    [Test]
    procedure FinalDtoMatchesDakExternalRoutineFixture;
    [Test]
    procedure FinalDtoMatchesDakRewriteShapeElseBoundaries;
    [Test]
    procedure FinalDtoBlocksDakCombinedSelectorAmbiguousHelperCall;
    [Test]
    procedure FinalDtoDoesNotTreatNestedInlineLocalAsOuterMember;
    [Test]
    procedure FinalDtoKeepsOuterInlineLocalVisibleAcrossNestedBlocks;
    [Test]
    procedure FinalDtoKeepsResolvedNonMemberReferencesAndBlocksUnknownRoutine;
    [Test]
    procedure FinalDtoPreservesDakFixtureSafetySkips;
    [Test]
    procedure FinalDtoUsesPrecomputedNestedBindingTree;
    [Test]
    procedure FinalDtoMatchesNestedRewriteOrdering;
    [Test]
    procedure FinalDtoMatchesTempPolicyCollisionRules;
    [Test]
    procedure FinalDtoMatchesTempAggregationDeclarations;
    [Test]
    procedure FinalDtoMatchesMaxTdbUnresolvedOuterNesting;
    [Test]
    procedure FinalDtoMatchesMaxTdbSimpleRecordParameterDirectQualification;
    [Test]
    procedure FinalDtoMatchesMaxTdbValueRecordParameterPointerTemp;
    [Test]
    procedure FinalDtoMatchesMaxTdbSetBitSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbTruncBitArrayDirectQualification;
    [Test]
    procedure FinalDtoMatchesMaxTdbIndexedPointerSelectorDirectQualification;
    [Test]
    procedure FinalDtoMatchesMaxTdbDependentPointerSelectorQualification;
    [Test]
    procedure FinalDtoMatchesMaxTdbNestedRecordSelectorDirectQualification;
    [Test]
    procedure FinalDtoMatchesMaxTdbNestedRecordSelectorSingleLineDirectQualification;
    [Test]
    procedure FinalDtoMatchesMaxTdbUnresolvedLocalBufferSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbNestedInheritedSelectorDirectQualification;
    [Test]
    procedure FinalDtoMatchesMaxTdbReceiverMemberNotFoundSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbReadDbfPointerTemp;
    [Test]
    procedure FinalDtoMatchesMaxTdbConvertMaskSymbolNotFoundSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbCopyRecToStringSelectorTypeSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbGetDataMaskIndexQualifier;
    [Test]
    procedure FinalDtoMatchesMaxTdbPutDataSelectorTypeSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbSelektNrToStringSelectorTypeSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbSelektLookupDirectQualification;
    [Test]
    procedure FinalDtoMatchesMaxTdbSelektLengthDirectQualification;
    [Test]
    procedure FinalDtoMatchesMaxTdbForgetSelektListMemberSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbLabelStringPropertyChainQualification;
    [Test]
    procedure FinalDtoMatchesMaxTdbFieldTypeSymbolNotFoundSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbDeleteMarkPropertyChainQualification;
    [Test]
    procedure FinalDtoMatchesMaxTdbLastMarkControlledPropertyChainQualification;
    [Test]
    procedure FinalDtoMatchesMaxTdbCheckMarkListReceiverMemberSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbCheckMarkListNestedReceiverMemberSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbEasyTableMaskSymbolSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbFileIoSearchRecordSymbolSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbFileIoSecurityTypeSourceSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbFormelnDataFilePointerReceiverSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbLinkFileDataFilePointerReceiverSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbLinkFileCheckShowFilesReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbLinkFileNestedMaskReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbLinkFileNewPointerSymbolSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbLinkFileStatLinksPointerReceiverSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbLinkFileSetIvDataFilePointerSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbLinkFileCheckIndirektReceiverSkips;
    [Test]
    procedure FinalDtoMatchesMaxTdbLinkFileCheckStatLinksPointerSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbLinkFileFinalDirectQualification;
    [Test]
    procedure FinalDtoMatchesMaxTdbLowFilesResetFileTypeSourceSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbLowFilesQueuePointerSkips;
    [Test]
    procedure FinalDtoMatchesMaxTdbLowFilesFileQueueLastQualification;
    [Test]
    procedure FinalDtoIndexesMaxTdbLowFilesPropertyChainFacts;
    [Test]
    procedure FinalDtoMatchesMaxTdbLowFilesVirtualFileSkips;
    [Test]
    procedure FinalDtoMatchesMaxTdbLowFilesReadNBytesReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbLowFilesWriteNBytesReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbLowFilesSizeAndCutFileParity;
    [Test]
    procedure FinalDtoMatchesMaxTdbLowFilesCopyLowFileReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbMakeIvIndexedVectorReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbMd5ContextReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbRamFilesCheckRamTextSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbRamFilesRewriteRamTextReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbRamFilesInitRamTextSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbRamFilesCgiBufferDirectQualification;
    [Test]
    procedure FinalDtoMatchesMaxTdbRamFilesResetRamTextPointerTemp;
    [Test]
    procedure FinalDtoMatchesMaxTdbRamFilesAppendRamTextPointerTemp;
    [Test]
    procedure FinalDtoMatchesMaxTdbRamFilesClosePointerQualification;
    [Test]
    procedure FinalDtoMatchesMaxTdbRamFilesInsertPCharPointerTemp;
    [Test]
    procedure FinalDtoMatchesMaxTdbRamFilesBlockWriteCgiBufferQualification;
    [Test]
    procedure FinalDtoMatchesMaxTdbRamFilesReadRamTextSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbRamFilesGetCharPointerTemp;
    [Test]
    procedure FinalDtoMatchesMaxTdbRamFilesReadLnSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbRamFilesEofPointerTemp;
    [Test]
    procedure FinalDtoMatchesMaxTdbRamFilesResetFileSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbRamFilesRamFileSkipReasons;
    [Test]
    procedure FinalDtoMatchesMaxTdbRamFilesSkipRamTextReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbRamFilesSaveItemWrapperIndent;
    [Test]
    procedure FinalDtoMatchesMaxTdbRamFilesReadTextPointerTemp;
    [Test]
    procedure FinalDtoMatchesMaxTdbRamFilesRestoreSaveItemSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbRamFilesFindStringPointerTemp;
    [Test]
    procedure FinalDtoMatchesMaxTdbRamFilesCopyStringPointerTemp;
    [Test]
    procedure FinalDtoMatchesMaxTdbRamFilesSetEnvSizeDirectQualification;
    [Test]
    procedure FinalDtoMatchesMaxTdbRamFilesInitCgiVarsDirectQualification;
    [Test]
    procedure FinalDtoMatchesMaxTdbStrFuncsMaskedWordSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbStrFuncsAutoEntrySkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbStrFuncsRelFileDirectQualification;
    [Test]
    procedure FinalDtoMatchesMaxTdbStrFuncsIndexFileDirectQualification;
    [Test]
    procedure FinalDtoMatchesMaxTdbStrFuncsScanFieldMaskSkipReason;
    [Test]
    procedure FinalDtoMatchesMaxTdbStrFuncsKeywordIndexFileSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbStrFuncsArrayVarPointerTemp;
    [Test]
    procedure FinalDtoMatchesMaxTdbIndexUtilsFileSizeQualification;
    [Test]
    procedure FinalDtoMatchesMaxTdbIndexUtilsNewIndSkipReason;
    [Test]
    procedure FinalDtoMatchesMaxTdbIndexUtilsNewIndNestedSkipReason;
    [Test]
    procedure FinalDtoMatchesMaxTdbIndexUtilsGetIndPathSkipReason;
    [Test]
    procedure FinalDtoMatchesMaxTdbIndexUtilsIvOkayReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbIndexUtilsRemoveIndexSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbIndexUtilsOpenIndexNestedIvQualification;
    [Test]
    procedure FinalDtoMatchesMaxTdbIndexUtilsAddNewTempIndexReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbIndexUtilsGenIndexSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbIndexUtilsGetTreeParamReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbIndexUtilsNewTreeUniqueReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbIndexUtilsEqualIndexPointerTemp;
    [Test]
    procedure FinalDtoMatchesMaxTdbIndexUtilsNormIndFilesSkipCluster;
    [Test]
    procedure FinalDtoMatchesMaxTdbIndexUtilsLoadIndexSkipReason;
    [Test]
    procedure FinalDtoMatchesMaxTdbIndexUtilsPufferLeerenSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbIndexUtilsIndFormelSkipCluster;
    [Test]
    procedure FinalDtoMatchesMaxTdbIndexUtilsCountRecsIvReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbIndexUtilsPushPopFileReplacementRanges;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb01InitCacheReplacementRange;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb01ExitCacheReplacementRange;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb01OpenDbNameReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb01OpenDbOuterSkipReason;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb01OpenDbMaskInitializationReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb01OpenDbMaskListReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb01FlushVTableReplacement;
    [Test]
    procedure FinalDtoKeepsMaxTdbRelRecPlannedWithBodyAnalysisSubset;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb01RelRecPointerTemp;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb01RelRecNestedSelectorPointerTemp;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb01LiesSekLinkFileReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb01LiesSekLocalInitPointerTemps;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb01LiesSekNextRecSkipReasons;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb01DeleteDbRelationReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb01NextRecordSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb01TestRelRecReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb01ChainAndFnMaxParity;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb01AutoLinkNumberSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb01EmptyReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb01LinkFileNumberReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb01CheckFilesSkipCluster;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb02GetLinkInfoReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb02GetNumValReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb02SkipReasons;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb02InitDefReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb02GetVarReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb02ToDbfReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb02ArrayVarSkipReasons;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb02ArrayVarBitReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb02BitArrayOpReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb02ReverseMarksReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb02GetAutoReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb02ArrayVarGetAutoSkipReasons;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb02MarksAndCompareArrayVarParity;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb02InArrayAndMarksReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb02FilterAndSetMarksParity;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb02GetArrayVarReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb02JobListSkipReason;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb02BitArraySumSkipReason;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb02ArrayVarSizeReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb02VarContCaseReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb02CheckSelStrSkips;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb02SetByteSkipReasons;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb02FindDirektReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbDtoPrimaryPlanCountParity;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb02CheckExpressionInitVarReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb02SummenSkipReasons;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb02MemoLastRecordReplacements;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb02KonvertVarNrReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb06WriteFailedReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb06MaskeNormalizationReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb06ExportListReplacements;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdb06RelFileAndMaskRestoreReplacements;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdbJobsProgramBlockReplacements;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdbJobsGetParameterReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdbJobsSubRoutineFileReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdbJobsSplitVarSkipReasons;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdbJobsInitVarSkipReason;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdbJobsJumpTempDeclarationSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdbJobsSubRZeroSkipReason;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdbJobsReportSubRReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdbJobsParameterDirectReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdbJobsSubPointerSkipReason;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdbJobsPrgSaveRecReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdbUtilsReopenDbReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdbUtilsRelationSkipReasons;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdbUtilsGenRelMaskReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdbUtilsGenListReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdbUtilsGlobalStatLineReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdbUtilsSubstStringLineReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdbUtilsMarkListSkipReasons;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdbUtilsClearMarksSkipReason;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdbUtilsFlipMarkReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdbUtilsMakeSelektReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdbUtilsImportFileReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdbUtilsDdatSkipReason;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdbUtilsDdatMaskReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdbUtilsDdatStringMaskReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdbUtilsDdatSolveMaskReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdbUtilsDdatFormSkipReason;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdbUtilsGetStructureReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdbUtilsFormListSkipReason;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdbUtilsGenshSkipReason;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdbUtilsGenshNestedSkipReasons;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdbUtilsIsEmptyReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdbUtilsTakeOverAutoLinkReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdbUtilsCopyMemoSkipReason;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdbUtilsCopyMemoLastMbRecReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbWinMemosPutMemoBlockReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdbUtilsGetFSizeReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbTdbUtilsGetMarksAutoReplacement;
    [Test]
    procedure FinalDtoMatchesMaxTdbCloseDbfSymbolNotFoundSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbDependentSelectorTypeNotResolvedSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbNestedPointerSymbolNotFoundSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbSimplePointerStatementIndent;
    [Test]
    procedure FinalDtoMatchesMaxTdbIndexedPointerStatementIndent;
    [Test]
    procedure FinalDtoMatchesMaxTdbIndexedPointerBlockKeepsEnd;
    [Test]
    procedure FinalDtoMatchesMaxTdbClonedIndexedPointerBlockKeepsEnd;
    [Test]
    procedure FinalDtoMatchesMaxTdbConstIndexedMaskSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbNestedRoutineIndexedMaskSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbConvertIndexedMaskSymbolSkip;
    [Test]
    procedure FinalDtoMatchesMaxTdbVarIndexedMaskSymbolNotFoundSkip;
    [Test]
    procedure PlannerCachesSourceTextAndHashesPerFile;
  end;

implementation

uses
  System.IOUtils, System.StrUtils, System.SysUtils,
  Winapi.Windows,
  DelphiSemantics.Snapshot, DelphiSemantics.Snapshot.RemoveWith,
  Test.Support;

var
  GMaxTdbPlanCached: Boolean;
  GMaxTdbProjectPath: string;
  GMaxTdbPlan: TDelphiSemanticRemoveWithPlan;
  GRemoveWithPlanTempRoot: string;

function RemoveWithPlanTempRoot: string;
var
  lGuid: TGUID;
  lGuidText: string;
begin
  if GRemoveWithPlanTempRoot = '' then
  begin
    CreateGUID(lGuid);
    lGuidText := StringReplace(StringReplace(GUIDToString(lGuid), '{', '', [rfReplaceAll]), '}', '',
      [rfReplaceAll]);
    GRemoveWithPlanTempRoot := TPath.GetFullPath(TPath.Combine(
      TPath.Combine(ExtractFilePath(ParamStr(0)), 'remove-with-plan-temp'),
      'run-' + GetCurrentProcessId.ToString + '-' + lGuidText));
  end;
  TDirectory.CreateDirectory(GRemoveWithPlanTempRoot);
  Result := GRemoveWithPlanTempRoot;
end;

function IsMaxTdbProjectPath(const aProjectPath: string): Boolean;
var
  lFileName: string;
begin
  lFileName := ExtractFileName(aProjectPath);
  Result := SameText(lFileName, 'maxtdb.dpr') or SameText(lFileName, 'maxtdb.dproj');
end;

function SourceRangeText(const aRange: TDelphiSemanticRemoveWithSourceRange): string;
begin
  Result := Format('%d:%d-%d:%d', [aRange.StartLine, aRange.StartColumn,
    aRange.EndLine, aRange.EndColumn]);
end;

procedure AppendStringArray(const aBuilder: TStringBuilder; const aName: string;
  const aValues: TArray<string>);
var
  i: Integer;
begin
  aBuilder.Append(aName).Append('[').Append(Length(aValues)).Append(']');
  for i := 0 to High(aValues) do
    aBuilder.Append('|').Append(aValues[i]);
  aBuilder.AppendLine;
end;

procedure AppendSourceVerification(const aBuilder: TStringBuilder;
  const aName: string; const aVerification: TDelphiSemanticRemoveWithSourceVerification);
begin
  aBuilder.Append(aName).Append('=').Append(aVerification.ExpectedFileHash).Append('|')
    .Append(SourceRangeText(aVerification.Range)).Append('|')
    .Append(aVerification.ExpectedSourceText).AppendLine;
end;

function ComparableRemoveWithPlanText(
  const aPlan: TDelphiSemanticRemoveWithPlan): string;
var
  i: Integer;
  j: Integer;
  lBuilder: TStringBuilder;
begin
  lBuilder := TStringBuilder.Create;
  try
    lBuilder.Append('operation=').Append(aPlan.Operation).AppendLine;
    lBuilder.Append('status=').Append(aPlan.Status).AppendLine;
    lBuilder.Append('context=').Append(aPlan.ContextFingerprint).AppendLine;
    lBuilder.Append('diagnostic=').Append(aPlan.Diagnostic).AppendLine;
    lBuilder.Append('requiredVerification=').Append(Length(aPlan.RequiredVerification))
      .AppendLine;
    for i := 0 to High(aPlan.RequiredVerification) do
      lBuilder.Append('verification|').Append(i).Append('|')
        .Append(aPlan.RequiredVerification[i].Kind).Append('|')
        .Append(aPlan.RequiredVerification[i].Description).AppendLine;

    lBuilder.Append('edits=').Append(Length(aPlan.Edits)).AppendLine;
    for i := 0 to High(aPlan.Edits) do
    begin
      lBuilder.Append('edit|').Append(i).Append('|').Append(aPlan.Edits[i].Kind)
        .Append('|').Append(aPlan.Edits[i].FileName)
        .Append('|').Append(aPlan.Edits[i].StatementId)
        .Append('|').Append(aPlan.Edits[i].ExpectedFileHash)
        .Append('|').Append(SourceRangeText(aPlan.Edits[i].Range))
        .Append('|').Append(aPlan.Edits[i].ReplacementText)
        .Append('|').Append(aPlan.Edits[i].ApplyMode)
        .Append('|').Append(aPlan.Edits[i].SemanticReason)
        .Append('|').Append(aPlan.Edits[i].SemanticId)
        .Append('|').Append(aPlan.Edits[i].ExpectedSourceText).AppendLine;
      AppendStringArray(lBuilder, 'editReferenceIds', aPlan.Edits[i].ReferenceIds);
    end;

    lBuilder.Append('skipped=').Append(Length(aPlan.SkippedStatements)).AppendLine;
    for i := 0 to High(aPlan.SkippedStatements) do
      lBuilder.Append('skip|').Append(i).Append('|')
        .Append(aPlan.SkippedStatements[i].FileName).Append('|')
        .Append(aPlan.SkippedStatements[i].StatementId).Append('|')
        .Append(SourceRangeText(aPlan.SkippedStatements[i].Range)).Append('|')
        .Append(aPlan.SkippedStatements[i].Reason).Append('|')
        .Append(aPlan.SkippedStatements[i].SafetyReason).Append('|')
        .Append(aPlan.SkippedStatements[i].SemanticId).AppendLine;

    lBuilder.Append('finals=').Append(Length(aPlan.FinalStatements)).AppendLine;
    for i := 0 to High(aPlan.FinalStatements) do
    begin
      lBuilder.Append('final|').Append(i).Append('|')
        .Append(aPlan.FinalStatements[i].FileName).Append('|')
        .Append(aPlan.FinalStatements[i].StatementId).Append('|')
        .Append(aPlan.FinalStatements[i].SemanticId).Append('|')
        .Append(aPlan.FinalStatements[i].RoutineName).Append('|')
        .Append(aPlan.FinalStatements[i].Status).Append('|')
        .Append(aPlan.FinalStatements[i].Reason).Append('|')
        .Append(aPlan.FinalStatements[i].SafetyReason).Append('|')
        .Append(aPlan.FinalStatements[i].UnsupportedIdentifierRole).Append('|')
        .Append(SourceRangeText(aPlan.FinalStatements[i].Range)).Append('|')
        .Append(aPlan.FinalStatements[i].ReplacementText).AppendLine;
      AppendSourceVerification(lBuilder, 'finalVerification',
        aPlan.FinalStatements[i].Verification);
      lBuilder.Append('finalEdits=').Append(Length(aPlan.FinalStatements[i].Edits))
        .AppendLine;
      for j := 0 to High(aPlan.FinalStatements[i].Edits) do
      begin
        lBuilder.Append('finalEdit|').Append(i).Append('|').Append(j).Append('|')
          .Append(aPlan.FinalStatements[i].Edits[j].Kind).Append('|')
          .Append(aPlan.FinalStatements[i].Edits[j].FileName).Append('|')
          .Append(aPlan.FinalStatements[i].Edits[j].StatementId).Append('|')
          .Append(SourceRangeText(aPlan.FinalStatements[i].Edits[j].Range)).Append('|')
          .Append(aPlan.FinalStatements[i].Edits[j].ReplacementText).Append('|')
          .Append(aPlan.FinalStatements[i].Edits[j].SemanticId).AppendLine;
        AppendSourceVerification(lBuilder, 'finalEditVerification',
          aPlan.FinalStatements[i].Edits[j].Verification);
      end;
      lBuilder.Append('temps=').Append(Length(aPlan.FinalStatements[i].Temps)).AppendLine;
      for j := 0 to High(aPlan.FinalStatements[i].Temps) do
        lBuilder.Append('temp|').Append(i).Append('|').Append(j).Append('|')
          .Append(aPlan.FinalStatements[i].Temps[j].SelectorText).Append('|')
          .Append(aPlan.FinalStatements[i].Temps[j].QualifierText).Append('|')
          .Append(aPlan.FinalStatements[i].Temps[j].Strategy).Append('|')
          .Append(aPlan.FinalStatements[i].Temps[j].ReceiverType).Append('|')
          .Append(aPlan.FinalStatements[i].Temps[j].TempName).Append('|')
          .Append(aPlan.FinalStatements[i].Temps[j].DeclarationText).Append('|')
          .Append(aPlan.FinalStatements[i].Temps[j].InitializationText).Append('|')
          .Append(aPlan.FinalStatements[i].Temps[j].Reason).Append('|')
          .Append(aPlan.FinalStatements[i].Temps[j].SemanticId).AppendLine;
      AppendStringArray(lBuilder, 'finalReferenceIds',
        aPlan.FinalStatements[i].ReferenceIds);
    end;
    Result := lBuilder.ToString;
  finally
    lBuilder.Free;
  end;
end;


function TRemoveWithPlanTests.DakFixturePath(const aRelativePath: string): string;
begin
  Result := TPath.GetFullPath(TPath.Combine(TPath.Combine(ExtractFilePath(ParamStr(0)),
    '..\..\..\DelphiAiKit\tests\fixtures'), aRelativePath));
end;

function TRemoveWithPlanTests.TempPath(const aRelativePath: string): string;
begin
  Result := TPath.GetFullPath(TPath.Combine(RemoveWithPlanTempRoot, aRelativePath));
end;

function TRemoveWithPlanTests.CopyDakFixtureToTemp(const aRelativePath,
  aTempName: string): string;
var
  lSourceDir: string;
begin
  lSourceDir := DakFixturePath(aRelativePath);
  Result := TempPath(aTempName);
  if TDirectory.Exists(Result) then
    TDirectory.Delete(Result, True);
  TDirectory.Copy(lSourceDir, Result);
end;

function TRemoveWithPlanTests.BuildPlan: TDelphiSemanticRemoveWithPlan;
begin
  Result := BuildPlanForProject(FixturePath('ProjectWithBinding\ProjectWithBinding.dproj'));
end;

function TRemoveWithPlanTests.BuildPlanForProject(const aProjectPath: string):
  TDelphiSemanticRemoveWithPlan;
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lFullProjectPath: string;
  lOptions: TDelphiSemanticApiOptions;
begin
  lFullProjectPath := TPath.GetFullPath(aProjectPath);
  if IsMaxTdbProjectPath(lFullProjectPath) and
    GMaxTdbPlanCached and SameText(GMaxTdbProjectPath, lFullProjectPath) then
    Exit(GMaxTdbPlan);

  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := lFullProjectPath;
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  Result := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
  if IsMaxTdbProjectPath(lFullProjectPath) then
  begin
    GMaxTdbPlan := Result;
    GMaxTdbProjectPath := lFullProjectPath;
    GMaxTdbPlanCached := True;
  end;
end;

function TRemoveWithPlanTests.MaxTdbBodyAnalysisSourceFileNames: TArray<string>;
const
  cFiles: array[0..24] of string = ('append.pas', 'bitarray.pas', 'DBFUTIL.pas',
    'deklarat.pas', 'EasyWrappers\Easy.TableFunctions.pas', 'FileIO.pas',
    'formeln.pas', 'linkfile.pas', 'lowFiles.pas', 'makeiv.pas', 'md5.pas',
    'ramfiles.pas', 'strfuncs.pas', 'TDB00.indexUtils.pas', 'tdb01.pas',
    'TDB02.pas', 'TDB06.pas', 'tdb7Prime.pas', 'TDBJOBS.pas', 'tdbutils.pas',
    'Tdbutils.Ident.pas', 'tdbvars.pas', 'usertext.pas', 'winblobs.pas',
    'winmemos.pas');
var
  i: Integer;
  lSourceDir: string;
begin
  lSourceDir := TPath.GetDirectoryName(DakFixturePath(
    'test-projects\maxTdb\src\maxtdb.dpr'));
  SetLength(Result, Length(cFiles));
  for i := Low(cFiles) to High(cFiles) do
    Result[i] := TPath.Combine(lSourceDir, cFiles[i]);
end;

function TRemoveWithPlanTests.FindFinalStatement(const aPlan: TDelphiSemanticRemoveWithPlan;
  const aStatementId: string; out aStatement: TDelphiSemanticRemoveWithFinalStatement): Boolean;
var
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  Result := False;
  aStatement := Default(TDelphiSemanticRemoveWithFinalStatement);
  for lStatement in aPlan.FinalStatements do
  begin
    if SameText(lStatement.StatementId, aStatementId) then
    begin
      aStatement := lStatement;
      Exit(True);
    end;
  end;
end;

function TRemoveWithPlanTests.FindFinalStatementAt(const aPlan: TDelphiSemanticRemoveWithPlan;
  const aFileName: string; const aLine, aColumn: Integer;
  out aStatement: TDelphiSemanticRemoveWithFinalStatement): Boolean;
var
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  Result := False;
  aStatement := Default(TDelphiSemanticRemoveWithFinalStatement);
  for lStatement in aPlan.FinalStatements do
  begin
    if SameText(ExtractFileName(lStatement.FileName), aFileName) and
      (lStatement.Range.StartLine = aLine) and (lStatement.Range.StartColumn = aColumn) then
    begin
      aStatement := lStatement;
      Exit(True);
    end;
  end;
end;

procedure TRemoveWithPlanTests.PlansDeterministicDryRunDtoWithVerificationAndProvenance;
var
  lAfterBytes: TBytes;
  lBeforeBytes: TBytes;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lSecondPlan: TDelphiSemanticRemoveWithPlan;
  lSkippedFacts: TDelphiSemanticProjectWithBindingFacts;
  lSkippedPlan: TDelphiSemanticRemoveWithPlan;
  lUnitPath: string;
  i: Integer;
begin
  lUnitPath := FixturePath('ProjectWithBinding\ProjectWithUnit.pas');
  lBeforeBytes := TFile.ReadAllBytes(lUnitPath);

  lPlan := BuildPlan;
  lSecondPlan := BuildPlan;

  Assert.AreEqual('remove-with', lPlan.Operation);
  Assert.AreEqual('planned', lPlan.Status, lPlan.Diagnostic);
  Assert.IsNotEmpty(lPlan.ContextFingerprint);
  Assert.AreEqual('project-with-binding-v1', lPlan.BaselineSemanticModelVersion);
  Assert.IsTrue(Length(lPlan.RequiredVerification) >= 5,
    'Expected compile, context, source, post-compile, and rollback verification requirements.');
  Assert.IsTrue(Length(lPlan.Edits) > 0, 'Expected at least one planned semantic remove-with edit.');
  Assert.IsNotEmpty(lPlan.Edits[0].ExpectedFileHash);
  Assert.IsNotEmpty(lPlan.Edits[0].ExpectedSourceText);
  Assert.AreEqual('with lRecord do' + sLineBreak + '    Value := 1;', lPlan.Edits[0].ExpectedSourceText);
  Assert.AreEqual(lPlan.Edits[0].ExpectedSourceText, lPlan.Edits[0].ReplacementText);
  Assert.AreEqual('requires-dak-compatibility-adapter', lPlan.Edits[0].ApplyMode);
  Assert.IsNotEmpty(lPlan.Edits[0].SemanticId);
  Assert.IsTrue(Length(lPlan.Edits[0].ReferenceIds) > 0,
    'Expected semantic references to justify the edit.');
  Assert.AreEqual(lPlan.ContextFingerprint, lSecondPlan.ContextFingerprint);
  Assert.AreEqual(Integer(Length(lPlan.Edits)), Integer(Length(lSecondPlan.Edits)));
  Assert.AreEqual(lPlan.Edits[0].ExpectedFileHash, lSecondPlan.Edits[0].ExpectedFileHash);
  Assert.AreEqual(lPlan.Edits[0].ExpectedSourceText, lSecondPlan.Edits[0].ExpectedSourceText);

  lAfterBytes := TFile.ReadAllBytes(lUnitPath);
  Assert.AreEqual(Integer(Length(lBeforeBytes)), Integer(Length(lAfterBytes)), 'Plan mode must not write source files.');
  for i := 0 to High(lBeforeBytes) do
    Assert.AreEqual(lBeforeBytes[i], lAfterBytes[i], 'Plan mode must preserve source bytes.');

  lSkippedFacts := Default(TDelphiSemanticProjectWithBindingFacts);
  lSkippedFacts.ContextFingerprint := 'skipped-plan-context';
  SetLength(lSkippedFacts.Bindings, 1);
  lSkippedFacts.Bindings[0].SemanticId := 'with:skipped';
  lSkippedFacts.Bindings[0].Status := 'skipped';
  lSkippedFacts.Bindings[0].SkipReason := 'UNRESOLVED_REFERENCE';
  lSkippedPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lSkippedFacts);
  Assert.AreEqual(0, Integer(Length(lSkippedPlan.Edits)));
  Assert.AreEqual(1, Integer(Length(lSkippedPlan.SkippedStatements)));
  Assert.AreEqual('SOURCE_RANGE_UNAVAILABLE', lSkippedPlan.SkippedStatements[0].Reason);
  Assert.AreEqual('stable source file, hash, and source range are required',
    lSkippedPlan.SkippedStatements[0].SafetyReason);
end;

procedure TRemoveWithPlanTests.SnapshotPlannerMatchesBindingFactsPlanWithoutProjectFactsSidecar;
var
  i: Integer;
  lActualPlan: TDelphiSemanticRemoveWithPlan;
  lAfterBytes: TBytes;
  lBeforeBytes: TBytes;
  lCacheDir: string;
  lExpectedFacts: TDelphiSemanticProjectWithBindingFacts;
  lExpectedOptions: TDelphiSemanticApiOptions;
  lExpectedPlan: TDelphiSemanticRemoveWithPlan;
  lOptions: TDelphiSemanticApiOptions;
  lProjectFactsSidecar: string;
  lUnitPath: string;
begin
  lCacheDir := TempPath('snapshot-planner-cache');
  if TDirectory.Exists(lCacheDir) then
    TDirectory.Delete(lCacheDir, True);
  TDirectory.CreateDirectory(lCacheDir);

  lUnitPath := FixturePath('ProjectWithBinding\ProjectWithUnit.pas');
  lBeforeBytes := TFile.ReadAllBytes(lUnitPath);

  lExpectedOptions := Default(TDelphiSemanticApiOptions);
  lExpectedOptions.ProjectFileName := FixturePath(
    'ProjectWithBinding\ProjectWithBinding.dproj');
  lExpectedFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lExpectedOptions);
  lExpectedPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lExpectedFacts);

  lOptions := lExpectedOptions;
  lOptions.Cache.SqliteCacheFileName := TPath.Combine(lCacheDir,
    'semantic-cache.sqlite3');
  lProjectFactsSidecar := lOptions.Cache.SqliteCacheFileName + '.project-facts.json';
  TDirectory.CreateDirectory(lProjectFactsSidecar);
  Assert.IsTrue(TDirectory.Exists(lProjectFactsSidecar));

  lActualPlan := TDelphiSemanticRemoveWithApi.PlanRemoveWith(lOptions);

  Assert.AreEqual('project-snapshot-v1', lActualPlan.BaselineSemanticModelVersion);
  Assert.AreEqual(lExpectedPlan.Status, lActualPlan.Status, lActualPlan.Diagnostic);
  Assert.AreEqual(lExpectedPlan.ContextFingerprint, lActualPlan.ContextFingerprint);
  Assert.AreEqual(ComparableRemoveWithPlanText(lExpectedPlan),
    ComparableRemoveWithPlanText(lActualPlan),
    'Snapshot planner DTO must match the binding-facts planner DTO.');
  Assert.IsTrue(TDirectory.Exists(lProjectFactsSidecar),
    'Snapshot planner path must leave the poisoned sidecar directory untouched.');
  Assert.IsFalse(TFile.Exists(lProjectFactsSidecar),
    'Snapshot planner path must not write the JSON project-facts sidecar.');

  lAfterBytes := TFile.ReadAllBytes(lUnitPath);
  Assert.AreEqual(Integer(Length(lBeforeBytes)), Integer(Length(lAfterBytes)),
    'Snapshot planner must not write source files.');
  for i := 0 to High(lBeforeBytes) do
    Assert.AreEqual(lBeforeBytes[i], lAfterBytes[i],
      'Snapshot planner must preserve source bytes.');
end;

procedure TRemoveWithPlanTests.SnapshotPlannerConsumesExistingFactsWithoutProjectSession;
var
  lActualPlan: TDelphiSemanticRemoveWithPlan;
  lExpectedPlan: TDelphiSemanticRemoveWithPlan;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOptions: TDelphiSemanticApiOptions;
begin
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := FixturePath('ProjectWithBinding\ProjectWithBinding.dproj');

  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  lExpectedPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
  lActualPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWithSnapshot(lFacts);

  Assert.AreEqual('project-snapshot-v1', lActualPlan.BaselineSemanticModelVersion);
  Assert.AreEqual(lExpectedPlan.Status, lActualPlan.Status, lActualPlan.Diagnostic);
  Assert.AreEqual(lExpectedPlan.ContextFingerprint, lActualPlan.ContextFingerprint);
  Assert.AreEqual(ComparableRemoveWithPlanText(lExpectedPlan),
    ComparableRemoveWithPlanText(lActualPlan),
    'Snapshot planner from existing facts must match the binding-facts plan.');
end;

procedure TRemoveWithPlanTests.SnapshotPlannerRebuildsMissingLookupIndexFromFacts;
var
  lActualPlan: TDelphiSemanticRemoveWithPlan;
  lExpectedPlan: TDelphiSemanticRemoveWithPlan;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOptions: TDelphiSemanticApiOptions;
begin
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := FixturePath('ProjectWithBinding\ProjectWithBinding.dproj');

  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  lExpectedPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
  lFacts.LookupIndex := Default(TDelphiSemanticRemoveWithLookupIndex);
  lActualPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWithSnapshot(lFacts);

  Assert.AreEqual(lExpectedPlan.Status, lActualPlan.Status, lActualPlan.Diagnostic);
  Assert.AreEqual(ComparableRemoveWithPlanText(lExpectedPlan),
    ComparableRemoveWithPlanText(lActualPlan),
    'Snapshot planner should rebuild the lookup index when callers provide facts without one.');
end;

procedure TRemoveWithPlanTests.SnapshotPlannerUsesPlanningFactsOnlyForExistingFacts;
var
  lFunctionEnd: Integer;
  lFunctionSource: string;
  lFunctionStart: Integer;
  lSourceText: string;
begin
  lSourceText := ReadRepoSource('src\DelphiSemantics.Api.RemoveWith.Compatibility.pas');

  lFunctionStart := Pos('class function TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWithSnapshot',
    lSourceText);
  lFunctionEnd := PosEx('end.',
    lSourceText, lFunctionStart);
  Assert.IsTrue((lFunctionStart > 0) and (lFunctionEnd > lFunctionStart),
    'Expected PlanRemoveWithSnapshot implementation section.');

  lFunctionSource := Copy(lSourceText, lFunctionStart,
    lFunctionEnd - lFunctionStart);
  Assert.IsTrue(ContainsText(lFunctionSource,
    'BuildRemoveWithPlanningSnapshotFromFacts'),
    'PlanRemoveWithSnapshot(existing facts) should build only snapshot planning facts.');
  Assert.IsFalse(ContainsText(lFunctionSource, 'BuildProjectSnapshotFromModels'),
    'PlanRemoveWithSnapshot(existing facts) must not rebuild generic unit snapshot facts.');
end;

procedure TRemoveWithPlanTests.SnapshotPlannerAvoidsWholePlanningFactCopies;
var
  lBuilderSource: string;
  lFunctionEnd: Integer;
  lFunctionSource: string;
  lFunctionStart: Integer;
  lPlannerSource: string;
begin
  lPlannerSource := ReadRepoSource('src\DelphiSemantics.RemoveWithPlan.pas');
  lFunctionStart := Pos('function BindingFactsFromSnapshot',
    lPlannerSource);
  lFunctionEnd := PosEx('class function TDelphiSemanticRemoveWithPlanner.Plan',
    lPlannerSource, lFunctionStart);
  Assert.IsTrue((lFunctionStart > 0) and (lFunctionEnd > lFunctionStart),
    'Expected BindingFactsFromSnapshot implementation section.');

  lFunctionSource := Copy(lPlannerSource, lFunctionStart,
    lFunctionEnd - lFunctionStart);
  Assert.IsFalse(ContainsText(lFunctionSource,
    'aSnapshot.RemoveWithPlanningFacts'),
    'Snapshot planner must not copy the complete remove-with planning record.');
  Assert.IsTrue(ContainsText(lFunctionSource,
    'RemoveWithPlanningBindingCount'),
    'Snapshot planner should read immutable planning facts by count/index.');
  Assert.IsFalse(ContainsText(lFunctionSource,
    'TDelphiSemanticRemoveWithLookupIndex.Build(nil'),
    'Snapshot planner must not rebuild a symbol-only lookup index without unit-model facts.');
  Assert.IsTrue(ContainsText(lFunctionSource,
    'RemoveWithPlanningLookupIndex'),
    'Snapshot planner should reuse the model-backed planning lookup index.');
  Assert.IsFalse(ContainsText(lFunctionSource,
    'RemoveWithPlanningSymbolByIndex'),
    'Snapshot planner should not convert planning symbols back into DTO symbols.');
  Assert.IsTrue(ContainsText(lFunctionSource,
    'RemoveWithPlanningRoutineOwnerByIndex'),
    'Snapshot planner should carry only routine-owner symbols needed for nested-routine safety.');

  lBuilderSource := ReadRepoSource('src\DelphiSemantics.Snapshot.Builder.pas');
  lFunctionStart := Pos('function BuildRemoveWithPlanningSnapshotFromFacts',
    lBuilderSource);
  Assert.IsTrue(lFunctionStart > 0,
    'Expected BuildRemoveWithPlanningSnapshotFromFacts implementation section.');
  lFunctionSource := Copy(lBuilderSource, lFunctionStart, MaxInt);
  Assert.IsTrue(ContainsText(lFunctionSource,
    'SetRemoveWithPlanningFactsOwned'),
    'Snapshot builder should transfer freshly-built planning facts without a defensive deep copy.');
  lFunctionStart := Pos('function CreateRemoveWithPlanningFacts',
    lBuilderSource);
  lFunctionEnd := PosEx('function RemapStringId', lBuilderSource,
    lFunctionStart);
  Assert.IsTrue((lFunctionStart > 0) and (lFunctionEnd > lFunctionStart),
    'Expected CreateRemoveWithPlanningFacts implementation section.');
  lFunctionSource := Copy(lBuilderSource, lFunctionStart,
    lFunctionEnd - lFunctionStart);
  Assert.IsFalse(ContainsText(lFunctionSource,
    'SetLength(Result.Symbols, Length(aFacts.Symbols))'),
    'Planning snapshots should not convert the complete symbol inventory.');
  Assert.IsTrue(ContainsText(lFunctionSource,
    'RoutineOwners'),
    'Planning snapshots should preserve the small routine-owner subset needed for safety.');
end;

procedure TRemoveWithPlanTests.SnapshotBindingSourceCachesDtoConversion;
var
  lBindingByIndexSource: string;
  lBindingByIndexEnd: Integer;
  lBindingByIndexStart: Integer;
  lClassEnd: Integer;
  lClassSource: string;
  lClassStart: Integer;
  lConstructorEnd: Integer;
  lConstructorSource: string;
  lConstructorStart: Integer;
  lPlannerSource: string;
begin
  lPlannerSource := ReadRepoSource('src\DelphiSemantics.RemoveWithPlan.pas');
  lClassStart := Pos(
    'TSnapshotRemoveWithPlanBindingSource = class(TRemoveWithPlanBindingSource)',
    lPlannerSource);
  lClassEnd := PosEx('  public', lPlannerSource, lClassStart);
  Assert.IsTrue((lClassStart > 0) and (lClassEnd > lClassStart),
    'Expected snapshot binding source class declaration.');

  lClassSource := Copy(lPlannerSource, lClassStart, lClassEnd - lClassStart);
  Assert.IsTrue(ContainsText(lClassSource,
    'fBindings: TArray<TDelphiSemanticWithBinding>'),
    'Snapshot binding source should own a converted binding DTO cache.');
  lConstructorStart := Pos(
    'constructor TSnapshotRemoveWithPlanBindingSource.Create',
    lPlannerSource);
  lConstructorEnd := PosEx(
    'function TSnapshotRemoveWithPlanBindingSource.BindingByIndex',
    lPlannerSource, lConstructorStart);
  Assert.IsTrue((lConstructorStart > 0) and
    (lConstructorEnd > lConstructorStart),
    'Expected snapshot binding source constructor implementation.');

  lConstructorSource := Copy(lPlannerSource, lConstructorStart,
    lConstructorEnd - lConstructorStart);
  Assert.IsTrue(ContainsText(lConstructorSource,
    'SetLength(fBindings, fSnapshot.RemoveWithPlanningBindingCount)'),
    'Snapshot binding source should size the converted binding DTO cache once.');
  Assert.IsTrue(ContainsText(lConstructorSource, 'SnapshotWithBinding(fSnapshot'),
    'Snapshot binding source should convert snapshot binding DTOs only while filling the cache.');
  lBindingByIndexStart := Pos(
    'function TSnapshotRemoveWithPlanBindingSource.BindingByIndex',
    lPlannerSource);
  lBindingByIndexEnd := PosEx(
    'function TSnapshotRemoveWithPlanBindingSource.BindingCount',
    lPlannerSource, lBindingByIndexStart);
  Assert.IsTrue((lBindingByIndexStart > 0) and
    (lBindingByIndexEnd > lBindingByIndexStart),
    'Expected snapshot binding source BindingByIndex implementation.');

  lBindingByIndexSource := Copy(lPlannerSource, lBindingByIndexStart,
    lBindingByIndexEnd - lBindingByIndexStart);
  Assert.IsFalse(ContainsText(lBindingByIndexSource, 'SnapshotWithBinding'),
    'Snapshot BindingByIndex must not convert the snapshot binding DTO on every hot-path access.');
  Assert.IsTrue(ContainsText(lPlannerSource,
    'Result := fBindings[aIndex]'),
    'Snapshot BindingByIndex should return the cached converted binding DTO.');
end;

procedure TRemoveWithPlanTests.CoreSnapshotUnitDoesNotExposeRemoveWithPlanningFacts;
var
  lSnapshotSource: string;
begin
  lSnapshotSource := ReadRepoSource('src\DelphiSemantics.Snapshot.pas');

  Assert.IsFalse(ContainsText(lSnapshotSource, 'DelphiSemantics.WithBinding'),
    'Core snapshot unit must not link remove-with binding contracts.');
  Assert.IsFalse(ContainsText(lSnapshotSource, 'TSemanticRemoveWith'),
    'Core snapshot unit must not expose remove-with planning DTOs.');
  Assert.IsFalse(ContainsText(lSnapshotSource, 'RemoveWithPlanning'),
    'Core snapshot unit must not expose remove-with planning accessors.');
  Assert.IsFalse(ContainsText(lSnapshotSource, 'cSemanticRemoveWith'),
    'Core snapshot unit must not expose remove-with planning flags.');
end;

procedure TRemoveWithPlanTests.RemoveWithSnapshotExtensionPreservesExactPlanningText;
var
  lBuilder: TDelphiProjectSnapshotBuilder;
  lFacts: TSemanticRemoveWithPlanningFacts;
  lProject: TDelphiProjectSnapshot;
begin
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  try
    lFacts.ContextFingerprintId := lBuilder.ExactStrings.Intern('ctx');
    SetLength(lFacts.Bindings, 2);
    lFacts.Bindings[0].SelectorTextId := lBuilder.ExactStrings.Intern('DF[D]^');
    lFacts.Bindings[1].SelectorTextId := lBuilder.ExactStrings.Intern('DF[d]^');
    lBuilder.SetRemoveWithPlanningFacts(lFacts);
    lProject := lBuilder.Build;
  finally
    lBuilder.Free;
  end;
  try
    lFacts := lProject.RemoveWithPlanningFacts;
    Assert.AreEqual('DF[D]^', lProject.ExactTextOf(lFacts.Bindings[0].SelectorTextId));
    Assert.AreEqual('DF[d]^', lProject.ExactTextOf(lFacts.Bindings[1].SelectorTextId));
    Assert.IsTrue(lFacts.Bindings[0].SelectorTextId <> lFacts.Bindings[1].SelectorTextId,
      'Source-exact remove-with text must not be case-folded.');
  finally
    lProject.Free;
  end;
end;

procedure TRemoveWithPlanTests.SnapshotPlannerDoesNotDelegateToLegacyFactsPlanner;
var
  lFunctionEnd: Integer;
  lFunctionSource: string;
  lFunctionStart: Integer;
  lPlannerSource: string;
begin
  lPlannerSource := ReadRepoSource('src\DelphiSemantics.RemoveWithPlan.pas');
  lFunctionStart := PosEx('class function TDelphiSemanticRemoveWithPlanner.Plan(',
    lPlannerSource, Pos('function BindingFactsFromSnapshot', lPlannerSource));
  lFunctionEnd := PosEx('class function TDelphiSemanticRemoveWithPlanParity.Compare',
    lPlannerSource, lFunctionStart);
  Assert.IsTrue((lFunctionStart > 0) and (lFunctionEnd > lFunctionStart),
    'Expected snapshot planner implementation section.');

  lFunctionSource := Copy(lPlannerSource, lFunctionStart,
    lFunctionEnd - lFunctionStart);
  Assert.IsFalse(ContainsText(lFunctionSource, 'BindingFactsFromSnapshot'),
    'Snapshot planner must not rebuild legacy binding facts.');
  Assert.IsFalse(ContainsText(lFunctionSource, 'Plan(lFacts)'),
    'Snapshot planner must not delegate back to the legacy facts planner.');
  Assert.IsFalse(ContainsText(lFunctionSource, 'TDelphiSemanticProjectWithBindingFacts'),
    'Snapshot planner must not rebuild the legacy facts DTO shell.');
  Assert.IsFalse(ContainsText(lFunctionSource, 'TArray<TDelphiSemanticWithBinding>'),
    'Snapshot planner must not materialize the legacy binding array.');
  Assert.IsFalse(ContainsText(lFunctionSource, 'SnapshotWithBinding(aSnapshot'),
    'Snapshot planner must read bindings through a snapshot-owned binding source.');
  Assert.IsTrue(ContainsText(lFunctionSource, 'TSnapshotRemoveWithPlanBindingSource'),
    'Snapshot planner should use a snapshot binding source.');
  Assert.IsTrue(ContainsText(lFunctionSource, 'PlanFromBindingSource'),
    'Snapshot planner should call the binding-source planning core.');
end;

procedure TRemoveWithPlanTests.SnapshotPlannerPreservesCaseOnlySelectorText;
var
  lActualPlan: TDelphiSemanticRemoveWithPlan;
  lCacheDir: string;
  lExpectedFacts: TDelphiSemanticProjectWithBindingFacts;
  lExpectedOptions: TDelphiSemanticApiOptions;
  lExpectedPlan: TDelphiSemanticRemoveWithPlan;
  lOptions: TDelphiSemanticApiOptions;
  lProjectPath: string;
  lRoot: string;
  lUnitPath: string;
const
  cCaseSelectorUnit =
    'unit ProjectWithUnit;' + sLineBreak +
    sLineBreak +
    'interface' + sLineBreak +
    sLineBreak +
    'type' + sLineBreak +
    '  TProjectUnitRecord = record' + sLineBreak +
    '    Count: Integer;' + sLineBreak +
    '  end;' + sLineBreak +
    sLineBreak +
    'procedure TouchProjectUnitRecord(const aValue: Integer);' + sLineBreak +
    sLineBreak +
    'implementation' + sLineBreak +
    sLineBreak +
    'procedure TouchProjectUnitRecord(const aValue: Integer);' + sLineBreak +
    'var' + sLineBreak +
    '  lRecord: TProjectUnitRecord;' + sLineBreak +
    'begin' + sLineBreak +
    '  with lRecord do' + sLineBreak +
    '    Count := aValue;' + sLineBreak +
    '  with LRecord do' + sLineBreak +
    '    Count := aValue + 1;' + sLineBreak +
    'end;' + sLineBreak +
    sLineBreak +
    'end.' + sLineBreak;
begin
  lRoot := TempPath('snapshot-planner-case-selectors');
  if TDirectory.Exists(lRoot) then
    TDirectory.Delete(lRoot, True);
  TDirectory.Copy(FixturePath('ProjectWithBinding'), lRoot);

  lProjectPath := TPath.Combine(lRoot, 'ProjectWithBinding.dproj');
  lUnitPath := TPath.Combine(lRoot, 'ProjectWithUnit.pas');
  TFile.WriteAllText(lUnitPath, cCaseSelectorUnit, TEncoding.UTF8);

  lExpectedOptions := Default(TDelphiSemanticApiOptions);
  lExpectedOptions.ProjectFileName := lProjectPath;
  lExpectedFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lExpectedOptions);
  lExpectedPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lExpectedFacts);

  lCacheDir := TempPath('snapshot-planner-case-selector-cache');
  if TDirectory.Exists(lCacheDir) then
    TDirectory.Delete(lCacheDir, True);
  TDirectory.CreateDirectory(lCacheDir);

  lOptions := lExpectedOptions;
  lOptions.Cache.SqliteCacheFileName := TPath.Combine(lCacheDir,
    'semantic-cache.sqlite3');
  lActualPlan := TDelphiSemanticRemoveWithApi.PlanRemoveWith(lOptions);

  Assert.AreEqual(ComparableRemoveWithPlanText(lExpectedPlan),
    ComparableRemoveWithPlanText(lActualPlan),
    'Snapshot planner must preserve source-exact selector casing.');
end;

procedure TRemoveWithPlanTests.SnapshotPlannerMaxTdbPreservesCountsWithoutProjectFactsSidecar;
var
  lCacheDir: string;
  lOptions: TDelphiSemanticApiOptions;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lProjectFactsSidecar: string;
  lProjectPath: string;
  lRequest: TDelphiSemanticRemoveWithRequest;
begin
  lProjectPath := DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr');
  if not TFile.Exists(lProjectPath) then
  begin
    Assert.Pass('Optional proprietary maxTdb fixture is absent; no maxTdb snapshot planner check was run.');
    Exit;
  end;

  lCacheDir := TempPath('snapshot-planner-maxtdb-cache');
  if TDirectory.Exists(lCacheDir) then
    TDirectory.Delete(lCacheDir, True);
  TDirectory.CreateDirectory(lCacheDir);

  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := lProjectPath;
  lOptions.Cache.SqliteCacheFileName := TPath.Combine(lCacheDir,
    'semantic-cache.sqlite3');
  lProjectFactsSidecar := lOptions.Cache.SqliteCacheFileName + '.project-facts.json';
  TDirectory.CreateDirectory(lProjectFactsSidecar);

  lRequest := Default(TDelphiSemanticRemoveWithRequest);
  lRequest.Options := lOptions;
  lRequest.BodyAnalysisSourceFileNames := MaxTdbBodyAnalysisSourceFileNames;
  lPlan := TDelphiSemanticRemoveWithApi.PlanRemoveWith(lRequest);

  Assert.AreEqual('planned', lPlan.Status, lPlan.Diagnostic);
  Assert.AreEqual('project-snapshot-v1', lPlan.BaselineSemanticModelVersion);
  Assert.IsTrue(Length(lPlan.Edits) > 0,
    'Expected maxTdb snapshot planning to produce semantic candidate edits.');
  Assert.IsTrue(Length(lPlan.FinalStatements) > 0,
    'Expected maxTdb snapshot planning to produce final statement DTOs.');
  Assert.IsTrue(TDirectory.Exists(lProjectFactsSidecar),
    'Snapshot maxTdb path must leave the poisoned sidecar directory untouched.');
  Assert.IsFalse(TFile.Exists(lProjectFactsSidecar),
    'Snapshot maxTdb path must not write the JSON project-facts sidecar.');
end;

procedure TRemoveWithPlanTests.DtoParityHarnessReportsMissingFinalStatements;
var
  lExpectedEdit: TDelphiSemanticRemoveWithPlanParityEdit;
  lExpectedStatement: TDelphiSemanticRemoveWithPlanParityStatement;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lReport: TDelphiSemanticRemoveWithPlanParityReport;
begin
  lPlan := BuildPlan;
  Assert.IsTrue(Length(lPlan.Edits) > 0, 'Expected current candidate DTO edits for parity harness input.');
  lPlan.FinalStatements := nil;

  lExpectedEdit := Default(TDelphiSemanticRemoveWithPlanParityEdit);
  lExpectedEdit.Kind := 'replace-statement';
  lExpectedEdit.FileName := lPlan.Edits[0].FileName;
  lExpectedEdit.StatementId := lPlan.Edits[0].StatementId;
  lExpectedEdit.Range := lPlan.Edits[0].Range;
  lExpectedEdit.Range.StartColumn := 1;
  lExpectedEdit.ReplacementText := 'lRecord.Value := 1;';

  lExpectedStatement := Default(TDelphiSemanticRemoveWithPlanParityStatement);
  lExpectedStatement.StatementId := lPlan.Edits[0].StatementId;
  lExpectedStatement.FileName := lPlan.Edits[0].FileName;
  lExpectedStatement.Status := 'planned';
  lExpectedStatement.Reason := 'current-dak-plan';
  lExpectedStatement.ReplacementText := lExpectedEdit.ReplacementText;
  lExpectedStatement.Edits := [lExpectedEdit];

  lReport := TDelphiSemanticRemoveWithPlanParity.Compare(lPlan, [lExpectedStatement]);

  Assert.AreEqual(2, lReport.MismatchCount, lReport.SummaryText);
  Assert.AreEqual('missing-final-statement', lReport.Mismatches[0].Kind);
  Assert.AreEqual(lExpectedStatement.StatementId, lReport.Mismatches[0].StatementId);
  Assert.IsTrue(ContainsText(lReport.SummaryText, lExpectedStatement.StatementId),
    'Expected mismatch report to include statement id.');
  Assert.IsTrue(ContainsText(lReport.SummaryText, ExtractFileName(lExpectedStatement.FileName)),
    'Expected mismatch report to include file.');
  Assert.IsTrue(ContainsText(lReport.SummaryText, 'status=planned'),
    'Expected mismatch report to include status.');
  Assert.IsTrue(ContainsText(lReport.SummaryText, 'reason=current-dak-plan'),
    'Expected mismatch report to include reason.');
  Assert.IsTrue(ContainsText(lReport.SummaryText, 'edit=replace-statement'),
    'Expected mismatch report to include edit kind.');
  Assert.IsTrue(ContainsText(lReport.SummaryText, 'range='),
    'Expected mismatch report to include edit range.');
  Assert.IsTrue(ContainsText(lReport.SummaryText, 'excerpt='),
    'Expected mismatch report to include replacement text excerpt.');
end;

procedure TRemoveWithPlanTests.DtoParityHarnessReportsUnexpectedFinalStatements;
var
  lFinalEdit: TDelphiSemanticRemoveWithFinalTextEdit;
  lFinalStatement: TDelphiSemanticRemoveWithFinalStatement;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lReport: TDelphiSemanticRemoveWithPlanParityReport;
begin
  lFinalEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
  lFinalEdit.Kind := 'replace-statement';
  lFinalEdit.FileName := FixturePath('ProjectWithBinding\ProjectWithUnit.pas');
  lFinalEdit.StatementId := 'with-extra';
  lFinalEdit.Range.StartLine := 10;
  lFinalEdit.Range.StartColumn := 1;
  lFinalEdit.Range.EndLine := 12;
  lFinalEdit.Range.EndColumn := 8;
  lFinalEdit.ReplacementText := 'lExtra.Value := 1;';

  lFinalStatement := Default(TDelphiSemanticRemoveWithFinalStatement);
  lFinalStatement.StatementId := lFinalEdit.StatementId;
  lFinalStatement.FileName := lFinalEdit.FileName;
  lFinalStatement.Status := 'planned';
  lFinalStatement.ReplacementText := lFinalEdit.ReplacementText;
  lFinalStatement.Edits := [lFinalEdit];

  lPlan := Default(TDelphiSemanticRemoveWithPlan);
  lPlan.Operation := 'remove-with';
  lPlan.Status := 'planned';
  lPlan.FinalStatements := [lFinalStatement];

  lReport := TDelphiSemanticRemoveWithPlanParity.Compare(lPlan, []);

  Assert.AreEqual(2, lReport.MismatchCount, lReport.SummaryText);
  Assert.AreEqual('unexpected-final-statement', lReport.Mismatches[0].Kind);
  Assert.AreEqual('with-extra', lReport.Mismatches[0].StatementId);
  Assert.AreEqual('unexpected-final-edit', lReport.Mismatches[1].Kind);
  Assert.IsTrue(ContainsText(lReport.SummaryText, 'statement=with-extra'),
    'Expected unexpected statement id in parity report.');
  Assert.IsTrue(ContainsText(lReport.SummaryText, 'edit=replace-statement'),
    'Expected unexpected edit kind in parity report.');
  Assert.IsTrue(ContainsText(lReport.SummaryText, 'range=10:1-12:8'),
    'Expected unexpected edit range in parity report.');
  Assert.IsTrue(ContainsText(lReport.SummaryText, 'excerpt='),
    'Expected unexpected edit replacement excerpt in parity report.');
end;

procedure TRemoveWithPlanTests.FinalStatementDtoPreservesCandidateFields;
var
  lCandidateEditCount: Integer;
  lExpectedStatement: TDelphiSemanticRemoveWithPlanParityStatement;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lPlannedEdit: TDelphiSemanticRemoveWithFinalTextEdit;
  lPlannedStatement: TDelphiSemanticRemoveWithFinalStatement;
  lReport: TDelphiSemanticRemoveWithPlanParityReport;
  lSkippedStatement: TDelphiSemanticRemoveWithFinalStatement;
  lTemp: TDelphiSemanticRemoveWithFinalTempDecision;
begin
  lPlan := BuildPlan;
  lCandidateEditCount := Length(lPlan.Edits);
  Assert.IsTrue(lCandidateEditCount > 0, 'Expected existing candidate edits to remain populated.');

  lTemp := Default(TDelphiSemanticRemoveWithFinalTempDecision);
  lTemp.SelectorText := 'lRecord';
  lTemp.QualifierText := 'lWithRecordPtr^';
  lTemp.Strategy := 'record-pointer-temp';
  lTemp.ReceiverType := 'TRecord';
  lTemp.TempName := 'lWithRecordPtr';
  lTemp.DeclarationText := 'lWithRecordPtr: ^TRecord;';
  lTemp.InitializationText := 'lWithRecordPtr := @lRecord;';
  lTemp.Reason := 'addressable-record';
  lTemp.SemanticId := lPlan.Edits[0].SemanticId;

  lPlannedEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
  lPlannedEdit.Kind := 'replace-statement';
  lPlannedEdit.FileName := lPlan.Edits[0].FileName;
  lPlannedEdit.StatementId := lPlan.Edits[0].StatementId;
  lPlannedEdit.Range := lPlan.Edits[0].Range;
  lPlannedEdit.Range.StartColumn := 1;
  lPlannedEdit.ReplacementText := 'lWithRecordPtr^.Value := 1;';
  lPlannedEdit.SemanticId := lPlan.Edits[0].SemanticId;
  lPlannedEdit.Verification.ExpectedFileHash := lPlan.Edits[0].ExpectedFileHash;
  lPlannedEdit.Verification.ExpectedSourceText := lPlan.Edits[0].ExpectedSourceText;
  lPlannedEdit.Verification.Range := lPlan.Edits[0].Range;

  lPlannedStatement := Default(TDelphiSemanticRemoveWithFinalStatement);
  lPlannedStatement.StatementId := lPlan.Edits[0].StatementId;
  lPlannedStatement.FileName := lPlan.Edits[0].FileName;
  lPlannedStatement.Status := 'planned';
  lPlannedStatement.Reason := 'dak-ready-final-dto';
  lPlannedStatement.ReplacementText := lPlannedEdit.ReplacementText;
  lPlannedStatement.Range := lPlan.Edits[0].Range;
  lPlannedStatement.SemanticId := lPlan.Edits[0].SemanticId;
  lPlannedStatement.ReferenceIds := lPlan.Edits[0].ReferenceIds;
  lPlannedStatement.Verification := lPlannedEdit.Verification;
  lPlannedStatement.Edits := [lPlannedEdit];
  lPlannedStatement.Temps := [lTemp];

  lSkippedStatement := Default(TDelphiSemanticRemoveWithFinalStatement);
  lSkippedStatement.StatementId := 'with-skipped';
  lSkippedStatement.FileName := lPlan.Edits[0].FileName;
  lSkippedStatement.Status := 'skipped';
  lSkippedStatement.Reason := 'selector-type-not-resolved';
  lSkippedStatement.SafetyReason := 'selector receiver type is unresolved';
  lSkippedStatement.SemanticId := 'semantic:with-skipped';
  lSkippedStatement.Verification.ExpectedFileHash := lPlan.Edits[0].ExpectedFileHash;

  lPlan.FinalStatements := [lPlannedStatement, lSkippedStatement];

  Assert.AreEqual(lCandidateEditCount, Integer(Length(lPlan.Edits)),
    'Final statement DTO fields must not replace candidate Edits.');
  Assert.AreEqual('requires-dak-compatibility-adapter', lPlan.Edits[0].ApplyMode,
    'Existing candidate apply mode must remain backward compatible.');
  Assert.AreEqual(2, Integer(Length(lPlan.FinalStatements)));
  Assert.AreEqual('planned', lPlan.FinalStatements[0].Status);
  Assert.AreEqual('skipped', lPlan.FinalStatements[1].Status);
  Assert.AreEqual('selector-type-not-resolved', lPlan.FinalStatements[1].Reason);
  Assert.AreEqual('lWithRecordPtr: ^TRecord;', lPlan.FinalStatements[0].Temps[0].DeclarationText);
  Assert.AreEqual(lPlan.Edits[0].ExpectedFileHash,
    lPlan.FinalStatements[0].Edits[0].Verification.ExpectedFileHash);
  Assert.AreEqual(lPlan.Edits[0].ReferenceIds[0], lPlan.FinalStatements[0].ReferenceIds[0]);

  lExpectedStatement := Default(TDelphiSemanticRemoveWithPlanParityStatement);
  lExpectedStatement.StatementId := lPlannedStatement.StatementId;
  lExpectedStatement.FileName := lPlannedStatement.FileName;
  lExpectedStatement.Status := lPlannedStatement.Status;
  lExpectedStatement.Reason := lPlannedStatement.Reason;
  lExpectedStatement.ReplacementText := lPlannedStatement.ReplacementText;
  SetLength(lExpectedStatement.Edits, 1);
  lExpectedStatement.Edits[0].Kind := lPlannedEdit.Kind;
  lExpectedStatement.Edits[0].FileName := lPlannedEdit.FileName;
  lExpectedStatement.Edits[0].StatementId := lPlannedEdit.StatementId;
  lExpectedStatement.Edits[0].Range := lPlannedEdit.Range;
  lExpectedStatement.Edits[0].ReplacementText := lPlannedEdit.ReplacementText;

  lReport := TDelphiSemanticRemoveWithPlanParity.Compare(lPlan, [lExpectedStatement]);
  Assert.AreEqual(1, lReport.MismatchCount, lReport.SummaryText);
  Assert.AreEqual('unexpected-final-statement', lReport.Mismatches[0].Kind);
  Assert.AreEqual('with-skipped', lReport.Mismatches[0].StatementId);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesFocusedRewriteCases;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath(
    'RemoveWithPlannerFixture\RemoveWithPlannerFixture.dproj'));

  Assert.AreEqual(7, Integer(Length(lPlan.FinalStatements)),
    'Expected focused final DTO to include planned and skipped statements.');

  Assert.IsTrue(FindFinalStatement(lPlan, 'with-1', lStatement),
    'Expected record selector statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText, 'lWithPlannerRecordPtr^.Name'),
    'Expected record member qualification.');
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)), 'Expected record pointer temp.');
  Assert.AreEqual('record-pointer-temp', lStatement.Temps[0].Strategy);
  Assert.AreEqual('lWithPlannerRecordPtr: ^TPlannerRecord;',
    lStatement.Temps[0].DeclarationText);
  Assert.AreEqual(2, Integer(Length(lStatement.Edits)), 'Expected declaration and replacement edits.');
  Assert.AreEqual('declare-temp', lStatement.Edits[0].Kind);
  Assert.AreEqual('replace-statement', lStatement.Edits[1].Kind);

  Assert.IsTrue(FindFinalStatement(lPlan, 'with-2', lStatement),
    'Expected object selector statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual('reference-temp', lStatement.Temps[0].Strategy);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText, 'lWithPlannerObject.Name'),
    'Expected object member qualification.');

  Assert.IsTrue(FindFinalStatement(lPlan, 'with-3', lStatement),
    'Expected property selector statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('property-selector', lStatement.Reason);

  Assert.IsTrue(FindFinalStatement(lPlan, 'with-4', lStatement),
    'Expected call selector statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('call-selector', lStatement.Reason);

  Assert.IsTrue(FindFinalStatement(lPlan, 'with-5', lStatement),
    'Expected if-controlled statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    '      lWithPlannerRecordPtr := @lRecord;'),
    'Expected controlled statement temp initialization to be indented inside wrapper.');
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    '      begin'),
    'Expected controlled statement body begin to be indented inside wrapper.');

  Assert.IsTrue(FindFinalStatement(lPlan, 'with-6', lStatement),
    'Expected case-label controlled statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText, 'lWithPlannerRecordPtr1^.Name'),
    'Expected second routine record temp to be reserved separately.');
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    '        lWithPlannerRecordPtr1 := @lRecord;'),
    'Expected case-label temp initialization to be indented inside wrapper.');
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    '        begin'),
    'Expected case-label body begin to be indented inside wrapper.');

  Assert.IsTrue(FindFinalStatement(lPlan, 'with-7', lStatement),
    'Expected pointer selector statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)), 'Expected direct pointer selector without temp.');
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)), 'Expected only replacement edit.');
  Assert.IsTrue(ContainsText(lStatement.ReplacementText, 'aRecordPtr^.Name'),
    'Expected direct pointer qualification.');
end;

procedure TRemoveWithPlanTests.FinalDtoPlansSourceBackedPropertyChainSelectorWithoutLinePatch;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(FixturePath(
    'RemoveWithPropertyChain\RemoveWithPropertyChain.dproj'));

  Assert.AreEqual(1, Integer(Length(lPlan.FinalStatements)),
    'Expected one final statement for the property-chain fixture.');
  Assert.IsTrue(FindFinalStatement(lPlan, 'with-1', lStatement),
    'Expected source-backed property-chain statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)),
    'Expected direct qualification without a temporary.');
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)),
    'Expected only the replacement edit.');
  Assert.AreEqual('  aParent^.Child.Count := aParent^.Child.Count + 1;',
    lStatement.ReplacementText);
  Assert.AreEqual(22, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(23, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(23, lStatement.Edits[0].Range.EndColumn);
end;

procedure TRemoveWithPlanTests.FinalDtoUsesRewriteRecipeFactsForRepresentativeHardCases;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lRecipe: TDelphiSemanticRemoveWithRewriteRecipe;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(FixturePath(
    'RemoveWithPropertyChain\RemoveWithPropertyChain.dproj'));

  Assert.IsTrue(FindFinalStatement(lPlan, 'with-1', lStatement),
    'Expected source-backed property-chain statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual('  aParent^.Child.Count := aParent^.Child.Count + 1;',
    lStatement.ReplacementText);

  lRecipe := lStatement.RewriteRecipe;
  Assert.AreEqual('planned', lRecipe.Status,
    'Rewrite recipe must mirror the final statement status.');
  Assert.AreEqual('source-backed-selector-chain', lRecipe.RuleId,
    'Expected source-backed property-chain recipe provenance.');
  Assert.AreEqual('semantic-remove-with-final-planner', lRecipe.Provenance);
  Assert.AreEqual('render-final-edits', lRecipe.RenderInstruction);
  Assert.AreEqual(lStatement.ReplacementText, lRecipe.ReplacementText);
  Assert.AreEqual(lStatement.Edits[0].Range.StartLine, lRecipe.ReplacementRange.StartLine);
  Assert.AreEqual(lStatement.Edits[0].Range.StartColumn, lRecipe.ReplacementRange.StartColumn);
  Assert.AreEqual(lStatement.Edits[0].Range.EndLine, lRecipe.ReplacementRange.EndLine);
  Assert.AreEqual(lStatement.Edits[0].Range.EndColumn, lRecipe.ReplacementRange.EndColumn);
  Assert.AreEqual(1, Integer(Length(lRecipe.SelectorDecisions)),
    'Expected one source-backed selector decision in the recipe.');
  Assert.AreEqual('aParent^.Child', lRecipe.SelectorDecisions[0].SelectorText);
  Assert.AreEqual('aParent^.Child', lRecipe.SelectorDecisions[0].QualifierText);
  Assert.AreEqual('direct-qualification', lRecipe.SelectorDecisions[0].Strategy);
  Assert.AreEqual('property-chain-direct-qualification',
    lRecipe.SelectorDecisions[0].Reason);
  Assert.AreEqual(0, Integer(Length(lRecipe.TempDeclarations)));
  Assert.AreEqual(1, Integer(Length(lRecipe.TextEdits)));
  Assert.AreEqual('replace-statement', lRecipe.TextEdits[0].Kind);
  Assert.AreEqual(lStatement.ReplacementText, lRecipe.TextEdits[0].ReplacementText);

  lPlan := BuildPlanForProject(DakFixturePath(
    'RemoveWithPlannerFixture\RemoveWithPlannerFixture.dproj'));

  Assert.IsTrue(FindFinalStatement(lPlan, 'with-1', lStatement),
    'Expected fixture-backed temp declaration statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)),
    'Expected record pointer temp declaration.');
  Assert.AreEqual(2, Integer(Length(lStatement.Edits)),
    'Expected declaration and replacement edits.');
  lRecipe := lStatement.RewriteRecipe;
  Assert.AreEqual('record-pointer-temp', lRecipe.RuleId);
  Assert.AreEqual(1, Integer(Length(lRecipe.TempDeclarations)),
    'Recipe must carry the temp declaration decision.');
  Assert.AreEqual(lStatement.Temps[0].TempName, lRecipe.TempDeclarations[0].TempName);
  Assert.AreEqual(lStatement.Temps[0].DeclarationText,
    lRecipe.TempDeclarations[0].DeclarationText);
  Assert.AreEqual(2, Integer(Length(lRecipe.TextEdits)),
    'Recipe must stay synchronized after late declaration edits.');
  Assert.AreEqual('declare-temp', lRecipe.TextEdits[0].Kind);
  Assert.AreEqual('replace-statement', lRecipe.TextEdits[1].Kind);
  Assert.AreEqual(lStatement.Edits[1].Range.StartLine, lRecipe.ReplacementRange.StartLine);
  Assert.AreEqual(lStatement.Edits[1].Range.StartColumn,
    lRecipe.ReplacementRange.StartColumn);

  lPlan := BuildPlanForProject(FixturePath(
    'RemoveWithRewriteRecipePatches\RemoveWithRewriteRecipePatches.dproj'));

  Assert.IsTrue(FindFinalStatement(lPlan, 'with-1', lStatement),
    'Expected fixture-backed legacy final rewrite statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  lRecipe := lStatement.RewriteRecipe;
  Assert.AreEqual('legacy-final-statement-patch', lRecipe.RuleId,
    'Line-specific replacement patches must be visible as recipe provenance.');
  Assert.AreEqual('render-final-edits', lRecipe.RenderInstruction);
  Assert.AreEqual(1, Integer(Length(lRecipe.TextEdits)));
  Assert.AreEqual('replace-statement', lRecipe.TextEdits[0].Kind);
  Assert.IsTrue(ContainsText(lRecipe.ReplacementText, 'ReadNBytes(Files[D]^.f^'),
    'Expected controlled fixture to exercise the legacy final rewrite replacement.');
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesDakBoundRewriteFixture;
var
  lFixtureDir: string;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lPlannedCount: Integer;
  lProjectPath: string;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lFixtureDir := CopyDakFixtureToTemp('RemoveWithBoundRewriteFixture',
    'dto-primary-bound-rewrite');
  lProjectPath := TPath.Combine(lFixtureDir, 'RemoveWithBoundRewriteFixture.dproj');
  lPlan := BuildPlanForProject(lProjectPath);

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'BoundRewriteUnit.pas', 33, 3,
    lStatement), 'Expected label/typecast statement.');
  Assert.AreEqual('planned', lStatement.Status,
    'Expected labels, gotos, and typecasts to remain harmless non-member syntax: ' +
    lStatement.Reason);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    'goto BoundLabel;'), 'Expected goto target to remain unqualified.');
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    'BoundLabel:'), 'Expected label declaration to remain unqualified.');
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    'TBoundRewriteCast(lCast).Name'),
    'Expected typecast target to remain unqualified.');
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    '.Name := TBoundRewriteCast(lCast).Name;'),
    'Expected receiver member assignment to be qualified.');

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'BoundRewriteUnit.pas', 41, 3,
    lStatement), 'Expected inline declaration statement.');
  Assert.AreEqual('planned', lStatement.Status,
    'Expected local inline declarations to remain unchanged while receiver members are qualified: ' +
    lStatement.Reason);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    'var Name := ''local'';'), 'Expected inline local declaration to remain local: ' +
    lStatement.ReplacementText);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    '.Count := Length(Name);'),
    'Expected receiver member assignment to be qualified while local Name remains unqualified.');

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'BoundRewriteUnit.pas', 53, 3,
    lStatement), 'Expected compact else-if statement.');
  Assert.AreEqual('planned', lStatement.Status,
    'Expected compact else-if body to be planned: ' + lStatement.Reason);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    'else if lWithBoundRewriteRecordPtr3^.Limit>0 then'), lStatement.ReplacementText);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    'lWithBoundRewriteRecordPtr3^.Count := 0;'), lStatement.ReplacementText);
  Assert.IsFalse(ContainsText(lStatement.ReplacementText,
    sLineBreak + '      Count := 0;'), lStatement.ReplacementText);

  lPlannedCount := 0;
  for lStatement in lPlan.FinalStatements do
    if SameText(lStatement.Status, 'planned') then
      Inc(lPlannedCount);
  Assert.AreEqual(4, lPlannedCount,
    'Expected label/typecast, declaration-like, and comparison with statements to be planned.');
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesDakExternalRoutineFixture;
var
  lFixtureDir: string;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lProjectPath: string;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lFixtureDir := CopyDakFixtureToTemp('RemoveWithExternalRoutineFixture',
    'dto-external-routine');
  lProjectPath := TPath.Combine(lFixtureDir, 'RemoveWithExternalRoutineFixture.dproj');
  lPlan := BuildPlanForProject(lProjectPath);

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'ExternalRoutineUnit.pas', 34, 3,
    lStatement), 'Expected known external-routine statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    'lWithExternalRoutineRecordPtr^.Name := ' +
    'lWithExternalRoutineRecordPtr^.Items[Low(lWithExternalRoutineRecordPtr^.Items)];'),
    lStatement.ReplacementText);
  Assert.IsFalse(ContainsText(lStatement.ReplacementText, 'Low(Items)'),
    lStatement.ReplacementText);
  Assert.IsFalse(ContainsText(lStatement.ReplacementText,
    ']ternalRoutineRecordPtr'), lStatement.ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesDakRewriteShapeElseBoundaries;
var
  lFixtureDir: string;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lProjectPath: string;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lFixtureDir := CopyDakFixtureToTemp('RemoveWithRewriteShapeFixture',
    'dto-rewrite-shape-else-boundaries');
  lProjectPath := TPath.Combine(lFixtureDir, 'RemoveWithRewriteShapeFixture.dproj');
  lPlan := BuildPlanForProject(lProjectPath);

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'RewriteShapeUnit.pas', 112, 5,
    lStatement), 'Expected controlled block value before else statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    'lWithRewriteShapeRecordPtr^.Name := ''controlled-block-value-before-else'';'),
    lStatement.ReplacementText);
  Assert.IsFalse(ContainsText(LowerCase(lStatement.ReplacementText),
    sLineBreak + '  else'), lStatement.ReplacementText);

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'RewriteShapeUnit.pas', 151, 3,
    lStatement), 'Expected hex literal statement.');
  Assert.AreEqual('planned', lStatement.Status, 'hex: ' + lStatement.Reason);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    'if (aRecordPtr^.Count and $7FFF) > 0 then'),
    lStatement.ReplacementText);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    'aRecordPtr^.Count := aRecordPtr^.Count + $FFFF;'),
    lStatement.ReplacementText);

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'RewriteShapeUnit.pas', 170, 3,
    lStatement), 'Expected implementation array statement.');
  Assert.AreEqual('planned', lStatement.Status, 'array: ' + lStatement.Reason);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    'lWithRewriteShapeImplementationItemPtr^.LocalName := ' +
    '''implementation-array'';'), lStatement.ReplacementText);

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'RewriteShapeUnit.pas', 259, 5,
    lStatement), 'Expected begin-end single-statement before else statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    'aLeftPtr^.Name := ''left'''),
    lStatement.ReplacementText);
  Assert.IsFalse(ContainsText(lStatement.ReplacementText,
    'aLeftPtr^.Name := ''right'''),
    lStatement.ReplacementText);
  Assert.IsFalse(ContainsText(LowerCase(lStatement.ReplacementText),
    'end else'), lStatement.ReplacementText);

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'RewriteShapeUnit.pas', 262, 5,
    lStatement), 'Expected begin-end else branch statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    'aRightPtr^.Name := ''right'''),
    lStatement.ReplacementText);

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'RewriteShapeUnit.pas', 270, 5,
    lStatement), 'Expected controlled single-statement before else statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    'aLeftPtr^.Name := ''controlled-left-before-else'''),
    lStatement.ReplacementText);
  Assert.IsFalse(ContainsText(LowerCase(lStatement.ReplacementText),
    sLineBreak + '  else'), lStatement.ReplacementText);

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'RewriteShapeUnit.pas', 273, 5,
    lStatement), 'Expected controlled single-statement else branch statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    'aRightPtr^.Name := ''controlled-right-before-else'''),
    lStatement.ReplacementText);

  Assert.IsTrue(FindFinalStatement(lPlan, 'with-21', lStatement),
    'Expected anonymous nested multi-selector statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    'lWithRewriteShapeAnonymousOuterPtr^.Struktur.InnerOnly := ' +
    'lWithRewriteShapeAnonymousOuterPtr^.OuterOnly;'),
    lStatement.ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoBlocksDakCombinedSelectorAmbiguousHelperCall;
var
  lFixtureDir: string;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lProjectPath: string;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lFixtureDir := CopyDakFixtureToTemp('RemoveWithCombinedSelectorRewriteFixture',
    'dto-combined-selector-ambiguous-helper');
  lProjectPath := TPath.Combine(lFixtureDir,
    'RemoveWithCombinedSelectorRewriteFixture.dproj');
  lPlan := BuildPlanForProject(lProjectPath);

  Assert.IsTrue(FindFinalStatement(lPlan, 'with-3', lStatement),
    'Expected ambiguous parent statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('multiple-member-candidates', lStatement.Reason);

  Assert.IsTrue(FindFinalStatement(lPlan, 'with-4', lStatement),
    'Expected safe child under blocked parent.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    'lWithCombinedOuterRight.RightOuterOnly := ' +
    '''safe-under-blocked-parent'';'), lStatement.ReplacementText);

  Assert.IsTrue(FindFinalStatement(lPlan, 'with-5', lStatement),
    'Expected ambiguous helper child.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('multiple-member-candidates', lStatement.Reason);
end;

procedure TRemoveWithPlanTests.FinalDtoDoesNotTreatNestedInlineLocalAsOuterMember;
var
  lFixtureDir: string;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lProjectPath: string;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
  lDprPath: string;
  lUnitPath: string;
begin
  lFixtureDir := TempPath('dto-inline-local-scope');
  if TDirectory.Exists(lFixtureDir) then
    TDirectory.Delete(lFixtureDir, True);
  TDirectory.CreateDirectory(lFixtureDir);
  lUnitPath := TPath.Combine(lFixtureDir, 'InlineLocalScopeUnit.pas');
  TFile.WriteAllText(lUnitPath,
    'unit InlineLocalScopeUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TInlineLocalRecord = record' + sLineBreak +
    '    Name: string;' + sLineBreak +
    '    Count: Integer;' + sLineBreak +
    '  end;' + sLineBreak +
    'procedure Run(var aRecord: TInlineLocalRecord);' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure Run(var aRecord: TInlineLocalRecord);' + sLineBreak +
    'begin' + sLineBreak +
    '  with aRecord do' + sLineBreak +
    '  begin' + sLineBreak +
    '    if Count > 0 then' + sLineBreak +
    '    begin' + sLineBreak +
    '      var Name := ''local'';' + sLineBreak +
    '      Count := Length(Name);' + sLineBreak +
    '    end;' + sLineBreak +
    '    Name := IntToStr(Count);' + sLineBreak +
    '  end;' + sLineBreak +
    'end;' + sLineBreak +
    'end.', TEncoding.UTF8);
  lDprPath := TPath.Combine(lFixtureDir, 'InlineLocalScopeFixture.dpr');
  TFile.WriteAllText(lDprPath,
    'program InlineLocalScopeFixture;' + sLineBreak +
    '{$APPTYPE CONSOLE}' + sLineBreak +
    'uses InlineLocalScopeUnit;' + sLineBreak +
    'begin' + sLineBreak +
    'end.', TEncoding.UTF8);
  lProjectPath := TPath.Combine(lFixtureDir, 'InlineLocalScopeFixture.dproj');
  TFile.WriteAllText(lProjectPath,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' + sLineBreak +
    '  <PropertyGroup>' + sLineBreak +
    '    <MainSource>InlineLocalScopeFixture.dpr</MainSource>' + sLineBreak +
    '    <DCC_UnitSearchPath>.;$(DCC_UnitSearchPath)</DCC_UnitSearchPath>' + sLineBreak +
    '  </PropertyGroup>' + sLineBreak +
    '  <ItemGroup>' + sLineBreak +
    '    <DelphiCompile Include="$(MainSource)">' + sLineBreak +
    '      <MainSource>MainSource</MainSource>' + sLineBreak +
    '    </DelphiCompile>' + sLineBreak +
    '    <DCCReference Include="InlineLocalScopeUnit.pas" />' + sLineBreak +
    '  </ItemGroup>' + sLineBreak +
    '</Project>', TEncoding.UTF8);

  lPlan := BuildPlanForProject(lProjectPath);

  Assert.IsTrue(FindFinalStatement(lPlan, 'with-1', lStatement),
    'Expected inline-local scope statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    'var Name := ''local'';'), 'Expected nested inline local declaration to remain local.');
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    '.Count := Length(Name);'),
    'Expected nested local reference to remain unqualified inside its block.');
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    'lWithInlineLocalRecordPtr^.Name := IntToStr(lWithInlineLocalRecordPtr^.Count);'),
    'Expected receiver member after the nested local block to stay qualified: ' +
    lStatement.ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoKeepsOuterInlineLocalVisibleAcrossNestedBlocks;
var
  lFixtureDir: string;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lProjectPath: string;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
  lDprPath: string;
  lLocalUsePos: Integer;
  lUnitPath: string;
begin
  lFixtureDir := TempPath('dto-inline-local-nested-visibility');
  if TDirectory.Exists(lFixtureDir) then
    TDirectory.Delete(lFixtureDir, True);
  TDirectory.CreateDirectory(lFixtureDir);
  lUnitPath := TPath.Combine(lFixtureDir, 'InlineLocalNestedVisibilityUnit.pas');
  TFile.WriteAllText(lUnitPath,
    'unit InlineLocalNestedVisibilityUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TInlineLocalRecord = record' + sLineBreak +
    '    Name: string;' + sLineBreak +
    '    Count: Integer;' + sLineBreak +
    '  end;' + sLineBreak +
    'procedure Run(var aRecord: TInlineLocalRecord);' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure Run(var aRecord: TInlineLocalRecord);' + sLineBreak +
    'begin' + sLineBreak +
    '  with aRecord do' + sLineBreak +
    '  begin' + sLineBreak +
    '    var Name := ''outer'';' + sLineBreak +
    '    if Count > 0 then' + sLineBreak +
    '    begin' + sLineBreak +
    '      Count := Length(Name);' + sLineBreak +
    '      var Name := ''inner'';' + sLineBreak +
    '      Count := Count + Length(Name);' + sLineBreak +
    '    end;' + sLineBreak +
    '    Count := Count + Length(Name);' + sLineBreak +
    '  end;' + sLineBreak +
    'end;' + sLineBreak +
    'end.', TEncoding.UTF8);
  lDprPath := TPath.Combine(lFixtureDir, 'InlineLocalNestedVisibilityFixture.dpr');
  TFile.WriteAllText(lDprPath,
    'program InlineLocalNestedVisibilityFixture;' + sLineBreak +
    '{$APPTYPE CONSOLE}' + sLineBreak +
    'uses InlineLocalNestedVisibilityUnit;' + sLineBreak +
    'begin' + sLineBreak +
    'end.', TEncoding.UTF8);
  lProjectPath := TPath.Combine(lFixtureDir, 'InlineLocalNestedVisibilityFixture.dproj');
  TFile.WriteAllText(lProjectPath,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' + sLineBreak +
    '  <PropertyGroup>' + sLineBreak +
    '    <MainSource>InlineLocalNestedVisibilityFixture.dpr</MainSource>' + sLineBreak +
    '    <DCC_UnitSearchPath>.;$(DCC_UnitSearchPath)</DCC_UnitSearchPath>' + sLineBreak +
    '  </PropertyGroup>' + sLineBreak +
    '  <ItemGroup>' + sLineBreak +
    '    <DelphiCompile Include="$(MainSource)">' + sLineBreak +
    '      <MainSource>MainSource</MainSource>' + sLineBreak +
    '    </DelphiCompile>' + sLineBreak +
    '    <DCCReference Include="InlineLocalNestedVisibilityUnit.pas" />' + sLineBreak +
    '  </ItemGroup>' + sLineBreak +
    '</Project>', TEncoding.UTF8);

  lPlan := BuildPlanForProject(lProjectPath);

  Assert.IsTrue(FindFinalStatement(lPlan, 'with-1', lStatement),
    'Expected inline-local nested visibility statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    'lWithInlineLocalRecordPtr^.Count := Length(Name);'),
    'Expected outer inline local to remain visible inside nested block: ' +
    lStatement.ReplacementText);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    'lWithInlineLocalRecordPtr^.Count := lWithInlineLocalRecordPtr^.Count + Length(Name);'),
    'Expected inner inline local to remain visible inside nested block: ' +
    lStatement.ReplacementText);
  lLocalUsePos := Pos(
    'lWithInlineLocalRecordPtr^.Count := lWithInlineLocalRecordPtr^.Count + Length(Name);',
    lStatement.ReplacementText);
  Assert.IsTrue(PosEx(
    'lWithInlineLocalRecordPtr^.Count := lWithInlineLocalRecordPtr^.Count + Length(Name);',
    lStatement.ReplacementText, lLocalUsePos + 1) > 0,
    'Expected outer inline local to be restored after the nested block: ' +
    lStatement.ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoKeepsResolvedNonMemberReferencesAndBlocksUnknownRoutine;
var
  lFixtureDir: string;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lProjectPath: string;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lFixtureDir := CopyDakFixtureToTemp('RemoveWithImplementationGlobalFixture',
    'dto-primary-implementation-global');
  lProjectPath := TPath.Combine(lFixtureDir, 'RemoveWithImplementationGlobalFixture.dproj');
  lPlan := BuildPlanForProject(lProjectPath);
  Assert.IsTrue(FindFinalStatementAt(lPlan, 'ImplementationGlobalUnit.pas', 33, 3,
    lStatement), 'Expected implementation-global final statement.');
  Assert.AreEqual('planned', lStatement.Status,
    'Expected implementation globals after routines to remain resolvable.');
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    'gCounter + gSplitCounter + cAfterRoutine'),
    'Expected implementation globals and constants to remain unqualified.');

  lFixtureDir := CopyDakFixtureToTemp('RemoveWithNestedRoutineScopeFixture',
    'dto-primary-nested-routine-scope');
  lProjectPath := TPath.Combine(lFixtureDir, 'RemoveWithNestedRoutineScopeFixture.dproj');
  lPlan := BuildPlanForProject(lProjectPath);
  Assert.IsTrue(FindFinalStatementAt(lPlan, 'NestedRoutineScopeUnit.pas', 30, 5,
    lStatement), 'Expected nested-routine final statement.');
  Assert.AreEqual('planned', lStatement.Status,
    'Expected outer routine locals captured by nested routine to remain resolvable: ' +
    lStatement.Reason);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText, 'State := nrsSaving;'),
    'Expected outer routine enum variable and value to remain unqualified.');
  Assert.IsTrue(ContainsText(lStatement.ReplacementText, 'i0'),
    'Expected captured outer routine local i0 to remain unqualified: ' +
    lStatement.ReplacementText);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText, 'ErrorFlag'),
    'Expected captured outer routine local ErrorFlag to remain unqualified: ' +
    lStatement.ReplacementText);

  lFixtureDir := CopyDakFixtureToTemp('RemoveWithEnumConstTypeAliasFixture',
    'dto-primary-enum-const-type-alias');
  lProjectPath := TPath.Combine(lFixtureDir, 'RemoveWithEnumConstTypeAliasFixture.dproj');
  lPlan := BuildPlanForProject(lProjectPath);
  Assert.IsTrue(FindFinalStatementAt(lPlan, 'EnumConstTypeAliasUnit.pas', 31, 3,
    lStatement), 'Expected enum/const/type-alias final statement.');
  Assert.AreEqual('planned', lStatement.Status,
    'Expected enum constants, typed constants, and type aliases to remain resolvable.');
  Assert.IsTrue(ContainsText(lStatement.ReplacementText, 'Ord(P_JZ)'),
    'Expected enum constants to remain unqualified.');
  Assert.IsTrue(ContainsText(lStatement.ReplacementText, 'SizeOf(TAliasInt)'),
    'Expected type alias use to remain unqualified.');

  lFixtureDir := CopyDakFixtureToTemp('RemoveWithIntrinsicSymbolFixture',
    'dto-primary-intrinsic-symbols');
  lProjectPath := TPath.Combine(lFixtureDir, 'RemoveWithIntrinsicSymbolFixture.dproj');
  lPlan := BuildPlanForProject(lProjectPath);
  Assert.IsTrue(FindFinalStatementAt(lPlan, 'IntrinsicSymbolUnit.pas', 33, 3,
    lStatement), 'Expected intrinsic final statement.');
  Assert.AreEqual('planned', lStatement.Status,
    'Expected modeled intrinsic routines to remain resolvable: ' +
    lStatement.Reason);
  Assert.IsTrue(FindFinalStatementAt(lPlan, 'IntrinsicSymbolUnit.pas', 81, 3,
    lStatement), 'Expected untyped intrinsic final statement.');
  Assert.AreEqual('planned', lStatement.Status,
    'Expected modeled untyped intrinsic routine to remain resolvable: ' +
    lStatement.Reason);

  lFixtureDir := CopyDakFixtureToTemp('RemoveWithUnresolvedReasonFixture',
    'dto-primary-unresolved-reason');
  lProjectPath := TPath.Combine(lFixtureDir, 'RemoveWithUnresolvedReasonFixture.dproj');
  lPlan := BuildPlanForProject(lProjectPath);
  Assert.IsTrue(FindFinalStatementAt(lPlan, 'UnresolvedReasonUnit.pas', 21, 3,
    lStatement), 'Expected unresolved-routine final statement.');
  Assert.AreEqual('skipped', lStatement.Status,
    'Expected truly unknown project routine to block final rewrite.');
  Assert.AreEqual('symbol-not-found', lStatement.Reason,
    'Expected true unknown routine to preserve symbol-not-found reason.');
end;

procedure TRemoveWithPlanTests.FinalDtoPreservesDakFixtureSafetySkips;
var
  lFixtureDir: string;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lProjectPath: string;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lFixtureDir := CopyDakFixtureToTemp('RemoveWithComplexSourceModelFixture',
    'dto-primary-complex-source-model');
  lProjectPath := TPath.Combine(lFixtureDir, 'RemoveWithComplexSourceModelFixture.dproj');
  lPlan := BuildPlanForProject(lProjectPath);
  Assert.IsTrue(FindFinalStatementAt(lPlan, 'ComplexSourceModelUnit.pas', 62, 3,
    lStatement), 'Expected attributed-record final statement.');
  Assert.AreEqual('skipped', lStatement.Status,
    'Expected attributed-record source model skip: ' + lStatement.Reason);
  Assert.AreEqual('unsupported-source-model-attribute', lStatement.Reason);
  Assert.IsTrue(FindFinalStatementAt(lPlan, 'ComplexSourceModelUnit.pas', 67, 3,
    lStatement), 'Expected conditional-record final statement.');
  Assert.AreEqual('skipped', lStatement.Status,
    'Expected conditional-record source model skip: ' + lStatement.Reason);
  Assert.AreEqual('unsupported-source-model-conditional-region', lStatement.Reason);
  Assert.IsTrue(FindFinalStatementAt(lPlan, 'ComplexSourceModelUnit.pas', 79, 3,
    lStatement), 'Expected generic-record final statement.');
  Assert.AreEqual('skipped', lStatement.Status,
    'Expected generic-record source model skip: ' + lStatement.Reason);
  Assert.AreEqual('unsupported-source-model-generic-declaration', lStatement.Reason);
  Assert.IsTrue(FindFinalStatementAt(lPlan, 'ComplexSourceModelUnit.pas', 84, 3,
    lStatement), 'Expected nested-type final statement.');
  Assert.AreEqual('skipped', lStatement.Status,
    'Expected nested-type source model skip: ' + lStatement.Reason);
  Assert.AreEqual('unsupported-source-model-nested-type', lStatement.Reason);

  lFixtureDir := CopyDakFixtureToTemp('RemoveWithCorpusSmokeFixture',
    'dto-primary-corpus-smoke');
  lProjectPath := TPath.Combine(lFixtureDir, 'RemoveWithCorpusSmokeFixture.dproj');
  lPlan := BuildPlanForProject(lProjectPath);
  Assert.IsTrue(FindFinalStatementAt(lPlan, 'CorpusSmokeMainUnit.pas', 36, 3,
    lStatement), 'Expected corpus attributed-record final statement.');
  Assert.AreEqual('skipped', lStatement.Status,
    'Expected corpus attributed-record source model skip: ' + lStatement.Reason);
  Assert.AreEqual('unsupported-source-model-attribute', lStatement.Reason);
  Assert.IsTrue(FindFinalStatementAt(lPlan, 'CorpusSmokeMainUnit.pas', 41, 3,
    lStatement), 'Expected corpus conditional-record final statement.');
  Assert.AreEqual('skipped', lStatement.Status,
    'Expected corpus conditional-record source model skip: ' + lStatement.Reason);
  Assert.AreEqual('unsupported-source-model-conditional-region', lStatement.Reason);

  lFixtureDir := CopyDakFixtureToTemp('RemoveWithNoEditFixture',
    'dto-primary-noedit-skips');
  lProjectPath := TPath.Combine(lFixtureDir, 'RemoveWithNoEditFixture.dproj');
  lPlan := BuildPlanForProject(lProjectPath);
  Assert.IsTrue(FindFinalStatementAt(lPlan, 'NoEditBlockedUnit.pas', 32, 7,
    lStatement), 'Expected no-edit call-selector final statement.');
  Assert.AreEqual('skipped', lStatement.Status,
    'Expected no-edit call-selector skip: ' + lStatement.Reason);
  Assert.AreEqual('call-selector', lStatement.Reason);

  lFixtureDir := CopyDakFixtureToTemp('RemoveWithE2EFixture',
    'dto-primary-e2e-skips');
  lProjectPath := TPath.Combine(lFixtureDir, 'RemoveWithE2EFixture.dproj');
  lPlan := BuildPlanForProject(lProjectPath);
  Assert.IsTrue(FindFinalStatementAt(lPlan, 'E2EExternalUnit.pas', 23, 5,
    lStatement), 'Expected e2e external-source final statement.');
  Assert.AreEqual('skipped', lStatement.Status,
    'Expected e2e external-source skip: ' + lStatement.Reason);
  Assert.AreEqual('type-source-not-indexed', lStatement.Reason);
  Assert.IsTrue(FindFinalStatementAt(lPlan, 'E2ESkippedUnit.pas', 43, 5,
    lStatement), 'Expected e2e controlled property-selector final statement.');
  Assert.AreEqual('skipped', lStatement.Status,
    'Expected e2e controlled statement skip: ' + lStatement.Reason);
  Assert.AreEqual('controlled-with-statement', lStatement.Reason);
end;

procedure TRemoveWithPlanTests.FinalDtoUsesPrecomputedNestedBindingTree;
var
  lBuildStatementEnd: Integer;
  lBuildStatementStart: Integer;
  lSourceText: string;
  lTreeStart: Integer;
begin
  lSourceText := ReadRepoSource('src\DelphiSemantics.RemoveWithPlan.pas');

  lTreeStart := Pos('function BuildFinalBindingTree', lSourceText);
  Assert.IsTrue(lTreeStart > 0,
    'Final DTO planning must precompute the direct nested binding tree once.');
  Assert.IsFalse(ContainsText(lSourceText, 'function DirectParentBindingIndex'),
    'Final binding tree construction must not run a full parent search per binding.');
  Assert.IsFalse(ContainsText(lSourceText,
    'for lCandidateIndex := 0 to Pred(aBindingSource.BindingCount)'),
    'Final binding tree construction must not scan all bindings for each binding parent.');

  lBuildStatementStart := Pos('function BuildFinalStatement', lSourceText);
  lBuildStatementEnd := lTreeStart;
  Assert.IsTrue((lBuildStatementStart > 0) and
    (lBuildStatementEnd > lBuildStatementStart),
    'Expected final statement builder source section.');
  Assert.IsFalse(ContainsText(Copy(lSourceText, lBuildStatementStart,
    lBuildStatementEnd - lBuildStatementStart), 'IsDirectNestedBinding'),
    'Final statement construction must consume the precomputed child index, not rescan all bindings.');
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesNestedRewriteOrdering;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath(
    'RemoveWithNestedRewriteFixture\RemoveWithNestedRewriteFixture.dproj'));

  Assert.AreEqual(1, Integer(Length(lPlan.FinalStatements)),
    'Expected nested child statement to be folded into the outer final DTO.');
  Assert.IsTrue(FindFinalStatement(lPlan, 'with-1', lStatement),
    'Expected outer nested statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(2, Integer(Length(lStatement.Temps)),
    'Expected outer DTO to include outer and inner temps in plan order.');
  Assert.AreEqual('lWithNestedOuter', lStatement.Temps[0].TempName);
  Assert.AreEqual('lWithNestedInner', lStatement.Temps[1].TempName);
  Assert.AreEqual(2, Integer(Length(lStatement.Edits)),
    'Expected declaration and outer replacement edits only.');
  Assert.AreEqual('declare-temp', lStatement.Edits[0].Kind);
  Assert.AreEqual('replace-statement', lStatement.Edits[1].Kind);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    'lWithNestedInner.InnerOnly := lWithNestedInner.Shared'),
    'Expected inner rewrite to be folded into outer replacement: ' +
    lStatement.ReplacementText);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    'lWithNestedOuter.OuterOnly := ''outer-from-inner'''),
    'Expected inner body to preserve outer receiver qualification.');
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesTempPolicyCollisionRules;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath(
    'RemoveWithTempPolicyFixture\RemoveWithTempPolicyFixture.dproj'));

  Assert.IsTrue(FindFinalStatement(lPlan, 'with-1', lStatement),
    'Expected constructor-local record selector.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual('lWithTempPolicyRecordPtr', lStatement.Temps[0].TempName,
    'Expected constructor routine not to reserve names from other routines.');
  Assert.AreEqual('  lWithTempPolicyRecordPtr := @lRecord;' + sLineBreak +
    '  begin' + sLineBreak +
    '    lWithTempPolicyRecordPtr^.Name := ''constructor'';' + sLineBreak +
    '  end;', lStatement.ReplacementText);
  Assert.AreEqual('  lWithTempPolicyRecordPtr: ^TTempPolicyRecord;' + sLineBreak,
    lStatement.Edits[0].ReplacementText);

  Assert.IsTrue(FindFinalStatement(lPlan, 'with-2', lStatement),
    'Expected run routine record selector.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual('lWithTempPolicyRecordPtr2', lStatement.Temps[0].TempName,
    'Expected existing run locals to be reserved before generated temps.');

  Assert.IsTrue(FindFinalStatement(lPlan, 'with-4', lStatement),
    'Expected indexed record selector.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual('lWithTempPolicyRecordPtr3', lStatement.Temps[0].TempName,
    'Expected sequential generated temps to stay reserved inside the routine.');

  Assert.IsTrue(FindFinalStatement(lPlan, 'with-9', lStatement),
    'Expected cast selector statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('cast-selector', lStatement.Reason);

  Assert.IsTrue(FindFinalStatement(lPlan, 'with-10', lStatement),
    'Expected unit-level indexed record selector.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('controlled-with-statement', lStatement.Reason);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesTempAggregationDeclarations;
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOptions: TDelphiSemanticApiOptions;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := DakFixturePath(
    'RemoveWithTempAggregationFixture\RemoveWithTempAggregationFixture.dproj');
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);

  Assert.IsTrue(lFacts.LookupIndex.FindRoutineSymbol(
    'TTempAggregationScope.ExistingVarSection', 'aFirstRecord', lSymbol),
    'Expected grouped record parameter to be indexed.');
  Assert.AreEqual('TTempAggregationRecord', lSymbol.TypeName);
  Assert.IsTrue(Length(lFacts.LookupIndex.FindMembersByOwnerAndName(
    'TTempAggregationRecord', 'Count')) > 0,
    'Expected record field to be indexed.');
  Assert.IsTrue(Length(lFacts.Bindings) > 0, 'Expected temp aggregation with bindings.');
  Assert.IsTrue(Length(lFacts.Bindings[0].Selectors) > 0,
    'Expected first binding selector.');
  Assert.AreEqual('TTempAggregationRecord', lFacts.Bindings[0].Selectors[0].TypeName);
  Assert.IsTrue(lFacts.LookupIndex.FindRoutineSymbol(lFacts.Bindings[0].RoutineName,
    'lMarker', lSymbol), 'Expected local marker to resolve in binding routine.');

  lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);

  Assert.IsTrue(FindFinalStatement(lPlan, 'with-1', lStatement),
    'Expected existing var-section record selector.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual('  lWithTempAggregationRecordPtr := @aFirstRecord;' + sLineBreak +
    '  begin' + sLineBreak +
    '    lWithTempAggregationRecordPtr^.Count := lMarker + lWithTempAggregationRecordPtr^.Count;' +
    sLineBreak +
    '  end;', lStatement.ReplacementText);

  Assert.IsTrue(FindFinalStatement(lPlan, 'with-3', lStatement),
    'Expected local-routine-before-begin record selector.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual('  lWithTempAggregationRecordPtr: ^TTempAggregationRecord;' + sLineBreak,
    lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbUnresolvedOuterNesting;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'append.pas', 106, 5, lStatement),
    'Expected maxTdb append outer with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'append.pas', 113, 7, lStatement),
    'Expected nested maxTdb append statement to remain visible after skipped outer.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText, 'Maske[Nr]^.Art'),
    'Expected nested append mask fields to keep the nested selector qualifier: ' +
    lStatement.ReplacementText);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    'TypeOkay(Maske[Nr]^.Art, t_Art)'),
    'Expected call arguments to qualify member fields only: ' +
    lStatement.ReplacementText);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    'OR (Maske[Nr]^.Art AND BitMask > 0)'),
    'Expected routine-scope parameter references to remain unchanged: ' +
    lStatement.ReplacementText);
  Assert.IsFalse(ContainsText(lStatement.ReplacementText, 'TypeOkay(Art'),
    'Expected bare nested append mask fields to be qualified: ' +
    lStatement.ReplacementText);
  Assert.IsFalse(ContainsText(lStatement.ReplacementText, 'Maske[Nr]^.IF'),
    'Expected Pascal keywords to remain unchanged: ' + lStatement.ReplacementText);
  Assert.AreEqual('      BEGIN' + #10 +
    '        IF NOT TypeOkay(Maske[Nr]^.Art, t_Art) OR (Maske[Nr]^.Art AND BitMask > 0)' + #10 +
    '        THEN' + #10 +
    '        BEGIN' + #10 +
    '          fc := 44;' + #10 +
    '          GOTO ERROR' + #10 +
    '        END;' + #10 +
    '      END;', lStatement.ReplacementText);
  Assert.IsTrue(FindFinalStatementAt(lPlan, 'append.pas', 127, 11, lStatement),
    'Expected second nested maxTdb append statement to remain visible after skipped outer.');
  Assert.AreEqual('planned', lStatement.Status, 'with-3: ' + lStatement.Reason);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText, 'IndFiles[AktIndex]^.IV[j].Feld'),
    'Expected nested append index fields to keep the nested selector qualifier: ' +
    lStatement.ReplacementText);
  Assert.IsFalse(ContainsText(lStatement.ReplacementText, 'WHILE IV[j].Feld'),
    'Expected bare nested append index fields to be qualified.');
  Assert.AreEqual('          BEGIN' + #10 +
    '            j := 1;' + #10 +
    '            WHILE IndFiles[AktIndex]^.IV[j].Feld <> 0 DO' + #10 +
    '            BEGIN' + #10 +
    '              IF IndFiles[AktIndex]^.IV[j].Feld AND $7FFF = Nr THEN' + #10 +
    '              BEGIN' + #10 +
    '                fc := 87;' + #10 +
    '                GOTO ERROR' + #10 +
    '              END;' + #10 +
    '              INC(j);' + #10 +
    '            END;' + #10 +
    '          END;', lStatement.ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbSimpleRecordParameterDirectQualification;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'bitarray.pas', 50, 3, lStatement),
    'Expected maxTdb ClearBitArray with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)),
    'Expected current DAK parity for BA selector to use direct qualification.');
  Assert.AreEqual('  fillchar(BA.Cont^, BA.MaxBytes, 0)' + sLineBreak + 'END;',
    lStatement.ReplacementText);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText, 'fillchar(BA.Cont^, BA.MaxBytes, 0)'),
    'Expected BA selector members to be directly qualified.');

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'bitarray.pas', 57, 3, lStatement),
    'Expected maxTdb NewBitArray with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)),
    'Expected current DAK parity for second BA selector to use direct qualification.');
  Assert.IsTrue(ContainsText(lStatement.ReplacementText, 'GetMem(BA.Cont, BA.MaxBytes)'),
    'Expected allocation target to use direct BA qualification: ' +
    lStatement.ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbValueRecordParameterPointerTemp;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'bitarray.pas', 115, 3, lStatement),
    'Expected maxTdb TestBit with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)),
    'Expected current DAK parity for value record parameter BA to use pointer temp.');
  Assert.AreEqual('record-pointer-temp', lStatement.Temps[0].Strategy);
  Assert.AreEqual('lWithBitArrayPtr', lStatement.Temps[0].TempName);
  Assert.AreEqual('lWithBitArrayPtr: ^TBitArray;',
    lStatement.Temps[0].DeclarationText);
  Assert.AreEqual('  lWithBitArrayPtr := @BA;' + sLineBreak +
    '  BEGIN' + sLineBreak +
    '    m := Bit SHR 3;' + sLineBreak +
    '    IF m < lWithBitArrayPtr^.MaxBytes THEN' + sLineBreak +
    '    BEGIN' + sLineBreak +
    '      b := addr(lWithBitArrayPtr^.Cont^[m]);' + sLineBreak +
    '      TestBit := b^ AND (1 SHL (Bit AND 7)) <> 0' + sLineBreak +
    '    END' + sLineBreak +
    '    ELSE' + sLineBreak +
    '      TestBit := FALSE' + sLineBreak +
    '  END' + sLineBreak, lStatement.ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbSetBitSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'bitarray.pas', 79, 3, lStatement),
    'Expected maxTdb SetBit with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTruncBitArrayDirectQualification;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'bitarray.pas', 202, 5, lStatement),
    'Expected maxTdb TruncBitArray with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)),
    'Expected current DAK parity for TruncBitArray BA selector to use direct qualification.');
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)), 'Expected only replacement edit.');
  Assert.AreEqual('    BEGIN' + sLineBreak +
    '      m := n SHR 3;' + sLineBreak +
    '      v := 8 - (n AND 7);' + sLineBreak +
    '      b := BA.Cont^[m];' + sLineBreak +
    '      b := b SHL v;' + sLineBreak +
    '      b := b SHR v;' + sLineBreak +
    '      BA.Cont^[m] := b;' + sLineBreak +
    '      FOR i := m + 1 TO BA.MaxBytes - 1 DO' + sLineBreak +
    '        BA.Cont^[i] := 0' + sLineBreak +
    '    END' + sLineBreak +
    ';', lStatement.ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbIndexedPointerSelectorDirectQualification;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'bitarray.pas', 225, 5, lStatement),
    'Expected maxTdb BitArraySum indexed pointer with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)),
    'Expected current DAK parity for indexed pointer selector to use direct qualification.');
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)), 'Expected only replacement edit.');
  Assert.AreEqual('    BEGIN' + sLineBreak +
    '      FOR i := 0 TO BitArrayListPtr^[c].MaxBytes - 1 DO' + sLineBreak +
    '      BEGIN' + sLineBreak +
    '        b := BitArrayListPtr^[c].Cont^[i];' + sLineBreak +
    '        FOR j := 0 TO 7 DO' + sLineBreak +
    '          IF t <= max THEN' + sLineBreak +
    '          BEGIN' + sLineBreak +
    '            INC(Int32(r0^), (b SHR j) AND 1);' + sLineBreak +
    '            INC(pByte(r0), SizeOf(Int32));' + sLineBreak +
    '            INC(t)' + sLineBreak +
    '          END' + sLineBreak +
    '      END' + sLineBreak +
    '    END' + sLineBreak +
    '  ', lStatement.ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbDependentPointerSelectorQualification;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'DBFUTIL.pas', 94, 3, lStatement),
    'Expected maxTdb NormRec outer with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)),
    'Expected current DAK parity for DF[D]^ selector to use direct qualification.');
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)), 'Expected only replacement edit.');
  Assert.AreEqual('  FOR i := 1 TO MaxRecZahl DO' + sLineBreak +
    '            begin' + sLineBreak +
    '        IF (DF[D]^.Maske[i]^.sl <> 0) THEN' + sLineBreak +
    '          INC(s);' + sLineBreak +
    '      end;', lStatement.ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbNestedRecordSelectorDirectQualification;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'DBFUTIL.pas', 214, 3, lStatement),
    'Expected maxTdb DBF structure with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)),
    'Expected current DAK parity for DBF, Struktur selectors to use direct qualification.');
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)), 'Expected only replacement edit.');
  Assert.AreEqual('  BEGIN' + sLineBreak +
    '    fillchar(DBF.Struktur, SizeOf(DBF.Struktur), 0);' + sLineBreak +
    '    DBF.Struktur.Version := 3;' + sLineBreak +
    '    IF DF[D]^.HatMemo THEN' + sLineBreak +
    '      INC(DBF.Struktur.Version, $80);' + sLineBreak +
    '    DBF.Struktur.Jahr := 90;' + sLineBreak +
    '    DBF.Struktur.Monat := 6;' + sLineBreak +
    '    DBF.Struktur.Tag := 26;' + sLineBreak +
    '    DBF.Struktur.Anzahl := 0;' + sLineBreak +
    '    DBF.Struktur.RecSize := 1;' + sLineBreak +
    '    DBF.DBFRec := NormRec(D);' + sLineBreak +
    '    DBF.Labels := NIL;' + sLineBreak +
    '    DBF.Struktur.Offset := (1 + DBF.DBFRec) * 32 + 1;' + sLineBreak +
    '  END;', lStatement.ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbNestedRecordSelectorSingleLineDirectQualification;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'DBFUTIL.pas', 395, 3, lStatement),
    'Expected maxTdb DBF single-line structure with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)),
    'Expected current DAK parity for single-line DBF, Struktur selectors to use direct qualification.');
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)), 'Expected only replacement edit.');
  Assert.AreEqual(
    '  WriteNBytes(DBF.m_f, Int32(DBF.Struktur.Offset) + (n - 1) * (DBF.Struktur.RecSize), DBF.Struktur.RecSize, DBF.E^, 0);',
    lStatement.ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbUnresolvedLocalBufferSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'DBFUTIL.pas', 403, 3, lStatement),
    'Expected maxTdb CloseDBFMemo with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbNestedInheritedSelectorDirectQualification;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'DBFUTIL.pas', 450, 5, lStatement),
    'Expected maxTdb OpenDBF_File nested Struktur with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)),
    'Expected current DAK parity for nested inherited Struktur selector to use direct qualification.');
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)), 'Expected only replacement edit.');
  Assert.AreEqual('    BEGIN' + sLineBreak +
    '      q := NIL;' + sLineBreak +
    '      IF DBF.new_dbf' + sLineBreak +
    '      THEN' + sLineBreak +
    '      BEGIN' + sLineBreak +
    '        Struktur.RecZahl := (Struktur.Offset - 68) DIV 48;' + sLineBreak +
    '        b_offset := 68' + sLineBreak +
    '      END' + sLineBreak +
    '      ELSE BEGIN' + sLineBreak +
    '        Struktur.RecZahl := (Struktur.Offset - 32) DIV 32;' + sLineBreak +
    '        b_offset := 32' + sLineBreak +
    '      END;' + sLineBreak +
    '      (* str(Reczahl,StatStr); domessage(statstr,statstr,0); *)' + sLineBreak +
    '      FOR i := 1 TO Struktur.RecZahl DO' + sLineBreak +
    '      BEGIN' + sLineBreak +
    '        NEW(p);' + sLineBreak +
    '        BEGIN' + sLineBreak +
    '          IF DBF.new_dbf' + sLineBreak +
    '          THEN' + sLineBreak +
    '          BEGIN' + sLineBreak +
    '            ReadNBytes(DBF.m_f, b_offset + (i - 1) * 48, 34, t_lr_new, 0);' + sLineBreak +
    '            p^ := t_lr_new;' + sLineBreak +
    '          END ELSE BEGIN' + sLineBreak +
    '            ReadNBytes(DBF.m_f, b_offset + (i - 1) * 32, 12, t_lr, 0);' + sLineBreak +
    '            move(t_lr.LabelString, p^.LabelString, 11);' + sLineBreak +
    '            p^.TYP := t_lr.TYP;' + sLineBreak +
    '            ReadNBytes(DBF.m_f, b_offset + 16 + (i - 1) * 32, 1, p^.Len, 0);' + sLineBreak +
    '            ReadNBytes(DBF.m_f, b_offset + 16 + (i - 1) * 32 + 1, 1, p^.Dezimal, 0)' + sLineBreak +
    '          END' + sLineBreak +
    '        END;' + sLineBreak +
    '        // ReadNBytes(m_f,i*32,11,p^.LabelString[1],0);' + sLineBreak +
    '        IF IO_Error <> 0 THEN' + sLineBreak +
    '        BEGIN' + sLineBreak +
    '          OpenDBF_File := IO_Error;' + sLineBreak +
    '          EXIT' + sLineBreak +
    '        END;' + sLineBreak +
    '        (*' + sLineBreak +
    '          p^.LabelString[0]:=#0;' + sLineBreak +
    '          WHILE p^.LabelString[1+ord(p^.LabelString[0])]<>#0 DO' + sLineBreak +
    '          INC(p^.LabelString[0]);' + sLineBreak +
    '        *)' + sLineBreak +
    '        // ReadNBytes(m_f,i*32+11,1,p^.Typ,0);' + sLineBreak +
    '        // IF IO_Error<>0 THEN BEGIN OpenDBF_File:=IO_Error; EXIT END;' + sLineBreak +
    '        IF (p^.TYP = ''M'') AND NOT DBF.MemoOffen THEN' + sLineBreak +
    '        BEGIN' + sLineBreak +
    '          reset(DBF.mm, 1);' + sLineBreak +
    '          IF IOResult = 0 THEN' + sLineBreak +
    '          BEGIN' + sLineBreak +
    '            // writeln(''Version: '',Version AND 127);' + sLineBreak +
    '            IF Struktur.Version AND 127 = $B THEN' + sLineBreak +
    '            BEGIN' + sLineBreak +
    '              seek(DBF.mm, 20);' + sLineBreak +
    '              blockread(DBF.mm, DBF.bs, SizeOf(DBF.bs));' + sLineBreak +
    '              // writeln(''Blocksize = '',bs); readln;' + sLineBreak +
    '              IF (DBF.bs <= 0) OR (DBF.bs > 1024) OR (DBF.bs AND 63 <> 0) THEN' + sLineBreak +
    '                DBF.bs := 512;' + sLineBreak +
    '            END;' + sLineBreak +
    '          END ELSE BEGIN' + sLineBreak +
    '            MName := copy(DBF.FileName, 1, length(DBF.FileName) - 3) + ''fpt'';' + sLineBreak +
    '            assign(DBF.mm, MName);' + sLineBreak +
    '            reset(DBF.mm, 1);' + sLineBreak +
    '            IF IOResult = 0 THEN' + sLineBreak +
    '            BEGIN' + sLineBreak +
    '              blockread(DBF.mm, mrec, 8);' + sLineBreak +
    '              DBF.bs := swap(mrec.ww);' + sLineBreak +
    '              DBF.bs := 64;' + sLineBreak +
    '              DBF.IsDBT := false;' + sLineBreak +
    '            END // ELSE writeln(''DBF-Memo NOT found.'');' + sLineBreak +
    '          END;' + sLineBreak +
    '          DBF.MemoOffen := TRUE;' + sLineBreak +
    '        END;' + sLineBreak +
    '        IF IO_Error <> 0 THEN' + sLineBreak +
    '        BEGIN' + sLineBreak +
    '          OpenDBF_File := IO_Error;' + sLineBreak +
    '          EXIT' + sLineBreak +
    '        END;' + sLineBreak +
    '        p^.next := NIL;' + sLineBreak +
    '        IF q = NIL THEN' + sLineBreak +
    '          DBF.Labels := p' + sLineBreak +
    '        ELSE' + sLineBreak +
    '          q^.next := p;' + sLineBreak +
    '        q := p;' + sLineBreak +
    '      END; (* FOR *)' + sLineBreak +
    '      GetMem(DBF.E, Struktur.RecSize);' + sLineBreak +
    '      OpenDBF_File := 0;' + sLineBreak +
    '    END;', lStatement.ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbReceiverMemberNotFoundSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'DBFUTIL.pas', 597, 3, lStatement),
    'Expected maxTdb ReadDBT DBF with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('receiver-member-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbReadDbfPointerTemp;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'DBFUTIL.pas', 661, 3, lStatement),
    'Expected maxTdb ReadDBF DBF, Struktur with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)),
    'Expected current DAK parity for ReadDBF DBF selector to use pointer temp.');
  Assert.AreEqual('record-pointer-temp', lStatement.Temps[0].Strategy);
  Assert.AreEqual('lWithDBF_FilePtr', lStatement.Temps[0].TempName);
  Assert.AreEqual('var' + sLineBreak +
    '  lWithDBF_FilePtr: ^DBF_File;' + sLineBreak,
    lStatement.Edits[0].ReplacementText);
  Assert.AreEqual('  lWithDBF_FilePtr := @DBF;' + sLineBreak +
    '  ReadNBytes(lWithDBF_FilePtr^.m_f, Int32(lWithDBF_FilePtr^.Struktur.Offset) + (Nr - 1) * lWithDBF_FilePtr^.Struktur.RecSize, lWithDBF_FilePtr^.Struktur.RecSize, lWithDBF_FilePtr^.E^, 0);',
    lStatement.ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbConvertMaskSymbolNotFoundSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'DBFUTIL.pas', 969, 7, lStatement),
    'Expected maxTdb Convert M[i]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbCopyRecToStringSelectorTypeSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'deklarat.pas', 1173, 3, lStatement),
    'Expected maxTdb CopyRecToString Maske[Nr]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('selector-type-not-resolved', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbGetDataMaskIndexQualifier;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'deklarat.pas', 1369, 5, lStatement),
    'Expected maxTdb GetData Mask[Nr]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual('    begin' + sLineBreak +
    '      CheckUnDef := (Mask[Nr]^.Art and 128 = 128) and (lFieldType <> A_LONG);' + sLineBreak +
    '      UnDef := CheckUnDef and (s[Mask[Nr]^.l] = #0);' + sLineBreak +
    '      ll := Mask[Nr]^.l; {TODO -oPawel -cInvestigation : where does this `L` ccome from? seems to be a globl variable}' + sLineBreak +
    '    end;', lStatement.ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbPutDataSelectorTypeSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'deklarat.pas', 1417, 3, lStatement),
    'Expected maxTdb PutData Mask[Nr]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('selector-type-not-resolved', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbSelektNrToStringSelectorTypeSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'deklarat.pas', 1491, 5, lStatement),
    'Expected maxTdb SelektNrToString sl^, Sel with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('selector-type-not-resolved', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbSelektLookupDirectQualification;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'deklarat.pas', 1503, 5, lStatement),
    'Expected maxTdb StringToSelektNr sl^, Sel with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual('    begin' + sLineBreak +
    '      for i := 1 to sl^.Sel.M_Az do' + sLineBreak +
    '        if s = SelektStr(sl^.Sel.Menu^[i]) then' + sLineBreak +
    '          exit(i);' + sLineBreak +
    '    end;', lStatement.ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbSelektLengthDirectQualification;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'deklarat.pas', 1518, 5, lStatement),
    'Expected maxTdb Selektlength sl^, Sel with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual('    begin' + sLineBreak +
    '      for i := 1 to sl^.Sel.M_Az do' + sLineBreak +
    '        Inc(s, 1 + length(SelektStr(sl^.Sel.Menu^[i])));' + sLineBreak +
    '    end;', lStatement.ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbForgetSelektListMemberSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'deklarat.pas', 1532, 5, lStatement),
    'Expected maxTdb ForgetSelektList p^.Sel with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('member-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbLabelStringPropertyChainQualification;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'deklarat.pas', 1614, 3, lStatement),
    'Expected maxTdb LabelString DF[d]^.Maske[Nr]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual('  if komplett and (DF[d]^.Maske[Nr]^.Art and 15 = A_LONG) then' + sLineBreak +
    '    begin' + sLineBreak +
    '      lTmpStr := DF[d]^.Maske[Nr]^.m;' + sLineBreak +
    '      while (lTmpStr <> '''') and (lTmpStr[length(lTmpStr)] <> '')'') do' + sLineBreak +
    '        delete(lTmpStr, length(lTmpStr), 1);' + sLineBreak +
    '    end' + sLineBreak +
    '    else' + sLineBreak +
    '      lTmpStr := LabString(DF[d]^.Maske[Nr]^.m);', lStatement.ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbFieldTypeSymbolNotFoundSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'deklarat.pas', 1632, 3, lStatement),
    'Expected maxTdb FieldType DF[d]^.Maske[Nr]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbDeleteMarkPropertyChainQualification;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'deklarat.pas', 2106, 3, lStatement),
    'Expected maxTdb loeschmark DF[d]^.MarkListe with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual('  begin' + sLineBreak +
    '    p := DF[d]^.MarkListe.Anfang;' + sLineBreak +
    '    q := nil;' + sLineBreak +
    '    while (p <> nil) and (p^.DV <> n) do' + sLineBreak +
    '    begin' + sLineBreak +
    '      // Inc(t);' + sLineBreak +
    '      q := p;' + sLineBreak +
    '      p := p^.Rest;' + sLineBreak +
    '    end;' + sLineBreak +
    '    if p <> nil then' + sLineBreak +
    '    begin' + sLineBreak +
    '      if q = nil then' + sLineBreak +
    '        DF[d]^.MarkListe.Anfang := p^.Rest' + sLineBreak +
    '      else' + sLineBreak +
    '        q^.Rest := p^.Rest;' + sLineBreak +
    '      if DF[d]^.MarkListe.Ende = p then' + sLineBreak +
    '        DF[d]^.MarkListe.Ende := q;' + sLineBreak +
    '      DF[d]^.MarkListe.Aktuell := nil;' + sLineBreak +
    '      dispose(p);' + sLineBreak +
    '      Dec(DF[d]^.MarkListe.AnzMarkiert);' + sLineBreak +
    '    end;' + sLineBreak +
    '  end;', lStatement.ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbLastMarkControlledPropertyChainQualification;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'deklarat.pas', 2197, 5, lStatement),
    'Expected maxTdb lastmark DF[d]^.MarkListe with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual('    begin' + sLineBreak +
    '      if DF[d]^.MarkListe.Anfang = nil then' + sLineBreak +
    '      begin' + sLineBreak +
    '        DF[d]^.MarkListe.Aktuell := nil;' + sLineBreak +
    '        DatError := 1;' + sLineBreak +
    '        lastmark := 0' + sLineBreak +
    '      end' + sLineBreak +
    '      else' + sLineBreak +
    '      begin' + sLineBreak +
    '        DatError := 0;' + sLineBreak +
    '        DF[d]^.MarkListe.Aktuell := DF[d]^.MarkListe.Ende;' + sLineBreak +
    '        lastmark := DF[d]^.MarkListe.Ende^.DV' + sLineBreak +
    '      end' + sLineBreak +
    'end;' + sLineBreak +
    '    end;', lStatement.ReplacementText);
  Assert.AreEqual(2197, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(2210, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(4, lStatement.Edits[0].Range.EndColumn);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbCheckMarkListReceiverMemberSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'deklarat.pas', 2290, 5, lStatement),
    'Expected maxTdb CheckMarkList DF[d]^.MarkListe with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('receiver-member-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbCheckMarkListNestedReceiverMemberSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'deklarat.pas', 2296, 9, lStatement),
    'Expected maxTdb CheckMarkList nested p^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('receiver-member-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbEasyTableMaskSymbolSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'Easy.TableFunctions.pas', 1715, 3, lStatement),
    'Expected maxTdb Easy.TableFunctions DF[DB].Maske[field]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbFileIoSearchRecordSymbolSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'FileIO.pas', 715, 7, lStatement),
    'Expected maxTdb FileIO _SR with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbFileIoSecurityTypeSourceSkip;
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOptions: TDelphiSemanticApiOptions;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj');
  lOptions.Configuration := 'Release';
  lOptions.Platform := 'Win32';
  lOptions.DelphiVersion := '23.0';
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'FileIO.pas', 853, 3, lStatement),
    'Expected maxTdb FileIO security with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('type-source-not-indexed', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbFormelnDataFilePointerReceiverSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'formeln.pas', 164, 5, lStatement),
    'Expected maxTdb formeln DF[D]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('receiver-member-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbLinkFileDataFilePointerReceiverSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'linkfile.pas', 220, 9, lStatement),
    'Expected maxTdb linkfile DF[i]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('receiver-member-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbLinkFileCheckShowFilesReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'linkfile.pas', 204, 11,
    lStatement), 'Expected maxTdb linkfile CheckShowFiles DF[i]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    'IF InSet(ShowFiles, i) AND (DF[i]^.LINKFILE <> 0)'),
    lStatement.ReplacementText);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    'AND NOT InSet(ShowFiles, DF[i]^.LINKFILE)'),
    lStatement.ReplacementText);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    'Include(ShowFiles, DF[i]^.LINKFILE);'),
    lStatement.ReplacementText);
  Assert.IsFalse(ContainsText(lStatement.ReplacementText, '(LINKFILE <> 0)'),
    lStatement.ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbLinkFileNestedMaskReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'linkfile.pas', 223, 13, lStatement),
    'Expected maxTdb linkfile nested Maske[j]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(417, Integer(Length(lStatement.ReplacementText)));
  Assert.AreEqual('            BEGIN' + #10 +
    '              IF Maske[j]^.Art AND 15 = A_LONG THEN' + #10 +
    '              BEGIN' + #10 +
    '                Maske[j]^.L_File := 0;' + #10 +
    '                Maske[j]^.L_Ind := 0' + #10 +
    '              END ELSE' + #10 +
    '                IF Maske[j]^.Art AND 15 = A_REL THEN' + #10 +
    '              BEGIN' + #10 +
    '                Maske[j]^.l := 0;' + #10 +
    '                Maske[j]^.R_File := 0;' + #10 +
    '                Maske[j]^.L_File := 0;' + #10 +
    '              END' + #10 +
    '            END' + #10 +
    '        ;', lStatement.ReplacementText);
  Assert.AreEqual(237, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(9, lStatement.Edits[0].Range.EndColumn);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbLinkFileNewPointerSymbolSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'linkfile.pas', 322, 5, lStatement),
    'Expected maxTdb linkfile p^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbLinkFileStatLinksPointerReceiverSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'linkfile.pas', 368, 5, lStatement),
    'Expected maxTdb linkfile StatLinks[i]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('receiver-member-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbLinkFileSetIvDataFilePointerSkip;
var
  lMatchedStatement: TDelphiSemanticRemoveWithFinalStatement;
  lMatchCount: Integer;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'linkfile.pas', 413, 7, lStatement),
    'Expected maxTdb linkfile SetIV DF[D]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
  lMatchCount := 0;
  for lMatchedStatement in lPlan.FinalStatements do
  begin
    if SameText(ExtractFileName(lMatchedStatement.FileName), 'linkfile.pas') and
      (lMatchedStatement.Range.StartLine = 413) and
      (lMatchedStatement.Range.StartColumn = 7) then
      Inc(lMatchCount);
  end;
  Assert.AreEqual(1, lMatchCount,
    'Expected exactly one semantic final DTO statement for linkfile SetIV DF[D]^.');
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbLinkFileCheckIndirektReceiverSkips;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'linkfile.pas', 446, 7, lStatement),
    'Expected maxTdb linkfile CheckIndirekt DF[D]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('receiver-member-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'linkfile.pas', 450, 13, lStatement),
    'Expected maxTdb linkfile CheckIndirekt Maske[j]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('receiver-member-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbLinkFileCheckStatLinksPointerSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'linkfile.pas', 609, 11, lStatement),
    'Expected maxTdb linkfile CheckStatLinks StatLinks[i]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('receiver-member-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbLinkFileFinalDirectQualification;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lReplacementText: string;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'linkfile.pas', 682, 9, lStatement),
    'Expected maxTdb linkfile final DF[i]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual(177, Integer(Length(lStatement.ReplacementText)));
  lReplacementText := StringReplace(lStatement.ReplacementText, #13#10, #10,
    [rfReplaceAll]);
  lReplacementText := StringReplace(lReplacementText, #13, #10, [rfReplaceAll]);
  Assert.AreEqual('        begin' + #10 +
    '          IF i <> FileNo THEN' + #10 +
    '          BEGIN' + #10 +
    '            DF[i]^.Zugriff := IndexZgr;' + #10 +
    '            DF[i]^.AktIndex := DF[i]^.LinkIndex' + #10 +
    '          END;' + #10 +
    '        end;', lReplacementText);
  Assert.AreEqual(682, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(687, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(14, lStatement.Edits[0].Range.EndColumn);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbLowFilesResetFileTypeSourceSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'lowFiles.pas', 138, 3, lStatement),
    'Expected maxTdb lowFiles ResetFile f with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('type-source-not-indexed', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbLowFilesQueuePointerSkips;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'lowFiles.pas', 155, 3, lStatement),
    'Expected maxTdb lowFiles AppendQueue fptr^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'lowFiles.pas', 173, 3, lStatement),
    'Expected maxTdb lowFiles DeleteQueue fptr^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbLowFilesFileQueueLastQualification;

  procedure AssertFileQueueLastStatement(const aStatement:
    TDelphiSemanticRemoveWithFinalStatement; const aStartLine,
    aEndLine: Integer);
  begin
    Assert.AreEqual('planned', aStatement.Status, aStatement.Reason);
    Assert.AreEqual(0, Integer(Length(aStatement.Temps)));
    Assert.AreEqual(1, Integer(Length(aStatement.Edits)));
    Assert.AreEqual('    BEGIN' + #10 +
      '      IO_Error := TDB_Closefile(FileQueue^.last^.handle);' + #10 +
      '      FileQueue^.last^.open := FALSE;' + #10 +
      '    END;', aStatement.ReplacementText);
    Assert.AreEqual(114, Integer(Length(aStatement.ReplacementText)));
    Assert.AreEqual(aStartLine, aStatement.Edits[0].Range.StartLine);
    Assert.AreEqual(1, aStatement.Edits[0].Range.StartColumn);
    Assert.AreEqual(aEndLine, aStatement.Edits[0].Range.EndLine);
    Assert.AreEqual(8, aStatement.Edits[0].Range.EndColumn);
  end;

var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'lowFiles.pas', 200, 5, lStatement),
    'Expected maxTdb lowFiles DoLRU FileQueue^.last^ with statement.');
  AssertFileQueueLastStatement(lStatement, 200, 204);

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'lowFiles.pas', 235, 5, lStatement),
    'Expected maxTdb lowFiles GetFreeHandles FileQueue^.last^ with statement.');
  AssertFileQueueLastStatement(lStatement, 235, 239);
end;

procedure TRemoveWithPlanTests.FinalDtoIndexesMaxTdbLowFilesPropertyChainFacts;
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lFileQueueSymbols: TArray<TDelphiSemanticInventorySymbol>;
  lLastSymbols: TArray<TDelphiSemanticInventorySymbol>;
  lOptions: TDelphiSemanticApiOptions;
begin
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr');
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  lFileQueueSymbols := lFacts.LookupIndex.FindUnitOrGlobalByName('FileQueue');
  lLastSymbols := lFacts.LookupIndex.FindMembersByOwnerAndName('LowFile', 'last');

  Assert.IsTrue(Length(lFileQueueSymbols) > 0,
    'Expected FileQueue unit-global to be indexed.');
  Assert.AreEqual('LowFilePtr', lFileQueueSymbols[0].TypeName,
    'Expected FileQueue to retain its pointer alias type.');
  Assert.AreEqual('LowFile', lFacts.LookupIndex.PointerTargetType('LowFilePtr'),
    'Expected LowFilePtr pointer alias to resolve to LowFile.');
  Assert.IsTrue(Length(lLastSymbols) > 0,
    'Expected LowFile.last record field to be indexed.');
  Assert.AreEqual('LowFilePtr', lLastSymbols[0].TypeName,
    'Expected LowFile.last to retain its pointer alias type.');
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbLowFilesVirtualFileSkips;

  procedure AssertSkippedStatement(const aPlan: TDelphiSemanticRemoveWithPlan;
    const aLine, aColumn: Integer; const aReason: string);
  var
    lStatement: TDelphiSemanticRemoveWithFinalStatement;
  begin
    Assert.IsTrue(FindFinalStatementAt(aPlan, 'lowFiles.pas', aLine, aColumn,
      lStatement), 'Expected maxTdb lowFiles with statement at line ' +
      IntToStr(aLine) + '.');
    Assert.AreEqual('skipped', lStatement.Status);
    Assert.AreEqual(aReason, lStatement.Reason);
    Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
    Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
  end;

var
  lPlan: TDelphiSemanticRemoveWithPlan;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  AssertSkippedStatement(lPlan, 266, 5, 'selector-type-not-resolved');
  AssertSkippedStatement(lPlan, 272, 9, 'selector-type-not-resolved');
  AssertSkippedStatement(lPlan, 315, 5, 'selector-type-not-resolved');
  AssertSkippedStatement(lPlan, 330, 13, 'selector-type-not-resolved');
  AssertSkippedStatement(lPlan, 351, 7, 'type-source-not-indexed');
  AssertSkippedStatement(lPlan, 382, 5, 'selector-type-not-resolved');
  AssertSkippedStatement(lPlan, 386, 7, 'selector-type-not-resolved');
  AssertSkippedStatement(lPlan, 398, 5, 'receiver-member-not-found');
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbLowFilesReadNBytesReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'lowFiles.pas', 434, 5, lStatement),
    'Expected maxTdb lowFiles ReadNBytes f with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
  Assert.AreEqual('lWithLowFilePtr', lStatement.Temps[0].TempName);
  Assert.AreEqual(2, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('    begin' + sLineBreak +
    '      lWithLowFilePtr := @f;' + sLineBreak +
    '      BEGIN' + #10 +
    '      // writeln(''v_readnbytes lowfile<br>'');' + #10 +
    '      IF lWithLowFilePtr^.v_handle_ptr = NIL THEN' + #10 +
    '        IO_Error := 1' + #10 +
    '      ELSE' + #10 +
    '        BEGIN' + #10 +
    '          IF ab + n > lWithLowFilePtr^.v_handle_ptr^.v_size THEN' + #10 +
    '            IO_Error := 2' + #10 +
    '          ELSE' + #10 +
    '          BEGIN' + #10 +
    '            p_from := lWithLowFilePtr^.v_handle_ptr^.v_Mem;' + #10 +
    '            INC(pByte(p_from), ab);' + #10 +
    '            p_to := addr(V);' + #10 +
    '            move(p_from^, p_to^, n);' + #10 +
    '            IO_Error := 0' + #10 +
    '          END' + #10 +
    '        END;' + #10 +
    '      Result:= IO_Error;' + #10 +
    '      EXIT' + #10 +
    '    END;' + sLineBreak +
    '    end;', lStatement.ReplacementText);
  Assert.AreEqual(587, Integer(Length(lStatement.ReplacementText)));
  Assert.AreEqual(432, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(434, lStatement.Edits[1].Range.StartLine);
  Assert.AreEqual(455, lStatement.Edits[1].Range.EndLine);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbLowFilesWriteNBytesReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'lowFiles.pas', 484, 5, lStatement),
    'Expected maxTdb lowFiles WriteNBytes f with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
  Assert.AreEqual('lWithLowFilePtr', lStatement.Temps[0].TempName);
  Assert.AreEqual(2, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('    begin' + sLineBreak +
    '      lWithLowFilePtr := @f;' + sLineBreak +
    '      BEGIN' + #10 +
    '      // writeln(''v_writenbytes lowfile<br>'');' + #10 +
    '      IF lWithLowFilePtr^.v_handle_ptr = NIL THEN' + #10 +
    '        IO_Error := 1' + #10 +
    '      ELSE' + #10 +
    '        BEGIN' + #10 +
    '          IF ab + n > Max_Virtual_Filesize THEN' + #10 +
    '            IO_Error := 2' + #10 +
    '          ELSE' + #10 +
    '          BEGIN' + #10 +
    '            IF ab + n > lWithLowFilePtr^.v_handle_ptr^.a_size THEN' + #10 +
    '            BEGIN' + #10 +
    '              // Speicher holen;' + #10 +
    '              new_size := ab + n;' + #10 +
    '              new_size := ((new_size + pred(Inc_Virtual_FileSize)) DIV Inc_Virtual_FileSize) * Inc_Virtual_FileSize;' + #10 +
    '              reallocmem(lWithLowFilePtr^.v_handle_ptr^.v_Mem, new_size);' + #10 +
    '              lWithLowFilePtr^.v_handle_ptr^.a_size := new_size;' + #10 +
    '            END;' + #10 +
    '            p_to := lWithLowFilePtr^.v_handle_ptr^.v_Mem;' + #10 +
    '            INC(pByte(p_to), ab);' + #10 +
    '            p_from := addr(V);' + #10 +
    '            move(p_from^, p_to^, n);' + #10 +
    '            IF ab + n > lWithLowFilePtr^.v_handle_ptr^.v_size THEN' + #10 +
    '              lWithLowFilePtr^.v_handle_ptr^.v_size := ab + n;' + #10 +
    '            IO_Error := 0' + #10 +
    '          END' + #10 +
    '        END;' + #10 +
    '      WriteNBytes := IO_Error;' + #10 +
    '      EXIT' + #10 +
    '    END;' + sLineBreak +
    '    end;', lStatement.ReplacementText);
  Assert.AreEqual(1130, Integer(Length(lStatement.ReplacementText)));
  Assert.AreEqual(482, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(484, lStatement.Edits[1].Range.StartLine);
  Assert.AreEqual(515, lStatement.Edits[1].Range.EndLine);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbLowFilesSizeAndCutFileParity;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'lowFiles.pas', 545, 5, lStatement),
    'Expected maxTdb lowFiles LowFileSize f with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
  Assert.AreEqual('lWithLowFilePtr', lStatement.Temps[0].TempName);
  Assert.AreEqual('    begin' + sLineBreak +
    '      lWithLowFilePtr := @f;' + sLineBreak +
    '      BEGIN' + #10 +
    '      // writeln(''v_filesize lowfile<br>'');' + #10 +
    '      IF lWithLowFilePtr^.v_handle_ptr = NIL' + #10 +
    '      THEN' + #10 +
    '        LowFileSize := 0' + #10 +
    '      ELSE' + #10 +
    '        LowFileSize := lWithLowFilePtr^.v_handle_ptr^.v_size;' + #10 +
    '      EXIT' + #10 +
    '    END;' + sLineBreak +
    '    end;', lStatement.ReplacementText);
  Assert.AreEqual(280, Integer(Length(lStatement.ReplacementText)));
  Assert.AreEqual(543, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual('var' + sLineBreak + '  lWithLowFilePtr: ^LowFile;' +
    sLineBreak, lStatement.Edits[0].ReplacementText);

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'lowFiles.pas', 603, 5, lStatement),
    'Expected maxTdb lowFiles CutFile f with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('selector-type-not-resolved', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'lowFiles.pas', 608, 9, lStatement),
    'Expected maxTdb lowFiles CutFile nested v_handle_ptr^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('selector-type-not-resolved', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbLowFilesCopyLowFileReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'lowFiles.pas', 696, 5, lStatement),
    'Expected maxTdb lowFiles CopyLowFile f with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
  Assert.AreEqual('lWithLowFilePtr', lStatement.Temps[0].TempName);
  Assert.AreEqual(2, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('    begin' + sLineBreak +
    '      lWithLowFilePtr := @f;' + sLineBreak +
    '      BEGIN' + #10 +
    '      IF lWithLowFilePtr^.v_handle_ptr <> NIL THEN' + #10 +
    '        BEGIN' + #10 +
    '          TDB_AssignFile(v_handle, path);' + #10 +
    '          io := TDB_RewriteFile(v_handle, 1);' + #10 +
    '          IF io = 0 THEN' + #10 +
    '          BEGIN' + #10 +
    '            io := TDB_BlockWrite(v_handle, lWithLowFilePtr^.v_handle_ptr^.v_Mem^, lWithLowFilePtr^.v_handle_ptr^.v_size);' + #10 +
    '            IF io = 0 THEN' + #10 +
    '              TDB_Closefile(v_handle)' + #10 +
    '          END' + #10 +
    '        END' + #10 +
    '    ;END;' + sLineBreak +
    '    end;', lStatement.ReplacementText);
  Assert.AreEqual(479, Integer(Length(lStatement.ReplacementText)));
  Assert.AreEqual(693, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(696, lStatement.Edits[1].Range.StartLine);
  Assert.AreEqual(710, lStatement.Edits[1].Range.EndLine);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbMakeIvIndexedVectorReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'makeiv.pas', 65, 7, lStatement),
    'Expected maxTdb makeiv IV[h] with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
  Assert.AreEqual('lWithIndexVektorItemPtr', lStatement.Temps[0].TempName);
  Assert.AreEqual(2, Integer(Length(lStatement.Edits)));
  Assert.AreEqual(2372, Integer(Length(lStatement.ReplacementText)));
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    'lWithIndexVektorItemPtr^.Feld := lWithIndexVektorItemPtr^.Feld OR $4000'),
    lStatement.ReplacementText);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    'lWithIndexVektorItemPtr^.IV_Art := DF[D]^.Maske[lWithIndexVektorItemPtr^.Feld]^.Art AND 15'),
    lStatement.ReplacementText);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    'lWithIndexVektorItemPtr^.Anzahl := 1 + DF[D]^.Maske[lWithIndexVektorItemPtr^.Feld]^.l'),
    lStatement.ReplacementText);
  Assert.AreEqual(25, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual('var' + sLineBreak +
    '  lWithIndexVektorItemPtr: ^TIndexVektorItem;' + sLineBreak,
    lStatement.Edits[0].ReplacementText);
  Assert.AreEqual(65, lStatement.Edits[1].Range.StartLine);
  Assert.AreEqual(128, lStatement.Edits[1].Range.EndLine);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbMd5ContextReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'md5.pas', 237, 3, lStatement),
    'Expected maxTdb md5 Context with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('  begin' + #10 +
    '    Context.State[0] := $67452301;' + #10 +
    '    Context.State[1] := $EFCDAB89;' + #10 +
    '    Context.State[2] := $98BADCFE;' + #10 +
    '    Context.State[3] := $10325476;' + #10 +
    '    Context.Count[0] := 0;' + #10 +
    '    Context.Count[1] := 0;' + #10 +
    '    FillChar(Context.Buffer, SizeOf(TMD5Buffer), 0);' + #10 +
    '  end;', lStatement.ReplacementText);
  Assert.AreEqual(261, Integer(Length(lStatement.ReplacementText)));
  Assert.AreEqual(237, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(246, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(6, lStatement.Edits[0].Range.EndColumn);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbRamFilesCheckRamTextSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'ramfiles.pas', 147, 3, lStatement),
    'Expected maxTdb ramfiles CheckRamText rt with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('receiver-member-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbRamFilesRewriteRamTextReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'ramfiles.pas', 249, 3, lStatement),
    'Expected maxTdb ramfiles RewriteRamText RamText with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
  Assert.AreEqual('lWithRamTextPtr', lStatement.Temps[0].TempName);
  Assert.AreEqual(2, Integer(Length(lStatement.Edits)));
  Assert.AreEqual(446, Integer(Length(lStatement.ReplacementText)));
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    'lWithRamTextPtr := @RamText'), lStatement.ReplacementText);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    'lWithRamTextPtr^.State := _write'), lStatement.ReplacementText);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText,
    'fillchar(lWithRamTextPtr^.Cont^, lWithRamTextPtr^._MaxFileSize, 0)'),
    lStatement.ReplacementText);
  Assert.AreEqual(248, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual('var' + sLineBreak + '  lWithRamTextPtr: ^TRamText;' +
    sLineBreak, lStatement.Edits[0].ReplacementText);
  Assert.AreEqual(249, lStatement.Edits[1].Range.StartLine);
  Assert.AreEqual(263, lStatement.Edits[1].Range.EndLine);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbRamFilesInitRamTextSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'ramfiles.pas', 267, 3, lStatement),
    'Expected maxTdb ramfiles InitRamText RamText with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbRamFilesCgiBufferDirectQualification;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'ramfiles.pas', 295, 3, lStatement),
    'Expected maxTdb ramfiles CGIBuffer with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('  begin' + sLineBreak +
    '    if CGIBuffer.Cont <> nil then' + sLineBreak +
    '      FreeMem(CGIBuffer.Cont, CGIBuffer._MaxFileSize);' + sLineBreak +
    '    CGIBuffer._MaxFileSize := n;' + sLineBreak +
    '    GetMem(CGIBuffer.Cont, n);' + sLineBreak +
    '    RewriteRamText(CGIBuffer, 0);' + sLineBreak +
    '  end' + sLineBreak, lStatement.ReplacementText);
  Assert.AreEqual(295, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(303, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.EndColumn);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbRamFilesResetRamTextPointerTemp;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'ramfiles.pas', 307, 3, lStatement),
    'Expected maxTdb ramfiles ResetRamText RamText with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
  Assert.AreEqual('record-pointer-temp', lStatement.Temps[0].Strategy);
  Assert.AreEqual('lWithRamTextPtr', lStatement.Temps[0].TempName);
  Assert.AreEqual(2, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('var' + sLineBreak + '  lWithRamTextPtr: ^TRamText;' +
    sLineBreak, lStatement.Edits[0].ReplacementText);
  Assert.AreEqual(306, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(307, lStatement.Edits[1].Range.StartLine);
  Assert.AreEqual(319, lStatement.Edits[1].Range.EndLine);
  Assert.AreEqual('  lWithRamTextPtr := @RamText;' + sLineBreak +
    '  begin' + sLineBreak +
    '    if lWithRamTextPtr^.State = _write then' + sLineBreak +
    '      ResetRamText := 1' + sLineBreak +
    '    else' + sLineBreak +
    '      ResetRamText := 0;' + sLineBreak +
    '    lWithRamTextPtr^.State := _read;' + sLineBreak +
    '    lWithRamTextPtr^._CharPtr := 0;' + sLineBreak +
    '    RamTextResult := 0;' + sLineBreak +
    '    lWithRamTextPtr^.ActChar := lWithRamTextPtr^.Cont;' + sLineBreak +
    '    lWithRamTextPtr^._mode := mode' + sLineBreak +
    '  end' + sLineBreak, lStatement.ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbRamFilesAppendRamTextPointerTemp;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'ramfiles.pas', 323, 3, lStatement),
    'Expected maxTdb ramfiles AppendRamText RamText with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
  Assert.AreEqual('record-pointer-temp', lStatement.Temps[0].Strategy);
  Assert.AreEqual('lWithRamTextPtr', lStatement.Temps[0].TempName);
  Assert.AreEqual(2, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('var' + sLineBreak + '  lWithRamTextPtr: ^TRamText;' +
    sLineBreak, lStatement.Edits[0].ReplacementText);
  Assert.AreEqual(322, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(323, lStatement.Edits[1].Range.StartLine);
  Assert.AreEqual(336, lStatement.Edits[1].Range.EndLine);
  Assert.AreEqual('  lWithRamTextPtr := @RamText;' + sLineBreak +
    '  begin' + sLineBreak +
    '    if lWithRamTextPtr^.State = _read then' + sLineBreak +
    '      AppendRamText := 1' + sLineBreak +
    '    else' + sLineBreak +
    '      AppendRamText := 0;' + sLineBreak +
    '    lWithRamTextPtr^.State := _write;' + sLineBreak +
    '    RamTextResult := 0;' + sLineBreak +
    '    lWithRamTextPtr^.ActChar := lWithRamTextPtr^.Cont;' + sLineBreak +
    '    lWithRamTextPtr^._mode := mode;' + sLineBreak +
    '    lWithRamTextPtr^._CharPtr := lWithRamTextPtr^._FileSize;' + sLineBreak +
    '    Inc(lWithRamTextPtr^.ActChar, lWithRamTextPtr^._CharPtr);' + sLineBreak +
    '  end' + sLineBreak, lStatement.ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbRamFilesClosePointerQualification;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'ramfiles.pas', 434, 5, lStatement),
    'Expected maxTdb ramfiles close rt^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('    begin' + sLineBreak +
    '      ResetRamText(rt^, 0);' + sLineBreak +
    '      TDB_BlockWrite(f, rt^.Cont^, rt^._FileSize);' + sLineBreak +
    '      io := TDB_CloseFile(f);' + sLineBreak +
    '      rt^.State := _close;' + sLineBreak +
    '    end;', lStatement.ReplacementText);
  Assert.AreEqual(434, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(440, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(8, lStatement.Edits[0].Range.EndColumn);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbRamFilesInsertPCharPointerTemp;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'ramfiles.pas', 456, 3, lStatement),
    'Expected maxTdb ramfiles InsertRamTextPChar rt with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
  Assert.AreEqual('record-pointer-temp', lStatement.Temps[0].Strategy);
  Assert.AreEqual('lWithRamTextPtr', lStatement.Temps[0].TempName);
  Assert.AreEqual(2, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('  lWithRamTextPtr: ^TRamText;' + sLineBreak,
    lStatement.Edits[0].ReplacementText);
  Assert.AreEqual(450, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(456, lStatement.Edits[1].Range.StartLine);
  Assert.AreEqual(474, lStatement.Edits[1].Range.EndLine);
  Assert.AreEqual('  lWithRamTextPtr := @rt;' + sLineBreak +
    '  begin' + sLineBreak +
    '    if ignore then' + sLineBreak +
    '      d := TDB_StrPosI(lWithRamTextPtr^.Cont, b)' + sLineBreak +
    '    else' + sLineBreak +
    '      d := TDB_StrPos(lWithRamTextPtr^.Cont, b);' + sLineBreak +
    '    if d <> nil then' + sLineBreak +
    '    begin' + sLineBreak +
    '      i := lWithRamTextPtr^._FileSize - (d - lWithRamTextPtr^.Cont) - ls + 1;' + sLineBreak +
    '      d1 := d + ls;' + sLineBreak +
    '      d2 := d + li;' + sLineBreak +
    '      move(d1^, d2^, i);' + sLineBreak +
    '      move(Ins^, d^, li);' + sLineBreak +
    '      lWithRamTextPtr^._FileSize := lWithRamTextPtr^._FileSize + li - ls;' + sLineBreak +
    '      lWithRamTextPtr^.ActChar := lWithRamTextPtr^.Cont + lWithRamTextPtr^._FileSize;' + sLineBreak +
    '      InsertRamTextPChar := d - lWithRamTextPtr^.Cont + 1' + sLineBreak +
    '    end' + sLineBreak +
    '  end' + sLineBreak, lStatement.ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbRamFilesBlockWriteCgiBufferQualification;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'ramfiles.pas', 478, 3, lStatement),
    'Expected maxTdb ramfiles Ramtext_blockwrite CGIBuffer with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('  begin' + sLineBreak +
    '    if CGIBuffer._FileSize + n >= CGIBuffer._MaxFileSize then' + sLineBreak +
    '    begin' + sLineBreak +
    '      if CGI_Output_Error = 0 then' + sLineBreak +
    '      begin' + sLineBreak +
    '        Write(CGIBuffer.Cont);' + sLineBreak +
    '        flush(output);' + sLineBreak +
    '        CGI_Output_Error := IOResult' + sLineBreak +
    '      end;' + sLineBreak +
    '      RewriteRamText(CGIBuffer, 0);' + sLineBreak +
    '    end;' + sLineBreak +
    '    move(b^, CGIBuffer.ActChar^, n);' + sLineBreak +
    '    Inc(CGIBuffer.ActChar, n);' + sLineBreak +
    '    Inc(CGIBuffer._FileSize, n)' + sLineBreak +
    '  end' + sLineBreak, lStatement.ReplacementText);
  Assert.AreEqual(478, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(494, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.EndColumn);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbRamFilesReadRamTextSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'ramfiles.pas', 544, 3, lStatement),
    'Expected maxTdb ramfiles ReadRamText RamText with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbRamFilesGetCharPointerTemp;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'ramfiles.pas', 586, 3, lStatement),
    'Expected maxTdb ramfiles GetCharRamText RamText with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
  Assert.AreEqual('record-pointer-temp', lStatement.Temps[0].Strategy);
  Assert.AreEqual('lWithRamTextPtr', lStatement.Temps[0].TempName);
  Assert.AreEqual(2, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('var' + sLineBreak + '  lWithRamTextPtr: ^TRamText;' +
    sLineBreak, lStatement.Edits[0].ReplacementText);
  Assert.AreEqual(585, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(586, lStatement.Edits[1].Range.StartLine);
  Assert.AreEqual(600, lStatement.Edits[1].Range.EndLine);
  Assert.AreEqual('  lWithRamTextPtr := @RamText;' + sLineBreak +
    '  begin' + sLineBreak +
    '    if lWithRamTextPtr^._CharPtr < lWithRamTextPtr^._FileSize then' + sLineBreak +
    '    begin' + sLineBreak +
    '      GetCharRamText := lWithRamTextPtr^.ActChar^;' + sLineBreak +
    '      Inc(lWithRamTextPtr^.ActChar);' + sLineBreak +
    '      Inc(lWithRamTextPtr^._CharPtr);' + sLineBreak +
    '    end' + sLineBreak +
    '    else' + sLineBreak +
    '    begin' + sLineBreak +
    '      GetCharRamText := #0;' + sLineBreak +
    '      RamTextResult := 2' + sLineBreak +
    '    end' + sLineBreak +
    '  end' + sLineBreak, lStatement.ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbRamFilesReadLnSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'ramfiles.pas', 608, 3, lStatement),
    'Expected maxTdb ramfiles ReadLnRamText RamText with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbRamFilesEofPointerTemp;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'ramfiles.pas', 666, 3, lStatement),
    'Expected maxTdb ramfiles EOFRamText RamText with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
  Assert.AreEqual('record-pointer-temp', lStatement.Temps[0].Strategy);
  Assert.AreEqual('lWithRamTextPtr', lStatement.Temps[0].TempName);
  Assert.AreEqual(2, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('var' + sLineBreak + '  lWithRamTextPtr: ^TRamText;' +
    sLineBreak, lStatement.Edits[0].ReplacementText);
  Assert.AreEqual(665, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(666, lStatement.Edits[1].Range.StartLine);
  Assert.AreEqual(670, lStatement.Edits[1].Range.EndLine);
  Assert.AreEqual('  lWithRamTextPtr := @RamText;' + sLineBreak +
    '  begin' + sLineBreak +
    '    EOFRamText := (RamTextResult = 2) or (lWithRamTextPtr^._CharPtr >= lWithRamTextPtr^._FileSize)' +
    sLineBreak +
    '  end' + sLineBreak, lStatement.ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbRamFilesResetFileSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'ramfiles.pas', 688, 3, lStatement),
    'Expected maxTdb ramfiles ResetRamFile f with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('type-source-not-indexed', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbRamFilesRamFileSkipReasons;
var
  lPlan: TDelphiSemanticRemoveWithPlan;

  procedure AssertRamFileSkip(const aLine, aColumn: Integer);
  var
    lStatement: TDelphiSemanticRemoveWithFinalStatement;
  begin
    Assert.IsTrue(FindFinalStatementAt(lPlan, 'ramfiles.pas', aLine, aColumn,
      lStatement),
      'Expected maxTdb ramfiles RamFile with statement at line ' + IntToStr(aLine) + '.');
    Assert.AreEqual('skipped', lStatement.Status);
    Assert.AreEqual('type-source-not-indexed', lStatement.Reason);
    Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
    Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
  end;

begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  AssertRamFileSkip(704, 3);
  AssertRamFileSkip(719, 3);
  AssertRamFileSkip(737, 5);
  AssertRamFileSkip(757, 3);
  AssertRamFileSkip(774, 3);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbRamFilesSkipRamTextReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'ramfiles.pas', 831, 3, lStatement),
    'Expected maxTdb ramfiles SkipRamText rt with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('  if rt._FileSize >= skip then' + sLineBreak +
    '    begin' + sLineBreak +
    '      Dec(rt._FileSize, skip);' + sLineBreak +
    '      Dec(rt.ActChar, skip);' + sLineBreak +
    '      Dec(rt._CharPtr, skip);' + sLineBreak +
    '      fillchar(rt.ActChar^, skip, #0)' + sLineBreak +
    '    end' + sLineBreak +
    'end;', lStatement.ReplacementText);
  Assert.AreEqual(831, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(839, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(4, lStatement.Edits[0].Range.EndColumn);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbRamFilesSaveItemWrapperIndent;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'ramfiles.pas', 899, 7, lStatement),
    'Expected maxTdb ramfiles SaveRamText RamTextSave[i] with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(2, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('      begin' + sLineBreak +
    '        lWithRamTextSaveItemPtr := @RamTextSave[i];' + sLineBreak +
    '        begin' + sLineBreak +
    '        if StrCmpI(lWithRamTextSaveItemPtr^.Name^, nn) = 0 then' + sLineBreak +
    '        begin' + sLineBreak +
    '          Result := addr(RamTextSave[i].rt);' + sLineBreak +
    '          exit' + sLineBreak +
    '        end;' + sLineBreak +
    '      end;' + sLineBreak +
    '      end;', lStatement.ReplacementText);
  Assert.AreEqual(899, lStatement.Edits[1].Range.StartLine);
  Assert.AreEqual(906, lStatement.Edits[1].Range.EndLine);
  Assert.AreEqual(10, lStatement.Edits[1].Range.EndColumn);

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'ramfiles.pas', 931, 7, lStatement),
    'Expected maxTdb ramfiles InitRamtextSize RamTextSave[i] with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(2, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('      begin' + sLineBreak +
    '        lWithRamTextSaveItemPtr := @RamTextSave[i];' + sLineBreak +
    '        begin' + sLineBreak +
    '        if StrCmpI(lWithRamTextSaveItemPtr^.Name^, nn) = 0 then' + sLineBreak +
    '        begin' + sLineBreak +
    '          InitRamtextSize := i;' + sLineBreak +
    '          exit' + sLineBreak +
    '        end' + sLineBreak +
    '      end;' + sLineBreak +
    '      end;', lStatement.ReplacementText);
  Assert.AreEqual(931, lStatement.Edits[1].Range.StartLine);
  Assert.AreEqual(938, lStatement.Edits[1].Range.EndLine);
  Assert.AreEqual(10, lStatement.Edits[1].Range.EndColumn);

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'ramfiles.pas', 1145, 5, lStatement),
    'Expected maxTdb ramfiles GetCGIText RamTextSave[i] with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(2, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('    begin' + sLineBreak +
    '      lWithRamTextSaveItemPtr := @RamTextSave[i];' + sLineBreak +
    '      begin' + sLineBreak +
    '      if StrCmpI(lWithRamTextSaveItemPtr^.Name^, n) = 0 then' + sLineBreak +
    '      begin' + sLineBreak +
    '        GetCGIText := addr(lWithRamTextSaveItemPtr^.rt);' + sLineBreak +
    '        exit' + sLineBreak +
    '      end;' + sLineBreak +
    '    end;' + sLineBreak +
    '    end;', lStatement.ReplacementText);
  Assert.AreEqual(1145, lStatement.Edits[1].Range.StartLine);
  Assert.AreEqual(1152, lStatement.Edits[1].Range.EndLine);
  Assert.AreEqual(8, lStatement.Edits[1].Range.EndColumn);

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'ramfiles.pas', 1161, 5, lStatement),
    'Expected maxTdb ramfiles GetCGIHdl RamTextSave[i] with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(2, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('    begin' + sLineBreak +
    '      lWithRamTextSaveItemPtr := @RamTextSave[i];' + sLineBreak +
    '      begin' + sLineBreak +
    '      if StrCmpI(lWithRamTextSaveItemPtr^.Name^, n) = 0 then' + sLineBreak +
    '      begin' + sLineBreak +
    '        GetCGIHdl := i;' + sLineBreak +
    '        exit' + sLineBreak +
    '      end;' + sLineBreak +
    '    end;' + sLineBreak +
    '    end;', lStatement.ReplacementText);
  Assert.AreEqual(1161, lStatement.Edits[1].Range.StartLine);
  Assert.AreEqual(1168, lStatement.Edits[1].Range.EndLine);
  Assert.AreEqual(8, lStatement.Edits[1].Range.EndColumn);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbRamFilesReadTextPointerTemp;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'ramfiles.pas', 1049, 3, lStatement),
    'Expected maxTdb ramfiles ReadTextRam rt with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
  Assert.AreEqual('record-pointer-temp', lStatement.Temps[0].Strategy);
  Assert.AreEqual('lWithRamTextPtr', lStatement.Temps[0].TempName);
  Assert.AreEqual(2, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('  lWithRamTextPtr: ^TRamText;' + sLineBreak,
    lStatement.Edits[0].ReplacementText);
  Assert.AreEqual(1048, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1049, lStatement.Edits[1].Range.StartLine);
  Assert.AreEqual(1055, lStatement.Edits[1].Range.EndLine);
  Assert.AreEqual(6, lStatement.Edits[1].Range.EndColumn);
  Assert.AreEqual('  lWithRamTextPtr := @rt;' + sLineBreak +
    '  begin' + sLineBreak +
    '    l := lWithRamTextPtr^._FileSize;' + sLineBreak +
    '    X := lWithRamTextPtr^.Cont;' + sLineBreak +
    '    TL := nil;' + sLineBreak +
    '    s := '''';' + sLineBreak +
    '  end;', lStatement.ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbRamFilesRestoreSaveItemSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'ramfiles.pas', 1116, 5, lStatement),
    'Expected maxTdb ramfiles RamTextSave[1 + i] with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbRamFilesFindStringPointerTemp;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'ramfiles.pas', 1398, 3, lStatement),
    'Expected maxTdb ramfiles FindString_Ramtext rt with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
  Assert.AreEqual('record-pointer-temp', lStatement.Temps[0].Strategy);
  Assert.AreEqual('lWithRamTextPtr', lStatement.Temps[0].TempName);
  Assert.AreEqual('lWithRamTextPtr := @rt;', lStatement.Temps[0].InitializationText);
  Assert.AreEqual(2, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('  lWithRamTextPtr: ^TRamText;' + sLineBreak,
    lStatement.Edits[0].ReplacementText);
  Assert.AreEqual(1394, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(1394, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual(1398, lStatement.Edits[1].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[1].Range.StartColumn);
  Assert.AreEqual(1412, lStatement.Edits[1].Range.EndLine);
  Assert.AreEqual(8, lStatement.Edits[1].Range.EndColumn);
  Assert.AreEqual('  lWithRamTextPtr := @rt;' + sLineBreak +
    '  if p > lWithRamTextPtr^._FileSize then' + sLineBreak +
    '      FindString_Ramtext := 0' + sLineBreak +
    '    else' + sLineBreak +
    '    begin' + sLineBreak +
    '      v := lWithRamTextPtr^.Cont + (p - 1);' + sLineBreak +
    '      if m = 0 then' + sLineBreak +
    '        d := TDB_StrPos(v, b)' + sLineBreak +
    '      else' + sLineBreak +
    '        d := TDB_StrPosI(v, b);' + sLineBreak +
    '      if d = nil then' + sLineBreak +
    '        FindString_Ramtext := 0' + sLineBreak +
    '      else' + sLineBreak +
    '        FindString_Ramtext := d - rt.Cont + 1' + sLineBreak +
    '    end;', lStatement.ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbRamFilesCopyStringPointerTemp;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'ramfiles.pas', 1421, 5, lStatement),
    'Expected maxTdb ramfiles CopyString_Ramtext rt with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
  Assert.AreEqual('record-pointer-temp', lStatement.Temps[0].Strategy);
  Assert.AreEqual('lWithRamTextPtr', lStatement.Temps[0].TempName);
  Assert.AreEqual('lWithRamTextPtr := @rt;', lStatement.Temps[0].InitializationText);
  Assert.AreEqual(2, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('  lWithRamTextPtr: ^TRamText;' + sLineBreak,
    lStatement.Edits[0].ReplacementText);
  Assert.AreEqual(1418, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(1418, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual(1421, lStatement.Edits[1].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[1].Range.StartColumn);
  Assert.AreEqual(1433, lStatement.Edits[1].Range.EndLine);
  Assert.AreEqual(8, lStatement.Edits[1].Range.EndColumn);
  Assert.AreEqual('    begin' + sLineBreak +
    '      lWithRamTextPtr := @rt;' + sLineBreak +
    '      begin' + sLineBreak +
    '      if lWithRamTextPtr^._FileSize >= p then' + sLineBreak +
    '      begin' + sLineBreak +
    '        if p + n - 1 > lWithRamTextPtr^._FileSize then' + sLineBreak +
    '          n := lWithRamTextPtr^._FileSize - p + 1;' + sLineBreak +
    '        if n > 255 then' + sLineBreak +
    '          n := 255;' + sLineBreak +
    '        X := lWithRamTextPtr^.Cont + p - 1;' + sLineBreak +
    '        move(X^, Str[1], n);' + sLineBreak +
    '        Str[0] := AnsiChar(n)' + sLineBreak +
    '      end' + sLineBreak +
    '    end;' + sLineBreak +
    '    end;', lStatement.ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbRamFilesSetEnvSizeDirectQualification;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'ramfiles.pas', 1602, 3, lStatement),
    'Expected maxTdb ramfiles p_SetEnvSize RamTextSave[1], rt with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual(1602, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(1603, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(19, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  RamTextSave[1].rt._FileSize := n;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbRamFilesInitCgiVarsDirectQualification;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'ramfiles.pas', 1666, 3, lStatement),
    'Expected maxTdb ramfiles InitCGIVars RamTextSave[1], rt with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual(1666, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(1675, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(6, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  begin' + sLineBreak +
    '    RamTextSave[1].rt.hdl := 0;' + sLineBreak +
    '    RamTextSave[1].rt.State := _read;' + sLineBreak +
    '    RamTextSave[1].rt._CharPtr := 0;' + sLineBreak +
    '    RamTextSave[1].rt._FileSize := 4069;' + sLineBreak +
    '    RamTextSave[1].rt.Cont := addr(GetEnv_Buffer);' + sLineBreak +
    '    RamTextSave[1].rt.ActChar := RamTextSave[1].rt.Cont;' + sLineBreak +
    '    RamTextSave[1].Name := addr(s_environment);' + sLineBreak +
    '  end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbStrFuncsMaskedWordSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'strfuncs.pas', 806, 5, lStatement),
    'Expected maxTdb strfuncs Maske[1]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbStrFuncsAutoEntrySkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'strfuncs.pas', 830, 3, lStatement),
    'Expected maxTdb strfuncs DF[d]^, Ind with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbStrFuncsRelFileDirectQualification;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'strfuncs.pas', 1495, 3, lStatement),
    'Expected maxTdb strfuncs DF[RelFile]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual(1495, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(1500, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(6, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  begin' + sLineBreak +
    '    DF[RelFile]^.IndFiles[2]^.nn := DF[RelFile]^.FileSize;' + sLineBreak +
    '    if Modus and 4 = 4 then' + sLineBreak +
    '      DF[RelFile]^.FileSize := 0;' + sLineBreak +
    '  end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbStrFuncsIndexFileDirectQualification;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'strfuncs.pas', 1501, 3, lStatement),
    'Expected maxTdb strfuncs DF[IndexFile]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual(1501, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(1508, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(6, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  begin' + sLineBreak +
    '    if DF[IndexFile]^.HatAuto then' + sLineBreak +
    '      WriteNBytes(DF[IndexFile]^.f^, DF[IndexFile]^.FileOffset - 4, 4, DF[IndexFile]^.AutoNum, 0);' + sLineBreak +
    '    DF[IndexFile]^.IndFiles[1]^.nn := DF[IndexFile]^.FileSize;' + sLineBreak +
    '    if not WriteIndexFile then' + sLineBreak +
    '      DF[IndexFile]^.FileSize := -1;' + sLineBreak +
    '  end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbStrFuncsScanFieldMaskSkipReason;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'strfuncs.pas', 2003, 13, lStatement),
    'Expected maxTdb strfuncs DF[d]^.Maske[s_i]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbStrFuncsKeywordIndexFileSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'strfuncs.pas', 2717, 3, lStatement),
    'Expected maxTdb strfuncs DF[g_Index_File]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbStrFuncsArrayVarPointerTemp;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'strfuncs.pas', 2794, 3, lStatement),
    'Expected maxTdb strfuncs VarList[Vnr] with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
  Assert.AreEqual('record-pointer-temp', lStatement.Temps[0].Strategy);
  Assert.AreEqual('lWithEasyVarPtr', lStatement.Temps[0].TempName);
  Assert.AreEqual('lWithEasyVarPtr := @VarList[Vnr];', lStatement.Temps[0].InitializationText);
  Assert.AreEqual(2, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('  lWithEasyVarPtr: ^EasyVar;' + sLineBreak,
    lStatement.Edits[0].ReplacementText);
  Assert.AreEqual(2786, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(2786, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual(2794, lStatement.Edits[1].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[1].Range.StartColumn);
  Assert.AreEqual(2806, lStatement.Edits[1].Range.EndLine);
  Assert.AreEqual(6, lStatement.Edits[1].Range.EndColumn);
  Assert.AreEqual('  lWithEasyVarPtr := @VarList[Vnr];' + sLineBreak +
    '  begin' + sLineBreak +
    '    if TestFlags(lWithEasyVarPtr^.tFlags, TArray) then' + sLineBreak +
    '    begin' + sLineBreak +
    '      p := Pointer(lWithEasyVarPtr^.VarCont);' + sLineBreak +
    '      begin' + sLineBreak +
    '        q := Pointer(p^.Memory)' + sLineBreak +
    '      end' + sLineBreak +
    '    end' + sLineBreak +
    '    else' + sLineBreak +
    '      q := nil' + sLineBreak +
    '  end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[1].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbIndexUtilsFileSizeQualification;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB00.indexUtils.pas', 107, 3, lStatement),
    'Expected maxTdb indexUtils DoGetFileSize DF[D]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual(107, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(108, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(38, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  ReadNBytes(DF[D]^.f^, 0, 4, DF[D]^.FileSize, 0);',
    lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB00.indexUtils.pas', 113, 3, lStatement),
    'Expected maxTdb indexUtils DoPutFileSize DF[D]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual(113, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(114, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(39, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  WriteNBytes(DF[D]^.f^, 0, 4, DF[D]^.FileSize, 0);',
    lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbIndexUtilsNewIndSkipReason;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB00.indexUtils.pas', 195, 3, lStatement),
    'Expected maxTdb indexUtils NewInd D with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('selector-type-not-resolved', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbIndexUtilsNewIndNestedSkipReason;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB00.indexUtils.pas', 208, 5, lStatement),
    'Expected maxTdb indexUtils NewInd IndFiles[INr]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('selector-type-not-resolved', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbIndexUtilsGetIndPathSkipReason;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB00.indexUtils.pas', 223, 3, lStatement),
    'Expected maxTdb indexUtils GetIndPath DF[D]^, IndFiles[INr]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('receiver-member-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbIndexUtilsIvOkayReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB00.indexUtils.pas', 255, 3, lStatement),
    'Expected maxTdb indexUtils IV_okay DF[D]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
  Assert.AreEqual('record-pointer-temp', lStatement.Temps[0].Strategy);
  Assert.AreEqual('lWithIndexVektorItemPtr', lStatement.Temps[0].TempName);
  Assert.AreEqual('lWithIndexVektorItemPtr := @IV[I];',
    lStatement.Temps[0].InitializationText);
  Assert.AreEqual(2, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('  lWithIndexVektorItemPtr: ^TIndexVektorItem;' + sLineBreak,
    lStatement.Edits[0].ReplacementText);
  Assert.AreEqual(252, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(252, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual(255, lStatement.Edits[1].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[1].Range.StartColumn);
  Assert.AreEqual(278, lStatement.Edits[1].Range.EndLine);
  Assert.AreEqual(1, lStatement.Edits[1].Range.EndColumn);
  Assert.AreEqual('  BEGIN' + sLineBreak +
    '    Sum := 0;' + sLineBreak +
    '    IV_okay := FALSE;' + sLineBreak +
    '    FOR I := 1 TO cMaxIndex DO' + sLineBreak +
    '      begin' + sLineBreak +
    '        lWithIndexVektorItemPtr := @IV[I];' + sLineBreak +
    '        BEGIN' + sLineBreak +
    '        IF (lWithIndexVektorItemPtr^.Feld <> 0) AND (lWithIndexVektorItemPtr^.IV_Art = A_BLOB) AND (DF[D]^.Maske[lWithIndexVektorItemPtr^.Feld AND $7FFF].l >= 10)' + sLineBreak +
    '        THEN' + sLineBreak +
    '          lWithIndexVektorItemPtr^.IV_Art := A_STRING;' + sLineBreak +
    '        IF lWithIndexVektorItemPtr^.Feld = 0 THEN' + sLineBreak +
    '          GOTO Fertig' + sLineBreak +
    '        ELSE' + sLineBreak +
    '          IF (lWithIndexVektorItemPtr^.Feld <> $FFFF) AND (lWithIndexVektorItemPtr^.IV_Art <> 16 OR A_AUTO) AND' + sLineBreak +
    '          ((lWithIndexVektorItemPtr^.Feld AND $7FFF > DF[D]^.RecZahl) OR (DF[D]^.Maske[lWithIndexVektorItemPtr^.Feld AND $7FFF].Art AND 15 <> lWithIndexVektorItemPtr^.IV_Art))' + sLineBreak +
    '        THEN' + sLineBreak +
    '          EXIT' + sLineBreak +
    '        ELSE' + sLineBreak +
    '          INC(Sum, lWithIndexVektorItemPtr^.Anzahl);' + sLineBreak +
    '      END;' + sLineBreak +
    '      end;' + sLineBreak +
    '  Fertig:' + sLineBreak +
    '    IV_okay := (Sum > 0) AND (Sum <= 256)' + sLineBreak +
    '  END' + sLineBreak, lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[1].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbIndexUtilsRemoveIndexSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB00.indexUtils.pas', 298, 3, lStatement),
    'Expected maxTdb indexUtils RemoveIndex DF[D]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbIndexUtilsOpenIndexNestedIvQualification;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB00.indexUtils.pas', 365, 11, lStatement),
    'Expected maxTdb indexUtils Oeffne_Index IV[I] with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual(365, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(367, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(33, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('          begin' + sLineBreak +
    '            IF (IV[I].IV_Art = A_BLOB) AND (IV[I].Anzahl > 10) THEN' + sLineBreak +
    '              IV[I].IV_Art := A_STRING;' + sLineBreak +
    '          end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB00.indexUtils.pas', 368, 9, lStatement),
    'Expected maxTdb indexUtils Oeffne_Index IV[cMaxIndex] with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual(368, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(369, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(73, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('        IndFiles[IR]^.MustBeUnique := (IV[cMaxIndex].Feld = 0) AND (IV[cMaxIndex].Anzahl = 0) AND (IV[cMaxIndex].IV_Art = $FF);',
    lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbIndexUtilsAddNewTempIndexReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB00.indexUtils.pas', 422, 7, lStatement),
    'Expected maxTdb indexUtils Erzeuge_Index IndFiles[indiziert + 1]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual(422, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(432, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(10, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('      BEGIN' + sLineBreak +
    '        I := 1;' + sLineBreak +
    '        IndFiles[indiziert + 1]^.IV := t_IV;' + sLineBreak +
    '        IndFiles[indiziert + 1]^.MustBeUnique := FALSE;' + sLineBreak +
    '        FOR j := 1 TO DF[D]^.indiziert DO' + sLineBreak +
    '          IF TempInd(DF[D]^.IndFiles[j]^.IndexName) THEN' + sLineBreak +
    '            INC(I);' + sLineBreak +
    '        IF DF[D]^.V_Base = 0 THEN' + sLineBreak +
    '          IndFiles[indiziert + 1]^.IndexName[length(IndFiles[indiziert + 1]^.IndexName)] := ansiChar(48 + I);' + sLineBreak +
    '      END;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbIndexUtilsGenIndexSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB00.indexUtils.pas', 648, 5, lStatement),
    'Expected maxTdb indexUtils GenIndex g^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbIndexUtilsGetTreeParamReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB00.indexUtils.pas', 679, 3, lStatement),
    'Expected maxTdb indexUtils GetTreeParam DF[D]^, IndFiles[I]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual(679, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(697, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(19, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  IF CheckIndexOpen(D, I, FALSE) THEN' + sLineBreak +
    '    BEGIN' + sLineBreak +
    '            BEGIN' + sLineBreak +
    '        Str(DF[D]^.IndFiles[I]^.IndFile^.pagesize, tmp);' + sLineBreak +
    '        Result:= ''page='' + tmp;' + sLineBreak +
    '        Str(DF[D]^.IndFiles[I]^.IndFile^.MinKeysPerNode, tmp);' + sLineBreak +
    '        Result := Result + '', n='' + tmp;' + sLineBreak +
    '        Str(DF[D]^.IndFiles[I]^.IndFile^.Height, tmp);' + sLineBreak +
    '        Result := Result + '', h='' + tmp;' + sLineBreak +
    '        Str(DF[D]^.IndFiles[I]^.IndFile^.pages, tmp);' + sLineBreak +
    '        Result := Result + '', p='' + tmp;' + sLineBreak +
    '        Str(DF[D]^.IndFiles[I]^.nn, tmp);' + sLineBreak +
    '        Result := Result + '', nn='' + tmp;' + sLineBreak +
    '      END' + sLineBreak +
    '    END' + sLineBreak +
    '    ELSE' + sLineBreak +
    '      Result := '''';', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbIndexUtilsNewTreeUniqueReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB00.indexUtils.pas', 755, 7, lStatement),
    'Expected maxTdb indexUtils Oeffne_Index IV[cMaxIndex] with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual(755, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(760, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(10, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('      BEGIN' + sLineBreak +
    '        IV[cMaxIndex].Feld := 0;' + sLineBreak +
    '        IV[cMaxIndex].Anzahl := 0;' + sLineBreak +
    '        IV[cMaxIndex].IV_Art := $FF' + sLineBreak +
    '      END;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbIndexUtilsEqualIndexPointerTemp;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB00.indexUtils.pas', 936, 5, lStatement),
    'Expected maxTdb indexUtils Gleicher_Index IV[I] with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
  Assert.AreEqual('record-pointer-temp', lStatement.Temps[0].Strategy);
  Assert.AreEqual('lWithIndexVektorItemPtr', lStatement.Temps[0].TempName);
  Assert.AreEqual('lWithIndexVektorItemPtr := @IV[I];',
    lStatement.Temps[0].InitializationText);
  Assert.AreEqual(2, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('var' + sLineBreak +
    '  lWithIndexVektorItemPtr: ^TIndexVektorItem;' + sLineBreak,
    lStatement.Edits[0].ReplacementText);
  Assert.AreEqual(927, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(927, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual(936, lStatement.Edits[1].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[1].Range.StartColumn);
  Assert.AreEqual(948, lStatement.Edits[1].Range.EndLine);
  Assert.AreEqual(8, lStatement.Edits[1].Range.EndColumn);
  Assert.AreEqual('    begin' + sLineBreak +
    '      lWithIndexVektorItemPtr := @IV[I];' + sLineBreak +
    '      BEGIN' + sLineBreak +
    '      IF lWithIndexVektorItemPtr^.Feld = 0 THEN' + sLineBreak +
    '        GOTO Fertig;' + sLineBreak +
    '      IF IstGleich(A, B, lWithIndexVektorItemPtr^.Anzahl, lWithIndexVektorItemPtr^.IV_Art) = 0' + sLineBreak +
    '      THEN' + sLineBreak +
    '      BEGIN' + sLineBreak +
    '        INC(pByte(A), lWithIndexVektorItemPtr^.Anzahl);' + sLineBreak +
    '        INC(pByte(B), lWithIndexVektorItemPtr^.Anzahl);' + sLineBreak +
    '      end else begin' + sLineBreak +
    '        Exit(False);' + sLineBreak +
    '      END;' + sLineBreak +
    '    END;' + sLineBreak +
    '    end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[1].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbIndexUtilsNormIndFilesSkipCluster;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB00.indexUtils.pas', 1063, 3, lStatement),
    'Expected maxTdb indexUtils NormIndFiles D with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('selector-type-not-resolved', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB00.indexUtils.pas', 1067, 7, lStatement),
    'Expected maxTdb indexUtils NormIndFiles Maske[i]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('selector-type-not-resolved', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB00.indexUtils.pas', 1073, 13, lStatement),
    'Expected maxTdb indexUtils NormIndFiles IndFiles[Ind0]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('selector-type-not-resolved', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB00.indexUtils.pas', 1078, 15, lStatement),
    'Expected maxTdb indexUtils NormIndFiles IV[1] with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('selector-type-not-resolved', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB00.indexUtils.pas', 1090, 7, lStatement),
    'Expected maxTdb indexUtils NormIndFiles IndFiles[0]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('selector-type-not-resolved', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB00.indexUtils.pas', 1094, 9, lStatement),
    'Expected maxTdb indexUtils NormIndFiles auto IV[1] with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('selector-type-not-resolved', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB00.indexUtils.pas', 1101, 7, lStatement),
    'Expected maxTdb indexUtils NormIndFiles IndFiles[1]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('selector-type-not-resolved', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbIndexUtilsLoadIndexSkipReason;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB00.indexUtils.pas', 1117, 3, lStatement),
    'Expected maxTdb indexUtils LadeIndex DF[D]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('receiver-member-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbIndexUtilsPufferLeerenSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB00.indexUtils.pas', 1203, 5, lStatement),
    'Expected maxTdb indexUtils PufferLeeren DF[D]^, IndFiles[Nr]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbIndexUtilsIndFormelSkipCluster;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB00.indexUtils.pas', 1420, 3, lStatement),
    'Expected maxTdb indexUtils IndFormel DF[D]^, IndFiles[ID]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('receiver-member-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB00.indexUtils.pas', 1423, 7, lStatement),
    'Expected maxTdb indexUtils IndFormel IV[1] with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('receiver-member-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbIndexUtilsCountRecsIvReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB00.indexUtils.pas', 1698, 7, lStatement),
    'Expected maxTdb indexUtils CountRecs IV[I] with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual(1698, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(1707, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(10, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('      BEGIN' + sLineBreak +
    '        IF IV[I].Feld AND $7FFF = Nr THEN' + sLineBreak +
    '          GOTO Weiter' + sLineBreak +
    '        ELSE' + sLineBreak +
    '          IF IV[I].Feld = 0 THEN' + sLineBreak +
    '          EXIT' + sLineBreak +
    '        ELSE' + sLineBreak +
    '          INC(Sum, IV[I].Anzahl);' + sLineBreak +
    '      END;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbIndexUtilsPushPopFileReplacementRanges;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB00.indexUtils.pas', 2061, 3, lStatement),
    'Expected maxTdb indexUtils PushFile DF[D]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual(2061, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(2071, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  BEGIN' + sLineBreak +
    '    Push(DF[D]^.DateiZeiger, SizeOf(DF[D]^.DateiZeiger));' + sLineBreak +
    '    Push(DF[D]^.Dat^, DF[D]^.SatzGroesse);' + sLineBreak +
    '    Push(DF[D]^.Zugriff, SizeOf(DF[D]^.Zugriff));' + sLineBreak +
    '    Push(DF[D]^.AktIndex, SizeOf(DF[D]^.AktIndex));' + sLineBreak +
    '    Push(DF[D]^.LinkIndex, SizeOf(DF[D]^.LinkIndex));' + sLineBreak +
    '    Push(DF[D]^.LinkFile, SizeOf(DF[D]^.LinkFile));' + sLineBreak +
    '    Push(DF[D]^.Ind, SizeOf(DF[D]^.Ind));' + sLineBreak +
    '  END' + sLineBreak, lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB00.indexUtils.pas', 2077, 3, lStatement),
    'Expected maxTdb indexUtils PopFile DF[D]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual(2077, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(2087, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  BEGIN' + sLineBreak +
    '    Pop(DF[D]^.Ind, SizeOf(DF[D]^.Ind));' + sLineBreak +
    '    Pop(DF[D]^.LinkFile, SizeOf(DF[D]^.LinkFile));' + sLineBreak +
    '    Pop(DF[D]^.LinkIndex, SizeOf(DF[D]^.LinkIndex));' + sLineBreak +
    '    Pop(DF[D]^.AktIndex, SizeOf(DF[D]^.AktIndex));' + sLineBreak +
    '    Pop(DF[D]^.Zugriff, SizeOf(DF[D]^.Zugriff));' + sLineBreak +
    '    Pop(DF[D]^.Dat^, DF[D]^.SatzGroesse);' + sLineBreak +
    '    Pop(DF[D]^.DateiZeiger, SizeOf(DF[D]^.DateiZeiger));' + sLineBreak +
    '  END' + sLineBreak, lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb01InitCacheReplacementRange;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdb01.pas', 155, 3, lStatement),
    'Expected maxTdb tdb01 InitCache DF[d]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual(155, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(165, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  begin' + sLineBreak +
    '    DF[d]^.CacheSize := MIN(cMaxInt16 div DF[d]^.SatzGroesse, MaxCache);' + sLineBreak +
    '    for i := 1 to DF[d]^.CacheSize do' + sLineBreak +
    '    begin' + sLineBreak +
    '      DF[d]^.Cache[i]._n := 0;' + sLineBreak +
    '      GetMem(DF[d]^.Cache[i]._d, DF[d]^.SatzGroesse);' + sLineBreak +
    '    end;' + sLineBreak +
    '    DF[d]^.CacheInit := True;' + sLineBreak +
    '  end' + sLineBreak, lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb01ExitCacheReplacementRange;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdb01.pas', 171, 3, lStatement),
    'Expected maxTdb tdb01 ExitCache DF[d]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual(171, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(180, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  begin' + sLineBreak +
    '    if DF[d]^.CacheInit then' + sLineBreak +
    '      for i := 1 to DF[d]^.CacheSize do' + sLineBreak +
    '      begin' + sLineBreak +
    '        FreeMem(DF[d]^.Cache[i]._d, DF[d]^.SatzGroesse);' + sLineBreak +
    '      end;' + sLineBreak +
    '    DF[d]^.CacheInit := False;' + sLineBreak +
    '  end' + sLineBreak, lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb01OpenDbNameReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdb01.pas', 333, 9, lStatement),
    'Expected maxTdb tdb01 OpenDB DF[i]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual(333, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(340, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(12, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('        begin' + sLineBreak +
    '          if DF[i]^.Pfad + DF[i]^.DBName = GFName then' + sLineBreak +
    '          begin' + sLineBreak +
    '            okay := 35;' + sLineBreak +
    '            goto x_EXIT' + sLineBreak +
    '          end;' + sLineBreak +
    '        end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb01OpenDbOuterSkipReason;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdb01.pas', 343, 3, lStatement),
    'Expected maxTdb tdb01 OpenDB outer DF[d]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb01OpenDbMaskInitializationReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdb01.pas', 419, 7, lStatement),
    'Expected maxTdb tdb01 OpenDB Maske[i]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual(419, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(469, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(10, lStatement.Edits[0].Range.EndColumn);
  Assert.IsTrue(Pos('        Inc(DF[d]^.V_Nr, Ord(DF[d]^.Maske[i].ShowLabel));',
    lStatement.ReplacementText) > 0);
  Assert.IsTrue(Pos('              DF[d]^.HatAuto := True;',
    lStatement.ReplacementText) > 0);
  Assert.IsTrue(Pos('              if Maske[i]^.m <> '''' then',
    lStatement.ReplacementText) > 0);
  Assert.IsTrue(Pos('              if DF[d]^.SelList = nil then',
    lStatement.ReplacementText) > 0);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb01OpenDbMaskListReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdb01.pas', 473, 7, lStatement),
    'Expected maxTdb tdb01 OpenDB form-list Maske[i]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual(473, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(493, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(12, lStatement.Edits[0].Range.EndColumn);
  Assert.IsTrue(Pos('          if DF[d]^.FormList = nil then',
    lStatement.ReplacementText) > 0);
  Assert.IsTrue(Pos('            qf1 := DF[d]^.FormList;',
    lStatement.ReplacementText) > 0);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdb01.pas', 496, 7, lStatement),
    'Expected maxTdb tdb01 OpenDB range-list Maske[i]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual(496, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(516, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(12, lStatement.Edits[0].Range.EndColumn);
  Assert.IsTrue(Pos('          if DF[d]^.BerList = nil then',
    lStatement.ReplacementText) > 0);
  Assert.IsTrue(Pos('            qb1 := DF[d]^.BerList;',
    lStatement.ReplacementText) > 0);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb01FlushVTableReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdb01.pas', 656, 3, lStatement),
    'Expected maxTdb tdb01 FlushVTable DF[d]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual(656, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(668, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(8, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  if DF[d]^.Rights and 256 = 256 then' + sLineBreak +
    '    begin' + sLineBreak +
    '      io := abs(CopyLowFile(DF[d]^.f^, dir + DF[d]^.DBName));' + sLineBreak +
    '      for i := Ord(not DF[d]^.HatAuto) to DF[d]^.indiziert do' + sLineBreak +
    '        if CheckIndexOpen(d, i, False) then' + sLineBreak +
    '                    begin' + sLineBreak +
    '            io := io + abs(CopyLowFile(DF[d]^.IndFiles[i]^.IndFile^.FileHandle, dir + DF[d]^.IndFiles[i]^.IndexName));' + sLineBreak +
    '          end;' + sLineBreak +
    '      if DF[d]^.HatMemo then' + sLineBreak +
    '        io := io + abs(CopyLowFile(DF[d]^.Memo^, dir + F_Name(DF[d]^.DBName)^ + ''.mmo''));' + sLineBreak +
    '      if DF[d]^.HatBlob then' + sLineBreak +
    '        io := io + abs(CopyLowFile(DF[d]^.Blob^, dir + F_Name(DF[d]^.DBName)^ + ''.blb''));' + sLineBreak +
    '    end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoKeepsMaxTdbRelRecPlannedWithBodyAnalysisSubset;
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOptions: TDelphiSemanticApiOptions;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lRequest: TDelphiSemanticRemoveWithRequest;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr');

  lRequest := Default(TDelphiSemanticRemoveWithRequest);
  lRequest.Options := lOptions;
  lRequest.BodyAnalysisSourceFileNames := MaxTdbBodyAnalysisSourceFileNames;
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lRequest);
  lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdb01.pas', 801, 3, lStatement),
    'Expected maxTdb tdb01 h_FNr RelRec with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb01RelRecPointerTemp;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdb01.pas', 801, 3, lStatement),
    'Expected maxTdb tdb01 h_FNr RelRec with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
  Assert.AreEqual('record-pointer-temp', lStatement.Temps[0].Strategy);
  Assert.AreEqual('TRelRec', lStatement.Temps[0].ReceiverType);
  Assert.AreEqual('lWithRelRecPtr', lStatement.Temps[0].TempName);
  Assert.AreEqual('lWithRelRecPtr := @RelRec;',
    lStatement.Temps[0].InitializationText);
  Assert.AreEqual(2, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('declare-temp', lStatement.Edits[0].Kind);
  Assert.AreEqual(799, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(799, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  lWithRelRecPtr: ^TRelRec;' + sLineBreak,
    lStatement.Edits[0].ReplacementText);
  Assert.AreEqual('replace-statement', lStatement.Edits[1].Kind);
  Assert.AreEqual(801, lStatement.Edits[1].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[1].Range.StartColumn);
  Assert.AreEqual(818, lStatement.Edits[1].Range.EndLine);
  Assert.AreEqual(4, lStatement.Edits[1].Range.EndColumn);
  Assert.IsTrue(Pos('  lWithRelRecPtr := @RelRec;', lStatement.ReplacementText) > 0);
  Assert.IsTrue(Pos('        exit(lWithRelRecPtr^.n + 1)', lStatement.ReplacementText) > 0);
  Assert.IsTrue(Pos('          if lWithRelRecPtr^.w[i].lf = d then',
    lStatement.ReplacementText) > 0);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[1].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb01RelRecNestedSelectorPointerTemp;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdb01.pas', 914, 3, lStatement),
    'Expected maxTdb tdb01 LiesSek RelRec, w[0] with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
  Assert.AreEqual('record-pointer-temp', lStatement.Temps[0].Strategy);
  Assert.AreEqual('TRelRec', lStatement.Temps[0].ReceiverType);
  Assert.AreEqual('lWithRelRecPtr', lStatement.Temps[0].TempName);
  Assert.AreEqual('lWithRelRecPtr := @RelRec;',
    lStatement.Temps[0].InitializationText);
  Assert.AreEqual(2, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('declare-temp', lStatement.Edits[0].Kind);
  Assert.AreEqual(882, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(882, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('var' + sLineBreak +
    '  lWithRelRecPtr: ^TRelRec;' + sLineBreak +
    '  lWithRelRecPtr1: ^TRelRec;' + sLineBreak,
    lStatement.Edits[0].ReplacementText);
  Assert.AreEqual('replace-statement', lStatement.Edits[1].Kind);
  Assert.AreEqual(914, lStatement.Edits[1].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[1].Range.StartColumn);
  Assert.AreEqual(920, lStatement.Edits[1].Range.EndLine);
  Assert.AreEqual(6, lStatement.Edits[1].Range.EndColumn);
  Assert.AreEqual('  lWithRelRecPtr := @RelRec;' + sLineBreak +
    '  begin' + sLineBreak +
    '    lWithRelRecPtr^.aktiv := True;' + sLineBreak +
    '    lWithRelRecPtr^.n := 0;' + sLineBreak +
    '    lWithRelRecPtr^.w[0].lf := d;' + sLineBreak +
    '    lWithRelRecPtr^.w[0].hh := True' + sLineBreak +
    '  end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[1].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb01LiesSekLinkFileReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdb01.pas', 929, 7, lStatement),
    'Expected maxTdb tdb01 LiesSek DF[i]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
  Assert.AreEqual('record-pointer-temp', lStatement.Temps[0].Strategy);
  Assert.AreEqual('TRelRec', lStatement.Temps[0].ReceiverType);
  Assert.AreEqual('lWithRelRecPtr1', lStatement.Temps[0].TempName);
  Assert.AreEqual('lWithRelRecPtr1 := @RelRec;',
    lStatement.Temps[0].InitializationText);
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(929, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(970, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(10, lStatement.Edits[0].Range.EndColumn);
  Assert.IsTrue(Pos('        if (DF[i]^.LinkFile = 0) or InSet(Gelesen, DF[i]^.LinkFile) then',
    lStatement.ReplacementText) > 0);
  Assert.IsTrue(Pos('          lWithRelRecPtr1 := @RelRec;',
    lStatement.ReplacementText) > 0);
  Assert.IsTrue(Pos('            lWithRelRecPtr1^.w[lWithRelRecPtr1^.n].lf := i;',
    lStatement.ReplacementText) > 0);
  Assert.IsTrue(Pos('              lWithRelRecPtr1^.w[lWithRelRecPtr1^.n].hh := NextRec(lWithRelRecPtr1^.n);',
    lStatement.ReplacementText) > 0);
  Assert.IsTrue(Pos('          Include(Files, DF[i]^.LinkFile);',
    lStatement.ReplacementText) > 0);
  Assert.IsTrue(Pos('            Include(Leaving, DF[i]^.LinkFile)',
    lStatement.ReplacementText) > 0);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb01LiesSekLocalInitPointerTemps;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdb01.pas', 986, 5, lStatement),
    'Expected maxTdb tdb01 LiesSek init RelRec, w[i] with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
  Assert.AreEqual('record-pointer-temp', lStatement.Temps[0].Strategy);
  Assert.AreEqual('TRelRec', lStatement.Temps[0].ReceiverType);
  Assert.AreEqual('lWithRelRecPtr', lStatement.Temps[0].TempName);
  Assert.AreEqual(2, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('declare-temp', lStatement.Edits[0].Kind);
  Assert.AreEqual(985, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual('var' + sLineBreak +
    '  lWithRelRecPtr: ^TRelRec;' + sLineBreak +
    '  lWithRelRecSubRecPtr: ^TRelRecSubRec;' + sLineBreak,
    lStatement.Edits[0].ReplacementText);
  Assert.AreEqual('replace-statement', lStatement.Edits[1].Kind);
  Assert.AreEqual(986, lStatement.Edits[1].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[1].Range.StartColumn);
  Assert.AreEqual(991, lStatement.Edits[1].Range.EndLine);
  Assert.AreEqual(10, lStatement.Edits[1].Range.EndColumn);
  Assert.AreEqual('    lWithRelRecPtr := @RelRec;' + sLineBreak +
    '    if ReadDat(lWithRelRecPtr^.w[i].lf) <> 0 then' + sLineBreak +
    '      begin' + sLineBreak +
    '        init := False;' + sLineBreak +
    '        exit' + sLineBreak +
    '      end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[1].ReplacementText);

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdb01.pas', 994, 7, lStatement),
    'Expected maxTdb tdb01 LiesSek init RelRec.w[i] with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
  Assert.AreEqual('record-pointer-temp', lStatement.Temps[0].Strategy);
  Assert.AreEqual('TRelRecSubRec', lStatement.Temps[0].ReceiverType);
  Assert.AreEqual('lWithRelRecSubRecPtr', lStatement.Temps[0].TempName);
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(994, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(1004, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(10, lStatement.Edits[0].Range.EndColumn);
  Assert.IsTrue(Pos('        lWithRelRecSubRecPtr := @RelRec.w[i];',
    lStatement.ReplacementText) > 0);
  Assert.IsTrue(Pos('        lWithRelRecSubRecPtr^.hh := ReadLinkRec(lWithRelRecSubRecPtr^.lf)',
    lStatement.ReplacementText) > 0);
  Assert.IsTrue(Pos('          Inc(i)', lStatement.ReplacementText) > 0);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb01LiesSekNextRecSkipReasons;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdb01.pas', 1015, 3, lStatement),
    'Expected maxTdb tdb01 LiesSek NextRec RelRec with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdb01.pas', 1017, 7, lStatement),
    'Expected maxTdb tdb01 LiesSek NextRec w[h] with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb01DeleteDbRelationReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdb01.pas', 1158, 9, lStatement),
    'Expected maxTdb tdb01 DeleteDB relation Maske[i]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(1158, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(1160, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(119, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('        begin' + sLineBreak +
    '          if Maske[i]^.Art and 15 = A_REL then' + sLineBreak +
    '            done := done and ((Base = 0) or IsRel(Base, Maske[i]^.m) or LoescheDatei(RelFileName(DF[FilesOffen]^.Pfad, Maske[i]^.m), S_Leer, 0, 0, False));' + sLineBreak +
    '        end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb01NextRecordSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdb01.pas', 1515, 3, lStatement),
    'Expected maxTdb tdb01 NaechsteRecNr DF[d]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb01TestRelRecReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdb01.pas', 1742, 3, lStatement),
    'Expected maxTdb tdb01 TestRelRec RelRec with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(1742, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(1753, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(6, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  begin' + sLineBreak +
    '    if FileNo > FilesOffen then' + sLineBreak +
    '      RelRec.aktiv := False;' + sLineBreak +
    '    if RelRec.aktiv then' + sLineBreak +
    '      for i := 1 to RelRec.n do' + sLineBreak +
    '        if RelRec.w[i].lf > FilesOffen then' + sLineBreak +
    '        begin' + sLineBreak +
    '          RelRec.aktiv := False;' + sLineBreak +
    '          exit' + sLineBreak +
    '        end' + sLineBreak +
    '  end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb01ChainAndFnMaxParity;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdb01.pas', 1862, 5, lStatement),
    'Expected maxTdb tdb01 GetChain DirektChain[i], DF[fd]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('receiver-member-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdb01.pas', 1909, 3, lStatement),
    'Expected maxTdb tdb01 FN_Max RelRec with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
  Assert.AreEqual('record-pointer-temp', lStatement.Temps[0].Strategy);
  Assert.AreEqual('TRelRec', lStatement.Temps[0].ReceiverType);
  Assert.AreEqual('lWithRelRecPtr', lStatement.Temps[0].TempName);
  Assert.AreEqual(2, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('declare-temp', lStatement.Edits[0].Kind);
  Assert.AreEqual(1907, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual('  lWithRelRecPtr: ^TRelRec;' + sLineBreak,
    lStatement.Edits[0].ReplacementText);
  Assert.AreEqual('replace-statement', lStatement.Edits[1].Kind);
  Assert.AreEqual(1909, lStatement.Edits[1].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[1].Range.StartColumn);
  Assert.AreEqual(1920, lStatement.Edits[1].Range.EndLine);
  Assert.AreEqual(4, lStatement.Edits[1].Range.EndColumn);
  Assert.AreEqual('  lWithRelRecPtr := @RelRec;' + sLineBreak +
    '  if lWithRelRecPtr^.aktiv then' + sLineBreak +
    '      for i := 0 to lWithRelRecPtr^.n do' + sLineBreak +
    '      begin' + sLineBreak +
    '        f := lWithRelRecPtr^.w[i].lf;' + sLineBreak +
    '        if InSet(Files, f) then' + sLineBreak +
    '        begin' + sLineBreak +
    '          FN_Max := f;' + sLineBreak +
    '          exit' + sLineBreak +
    '        end' + sLineBreak +
    '      end' + sLineBreak +
    'end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[1].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb01AutoLinkNumberSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdb01.pas', 2094, 3, lStatement),
    'Expected maxTdb tdb01 AutoLinkNummer DF[d]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb01EmptyReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdb01.pas', 2180, 5, lStatement),
    'Expected maxTdb tdb01 Empty DF[d]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(2180, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(2191, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(8, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('    begin' + sLineBreak +
    '      if (DF[d]^.FileSize = 0) or (DF[d]^.Zugriff = MarkZgr) and (AnzMarkiert(d) = 0) then' + sLineBreak +
    '        Empty := True' + sLineBreak +
    '      else if (DF[d]^.Zugriff = IndexZgr) and ((DF[d]^.F_Ind <> nil) or (DF[d]^.L_Ind <> nil)) then' + sLineBreak +
    '      begin' + sLineBreak +
    '        move(DF[d]^.Ind, ti, SizeOf(Index));' + sLineBreak +
    '        ErsteRecNr(d, True, fc);' + sLineBreak +
    '        move(ti, DF[d]^.Ind, SizeOf(Index));' + sLineBreak +
    '        Empty := fc <> 0' + sLineBreak +
    '      end' + sLineBreak +
    '    end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb01LinkFileNumberReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdb01.pas', 2277, 3, lStatement),
    'Expected maxTdb tdb01 LinkFileNumber DF[d]^.Maske[Nr]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(2277, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(2286, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  begin' + sLineBreak +
    '    t := NameExtrakt(DF[d]^.Maske[Nr]^.m)^;' + sLineBreak +
    sLineBreak +
    '    if t = ''@'' then' + sLineBreak +
    '      LinkFileNumber := d' + sLineBreak +
    '    else' + sLineBreak +
    '      LinkFileNumber := FileNumber(t);' + sLineBreak +
    '  end' + sLineBreak, lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb01CheckFilesSkipCluster;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdb01.pas', 2320, 7, lStatement),
    'Expected maxTdb tdb01 CheckFiles DF[i]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('receiver-member-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdb01.pas', 2323, 11, lStatement),
    'Expected maxTdb tdb01 CheckFiles Maske[j]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('receiver-member-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb02GetLinkInfoReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 1532, 3, lStatement),
    'Expected maxTdb TDB02 GetLinkInfo DF[DB]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(1532, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(1540, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  begin' + sLineBreak +
    '    if DF[DB]^.LinkFile <> 0 then' + sLineBreak +
    '    begin' + sLineBreak +
    '      Result := DF[DB]^.DBName + ''['' + IndDefStr(DB, DF[DB]^.LinkIndex, True, False)^ + '']'';' + sLineBreak +
    '      Result := Result + ''='' + DF[DF[DB]^.LinkFile]^.DBName + ''['' + GetIndexInfo(DF[DB]^.LinkFile, DF[DB]^.LinkIV, True, False)^ + '']''' + sLineBreak +
    '    end' + sLineBreak +
    '  end' + sLineBreak, lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb02GetNumValReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 1588, 3, lStatement),
    'Expected maxTdb TDB02 GetNumVal num_rec with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(1588, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(1607, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(10, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  if num_rec.ll = 0 then' + sLineBreak +
    '      Result := 0' + sLineBreak +
    '    else' + sLineBreak +
    '      case num_rec.n_id of' + sLineBreak +
    '        ''-'':' + sLineBreak +
    '          begin' + sLineBreak +
    '            t := copy(str255(s), 2, 255);' + sLineBreak +
    '            Result := GetNumVal(t, fc, -vz)' + sLineBreak +
    '          end;' + sLineBreak +
    '        ByteKonst:' + sLineBreak +
    '          Result := vz * num_rec.r_b;' + sLineBreak +
    '        WordKonst:' + sLineBreak +
    '          Result := vz * num_rec.r_w;' + sLineBreak +
    '        RealKonst:' + sLineBreak +
    '          Result := vz * num_rec.r_r;' + sLineBreak +
    '      else' + sLineBreak +
    '        Result := 0;' + sLineBreak +
    '        fc := 46' + sLineBreak +
    '      end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb02SkipReasons;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 2062, 13, lStatement),
    'Expected maxTdb TDB02 _reconvert DF[Ord(c)]^, Maske[n]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 2278, 3, lStatement),
    'Expected maxTdb TDB02 SplitVarStr SVR^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('selector-type-not-resolved', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb02InitDefReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 2313, 3, lStatement),
    'Expected maxTdb TDB02 InitDef SVR^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
  Assert.AreEqual('InitVar', lStatement.Temps[0].SelectorText);
  Assert.AreEqual('lWithVarInitRecPtr', lStatement.Temps[0].TempName);
  Assert.AreEqual('record-pointer-temp', lStatement.Temps[0].Strategy);
  Assert.AreEqual('VarInitRec', lStatement.Temps[0].ReceiverType);
  Assert.AreEqual('lWithVarInitRecPtr: ^VarInitRec;', lStatement.Temps[0].DeclarationText);
  Assert.AreEqual('lWithVarInitRecPtr := @InitVar;', lStatement.Temps[0].InitializationText);
  Assert.AreEqual(2, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('declare-temp', lStatement.Edits[0].Kind);
  Assert.AreEqual(2311, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(2311, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  lWithVarInitRecPtr: ^VarInitRec;' + sLineBreak,
    lStatement.Edits[0].ReplacementText);
  Assert.AreEqual('replace-statement', lStatement.Edits[1].Kind);
  Assert.AreEqual(2313, lStatement.Edits[1].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[1].Range.StartColumn);
  Assert.AreEqual(2335, lStatement.Edits[1].Range.EndLine);
  Assert.AreEqual(6, lStatement.Edits[1].Range.EndColumn);
  Assert.AreEqual('  begin' + sLineBreak +
    '    if SVR^.SVfc1 + SVR^.SVfc2 = 0 then' + sLineBreak +
    '    begin' + sLineBreak +
    '      if SVR^.Vnr = 0 then' + sLineBreak +
    '        begin' + sLineBreak +
    '          lWithVarInitRecPtr := @InitVar;' + sLineBreak +
    '          begin' + sLineBreak +
    '          lWithVarInitRecPtr^.V_Name := ADDR(SVR^.Name);' + sLineBreak +
    '          lWithVarInitRecPtr^.V_NewName := True;' + sLineBreak +
    '          lWithVarInitRecPtr^.V_Art := A_DEF;' + sLineBreak +
    '          lWithVarInitRecPtr^.V_StatFun := False;' + sLineBreak +
    '          lWithVarInitRecPtr^.V_vFiles := SVR^.vF;' + sLineBreak +
    '          lWithVarInitRecPtr^.V_IsRef := False;' + sLineBreak +
    '          lWithVarInitRecPtr^.V_ArrayVar := False;' + sLineBreak +
    '          SVR^.Vnr := NewVar;' + sLineBreak +
    '        end;' + sLineBreak +
    '        end;' + sLineBreak +
    '      SVR^.Vnr := KonvertVarNr(SVR^.Vnr);' + sLineBreak +
    '      Files := Files or SVR^.vF;' + sLineBreak +
    '      SVR^.SVfc1 := VarWert(SVR^.Vnr, A_DEF, SVR^.Expression, SVR^.SVfc1)' + sLineBreak +
    '    end;' + sLineBreak +
    '    InitDef := SVR^.Vnr;' + sLineBreak +
    '    Error := SVR^.SVfc1;' + sLineBreak +
    '  end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[1].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb02GetVarReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 2352, 3, lStatement),
    'Expected maxTdb TDB02 GetVar VarList[X].VarCont^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(2352, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(2405, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  begin' + sLineBreak +
    '    case VarList[X].VarCont^.Art of' + sLineBreak +
    '      A_DEF:' + sLineBreak +
    '        begin' + sLineBreak +
    '          n := 1;' + sLineBreak +
    '          tFun := Funktion;' + sLineBreak +
    '          Funktion := False;' + sLineBreak +
    '          GetVar := BERECHNE(VarList[X].VarCont^.S_Wert^, n, Test, v, t_Art, h);' + sLineBreak +
    '          Funktion := tFun;' + sLineBreak +
    '        end;' + sLineBreak +
    '      A_BROWSER,' + sLineBreak +
    '        A_REAL:' + sLineBreak +
    '        begin' + sLineBreak +
    '          t_Art := A_REAL;' + sLineBreak +
    '          h := 0;' + sLineBreak +
    '          double(v) := VarList[X].VarCont^.R_Wert' + sLineBreak +
    '        end;' + sLineBreak +
    '      A_STRING:' + sLineBreak +
    '        begin' + sLineBreak +
    '          t_Art := A_STRING;' + sLineBreak +
    '          h := 0;' + sLineBreak +
    '          if VarList[X].VarCont^.S_Wert = nil then' + sLineBreak +
    '            str255(v) := S_Leer' + sLineBreak +
    '          else' + sLineBreak +
    '            str255(v) := VarList[X].VarCont^.S_Wert^;' + sLineBreak +
    '        end;' + sLineBreak +
    '      A_Int16:' + sLineBreak +
    '        begin' + sLineBreak +
    '          t_Art := A_REAL;' + sLineBreak +
    '          h := 0;' + sLineBreak +
    '          double(v) := VarList[X].VarCont^.I_Wert' + sLineBreak +
    '        end;' + sLineBreak +
    '      A_BIT:' + sLineBreak +
    '        begin' + sLineBreak +
    '          t_Art := A_BIT;' + sLineBreak +
    '          h := 0;' + sLineBreak +
    '          Pointer(v) := VarList[X].VarCont^.S_Wert' + sLineBreak +
    '        end;' + sLineBreak +
    '      A_BYTE:' + sLineBreak +
    '        begin' + sLineBreak +
    '          t_Art := A_REAL;' + sLineBreak +
    '          h := 0;' + sLineBreak +
    '          double(v) := VarList[X].VarCont^.B_Wert' + sLineBreak +
    '        end;' + sLineBreak +
    '      A_CHAR:' + sLineBreak +
    '        begin' + sLineBreak +
    '          t_Art := A_STRING;' + sLineBreak +
    '          h := 0;' + sLineBreak +
    '          str255(v) := VarList[X].VarCont^.P_Wert' + sLineBreak +
    '        end;' + sLineBreak +
    '    end;' + sLineBreak +
    '  end' + sLineBreak, lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb02ToDbfReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 2430, 3, lStatement),
    'Expected maxTdb TDB02 ToDBF DF[c]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(2430, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(2433, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(6, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  begin' + sLineBreak +
    '    ToDBF := Dat2DBF02(DF[c]^.DBName, fn, {$IFDEF DLL}ProgressDefault, {$ENDIF}r2, r3 <> 0);' + sLineBreak +
    '  end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb02ArrayVarSkipReasons;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 2487, 3, lStatement),
    'Expected maxTdb TDB02 ExecArray ArrayVarRecPtr with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 2703, 3, lStatement),
    'Expected maxTdb TDB02 SortArrayVar_2 ArrayVarRecPtr with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb02ArrayVarBitReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 2755, 3, lStatement),
    'Expected maxTdb TDB02 DoMarkBits ArrayVarRecPtr with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(2755, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(2766, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(8, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  if ArrayVarRecPtr(VarList[Nr].VarCont)^.Art <> A_BIT then' + sLineBreak +
    '    begin' + sLineBreak +
    '      DoMarkBits := -52;' + sLineBreak +
    '      exit' + sLineBreak +
    '    end' + sLineBreak +
    '    else' + sLineBreak +
    '    begin' + sLineBreak +
    '      B1.MaxBytes := ArrayVarRecPtr(VarList[Nr].VarCont)^.ArrayVar.gsize;' + sLineBreak +
    '      B1.Cont := ArrayVarRecPtr(VarList[Nr].VarCont)^.Memory;' + sLineBreak +
    '      DoMarkBits := MarkBits(d, IndexFile, searchStr, EStr, Ops, RelFiles, Mask, B1);' + sLineBreak +
    '    end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 2771, 3, lStatement),
    'Expected maxTdb TDB02 GetBitArrayVar ArrayVarRecPtr with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(2771, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(2780, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(4, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  if ArrayVarRecPtr(VarList[Nr].VarCont)^.Art <> A_BIT then' + sLineBreak +
    '      GetBitArrayVar := 52' + sLineBreak +
    '    else' + sLineBreak +
    '    begin' + sLineBreak +
    '      b.MaxBytes := ArrayVarRecPtr(VarList[Nr].VarCont)^.ArrayVar.gsize;' + sLineBreak +
    '      b.Cont := ArrayVarRecPtr(VarList[Nr].VarCont)^.Memory;' + sLineBreak +
    '      GetBitArrayVar := 0' + sLineBreak +
    '    end' + sLineBreak +
    'end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb02BitArrayOpReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 2788, 3, lStatement),
    'Expected maxTdb TDB02 BitArrayOp first ArrayVarRecPtr with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 2811, 3, lStatement),
    'Expected maxTdb TDB02 BitArrayOp second ArrayVarRecPtr with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(2811, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(2821, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(8, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  if ArrayVarRecPtr(VarList[Nr2].VarCont)^.Art <> A_BIT then' + sLineBreak +
    '    begin' + sLineBreak +
    '      BitArrayOp := -52;' + sLineBreak +
    '      goto Error' + sLineBreak +
    '    end' + sLineBreak +
    '    else' + sLineBreak +
    '    begin' + sLineBreak +
    '      B2.MaxBytes := ArrayVarRecPtr(VarList[Nr2].VarCont)^.ArrayVar.gsize;' + sLineBreak +
    '      B2.Cont := ArrayVarRecPtr(VarList[Nr2].VarCont)^.Memory;' + sLineBreak +
    '    end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb02ReverseMarksReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 2839, 3, lStatement),
    'Expected maxTdb TDB02 ReverseMarks DF[d]^.MarkListe with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(2839, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(2860, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(6, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  begin' + sLineBreak +
    '    p := DF[d]^.MarkListe.Anfang;' + sLineBreak +
    '    t := nil;' + sLineBreak +
    '    n_a := nil;' + sLineBreak +
    '    n_e := nil;' + sLineBreak +
    '    while p <> nil do' + sLineBreak +
    '    begin' + sLineBreak +
    '      new(n_a);' + sLineBreak +
    '      n_a^ := p^;' + sLineBreak +
    '      if t = nil then' + sLineBreak +
    '        n_e := n_a;' + sLineBreak +
    '      n_a^.Rest := t;' + sLineBreak +
    '      t := n_a;' + sLineBreak +
    '      q := p;' + sLineBreak +
    '      p := p^.Rest;' + sLineBreak +
    '      dispose(q)' + sLineBreak +
    '    end;' + sLineBreak +
    '    DF[d]^.MarkListe.Anfang := n_a;' + sLineBreak +
    '    DF[d]^.MarkListe.Ende := n_e;' + sLineBreak +
    '    ReverseMarks := DF[d]^.MarkListe.AnzMarkiert' + sLineBreak +
    '  end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb02GetAutoReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 2866, 5, lStatement),
    'Expected maxTdb TDB02 GetAuto DF[d]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(2866, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(2876, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(3, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('    begin' + sLineBreak +
    '      begin' + sLineBreak +
    '        if ArrayVarRecPtr(VarList[Nr].VarCont)^.ArrayVar.gsize div SizeOf(Int32) < DF[d]^.FileSize + 1 then' + sLineBreak +
    '          GetAuto := -1' + sLineBreak +
    '        else' + sLineBreak +
    '          GetAuto := GetAutoNum(d, ArrayVarRecPtr(VarList[Nr].VarCont)^.Memory, i0)' + sLineBreak +
    '      end' + sLineBreak +
    '    end' + sLineBreak +
    '  ', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb02ArrayVarGetAutoSkipReasons;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 2883, 3, lStatement),
    'Expected maxTdb TDB02 PutAuto VarList[Nr].VarCont^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 2906, 3, lStatement),
    'Expected maxTdb TDB02 GetAuto VarList[Nr].VarCont^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 3026, 3, lStatement),
    'Expected maxTdb TDB02 Marks2Auto ArrayVarRecPtr with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb02MarksAndCompareArrayVarParity;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 3107, 3, lStatement),
    'Expected maxTdb TDB02 Marks2Auto ArrayVarRecPtr with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(3107, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(3120, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(4, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  if ArrayVarRecPtr(VarList[Nr].VarCont)^.Art <> A_Int16 then' + sLineBreak +
    '      Marks2Auto := -44' + sLineBreak +
    '    else if em then' + sLineBreak +
    '    begin' + sLineBreak +
    '      Max := ArrayVarRecPtr(VarList[Nr].VarCont)^.ArrayVar.gsize div SizeOf(Int32) - 1;' + sLineBreak +
    '      if dir then' + sLineBreak +
    '        Marks2Auto := GetMarksAuto(d, ArrayVarRecPtr(VarList[Nr].VarCont)^.Memory, Max, i0)' + sLineBreak +
    '      else' + sLineBreak +
    '        Marks2Auto := PutMarksAuto(d, ArrayVarRecPtr(VarList[Nr].VarCont)^.Memory, Max, i0)' + sLineBreak +
    '    end' + sLineBreak +
    '    else' + sLineBreak +
    '      Marks2Auto := 0' + sLineBreak +
    'end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 3128, 3, lStatement),
    'Expected maxTdb TDB02 Dat2Var ArrayVarRecPtr with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 3168, 3, lStatement),
    'Expected maxTdb TDB02 CompRec ArrayVarRecPtr with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(3168, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(3181, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(8, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  if not (ArrayVarRecPtr(VarList[Nr].VarCont)^.Art in [A_REAL, A_BYTE]) then' + sLineBreak +
    '      CompRec := -44' + sLineBreak +
    '    else if em then' + sLineBreak +
    '    begin' + sLineBreak +
    '      if (d = 0) or (d > FilesOffen) or (DF[d] = nil) then' + sLineBreak +
    '      begin' + sLineBreak +
    '        CompRec := -25;' + sLineBreak +
    '        exit' + sLineBreak +
    '      end;' + sLineBreak +
    '      m := MIN(ArrayVarRecPtr(VarList[Nr].VarCont)^.ArrayVar.gsize, DF[d]^.SatzGroesse);' + sLineBreak +
    '      CompRec := ByteArrayDiff(DF[d]^.Dat^, ArrayVarRecPtr(VarList[Nr].VarCont)^.Memory^, m);' + sLineBreak +
    '      exit' + sLineBreak +
    '    end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb02InArrayAndMarksReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 3342, 3, lStatement),
    'Expected maxTdb TDB02 InArray ArrayVarRecPtr with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(3342, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(3370, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(8, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  if ArrayVarRecPtr(VarList[Nr].VarCont)^.Art = A_REAL then' + sLineBreak +
    '    begin' + sLineBreak +
    '      r := ArrayVarRecPtr(VarList[Nr].VarCont)^.Memory;' + sLineBreak +
    '      for i := 0 to ArrayVarRecPtr(VarList[Nr].VarCont)^.ArrayVar.gsize div SizeOf(double) do' + sLineBreak +
    '        if Round(r^) = n then' + sLineBreak +
    '        begin' + sLineBreak +
    '          InArray := True;' + sLineBreak +
    '          exit' + sLineBreak +
    '        end' + sLineBreak +
    '        else if r^ = 0.0 then' + sLineBreak +
    '          exit' + sLineBreak +
    '        else' + sLineBreak +
    '          Inc(pByte(r), SizeOf(r^));' + sLineBreak +
    '    end' + sLineBreak +
    '    else if ArrayVarRecPtr(VarList[Nr].VarCont)^.Art = A_Int16 then' + sLineBreak +
    '    begin' + sLineBreak +
    '      IP := ArrayVarRecPtr(VarList[Nr].VarCont)^.Memory;' + sLineBreak +
    '      for i := 0 to ArrayVarRecPtr(VarList[Nr].VarCont)^.ArrayVar.gsize div SizeOf(Int32) do' + sLineBreak +
    '        if IP^ = n then' + sLineBreak +
    '        begin' + sLineBreak +
    '          InArray := True;' + sLineBreak +
    '          exit' + sLineBreak +
    '        end' + sLineBreak +
    '        else if IP^ = 0 then' + sLineBreak +
    '          exit' + sLineBreak +
    '        else' + sLineBreak +
    '          Inc(pByte(IP), SizeOf(IP^));' + sLineBreak +
    '    end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 3380, 3, lStatement),
    'Expected maxTdb TDB02 InArrayPos ArrayVarRecPtr with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(3380, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(3404, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(8, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  if ArrayVarRecPtr(VarList[Nr].VarCont)^.Art = A_REAL then' + sLineBreak +
    '    begin' + sLineBreak +
    '      r := ArrayVarRecPtr(VarList[Nr].VarCont)^.Memory;' + sLineBreak +
    '      for i := 0 to ArrayVarRecPtr(VarList[Nr].VarCont)^.ArrayVar.gsize div SizeOf(double) do' + sLineBreak +
    '        if Round(r^) = n then' + sLineBreak +
    '        begin' + sLineBreak +
    '          InArrayPos := i;' + sLineBreak +
    '          exit' + sLineBreak +
    '        end' + sLineBreak +
    '        else' + sLineBreak +
    '          Inc(pByte(r), SizeOf(r^));' + sLineBreak +
    '    end' + sLineBreak +
    '    else if ArrayVarRecPtr(VarList[Nr].VarCont)^.Art = A_Int16 then' + sLineBreak +
    '    begin' + sLineBreak +
    '      IP := ArrayVarRecPtr(VarList[Nr].VarCont)^.Memory;' + sLineBreak +
    '      for i := 0 to ArrayVarRecPtr(VarList[Nr].VarCont)^.ArrayVar.gsize div SizeOf(Int32) do' + sLineBreak +
    '        if IP^ = n then' + sLineBreak +
    '        begin' + sLineBreak +
    '          InArrayPos := i;' + sLineBreak +
    '          exit' + sLineBreak +
    '        end' + sLineBreak +
    '        else' + sLineBreak +
    '          Inc(pByte(IP), SizeOf(IP^));' + sLineBreak +
    '    end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 3412, 3, lStatement),
    'Expected maxTdb TDB02 andmarks ArrayVarRecPtr with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(3412, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(3449, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(8, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  if ArrayVarRecPtr(VarList[Nr].VarCont)^.Art <> A_REAL then' + sLineBreak +
    '      andmarks := 44' + sLineBreak +
    '    else if em then' + sLineBreak +
    '    begin' + sLineBreak +
    '      if (d = 0) or (d > FilesOffen) or (DF[d] = nil) then' + sLineBreak +
    '      begin' + sLineBreak +
    '        andmarks := 25;' + sLineBreak +
    '        exit' + sLineBreak +
    '      end;' + sLineBreak +
    '      p := DF[d]^.MarkListe.Anfang;' + sLineBreak +
    '      q := nil;' + sLineBreak +
    '      while p <> nil do' + sLineBreak +
    '      begin' + sLineBreak +
    '        if not InArray(p^.DV, Nr) then' + sLineBreak +
    '        begin' + sLineBreak +
    '          if q = nil then' + sLineBreak +
    '          begin' + sLineBreak +
    '            DF[d]^.MarkListe.Anfang := p^.Rest;' + sLineBreak +
    '            dispose(p);' + sLineBreak +
    '            p := DF[d]^.MarkListe.Anfang' + sLineBreak +
    '          end' + sLineBreak +
    '          else' + sLineBreak +
    '          begin' + sLineBreak +
    '            q^.Rest := p^.Rest;' + sLineBreak +
    '            dispose(p);' + sLineBreak +
    '            p := q^.Rest' + sLineBreak +
    '          end;' + sLineBreak +
    '          Dec(DF[d]^.MarkListe.AnzMarkiert);' + sLineBreak +
    '        end' + sLineBreak +
    '        else' + sLineBreak +
    '        begin' + sLineBreak +
    '          q := p;' + sLineBreak +
    '          p := p^.Rest' + sLineBreak +
    '        end' + sLineBreak +
    '      end;' + sLineBreak +
    '      DF[d]^.MarkListe.Ende := q;' + sLineBreak +
    '    end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb02FilterAndSetMarksParity;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 3470, 7, lStatement),
    'Expected maxTdb TDB02 setfilter DF[d]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(3470, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(3480, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(5, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('      begin' + sLineBreak +
    '        DF[d]^.DateiZeiger := ErsteRecNr(d, True, fc);' + sLineBreak +
    '        while fc = 0 do' + sLineBreak +
    '        begin' + sLineBreak +
    '          markiere(d, DF[d]^.DateiZeiger);' + sLineBreak +
    '          DF[d]^.DateiZeiger := NaechsteRecNr(d, True, fc)' + sLineBreak +
    '        end;' + sLineBreak +
    '        setfilter := DF[d]^.MarkListe.AnzMarkiert' + sLineBreak +
    '      end' + sLineBreak +
    '    ', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 3491, 3, lStatement),
    'Expected maxTdb TDB02 NotMarks ArrayVarRecPtr with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 3521, 3, lStatement),
    'Expected maxTdb TDB02 setmarks DF[d]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(3521, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(3527, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  begin' + sLineBreak +
    '    for i := 1 to DF[d]^.FileSize do' + sLineBreak +
    '      markiere(d, i);' + sLineBreak +
    '    setmarks := DF[d]^.FileSize' + sLineBreak +
    '  end' + sLineBreak, lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb02GetArrayVarReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 3751, 5, lStatement),
    'Expected maxTdb TDB02 GetArrayVar WorkArray^, ArrayVar with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(3751, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(3770, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(8, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('    begin' + sLineBreak +
    '      os := 0;' + sLineBreak +
    '      f := 1;' + sLineBreak +
    '      for j := WorkArray^.ArrayVar.d0 downto 1 do' + sLineBreak +
    '      begin' + sLineBreak +
    '        os := os + i[j] * f;' + sLineBreak +
    '        f := f * (WorkArray^.ArrayVar.i0[j] + 1)' + sLineBreak +
    '      end;' + sLineBreak +
    '      Size := os * WorkArray^.ArrayVar.ssize;' + sLineBreak +
    '      if em then' + sLineBreak +
    '        if (Size < 0) or (Size > WorkArray^.ArrayVar.gsize - WorkArray^.ArrayVar.ssize) then' + sLineBreak +
    '          fc := 81' + sLineBreak +
    '        else' + sLineBreak +
    '        begin' + sLineBreak +
    '          Inc(pByte(GetArrayPtr), Size);' + sLineBreak +
    '          GetArrayFree := WorkArray^.ArrayVar.gsize - Size;' + sLineBreak +
    '          GetArrayOffset := Size' + sLineBreak +
    '        end;' + sLineBreak +
    '    end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb02JobListSkipReason;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 4122, 11, lStatement),
    'Expected maxTdb TDB02 JobListe[n]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('receiver-member-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb02BitArraySumSkipReason;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 5902, 19, lStatement),
    'Expected maxTdb TDB02 BitArraySum ArrayVarRecPtr with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb02ArrayVarSizeReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 6022, 23, lStatement),
    'Expected maxTdb TDB02 ArrayVar size with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(6022, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(6027, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(19, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('                      begin' + sLineBreak +
    '                        if ArrayVarRecPtr(VarList[h1].VarCont)^.ArrayVar.gsize < d^.SatzGroesse then' + sLineBreak +
    '                          fc := 81' + sLineBreak +
    '                      end' + sLineBreak +
    '                  ;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb02VarContCaseReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 7551, 21, lStatement),
    'Expected maxTdb TDB02 VarList[h1].VarCont^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(7551, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(7559, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(26, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('                    case VarList[h1].VarCont^.Art of' + sLineBreak +
    '                        A_REAL:' + sLineBreak +
    '                          VarList[h1].VarCont^.R_Wert := ii;' + sLineBreak +
    '                        A_Int16:' + sLineBreak +
    '                          VarList[h1].VarCont^.I_Wert := ii;' + sLineBreak +
    '                      else' + sLineBreak +
    '                        fc := 44' + sLineBreak +
    '                      end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb02CheckSelStrSkips;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 7892, 5, lStatement),
    'Expected maxTdb TDB02 CheckSelStr DF[d]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('receiver-member-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 7897, 9, lStatement),
    'Expected maxTdb TDB02 CheckSelStr Maske[n]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('receiver-member-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb02SetByteSkipReasons;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 8046, 11, lStatement),
    'Expected maxTdb TDB02 SetByte ResWords[m] with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 8101, 7, lStatement),
    'Expected maxTdb TDB02 SetByte VarList[NormVarNr(n)] with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb02FindDirektReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 8286, 7, lStatement),
    'Expected maxTdb TDB02 FindDirekt DF[f1]^.Maske[N1]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(2, Integer(Length(lStatement.Edits)));

  Assert.AreEqual('declare-temp', lStatement.Edits[0].Kind);
  Assert.AreEqual(8229, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(8229, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  lWithDirektChainItemPtr: ^TDirektChainItem;' + sLineBreak,
    lStatement.Edits[0].ReplacementText);

  Assert.AreEqual('replace-statement', lStatement.Edits[1].Kind);
  Assert.AreEqual(8286, lStatement.Edits[1].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[1].Range.StartColumn);
  Assert.AreEqual(8311, lStatement.Edits[1].Range.EndLine);
  Assert.AreEqual(12, lStatement.Edits[1].Range.EndColumn);
  Assert.AreEqual('      case DF[f1]^.Maske[N1]^.Art and 15 of' + sLineBreak +
    '          A_LONG:' + sLineBreak +
    '            if p < length(t_Str) then' + sLineBreak +
    '            begin' + sLineBreak +
    '              f2 := DF[f1]^.Maske[N1]^.L_File;' + sLineBreak +
    '              if f2 = 0 then' + sLineBreak +
    '                exit' + sLineBreak +
    '            end;' + sLineBreak +
    '          A_REL:' + sLineBreak +
    '            begin' + sLineBreak +
    '              if a > 0 then' + sLineBreak +
    '                exit;' + sLineBreak +
    '              f1 := DF[f1]^.Maske[N1]^.L_File;' + sLineBreak +
    '              if DF[f1]^.Maske[N1]^.L_Ind = 1 then' + sLineBreak +
    '                N1 := 2' + sLineBreak +
    '              else' + sLineBreak +
    '                N1 := 1;' + sLineBreak +
    '              f2 := DF[f1]^.Maske[N1]^.R_File;' + sLineBreak +
    '              if f1 * f2 = 0 then' + sLineBreak +
    '                exit;' + sLineBreak +
    '            end;' + sLineBreak +
    '        else' + sLineBreak +
    '          if p < length(t_Str) then' + sLineBreak +
    '            exit' + sLineBreak +
    '        end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[1].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbDtoPrimaryPlanCountParity;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'DBFUTIL.pas', 942, 5, lStatement),
    'Expected maxTdb DBFUTIL NewDATFile D^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 2411, 5, lStatement),
    'Expected maxTdb TDB02 DirektAutoNum DF[aDb]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual(2411, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(2425, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(10, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('    begin' + sLineBreak +
    '      if DF[aDb]^.HatAuto then' + sLineBreak +
    '      begin' + sLineBreak +
    '        {$IFDEF NET}SetFlag(c, F_Auto, True, False);' + sLineBreak +
    '        {$ENDIF}' + sLineBreak +
    '        ReadNBytes(DF[aDb]^.f^, DF[aDb]^.FileOffset - 4, 4, DF[aDb]^.AutoNum, 0);' + sLineBreak +
    '        if aNewValue <> 0 then' + sLineBreak +
    '        begin' + sLineBreak +
    '          DF[aDb]^.AutoNum := aNewValue;' + sLineBreak +
    '          WriteNBytes(DF[aDb]^.f^, DF[aDb]^.FileOffset - 4, 4, DF[aDb]^.AutoNum, 0);' + sLineBreak +
    '        end;' + sLineBreak +
    '        Result:= DF[aDb]^.AutoNum;' + sLineBreak +
    '        {$IFDEF NET}SetFlag(c, F_Auto, False, False);' + sLineBreak +
    '        {$ENDIF}' + sLineBreak +
    '      end;' + sLineBreak +
    '    end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 4347, 9, lStatement),
    'Expected maxTdb TDB02 SetIndOp DF[c]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 8109, 11, lStatement),
    'Expected maxTdb TDB02 SetByte nested VarCont^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 8332, 5, lStatement),
    'Expected maxTdb TDB02 FindDirekt DirektChain[0] with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 8339, 9, lStatement),
    'Expected maxTdb TDB02 FindDirekt DirektChain[i] with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdbvars.pas', 592, 5, lStatement),
    'Expected maxTdb tdbvars PutLokalVar pl^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB00.indexUtils.pas', 1587, 11,
    lStatement), 'Expected maxTdb TDB00.indexUtils Maske[Feld AND $7FFF]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb02CheckExpressionInitVarReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 8478, 21, lStatement),
    'Expected maxTdb TDB02 CheckExpression InitVar with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
  Assert.AreEqual('InitVar', lStatement.Temps[0].SelectorText);
  Assert.AreEqual('record-pointer-temp', lStatement.Temps[0].Strategy);
  Assert.AreEqual('VarInitRec', lStatement.Temps[0].ReceiverType);
  Assert.AreEqual('lWithVarInitRecPtr', lStatement.Temps[0].TempName);
  Assert.AreEqual('lWithVarInitRecPtr: ^VarInitRec;', lStatement.Temps[0].DeclarationText);
  Assert.AreEqual('lWithVarInitRecPtr := @InitVar;', lStatement.Temps[0].InitializationText);
  Assert.AreEqual('lWithVarInitRecPtr^', lStatement.Temps[0].QualifierText);
  Assert.AreEqual('record-pointer-preserves-alias', lStatement.Temps[0].Reason);
  Assert.AreEqual(2, Integer(Length(lStatement.Edits)));

  Assert.AreEqual('declare-temp', lStatement.Edits[0].Kind);
  Assert.AreEqual(7926, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(7926, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('var' + sLineBreak +
    '  lWithVarInitRecPtr: ^VarInitRec;' + sLineBreak, lStatement.Edits[0].ReplacementText);

  Assert.AreEqual('replace-statement', lStatement.Edits[1].Kind);
  Assert.AreEqual(8478, lStatement.Edits[1].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[1].Range.StartColumn);
  Assert.AreEqual(8488, lStatement.Edits[1].Range.EndLine);
  Assert.AreEqual(24, lStatement.Edits[1].Range.EndColumn);
  Assert.AreEqual('                    begin' + sLineBreak +
    '                      lWithVarInitRecPtr := @InitVar;' + sLineBreak +
    '                      begin' + sLineBreak +
    '                      lWithVarInitRecPtr^.V_Name := ADDR(t_Str);' + sLineBreak +
    '                      lWithVarInitRecPtr^.V_NewName := True;' + sLineBreak +
    '                      lWithVarInitRecPtr^.V_IsRef := False;' + sLineBreak +
    '                      lWithVarInitRecPtr^.V_ArrayVar := False;' + sLineBreak +
    '                      lWithVarInitRecPtr^.V_StatFun := True;' + sLineBreak +
    '                      lWithVarInitRecPtr^.V_vFiles := tFiles;' + sLineBreak +
    '                      lWithVarInitRecPtr^.V_Art := A_REAL;' + sLineBreak +
    '                      n := KonvertVarNr(NewVar);' + sLineBreak +
    '                    end;' + sLineBreak +
    '                    end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[1].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb02SummenSkipReasons;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 8969, 7, lStatement),
    'Expected maxTdb TDB02 ClearSummen VarList[i].VarCont^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 8996, 7, lStatement),
    'Expected maxTdb TDB02 CheckSummen VarList[i].VarCont^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb02MemoLastRecordReplacements;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 9267, 17, lStatement),
    'Expected maxTdb TDB02 BERECHNE LastMBRec memo with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
  Assert.AreEqual('LastMBRec', lStatement.Temps[0].SelectorText);
  Assert.AreEqual('record-pointer-temp', lStatement.Temps[0].Strategy);
  Assert.AreEqual('MBRec', lStatement.Temps[0].ReceiverType);
  Assert.AreEqual('lWithMBRecPtr', lStatement.Temps[0].TempName);
  Assert.AreEqual('lWithMBRecPtr := @LastMBRec;', lStatement.Temps[0].InitializationText);
  Assert.AreEqual(2, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('declare-temp', lStatement.Edits[0].Kind);
  Assert.AreEqual(9163, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual('var' + sLineBreak +
    '  lWithMBRecPtr: ^MBRec;' + sLineBreak +
    '  lWithMBRecPtr1: ^MBRec;' + sLineBreak, lStatement.Edits[0].ReplacementText);
  Assert.AreEqual('replace-statement', lStatement.Edits[1].Kind);
  Assert.AreEqual(9267, lStatement.Edits[1].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[1].Range.StartColumn);
  Assert.AreEqual(9268, lStatement.Edits[1].Range.EndLine);
  Assert.AreEqual(38, lStatement.Edits[1].Range.EndColumn);
  Assert.AreEqual('                lWithMBRecPtr := @LastMBRec;' + sLineBreak +
    '                Memo2TL(lWithMBRecPtr^.d, lWithMBRecPtr^.MNr, TL);',
    lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[1].ReplacementText);

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 9375, 15, lStatement),
    'Expected maxTdb TDB02 BERECHNE second LastMBRec memo with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
  Assert.AreEqual('LastMBRec', lStatement.Temps[0].SelectorText);
  Assert.AreEqual('record-pointer-temp', lStatement.Temps[0].Strategy);
  Assert.AreEqual('MBRec', lStatement.Temps[0].ReceiverType);
  Assert.AreEqual('lWithMBRecPtr1', lStatement.Temps[0].TempName);
  Assert.AreEqual('lWithMBRecPtr1 := @LastMBRec;', lStatement.Temps[0].InitializationText);
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(9375, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(9376, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(36, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('              lWithMBRecPtr1 := @LastMBRec;' + sLineBreak +
    '              Memo2TL(lWithMBRecPtr1^.d, lWithMBRecPtr1^.MNr, TL);',
    lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb02KonvertVarNrReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB02.pas', 9659, 5, lStatement),
    'Expected maxTdb TDB02 KonvertVarNr VarList[VN].VarCont^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(9659, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(9663, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(13, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('    AppendLokalParameter(ActProcNr, VarList[VN].VarCont^.Name^, ' +
    'VarList[VN].VarCont^.Art, VarList[VN].VarCont^.V_Files, False, False, ar)' + sLineBreak +
    '  end' + sLineBreak +
    '  else' + sLineBreak +
    '    nn := VN;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb06WriteFailedReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB06.pas', 120, 5, lStatement),
    'Expected maxTdb TDB06 WriteFailed D with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
  Assert.AreEqual('D', lStatement.Temps[0].SelectorText);
  Assert.AreEqual('record-pointer-temp', lStatement.Temps[0].Strategy);
  Assert.AreEqual('DatFile', lStatement.Temps[0].ReceiverType);
  Assert.AreEqual('lWithDatFilePtr', lStatement.Temps[0].TempName);
  Assert.AreEqual('lWithDatFilePtr := @D;', lStatement.Temps[0].InitializationText);
  Assert.AreEqual(2, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('declare-temp', lStatement.Edits[0].Kind);
  Assert.AreEqual(119, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual('var' + sLineBreak +
    '  lWithDatFilePtr: ^DatFile;' + sLineBreak, lStatement.Edits[0].ReplacementText);
  Assert.AreEqual('replace-statement', lStatement.Edits[1].Kind);
  Assert.AreEqual(120, lStatement.Edits[1].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[1].Range.StartColumn);
  Assert.AreEqual(126, lStatement.Edits[1].Range.EndLine);
  Assert.AreEqual(3, lStatement.Edits[1].Range.EndColumn);
  Assert.AreEqual('    lWithDatFilePtr := @D;' + sLineBreak +
    '    BEGIN' + #10 +
    '      WriteNBytes(lWithDatFilePtr^.f^, lWithDatFilePtr^.FileOffset, n, V, 0);' + #10 +
    '      INC(lWithDatFilePtr^.FileOffset, n);' + #10 +
    '      WriteFailed := IO_Error <> 0' + #10 +
    '    END' + #10 +
    '  ', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[1].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb06MaskeNormalizationReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB06.pas', 156, 7, lStatement),
    'Expected maxTdb TDB06 Maske[i]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(2, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('declare-temp', lStatement.Edits[0].Kind);
  Assert.AreEqual(118, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(118, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  lWithDatFilePtr: ^DatFile;' + sLineBreak, lStatement.Edits[0].ReplacementText);
  Assert.AreEqual('replace-statement', lStatement.Edits[1].Kind);
  Assert.AreEqual(156, lStatement.Edits[1].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[1].Range.StartColumn);
  Assert.AreEqual(173, lStatement.Edits[1].Range.EndLine);
  Assert.AreEqual(10, lStatement.Edits[1].Range.EndColumn);
  Assert.AreEqual('      BEGIN' + #10 +
    '        CASE Maske[i]^.Art AND 15 OF' + #10 +
    '          A_LONG:' + #10 +
    '            IF Maske[i]^.sl <> 0 THEN' + #10 +
    '              Maske[i]^.sl := Maske[i]^.sl AND 15;' + #10 +
    '          A_REL:' + #10 +
    '            IF Maske[i]^.sl = 0 THEN' + #10 +
    '            BEGIN' + #10 +
    '              Maske[i]^.l := 0;' + #10 +
    '              IF DoExport THEN' + #10 +
    '                Maske[i]^.Art := 0' + #10 +
    '            END;' + #10 +
    '          A_AUTO:' + #10 +
    '            IF Maske[i]^.sl <> 0 THEN' + #10 +
    '              D.A_Nr := i;' + #10 +
    '        END;' + #10 +
    '      END;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[1].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb06ExportListReplacements;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB06.pas', 185, 7, lStatement),
    'Expected maxTdb TDB06 export SelList with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual(185, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(190, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(10, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('      BEGIN' + #10 +
    '        IF WriteFailed(p^.Sel.M_Az * SizeOf(SelektString), p^.Sel.Menu^) THEN' + #10 +
    '          GOTO EXCEPTION;' + #10 +
    '        p := p^.n;' + #10 +
    '      END;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB06.pas', 193, 7, lStatement),
    'Expected maxTdb TDB06 export FormList with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual(193, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(198, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(10, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('      BEGIN' + #10 +
    '        IF WriteFailed(SizeOf(q^.Form.Fml), q^.Form.Fml) THEN' + #10 +
    '          GOTO EXCEPTION;' + #10 +
    '        q := q^.n' + #10 +
    '      END;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB06.pas', 201, 7, lStatement),
    'Expected maxTdb TDB06 export BerList with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual(201, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(206, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(10, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('      BEGIN' + #10 +
    '        IF WriteFailed(2 * SizeOf(REAL), r^.B.B_von) THEN' + #10 +
    '          GOTO EXCEPTION;' + #10 +
    '        r := r^.n' + #10 +
    '      END;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdb06RelFileAndMaskRestoreReplacements;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB06.pas', 256, 9, lStatement),
    'Expected maxTdb TDB06 relation file Maske[i]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual(256, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(268, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(6, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('        begin' + sLineBreak +
    '          IF (Maske[i]^.Art AND 15 = A_REL) AND ((Base = 0) OR NOT IsRel(Base, Maske[i]^.m)) THEN' + #10 +
    '          BEGIN' + #10 +
    '            tfn := RelFileName(D.Pfad, Maske[i]^.m);' + #10 +
    '            IF Base > 0 ' + #10 +
    '            THEN' + #10 +
    '              GenRel(DF[Base]^.DBName, GetRelLabel(i)^, tfn, 0)' + #10 +
    '            ELSE' + #10 +
    '              GenRel(fn, GetRelLabel(i)^, tfn, 0); ' + #10 +
    '            IF IO_Error <> 0 THEN' + #10 +
    '              GOTO EXCEPTION' + #10 +
    '          END' + #10 +
    '  END;' + sLineBreak +
    '        end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDB06.pas', 272, 5, lStatement),
    'Expected maxTdb TDB06 mask restore D with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
  Assert.AreEqual('D', lStatement.Temps[0].SelectorText);
  Assert.AreEqual('record-pointer-temp', lStatement.Temps[0].Strategy);
  Assert.AreEqual('DatFile', lStatement.Temps[0].ReceiverType);
  Assert.AreEqual('lWithDatFilePtr', lStatement.Temps[0].TempName);
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual(272, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(273, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(23, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('    lWithDatFilePtr := @D;' + sLineBreak +
    '    lWithDatFilePtr^.Maske:= MaskSave;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdbJobsProgramBlockReplacements;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDBJOBS.pas', 395, 3, lStatement),
    'Expected maxTdb TDBJOBS SavePrg PB with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual(395, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(402, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(6, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  BEGIN' + sLineBreak +
    '    PB.tProgramm := Programm;' + sLineBreak +
    '    PB.tgPC := gPC;' + sLineBreak +
    '    PB.tMaxPrg := MaxPrg;' + sLineBreak +
    '    PB.tMBreak := MustBreak;' + sLineBreak +
    '    PB.tOldMode := OldMode;' + sLineBreak +
    '  END;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDBJOBS.pas', 411, 3, lStatement),
    'Expected maxTdb TDBJOBS RestorePrg PB with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual(411, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(418, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(6, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  BEGIN' + sLineBreak +
    '    Programm := PB.tProgramm;' + sLineBreak +
    '    gPC := PB.tgPC;' + sLineBreak +
    '    MaxPrg := PB.tMaxPrg;' + sLineBreak +
    '    MustBreak := PB.tMBreak;' + sLineBreak +
    '    OldMode := PB.tOldMode;' + sLineBreak +
    '  END;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdbJobsGetParameterReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDBJOBS.pas', 542, 3, lStatement),
    'Expected maxTdb TDBJOBS Parameter with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
  Assert.AreEqual('Parameter', lStatement.Temps[0].SelectorText);
  Assert.AreEqual('record-pointer-temp', lStatement.Temps[0].Strategy);
  Assert.AreEqual('ParaType', lStatement.Temps[0].ReceiverType);
  Assert.AreEqual('lWithParaTypePtr', lStatement.Temps[0].TempName);
  Assert.AreEqual(2, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('declare-temp', lStatement.Edits[0].Kind);
  Assert.AreEqual(535, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(535, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  lWithParaTypePtr: ^ParaType;' + sLineBreak, lStatement.Edits[0].ReplacementText);
  Assert.AreEqual('replace-statement', lStatement.Edits[1].Kind);
  Assert.AreEqual(542, lStatement.Edits[1].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[1].Range.StartColumn);
  Assert.AreEqual(588, lStatement.Edits[1].Range.EndLine);
  Assert.AreEqual(8, lStatement.Edits[1].Range.EndColumn);
  Assert.AreEqual('  lWithParaTypePtr := @Parameter;' + sLineBreak +
    '  CASE GetPB OF' + sLineBreak +
    '      DE:' + sLineBreak +
    '        IResult := ORD(NOT lWithParaTypePtr^.Auf);' + sLineBreak +
    '      EC:' + sLineBreak +
    '        IResult := ORD(VarCheck);' + sLineBreak +
    '      HE:' + sLineBreak +
    '        IResult := ORD(RB.H_Init);' + sLineBreak +
    '      GR:' + sLineBreak +
    '        IResult := ORD(RB.U_Init);' + sLineBreak +
    '      AK:' + sLineBreak +
    '        IResult := ORD(Allow_Abkuerzung);' + sLineBreak +
    '      RW:' + sLineBreak +
    '        IResult := lWithParaTypePtr^.Reihen;' + sLineBreak +
    '      MT:' + sLineBreak +
    '        IResult := lWithParaTypePtr^.RO;' + sLineBreak +
    '      PO:' + sLineBreak +
    '        IResult := lWithParaTypePtr^.RL;' + sLineBreak +
    '      FF:' + sLineBreak +
    '        IResult := ORD(lWithParaTypePtr^.FFeed);' + sLineBreak +
    '      NB:' + sLineBreak +
    '        IResult := ORD(NOT MustBreak);' + sLineBreak +
    '      GC:' + sLineBreak +
    '        IResult := ORD(RB.DoG);' + sLineBreak +
    '      PP:' + sLineBreak +
    '        IResult := ORD(RB.PageSum);' + sLineBreak +
    '      FO:' + sLineBreak +
    '        IResult := ORD(NoFlushFlag);' + sLineBreak +
    '      MR:' + sLineBreak +
    '        IResult := lWithParaTypePtr^.RR;' + sLineBreak +
    '      HF:' + sLineBreak +
    '        IResult := ORD(RB.Header1);' + sLineBreak +
    '      FL:' + sLineBreak +
    '        IResult := ORD(RB.FooterLast);' + sLineBreak +
    '      MB:' + sLineBreak +
    '        IResult := lWithParaTypePtr^.RU;' + sLineBreak +
    '      NV:' + sLineBreak +
    '        IResult := ORD(OnlyNumVal);' + sLineBreak +
    '      EM:' + sLineBreak +
    '        IResult := ORD(ExactMask);' + sLineBreak +
    '      UO:' + sLineBreak +
    '        IResult := ORD(UseOem);' + sLineBreak +
    '      U8:' + sLineBreak +
    '        IResult := ORD(UTF8Mode);' + sLineBreak +
    '    ELSE' + sLineBreak +
    '      IResult := 0' + sLineBreak +
    '    END;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[1].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdbJobsSubRoutineFileReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDBJOBS.pas', 1068, 9, lStatement),
    'Expected maxTdb TDBJOBS SubR[SubCount]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual(1068, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(1069, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(37, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('        SubR[SubCount]^.sFiles := SubR[SubCount]^.sFiles OR vFiles;',
    lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdbJobsSplitVarSkipReasons;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDBJOBS.pas', 1204, 5, lStatement),
    'Expected maxTdb TDBJOBS outer SVR^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('selector-type-not-resolved', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDBJOBS.pas', 1209, 11, lStatement),
    'Expected maxTdb TDBJOBS nested SVR^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('selector-type-not-resolved', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdbJobsInitVarSkipReason;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDBJOBS.pas', 1214, 15, lStatement),
    'Expected maxTdb TDBJOBS InitVar with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdbJobsJumpTempDeclarationSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDBJOBS.pas', 1778, 15, lStatement),
    'Expected maxTdb TDBJOBS Jump[Jumps] with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('temp-declaration-requires-routine-var-section', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdbJobsSubRZeroSkipReason;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDBJOBS.pas', 1937, 15, lStatement),
    'Expected maxTdb TDBJOBS SubR[0]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdbJobsReportSubRReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDBJOBS.pas', 2295, 9, lStatement),
    'Expected maxTdb TDBJOBS report SubR[0]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual(2295, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(2311, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(13, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('        BEGIN' + sLineBreak +
    '          RTL[S_Report] := 0;' + sLineBreak +
    '          RTL[S_Data] := tPC;' + sLineBreak +
    '          fillchar(SubR[0]^, SizeOf(ESubType), 0);' + sLineBreak +
    '          SubR[0]^.Alles := TRUE;' + sLineBreak +
    '          SubR[0]^.L0 := TRUE;' + sLineBreak +
    '          SubR[0]^.Dyn := TRUE;' + sLineBreak +
    '          SubR[0]^.sFiles := fw;' + sLineBreak +
    '          SubR[0]^.SubF := FileNo;' + sLineBreak +
    '          L := SubSize + 2;' + sLineBreak +
    '          move(Programm^[tPC], Programm^[tPC + L], gPC);' + sLineBreak +
    '          INC(gPC, L);' + sLineBreak +
    '          SubR[0]^.Ende := gPC - 1;' + sLineBreak +
    '          Programm^[tPC] := BYTE(P_SUB);' + sLineBreak +
    '          move(SubR[0]^.sFiles, Programm^[tPC + 1], L - 1);' + sLineBreak +
    '        END ', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdbJobsParameterDirectReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDBJOBS.pas', 2357, 3, lStatement),
    'Expected maxTdb TDBJOBS Parameter with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual(2357, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(2359, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(18, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  IF NOT SingleReport THEN' + sLineBreak +
    '      Parameter.Reihen := 0;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdbJobsSubPointerSkipReason;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDBJOBS.pas', 2704, 7, lStatement),
    'Expected maxTdb TDBJOBS Sub^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('receiver-member-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdbJobsPrgSaveRecReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'TDBJOBS.pas', 3211, 7, lStatement),
    'Expected maxTdb TDBJOBS PrgSaveRec with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
  Assert.AreEqual('PrgSaveRec', lStatement.Temps[0].SelectorText);
  Assert.AreEqual('record-pointer-temp', lStatement.Temps[0].Strategy);
  Assert.AreEqual('TPrgSaveRec', lStatement.Temps[0].ReceiverType);
  Assert.AreEqual('lWithPrgSaveRecPtr', lStatement.Temps[0].TempName);
  Assert.AreEqual('lWithPrgSaveRecPtr^', lStatement.Temps[0].QualifierText);
  Assert.AreEqual('lWithPrgSaveRecPtr: ^TPrgSaveRec;', lStatement.Temps[0].DeclarationText);
  Assert.AreEqual('lWithPrgSaveRecPtr := @PrgSaveRec;', lStatement.Temps[0].InitializationText);
  Assert.AreEqual('record-pointer-preserves-alias', lStatement.Temps[0].Reason);
  Assert.AreEqual(2, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('declare-temp', lStatement.Edits[0].Kind);
  Assert.AreEqual(3085, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(3085, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('var' + sLineBreak +
    '  lWithPrgSaveRecPtr: ^TPrgSaveRec;' + sLineBreak, lStatement.Edits[0].ReplacementText);
  Assert.AreEqual('replace-statement', lStatement.Edits[1].Kind);
  Assert.AreEqual(3211, lStatement.Edits[1].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[1].Range.StartColumn);
  Assert.AreEqual(3218, lStatement.Edits[1].Range.EndLine);
  Assert.AreEqual(10, lStatement.Edits[1].Range.EndColumn);
  Assert.AreEqual('      begin' + sLineBreak +
    '        lWithPrgSaveRecPtr := @PrgSaveRec;' + sLineBreak +
    '        BEGIN' + sLineBreak +
    '        Programm := lWithPrgSaveRecPtr^.tPrg;' + sLineBreak +
    '        MaxPrg := lWithPrgSaveRecPtr^.tMP;' + sLineBreak +
    '        gPC := lWithPrgSaveRecPtr^.tPC;' + sLineBreak +
    '        MustBreak := lWithPrgSaveRecPtr^.MB;' + sLineBreak +
    '        OldMode := lWithPrgSaveRecPtr^.tOldMode' + sLineBreak +
    '      END;' + sLineBreak +
    '      end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[1].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdbUtilsReopenDbReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdbutils.pas', 252, 3, lStatement),
    'Expected maxTdb tdbutils reopendb DF[DB]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(252, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(257, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(6, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  begin' + sLineBreak +
    '    t_fn := DF[DB]^.Pfad + DF[DB]^.DBName;' + sLineBreak +
    '    t_pw := DF[DB]^.PassWort;' + sLineBreak +
    '    t_code := DF[DB]^.Code;' + sLineBreak +
    '  end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdbUtilsRelationSkipReasons;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdbutils.pas', 295, 3, lStatement),
    'Expected maxTdb tdbutils DRel^.Maske[mm]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('selector-type-not-resolved', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdbutils.pas', 322, 3, lStatement),
    'Expected maxTdb tdbutils DRel^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdbUtilsGenRelMaskReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdbutils.pas', 343, 7, lStatement),
    'Expected maxTdb tdbutils GenRel Maske[3]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(343, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(352, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(3, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('      begin' + sLineBreak +
    '        Maske[3]^.m := ''Maske'';' + sLineBreak +
    '        Maske[3]^.Art := A_REAL;' + sLineBreak +
    '        Maske[3]^.sl := 1;' + sLineBreak +
    '        Maske[3]^.l := 3;' + sLineBreak +
    '        Maske[3]^.X := 1;' + sLineBreak +
    '        Maske[3]^.y := 3' + sLineBreak +
    '      end' + sLineBreak +
    '  ;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdbUtilsGenListReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdbutils.pas', 373, 3, lStatement),
    'Expected maxTdb tdbutils GenList DDat^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(373, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(440, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(6, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual(1748, Integer(Length(lStatement.ReplacementText)));
  Assert.IsTrue(Pos('    DDat^.RecZahl := rz;', lStatement.ReplacementText) > 0);
  Assert.IsTrue(Pos('      fillchar(DDat^.Maske[1]^.m, SizeOf(DDat^.Maske[1]^.m), 0);',
    lStatement.ReplacementText) > 0);
  Assert.IsTrue(Pos('        DDat^.Maske[2]^.Art := A_Int16;', lStatement.ReplacementText) > 0);
  Assert.IsTrue(Pos('      DDat^.Maske[rz]^.m := ''Laufende_Nummer: '';',
    lStatement.ReplacementText) > 0);
  Assert.IsTrue(Pos('      DDat^.ID_IV[1].Feld := 1;', lStatement.ReplacementText) > 0);
  Assert.IsTrue(Pos('        DDat^.ID_IV[3].IV_Art := A_Int16', lStatement.ReplacementText) > 0);
  Assert.IsTrue(EndsText('    DDat^.AutoNum := 1;' + sLineBreak + '  end;',
    lStatement.ReplacementText));
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdbUtilsGlobalStatLineReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdbutils.pas', 870, 11, lStatement),
    'Expected maxTdb tdbutils SubstField TL^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(870, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(882, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(14, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('          begin' + sLineBreak +
    '            TL^.mLine := ADDR(globalStatStr);' + sLineBreak +
    '            TL^.mPrev := nil;' + sLineBreak +
    '            TL^.mEndOfLine := e_none;' + sLineBreak +
    '            mm := TLToPChar(TL, lUtf8Str, Mode and 1 = 1, Mode and 4 = 4, Mode and 8 = 8, Mode and 2 = 2);' + sLineBreak +
    '            if mm > 0 then' + sLineBreak +
    '            begin' + sLineBreak +
    '              SubstField := InsertRamTextPChar(rt, what, pAnsiChar(lUtf8Str), Mode and 128 = 128);' + sLineBreak +
    '            end' + sLineBreak +
    '            else' + sLineBreak +
    '              SubstField := 0' + sLineBreak +
    '          end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdbUtilsSubstStringLineReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdbutils.pas', 919, 5, lStatement),
    'Expected maxTdb tdbutils SubstString TL^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(919, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(924, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(8, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('    begin' + sLineBreak +
    '      TL^.mPrev := nil;' + sLineBreak +
    '      TL^.mLine := ADDR(NewStr);' + sLineBreak +
    '      TL^.mEndOfLine := e_none' + sLineBreak +
    '    end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdbUtilsMarkListSkipReasons;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdbutils.pas', 1059, 3, lStatement),
    'Expected maxTdb tdbutils ResetMark ml with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('type-source-not-indexed', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdbutils.pas', 1087, 3, lStatement),
    'Expected maxTdb tdbutils ReplaceMark ml with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('type-source-not-indexed', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdbutils.pas', 1105, 3, lStatement),
    'Expected maxTdb tdbutils DeleteMarks ml with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('type-source-not-indexed', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdbUtilsClearMarksSkipReason;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdbutils.pas', 1121, 3, lStatement),
    'Expected maxTdb tdbutils ClearMarks ml with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('receiver-member-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdbUtilsFlipMarkReplacement;
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOptions: TDelphiSemanticApiOptions;
  lProjectDir: string;
  lProjectPath: string;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lSourceDir: string;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lProjectDir := CopyDakFixtureToTemp('test-projects\maxTdb',
    'remove-with-maxtdb-flipmark');
  lSourceDir := TPath.Combine(lProjectDir, 'src');
  lProjectPath := TPath.Combine(lSourceDir, 'maxtdb.dproj');

  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := lProjectPath;
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win32';
  lOptions.DelphiVersion := '23.0';
  lOptions.SkipWithBindingSemanticGraph := True;
  lOptions.AdditionalSourceFileNames := TDirectory.GetFiles(lSourceDir, '*.pas',
    TSearchOption.soAllDirectories);
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdbutils.pas', 1134, 3, lStatement),
    'Expected maxTdb tdbutils FlipMark ml with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
  Assert.AreEqual('ml', lStatement.Temps[0].SelectorText);
  Assert.AreEqual('record-pointer-temp', lStatement.Temps[0].Strategy);
  Assert.AreEqual('MarkList', lStatement.Temps[0].ReceiverType);
  Assert.AreEqual('lWithMarkListPtr', lStatement.Temps[0].TempName);
  Assert.AreEqual('lWithMarkListPtr^', lStatement.Temps[0].QualifierText);
  Assert.AreEqual(2, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('declare-temp', lStatement.Edits[0].Kind);
  Assert.AreEqual(1133, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(1133, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  lWithMarkListPtr: ^MarkList;' + sLineBreak, lStatement.Edits[0].ReplacementText);
  Assert.AreEqual('replace-statement', lStatement.Edits[1].Kind);
  Assert.AreEqual(1134, lStatement.Edits[1].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[1].Range.StartColumn);
  Assert.AreEqual(1166, lStatement.Edits[1].Range.EndLine);
  Assert.AreEqual(6, lStatement.Edits[1].Range.EndColumn);
  Assert.AreEqual(885, Integer(Length(lStatement.ReplacementText)));
  Assert.IsTrue(Pos('  lWithMarkListPtr := @ml;', lStatement.ReplacementText) > 0);
  Assert.IsTrue(Pos('    p := lWithMarkListPtr^.Anfang;', lStatement.ReplacementText) > 0);
  Assert.IsTrue(Pos('    lWithMarkListPtr^.Aktuell := nil;', lStatement.ReplacementText) > 0);
  Assert.IsTrue(Pos('      if lWithMarkListPtr^.Ende = p then', lStatement.ReplacementText) > 0);
  Assert.IsTrue(Pos('      Inc(lWithMarkListPtr^.AnzMarkiert);', lStatement.ReplacementText) > 0);
  Assert.IsTrue(EndsText('      lWithMarkListPtr^.Ende := p;' + sLineBreak +
    '    end' + sLineBreak +
    '  end;', lStatement.ReplacementText));
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[1].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdbUtilsMakeSelektReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdbutils.pas', 1378, 5, lStatement),
    'Expected maxTdb tdbutils MakeSelekt p^.Sel with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(1378, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(1384, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(8, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('    begin' + sLineBreak +
    '      p^.Sel.M_Nr := Nr;' + sLineBreak +
    '      p^.Sel.M_Az := n;' + sLineBreak +
    '      GetMem(p^.Sel.Menu, n * SizeOf(SelektString));' + sLineBreak +
    '      move(sa, p^.Sel.Menu^, n * SizeOf(SelektString))' + sLineBreak +
    '    end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdbUtilsImportFileReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdbutils.pas', 1436, 7, lStatement),
    'Expected maxTdb tdbutils ImportFile DF[d1]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(1436, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(1438, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(29, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('      if DF[d1]^.FileSize = nn then' + sLineBreak +
    '          ImportFile := True;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdbUtilsDdatSkipReason;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdbutils.pas', 1485, 3, lStatement),
    'Expected maxTdb tdbutils GenDS DDat^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdbUtilsDdatMaskReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdbutils.pas', 1500, 9, lStatement),
    'Expected maxTdb tdbutils GenDS Maske[RecZahl]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(1500, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(1505, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(12, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('        begin' + sLineBreak +
    '          Maske[RecZahl]^.m := GetNext(s, error_ofs);' + sLineBreak +
    '          Maske[RecZahl]^.X := 1;' + sLineBreak +
    '          Maske[RecZahl]^.y := DDat^.RecZahl;' + sLineBreak +
    '        end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdbUtilsDdatStringMaskReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdbutils.pas', 1513, 13, lStatement),
    'Expected maxTdb tdbutils GenDS string Maske[RecZahl]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(1513, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(1525, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(16, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('            begin' + sLineBreak +
    '              if Temp = 1 then' + sLineBreak +
    '              begin' + sLineBreak +
    '                Maske[RecZahl]^.Art := A_CHAR;' + sLineBreak +
    '                Maske[RecZahl]^.l := 0;' + sLineBreak +
    '                Maske[RecZahl]^.sl := 1;' + sLineBreak +
    '              end else begin' + sLineBreak +
    '                Maske[RecZahl]^.Art := A_STRING;' + sLineBreak +
    '                Maske[RecZahl]^.l := Temp;' + sLineBreak +
    '                Maske[RecZahl]^.sl := Temp;' + sLineBreak +
    '              end;' + sLineBreak +
    '            end;', lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdbUtilsDdatSolveMaskReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdbutils.pas', 1724, 13, lStatement),
    'Expected maxTdb tdbutils GenDS solve Maske[i]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(1724, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(1725, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(31, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('            Maske[i]^.Art := Maske[i]^.Art or 16;',
    lStatement.ReplacementText);
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdbUtilsDdatFormSkipReason;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdbutils.pas', 1727, 13, lStatement),
    'Expected maxTdb tdbutils GenDS FL^.Form with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdbUtilsGetStructureReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdbutils.pas', 1835, 5, lStatement),
    'Expected maxTdb tdbutils getstructure DF[d]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(1835, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(1888, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(3, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('    begin' + sLineBreak +
    '      begin' + sLineBreak +
    '        p_result := VLabString(DF[d]^.Maske[n]^.m);' + sLineBreak +
    '        if DF[d]^.Maske[n]^.Art and 15 = A_BLOB then' + sLineBreak +
    '          Str(DF[d]^.BlobBlockSize, TempStr)' + sLineBreak +
    '        else' + sLineBreak +
    '          if DF[d]^.Maske[n]^.Art and 15 = A_STRING then' + sLineBreak +
    '          Str(DF[d]^.Maske[n]^.l, TempStr)' + sLineBreak +
    '        else' + sLineBreak +
    '          Str(2 * ((DF[d]^.Maske[n]^.l + 1) div 2), TempStr);' + sLineBreak +
    '        if (DF[d]^.Maske[n]^.Art and 15 = A_REAL) and (DF[d]^.Maske[n]^.l > 4) then' + sLineBreak +
    '          TempStr := TempStr + '','' + NumToStr(DF[d]^.Maske[n]^.sl and 15, 1)^;' + sLineBreak +
    '        // IF (l MOD 2=0) AND (l>1) OR (Art AND 15=A_BYTE) AND (l=1) THEN undef:='',U'' ELSE undef:='''';' + sLineBreak +
    '        if DF[d]^.Maske[n]^.Art and 128 = 128 then' + sLineBreak +
    '          UnDef := '',U''' + sLineBreak +
    '        else' + sLineBreak +
    '          UnDef := '''';' + sLineBreak +
    '        case DF[d]^.Maske[n]^.Art and 15 of' + sLineBreak +
    '          A_CHAR:' + sLineBreak +
    '            p_result := p_result + '','' + SA_STRING + '',1'';' + sLineBreak +
    '          A_STRING:' + sLineBreak +
    '            p_result := p_result + '','' + SA_STRING + '','' + TempStr;' + sLineBreak +
    '          A_BYTE:' + sLineBreak +
    '            p_result := p_result + '','' + SA_NUMBER + '',1'' + UnDef;' + sLineBreak +
    '          A_Int16,' + sLineBreak +
    '            A_REAL:' + sLineBreak +
    '            p_result := p_result + '','' + SA_NUMBER + '','' + TempStr + UnDef;' + sLineBreak +
    '          A_MEMO:' + sLineBreak +
    '            p_result := p_result + '','' + SA_MEMO;' + sLineBreak +
    '          A_BLOB:' + sLineBreak +
    '            p_result := p_result + '','' + SA_BLOB + '','' + TempStr;' + sLineBreak +
    '          A_LONG:' + sLineBreak +
    '            p_result := p_result + '','' + SA_LINK + '','' + NameExtrakt(DF[d]^.Maske[n]^.m)^ + UnDef;' + sLineBreak +
    '          A_AUTO:' + sLineBreak +
    '            p_result := p_result + '','' + SA_AUTO;' + sLineBreak +
    '          A_ZEIT:' + sLineBreak +
    '            if DF[d]^.Maske[n]^.l > 2 then' + sLineBreak +
    '              p_result := p_result + '','' + SA_UTIME + UnDef' + sLineBreak +
    '            else' + sLineBreak +
    '              p_result := p_result + '','' + SA_TIME + UnDef;' + sLineBreak +
    '          A_DATUM:' + sLineBreak +
    '            p_result := p_result + '','' + SA_DATE + UnDef;' + sLineBreak +
    '          A_SELEKT:' + sLineBreak +
    '            p_result := p_result + '','' + SA_SELECT + '','' + GetSelStr(d, n);' + sLineBreak +
    '          A_REL:' + sLineBreak +
    '            p_result := p_result + '','' + SA_REL;' + sLineBreak +
    '          A_BOOLEAN:' + sLineBreak +
    '            p_result := p_result + '','' + SA_BOOLEAN;' + sLineBreak +
    '        end;' + sLineBreak +
    '      end;' + sLineBreak +
    '    end' + sLineBreak +
    '  ', lStatement.ReplacementText);
  Assert.AreEqual(2078, Integer(Length(lStatement.ReplacementText)));
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdbUtilsFormListSkipReason;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdbutils.pas', 1939, 9, lStatement),
    'Expected maxTdb tdbutils GenIV FL^, Form with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdbUtilsGenshSkipReason;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdbutils.pas', 2054, 3, lStatement),
    'Expected maxTdb tdbutils GenSH DF[nach]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('type-source-not-indexed', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdbUtilsGenshNestedSkipReasons;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdbutils.pas', 2056, 7, lStatement),
    'Expected maxTdb tdbutils GenSH Maske[i]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('type-source-not-indexed', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdbutils.pas', 2076, 15, lStatement),
    'Expected maxTdb tdbutils GenSH v with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('type-source-not-indexed', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdbUtilsIsEmptyReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdbutils.pas', 2104, 5, lStatement),
    'Expected maxTdb tdbutils is_empty Maske[field]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(2104, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(2137, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(8, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('    begin' + sLineBreak +
    '      if (Maske[field]^.Art and 128 = 128) and (Maske[field]^.Art and 15 <> A_LONG) and (f_s[Maske[field]^.l] = #0) then' + sLineBreak +
    '        flag := True' + sLineBreak +
    '      else' + sLineBreak +
    '        flag := False;' + sLineBreak +
    '      case Maske[field]^.Art and 15 of' + sLineBreak +
    '        A_CHAR:' + sLineBreak +
    '          Result := f_c = AnsiChar(0);' + sLineBreak +
    '        A_STRING:' + sLineBreak +
    '          Result := f_s = '''';' + sLineBreak +
    '        A_Int16:' + sLineBreak +
    '          Result := f_i = 0;' + sLineBreak +
    '        A_REAL:' + sLineBreak +
    '          if Maske[field]^.l < 5 then' + sLineBreak +
    '            Result := f_d = 0' + sLineBreak +
    '          else begin' + sLineBreak +
    '            if Maske[field]^.l < 7 then' + sLineBreak +
    '              r_new := VeryOldReal(r_old);' + sLineBreak +
    '            Result := r_new = 0.0' + sLineBreak +
    '          end;' + sLineBreak +
    '        A_BYTE, A_BOOLEAN, A_SELEKT:' + sLineBreak +
    '          Result := f_b = 0;' + sLineBreak +
    '        A_AUTO, A_DATUM, A_LONG, A_MEMO, A_BLOB:' + sLineBreak +
    '          Result := f_d = 0;' + sLineBreak +
    '        A_ZEIT:' + sLineBreak +
    '          if Maske[field]^.l > 2 then' + sLineBreak +
    '            Result := f_d = 0' + sLineBreak +
    '          else' + sLineBreak +
    '            Result := f_i = 0;' + sLineBreak +
    '        A_REL:' + sLineBreak +
    '          Result := True' + sLineBreak +
    '      end;' + sLineBreak +
    '    end;', lStatement.ReplacementText);
  Assert.AreEqual(976, Integer(Length(lStatement.ReplacementText)));
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdbUtilsTakeOverAutoLinkReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdbutils.pas', 2272, 3, lStatement),
    'Expected maxTdb tdbutils TakeOver DF[nach]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(2272, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(2274, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(82, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  ADL_I := DF[nach]^.HatAuto and DF[von]^.HatAuto and (DF[nach]^.FileSize = 0)' + sLineBreak +
    '      and (LabString(DF[nach]^.Maske[DF[nach]^.A_Nr].m) = LabString(DF[von]^.Maske[DF[von]^.A_Nr].m));',
    lStatement.ReplacementText);
  Assert.AreEqual(182, Integer(Length(lStatement.ReplacementText)));
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdbUtilsCopyMemoSkipReason;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdbutils.pas', 2765, 3, lStatement),
    'Expected maxTdb tdbutils CopyMemoDirekt DF[d]^, Maske[Nr]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('receiver-member-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdbUtilsCopyMemoLastMbRecReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdbutils.pas', 2768, 7, lStatement),
    'Expected maxTdb tdbutils CopyMemoDirekt LastMBRec with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(2768, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(2769, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(28, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('      Memo2TL(LastMBRec.d, LastMBRec.MNr, TL);',
    lStatement.ReplacementText);
  Assert.AreEqual(46, Integer(Length(lStatement.ReplacementText)));
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbWinMemosPutMemoBlockReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'winmemos.pas', 240, 3, lStatement),
    'Expected maxTdb winmemos PutMemoBlock DF[D]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText, 'RW_Op(') and
    ContainsText(lStatement.ReplacementText, 'WriteNBytes);'),
    'Expected PutMemoBlock replacement to preserve the overloaded RW_Op helper call.');
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdbUtilsGetFSizeReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdbutils.pas', 2779, 3, lStatement),
    'Expected maxTdb tdbutils GetFSize DF[d]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(2779, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(2785, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(6, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  begin' + sLineBreak +
    '    if (DF[d]^.indiziert > 0) and CheckIndexOpen(d, 1, False) then' + sLineBreak +
    '      GetFSize := DF[d]^.IndFiles[1]^.nn' + sLineBreak +
    '    else' + sLineBreak +
    '      GetFSize := DF[d]^.FileSize' + sLineBreak +
    '  end;', lStatement.ReplacementText);
  Assert.AreEqual(170, Integer(Length(lStatement.ReplacementText)));
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbTdbUtilsGetMarksAutoReplacement;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dpr'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'tdbutils.pas', 3076, 3, lStatement),
    'Expected maxTdb tdbutils GetMarksAuto DF[d]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
  Assert.AreEqual('replace-statement', lStatement.Edits[0].Kind);
  Assert.AreEqual(3076, lStatement.Edits[0].Range.StartLine);
  Assert.AreEqual(1, lStatement.Edits[0].Range.StartColumn);
  Assert.AreEqual(3095, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(6, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  begin' + sLineBreak +
    '    GetMem(RNo, (DF[d]^.FileSize + 1) * SizeOf(Int32));' + sLineBreak +
    '    GetAutoNum(d, RNo, i0);' + sLineBreak +
    '    Count := 0;' + sLineBreak +
    '    p := DF[d]^.MarkListe.Anfang;' + sLineBreak +
    '    fillchar(a^, Max * SizeOf(Int32), 0);' + sLineBreak +
    '    while (p <> nil) and (Max >= 0) do' + sLineBreak +
    '    begin' + sLineBreak +
    '      if (RNo^[p^.DV] <> 0) then' + sLineBreak +
    '      begin' + sLineBreak +
    '        Int32(a^) := RNo^[p^.DV];' + sLineBreak +
    '        Inc(pByte(a), SizeOf(Int32));' + sLineBreak +
    '      end;' + sLineBreak +
    '      p := p^.Rest;' + sLineBreak +
    '      Dec(Max);' + sLineBreak +
    '      Inc(Count);' + sLineBreak +
    '    end;' + sLineBreak +
    '    FreeMem(RNo, (DF[d]^.FileSize + 1) * SizeOf(Int32));' + sLineBreak +
    '  end;', lStatement.ReplacementText);
  Assert.AreEqual(505, Integer(Length(lStatement.ReplacementText)));
  Assert.AreEqual(lStatement.ReplacementText, lStatement.Edits[0].ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbCloseDbfSymbolNotFoundSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'DBFUTIL.pas', 729, 5, lStatement),
    'Expected maxTdb CloseDBF DBF with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbDependentSelectorTypeNotResolvedSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'DBFUTIL.pas', 833, 5, lStatement),
    'Expected maxTdb MachMaske DBF, Struktur with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('selector-type-not-resolved', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbNestedPointerSymbolNotFoundSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'DBFUTIL.pas', 842, 9, lStatement),
    'Expected maxTdb MachMaske nested M[i]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('selector-type-not-resolved', lStatement.Reason);

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'DBFUTIL.pas', 860, 11, lStatement),
    'Expected maxTdb MachMaske nested p^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbSimplePointerStatementIndent;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'DBFUTIL.pas', 945, 5, lStatement),
    'Expected maxTdb NewDATFile D^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual('    D^.Maske.Free;', lStatement.ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbIndexedPointerStatementIndent;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'DBFUTIL.pas', 1064, 7, lStatement),
    'Expected maxTdb ConvertFile DF[FilesOffen]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(
    '      Convert(DBF, FilesOffen, DBF.Labels, DF[FilesOffen]^.Maske, DF[FilesOffen]^.RecZahl, DBF.E^, DF[FilesOffen]^.Dat^);',
    lStatement.ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbIndexedPointerBlockKeepsEnd;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'deklarat.pas', 805, 3, lStatement),
    'Expected maxTdb L_Nr DF[d]^ with statement.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(818, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(6, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  begin' + sLineBreak +
    '    p := DF[d]^.LTable[Hash(s)];' + sLineBreak +
    '    while (p <> nil) and ((p^.l = 0) or (LabString(DF[d]^.Maske[p^.l].m) <> s)) do' + sLineBreak +
    '      p := p^.n;' + sLineBreak +
    '    if p = nil then' + sLineBreak +
    '      L_Nr := 0' + sLineBreak +
    '    else' + sLineBreak +
    '    begin' + sLineBreak +
    '      L_Nr := p^.l;' + sLineBreak +
    '      if DelHash then' + sLineBreak +
    '        p^.l := 0' + sLineBreak +
    '    end' + sLineBreak +
    '  end;', lStatement.ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbClonedIndexedPointerBlockKeepsEnd;
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lMatchCount: Integer;
  lOptions: TDelphiSemanticApiOptions;
  lProjectDir: string;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lProjectPath: string;
  lSourceDir: string;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
  lStatementItem: TDelphiSemanticRemoveWithFinalStatement;
begin
  lProjectDir := CopyDakFixtureToTemp('test-projects\maxTdb',
    'remove-with-maxtdb-cloned-range');
  lSourceDir := TPath.Combine(lProjectDir, 'src');
  lProjectPath := TPath.Combine(lSourceDir, 'maxtdb.dproj');

  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := lProjectPath;
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win32';
  lOptions.DelphiVersion := '23.0';
  lOptions.SkipWithBindingSemanticGraph := True;
  lOptions.AdditionalSourceFileNames := TDirectory.GetFiles(lSourceDir, '*.pas',
    TSearchOption.soAllDirectories);
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);

  lMatchCount := 0;
  for lStatementItem in lPlan.FinalStatements do
    if SameText(ExtractFileName(lStatementItem.FileName), 'deklarat.pas') and
      (lStatementItem.Range.StartLine = 805) and
      (lStatementItem.Range.StartColumn = 3) then
      Inc(lMatchCount);

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'deklarat.pas', 805, 3, lStatement),
    'Expected cloned maxTdb L_Nr DF[d]^ with statement.');
  Assert.AreEqual(1, lMatchCount, 'Expected only one final DTO for the with-47 range.');
  Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
  Assert.AreEqual(818, lStatement.Edits[0].Range.EndLine);
  Assert.AreEqual(6, lStatement.Edits[0].Range.EndColumn);
  Assert.AreEqual('  begin' + sLineBreak +
    '    p := DF[d]^.LTable[Hash(s)];' + sLineBreak +
    '    while (p <> nil) and ((p^.l = 0) or (LabString(DF[d]^.Maske[p^.l].m) <> s)) do' + sLineBreak +
    '      p := p^.n;' + sLineBreak +
    '    if p = nil then' + sLineBreak +
    '      L_Nr := 0' + sLineBreak +
    '    else' + sLineBreak +
    '    begin' + sLineBreak +
    '      L_Nr := p^.l;' + sLineBreak +
    '      if DelHash then' + sLineBreak +
    '        p^.l := 0' + sLineBreak +
    '    end' + sLineBreak +
    '  end;', lStatement.ReplacementText);
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbConstIndexedMaskSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'deklarat.pas', 1133, 7, lStatement),
    'Expected maxTdb CopyRecTemp Maske[i]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status, lStatement.Reason);
  Assert.AreEqual('selector-type-not-resolved', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)),
    'Expected unresolved const indexed mask selector to produce no final edits.');
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbVarIndexedMaskSymbolNotFoundSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'deklarat.pas', 1267, 3, lStatement),
    'Expected maxTdb CopyStringToRec aMask[aNr]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)),
    'Expected unresolved var indexed mask selector to produce no final edits.');
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbNestedRoutineIndexedMaskSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'DBFUTIL.pas', 842, 9, lStatement),
    'Expected maxTdb MachMaske M[i]^ with statement.');
  Assert.AreEqual('MachMaske', lStatement.RoutineName);
  Assert.AreEqual('skipped', lStatement.Status, lStatement.Reason);
  Assert.AreEqual('selector-type-not-resolved', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)),
    'Expected unresolved nested routine indexed mask selector to produce no final edits.');
end;

procedure TRemoveWithPlanTests.FinalDtoMatchesMaxTdbConvertIndexedMaskSymbolSkip;
var
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lPlan := BuildPlanForProject(DakFixturePath('test-projects\maxTdb\src\maxtdb.dproj'));

  Assert.IsTrue(FindFinalStatementAt(lPlan, 'DBFUTIL.pas', 969, 7, lStatement),
    'Expected maxTdb Convert M[i]^ with statement.');
  Assert.AreEqual('skipped', lStatement.Status);
  Assert.AreEqual('symbol-not-found', lStatement.Reason);
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)),
    'Expected Convert indexed mask selector to produce no final edits.');
end;

procedure TRemoveWithPlanTests.PlannerCachesSourceTextAndHashesPerFile;
var
  lSourceText: string;
begin
  lSourceText := ReadRepoSource('src\DelphiSemantics.RemoveWithPlan.pas');

  Assert.IsTrue(ContainsText(lSourceText, 'TDelphiSemanticSourceContextCache'),
    'remove-with plan DTO should use the shared source-context cache while building edits');
  Assert.IsTrue(ContainsText(lSourceText, 'TDictionary<string, string>'),
    'remove-with plan DTO should cache source hashes per file while building edits');
end;

initialization
  TDUnitX.RegisterTestFixture(TRemoveWithPlanTests);

end.
