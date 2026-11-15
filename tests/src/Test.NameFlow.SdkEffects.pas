unit Test.NameFlow.SdkEffects;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.NameConsumers, DelphiSemantics.NameFlow.SdkEffects;

type
  [TestFixture]
  TSdkEffectsTests = class
  private
    function ArtifactRequest(out aArtifact: string): TNameSdkGenerationRequest;
  public
    [Test] procedure SdkConsumerBuildsRequiredFactsFromCoreRequest;
    [Test] procedure CompletePassiveCandidateJoin;
    [Test] procedure ConsumerSurvivesCandidateJoin;
    [Test] procedure IncompleteAndEmptyCandidatesStayOpaque;
    [Test] procedure ClassMetadataDoesNotObserveRecordOrRoutine;
    [Test] procedure GeneratedIdentityRejectsAnySdkFileChange;
    [Test] procedure ExtractedSdkProducerPropagatesAcrossRoutineBody;
    [Test] procedure SdkBudgetExhaustionPoisonsEveryLookup;
    [Test] procedure MissingExpectedPinDeniesAllCalls;
    [Test] procedure SourceAndCompilerPinsAreCheckedIndependently;
    [Test] procedure NativeCatalogArtifactRoundTripPreservesEffects;
    [Test] procedure ArtifactRejectsCorruptionKeysPinsCountsAndOversize;
    [Test] procedure SourceCapSkipsExtractionAndCachedGapStaysOpaque;
    [Test] procedure InitialPinMismatchRetainsActualInputCurrentness;
    [Test] procedure InitialCompilerMismatchDoesNotRebaselineActualInputs;
  end;

implementation

uses
  System.Classes, System.Hash, System.IOUtils, System.JSON, System.StrUtils, System.SysUtils,
  AutoFree,
  DelphiSemantics.Model,
  Test.Support;

function TSdkEffectsTests.ArtifactRequest(out aArtifact: string): TNameSdkGenerationRequest;
var
  lOwnedRoot, lSdkRoot, lSource: string;
begin
  lOwnedRoot := CreateTestTempRoot('ds803-sdk-artifact-rejections-temp');
  lSdkRoot := TPath.Combine(lOwnedRoot, 'sdk');
  TDirectory.CreateDirectory(lSdkRoot);
  lSource := TPath.Combine(lSdkRoot, 'System.pas');
  aArtifact := TPath.Combine(lOwnedRoot, 'catalog.json');
  TFile.WriteAllText(lSource, 'unit System; interface type TObject = class function ClassName: string; end; ' +
    'implementation function TObject.ClassName: string; begin Result := ''name''; end; end.');
  Result := Default(TNameSdkGenerationRequest);
  Result.SdkRoot := lSdkRoot;
  Result.CompilerFileName := ParamStr(0);
  Result.CompilerVersion := 'test-identity';
  Result.ExpectedSourceIdentity := CaptureSdkSourceIdentity(lSdkRoot);
  Result.ExpectedCompilerHash := THashSHA2.GetHashStringFromFile(ParamStr(0));
  Result.Platform := 'Win64';
  Result.Configuration := 'Debug';
  SetLength(Result.UnitOptions, 1);
  Result.UnitOptions[0].SourceFileName := lSource;
end;

procedure TSdkEffectsTests.SdkConsumerBuildsRequiredFactsFromCoreRequest;
var
  g: TGarbos;
  lRequest: TNameSdkGenerationRequest;
  lCore, lRich: TNameSdkCatalog;
  lArtifact: string;
begin
  lRequest := ArtifactRequest(lArtifact);
  lRequest.UnitOptions[0].SkipNameFlowFacts := True;
  GC(lCore, TNameSdkCatalog.Create(lRequest), g);
  lCore.Generate;
  Assert.IsTrue(lCore.Validated, lCore.Reason);
  Assert.IsTrue(lCore.Statistics.FactNodes > 0,
    'SDK effects consume name-flow facts and must build them even from core-only options.');
  Assert.AreEqual(1, lCore.Statistics.CoveredSourceCount);
  Assert.IsTrue(lCore.Save(lArtifact), lCore.CacheReason);
  lRequest.UnitOptions[0].SkipNameFlowFacts := False;
  GC(lRich, TNameSdkCatalog.Create(lRequest), g);
  Assert.AreEqual(lCore.ArtifactKey, lRich.ArtifactKey,
    'SDK effects always use the rich capability, independently of the caller model projection.');
  Assert.IsTrue(lRich.TryLoad(lArtifact), lRich.CacheReason);
  Assert.AreEqual(lCore.Statistics.FactNodes, lRich.Statistics.FactNodes);
  Assert.AreEqual(lCore.Identity, lRich.Identity);
end;

procedure RewriteArtifactCountWithValidDigest(const aFileName: string);
var
  g: TGarbos;
  lEnvelope, lPayload, lStats: TJSONObject;
  lPair: TJSONPair;
  lCount: Integer;
begin
  GC(lEnvelope, TJSONObject(TJSONObject.ParseJSONValue(TFile.ReadAllText(aFileName, TEncoding.UTF8))), g);
  Assert.IsNotNull(lEnvelope);
  lPayload := TJSONObject(lEnvelope.GetValue('payload'));
  lStats := TJSONObject(lPayload.GetValue('statistics'));
  lCount := StrToInt(lStats.GetValue('routines').Value);
  GC(lPair, lStats.RemovePair('routines'), g);
  lStats.AddPair('routines', TJSONNumber.Create(lCount + 1));
  GC(lPair, lEnvelope.RemovePair('digest'), g);
  lEnvelope.AddPair('digest', THashSHA2.GetHashString(lPayload.ToJSON));
  TFile.WriteAllText(aFileName, lEnvelope.ToJSON, TEncoding.UTF8);
end;

procedure WriteOversizedArtifact(const aFileName: string);
var
  g: TGarbos;
  lStream: TFileStream;
begin
  GC(lStream, TFileStream.Create(aFileName, fmCreate), g);
  lStream.Size := 32 * 1024 * 1024 + 1;
end;

procedure TSdkEffectsTests.ArtifactRejectsCorruptionKeysPinsCountsAndOversize;
var
  g: TGarbos;
  lRequest, lOtherRequest: TNameSdkGenerationRequest;
  lGenerated, lLoaded, lOther: TNameSdkCatalog;
  lArtifact, lOriginal, lChangedFile: string;
begin
  lRequest := ArtifactRequest(lArtifact);
  GC(lGenerated, TNameSdkCatalog.Create(lRequest), g);
  lGenerated.Generate;
  Assert.IsTrue(lGenerated.Save(lArtifact), lGenerated.CacheReason);
  lOriginal := TFile.ReadAllText(lArtifact, TEncoding.UTF8);
  lOtherRequest := lRequest;
  lOtherRequest.Configuration := 'Release';
  GC(lOther, TNameSdkCatalog.Create(lOtherRequest), g);
  Assert.IsFalse(lOther.TryLoad(lArtifact));
  Assert.IsTrue(ContainsText(lOther.CacheReason, 'request/policy mismatch'), lOther.CacheReason);
  Assert.IsFalse(lOther.Validated);
  GC(lLoaded, TNameSdkCatalog.Create(lRequest), g);
  lChangedFile := TPath.Combine(lRequest.SdkRoot, 'changed.any-extension');
  TFile.WriteAllText(lChangedFile, 'changed');
  Assert.IsFalse(lLoaded.TryLoad(lArtifact));
  Assert.AreEqual('sdk-identity-mismatch', lLoaded.Reason);
  Assert.IsTrue(TNameEffectChannel.Opaque in lLoaded.Lookup('anything').Channels);
  TFile.Delete(lChangedFile);
  TFile.WriteAllText(lArtifact, 'corrupt JSON');
  Assert.IsFalse(lLoaded.TryLoad(lArtifact));
  Assert.IsFalse(lLoaded.Validated);
  Assert.IsTrue(TNameEffectChannel.Opaque in lLoaded.Lookup('anything').Channels);
  TFile.WriteAllText(lArtifact, lOriginal, TEncoding.UTF8);
  RewriteArtifactCountWithValidDigest(lArtifact);
  Assert.IsFalse(lLoaded.TryLoad(lArtifact));
  Assert.IsTrue(ContainsText(lLoaded.CacheReason, 'coverage/count mismatch'), lLoaded.CacheReason);
  Assert.IsTrue(TNameEffectChannel.Opaque in lLoaded.Lookup('anything').Channels);
  WriteOversizedArtifact(lArtifact);
  Assert.IsFalse(lLoaded.TryLoad(lArtifact));
  Assert.IsTrue(ContainsText(lLoaded.CacheReason, 'byte budget'), lLoaded.CacheReason);
  Assert.IsFalse(lLoaded.Validated);
  Assert.IsTrue(TNameEffectChannel.Opaque in lLoaded.Lookup('anything').Channels);
end;

procedure TSdkEffectsTests.SourceCapSkipsExtractionAndCachedGapStaysOpaque;
var
  g: TGarbos;
  lRequest: TNameSdkGenerationRequest;
  lGenerated, lLoaded: TNameSdkCatalog;
  lCoverage: TArray<TNameSdkSourceCoverage>;
  lArtifact: string;
  lExtractionCount, lHashPasses: Integer;
begin
  lRequest := ArtifactRequest(lArtifact);
  lRequest.MaxUnitSourceBytes := 1;
  lExtractionCount := 0;
  lRequest.OnProgress :=
    procedure(const aStage, aSource: string; const aElapsedMilliseconds: Int64)
    begin
      if aStage = 'extract-start' then
        Inc(lExtractionCount);
    end;
  GC(lGenerated, TNameSdkCatalog.Create(lRequest), g);
  lGenerated.Generate;
  Assert.IsTrue(lGenerated.Validated, lGenerated.Reason);
  Assert.AreEqual(0, lExtractionCount, 'Oversized sources must not enter the parser');
  Assert.AreEqual(1, lGenerated.Statistics.RequestedSourceCount);
  Assert.AreEqual(1, lGenerated.Statistics.SkippedSourceCount);
  Assert.AreEqual(0, lGenerated.Statistics.CoveredSourceCount);
  Assert.AreEqual<Integer>(0, Length(lGenerated.Entries));
  lCoverage := lGenerated.SourceCoverage;
  Assert.AreEqual<Integer>(1, Length(lCoverage));
  Assert.IsFalse(lCoverage[0].Covered);
  Assert.AreEqual('sdk-unit-source-budget-exceeded', lCoverage[0].Reason);
  lHashPasses := lGenerated.Statistics.HashPasses;
  Assert.IsTrue(lGenerated.Save(lArtifact), lGenerated.CacheReason);
  Assert.AreEqual(lHashPasses, lGenerated.Statistics.HashPasses, 'Save must not rehash the SDK');
  lRequest.MaxUnitSourceBytes := 64 * 1024;
  GC(lLoaded, TNameSdkCatalog.Create(lRequest), g);
  Assert.AreEqual(lGenerated.ArtifactKey, lLoaded.ArtifactKey, 'Resource ceilings are not semantic policy');
  Assert.IsTrue(lLoaded.TryLoad(lArtifact), lLoaded.CacheReason);
  Assert.AreEqual(1, lLoaded.Statistics.HashPasses, 'A cache query validates SDK pins exactly once');
  Assert.IsTrue(lLoaded.Statistics.CacheLoaded);
  Assert.AreEqual<Integer>(0, Length(lLoaded.Entries));
  Assert.IsTrue(TNameEffectChannel.Opaque in lLoaded.Lookup('System.TObject.ClassName').Channels);
  lCoverage := lLoaded.SourceCoverage;
  Assert.AreEqual('sdk-unit-source-budget-exceeded', lCoverage[0].Reason);
end;

procedure TSdkEffectsTests.NativeCatalogArtifactRoundTripPreservesEffects;
var
  g: TGarbos;
  lRequest: TNameSdkGenerationRequest;
  lGenerated, lLoaded: TNameSdkCatalog;
  lBefore, lAfter: TArray<TNameSdkEffectEntry>;
  lOwnedRoot, lSdkRoot, lSource, lArtifact: string;
  i: Integer;
begin
  lOwnedRoot := CreateTestTempRoot('ds803-sdk-artifact-temp');
  lSdkRoot := TPath.Combine(lOwnedRoot, 'sdk');
  TDirectory.CreateDirectory(lSdkRoot);
  lSource := TPath.Combine(lSdkRoot, 'System.pas');
  lArtifact := TPath.Combine(lOwnedRoot, 'catalog.json');
  TFile.WriteAllText(lSource, 'unit System; interface type TObject = class function ClassName: string; end; ' +
    'implementation function TObject.ClassName: string; begin Result := ''name''; end; end.');
  lRequest := Default(TNameSdkGenerationRequest);
  lRequest.SdkRoot := lSdkRoot;
  lRequest.CompilerFileName := ParamStr(0);
  lRequest.CompilerVersion := 'test-identity';
  lRequest.ExpectedSourceIdentity := CaptureSdkSourceIdentity(lSdkRoot);
  lRequest.ExpectedCompilerHash := THashSHA2.GetHashStringFromFile(ParamStr(0));
  lRequest.Platform := 'Win64';
  lRequest.Configuration := 'Debug';
  SetLength(lRequest.UnitOptions, 1);
  lRequest.UnitOptions[0].SourceFileName := lSource;
  GC(lGenerated, TNameSdkCatalog.Create(lRequest), g);
  lGenerated.Generate;
  lBefore := lGenerated.Entries;
  Assert.IsTrue(Length(lBefore) > 0, lGenerated.Reason);
  Assert.IsTrue(lGenerated.Save(lArtifact), lGenerated.CacheReason);
  GC(lLoaded, TNameSdkCatalog.Create(lRequest), g);
  Assert.IsTrue(lLoaded.TryLoad(lArtifact), lLoaded.CacheReason);
  lAfter := lLoaded.Entries;
  Assert.AreEqual(lGenerated.Identity, lLoaded.Identity);
  Assert.AreEqual(Length(lBefore), Length(lAfter));
  for i := 0 to High(lBefore) do
  begin
    Assert.AreEqual(lBefore[i].DeclarationId, lAfter[i].DeclarationId);
    Assert.IsTrue(lBefore[i].Effect.Channels = lAfter[i].Effect.Channels);
    Assert.IsTrue(lBefore[i].Effect.Targets = lAfter[i].Effect.Targets);
    Assert.AreEqual(lBefore[i].Effect.MetadataFormalOrdinal, lAfter[i].Effect.MetadataFormalOrdinal);
    Assert.AreEqual(lBefore[i].Effect.Precision.FormalOrdinal, lAfter[i].Effect.Precision.FormalOrdinal);
    Assert.AreEqual(Ord(lBefore[i].Effect.Precision.Grammar), Ord(lAfter[i].Effect.Precision.Grammar));
  end;
  Assert.IsTrue(lLoaded.Statistics.CacheLoaded);
end;

procedure TSdkEffectsTests.SourceAndCompilerPinsAreCheckedIndependently;
var
  g: TGarbos;
  lRequest: TNameSdkGenerationRequest;
  lCatalog: TNameSdkCatalog;
  lRoot, lSource: string;
begin
  lRoot := CreateTestTempRoot('ds803-sdk-independent-pins-temp');
  lSource := TPath.Combine(lRoot, 'SdkControl.pas');
  TFile.WriteAllText(lSource, 'unit SdkControl; interface procedure Work; implementation procedure Work; begin end; end.');
  lRequest := Default(TNameSdkGenerationRequest);
  lRequest.SdkRoot := lRoot;
  lRequest.CompilerFileName := ParamStr(0);
  lRequest.CompilerVersion := 'test-identity';
  lRequest.Platform := 'Win64';
  lRequest.Configuration := 'Debug';
  SetLength(lRequest.UnitOptions, 1);
  lRequest.UnitOptions[0].SourceFileName := lSource;
  lRequest.ExpectedSourceIdentity := CaptureSdkSourceIdentity(lRoot);
  lRequest.ExpectedCompilerHash := 'wrong-compiler-pin';
  GC(lCatalog, TNameSdkCatalog.Create(lRequest), g);
  lCatalog.Generate;
  Assert.IsFalse(lCatalog.ValidateCurrentIdentity);
  Assert.AreEqual('sdk-identity-mismatch', lCatalog.Reason);
  Assert.IsTrue(TNameEffectChannel.Opaque in lCatalog.Lookup('anything').Channels);
  lRequest.ExpectedSourceIdentity := 'wrong-source-pin';
  lRequest.ExpectedCompilerHash := THashSHA2.GetHashStringFromFile(ParamStr(0));
  GC(lCatalog, TNameSdkCatalog.Create(lRequest), g);
  lCatalog.Generate;
  Assert.IsFalse(lCatalog.ValidateCurrentIdentity);
  Assert.AreEqual('sdk-identity-mismatch', lCatalog.Reason);
  Assert.IsTrue(TNameEffectChannel.Opaque in lCatalog.Lookup('anything').Channels);
end;

procedure TSdkEffectsTests.MissingExpectedPinDeniesAllCalls;
var
  g: TGarbos;
  lRequest: TNameSdkGenerationRequest;
  lCatalog: TNameSdkCatalog;
  lRoot, lSource: string;
begin
  lRoot := CreateTestTempRoot('ds803-sdk-missing-pin-temp');
  lSource := TPath.Combine(lRoot, 'SdkControl.pas');
  TFile.WriteAllText(lSource, 'unit SdkControl; interface procedure Work; implementation procedure Work; begin end; end.');
  lRequest := Default(TNameSdkGenerationRequest);
  lRequest.SdkRoot := lRoot;
  lRequest.CompilerFileName := ParamStr(0);
  lRequest.CompilerVersion := 'test-identity';
  lRequest.Platform := 'Win64';
  lRequest.Configuration := 'Debug';
  SetLength(lRequest.UnitOptions, 1);
  lRequest.UnitOptions[0].SourceFileName := lSource;
  GC(lCatalog, TNameSdkCatalog.Create(lRequest), g);
  lCatalog.Generate;
  Assert.IsFalse(lCatalog.ValidateCurrentIdentity, 'Missing reviewed source/compiler pins must refuse');
  Assert.AreEqual('sdk-expected-pin-missing', lCatalog.Reason);
  Assert.IsTrue(TNameEffectChannel.Opaque in lCatalog.Lookup('anything').Channels);
end;

procedure TSdkEffectsTests.SdkBudgetExhaustionPoisonsEveryLookup;
var
  g: TGarbos;
  lRequest: TNameSdkGenerationRequest;
  lCatalog: TNameSdkCatalog;
begin
  lRequest := Default(TNameSdkGenerationRequest);
  lRequest.MaxSources := 1;
  SetLength(lRequest.UnitOptions, 2);
  GC(lCatalog, TNameSdkCatalog.Create(lRequest), g);
  lCatalog.Generate;
  Assert.IsTrue(StartsText('sdk-generation-budget-exceeded:', lCatalog.Reason), lCatalog.Reason);
  Assert.IsFalse(lCatalog.ValidateCurrentIdentity);
  Assert.IsTrue(TNameEffectChannel.Opaque in lCatalog.Lookup('any-sdk-declaration').Channels);
end;

procedure TSdkEffectsTests.GeneratedIdentityRejectsAnySdkFileChange;
var
  g: TGarbos;
  lRequest: TNameSdkGenerationRequest;
  lCatalog: TNameSdkCatalog;
  lRoot, lSource: string;
begin
  lRoot := CreateTestTempRoot('ds803-sdk-temp');
  lSource := TPath.Combine(lRoot, 'SdkControl.pas');
  TFile.WriteAllText(lSource, 'unit SdkControl; interface procedure Work; implementation procedure Work; begin end; end.');
  lRequest := Default(TNameSdkGenerationRequest);
  lRequest.SdkRoot := lRoot;
  lRequest.CompilerFileName := ParamStr(0);
  lRequest.CompilerVersion := 'test-identity';
  lRequest.ExpectedSourceIdentity := CaptureSdkSourceIdentity(lRoot);
  lRequest.ExpectedCompilerHash := THashSHA2.GetHashStringFromFile(ParamStr(0));
  lRequest.Platform := 'Win64';
  lRequest.Configuration := 'Debug';
  SetLength(lRequest.UnitOptions, 1);
  lRequest.UnitOptions[0].SourceFileName := lSource;
  GC(lCatalog, TNameSdkCatalog.Create(lRequest), g);
    lCatalog.Generate;
    Assert.IsTrue(lCatalog.ValidateCurrentIdentity, lCatalog.Reason);
    TFile.WriteAllText(TPath.Combine(lRoot, 'not-extracted.def'), '{$DEFINE Changed}');
    Assert.IsFalse(lCatalog.ValidateCurrentIdentity);
    Assert.AreEqual('sdk-identity-mismatch', lCatalog.Reason);
    Assert.IsTrue(TNameEffectChannel.Opaque in lCatalog.Lookup('anything').Channels);
    // Restoring the file set cannot revive a poisoned query view.
    TFile.Delete(TPath.Combine(lRoot, 'not-extracted.def'));
    Assert.IsFalse(lCatalog.ValidateCurrentIdentity);
end;

procedure TSdkEffectsTests.ExtractedSdkProducerPropagatesAcrossRoutineBody;
var
  g: TGarbos;
  lRequest: TNameSdkGenerationRequest;
  lCatalog: TNameSdkCatalog;
  lEntry: TNameSdkEffectEntry;
  lRoot, lSource, lObserved: string;
  lFound: Boolean;
begin
  lRoot := CreateTestTempRoot('ds803-sdk-effects-temp');
  lSource := TPath.Combine(lRoot, 'System.pas');
  TFile.WriteAllText(lSource, 'unit System; interface type TObject = class ' +
    'function ClassName: string; function ToString: string; end; implementation ' +
    'function TObject.ClassName: string; begin Result := ''name''; end; ' +
    'function TObject.ToString: string; begin Result := ClassName; end; end.');
  lRequest := Default(TNameSdkGenerationRequest);
  lRequest.SdkRoot := lRoot;
  lRequest.CompilerFileName := ParamStr(0);
  lRequest.CompilerVersion := 'test-identity';
  lRequest.ExpectedSourceIdentity := CaptureSdkSourceIdentity(lRoot);
  lRequest.ExpectedCompilerHash := THashSHA2.GetHashStringFromFile(ParamStr(0));
  lRequest.Platform := 'Win64';
  lRequest.Configuration := 'Debug';
  SetLength(lRequest.UnitOptions, 1);
  lRequest.UnitOptions[0].SourceFileName := lSource;
  GC(lCatalog, TNameSdkCatalog.Create(lRequest), g);
  lCatalog.Generate;
  lFound := False;
  lObserved := lCatalog.Reason + ' entries:';
  for lEntry in lCatalog.Entries do
  begin
    lObserved := lObserved + ' ' + lEntry.QualifiedName;
    if SameText(lEntry.QualifiedName, 'System.TObject.ToString') then
    begin
      lFound := True;
      Assert.IsTrue(TNameEffectChannel.ReceiverMetadata in lEntry.Effect.Channels, lEntry.DeclarationId);
      Assert.IsTrue(TNameEffectChannel.ProducedName in lEntry.Effect.Channels, lEntry.DeclarationId);
      Assert.IsFalse(lEntry.Effect.IsPassive);
    end;
  end;
  Assert.IsTrue(lFound, 'Own extractor must enumerate the implementation routine; ' + lObserved);
  Assert.IsTrue(lCatalog.Statistics.FixedPointPasses > 0);
end;

procedure TSdkEffectsTests.CompletePassiveCandidateJoin;
var
  lEffect: TNameSdkEffect;
begin
  lEffect := TNameSdkEffect.Join([TNameSdkEffect.PassiveEffect,
    TNameSdkEffect.PassiveEffect], True);
  Assert.IsTrue(lEffect.IsPassive);
end;

procedure TSdkEffectsTests.ConsumerSurvivesCandidateJoin;
var
  lConsumer, lEffect: TNameSdkEffect;
begin
  lConsumer := TNameSdkEffect.PassiveEffect;
  lConsumer.Channels := [TNameEffectChannel.ReceiverMetadata, TNameEffectChannel.ProducedName];
  lConsumer.Targets := [TNameEffectTargetKind.ClassType, TNameEffectTargetKind.UnitName];
  lConsumer.MetadataFormalOrdinal := 0;
  lEffect := TNameSdkEffect.Join([TNameSdkEffect.PassiveEffect, lConsumer], True);
  Assert.IsTrue(TNameEffectChannel.ReceiverMetadata in lEffect.Channels);
  Assert.IsTrue(TNameEffectChannel.ProducedName in lEffect.Channels);
  Assert.IsFalse(TNameEffectChannel.Opaque in lEffect.Channels);
end;

procedure TSdkEffectsTests.IncompleteAndEmptyCandidatesStayOpaque;
var
  lEffect, lObserver: TNameSdkEffect;
begin
  lEffect := TNameSdkEffect.Join([TNameSdkEffect.PassiveEffect], False);
  Assert.IsTrue(TNameEffectChannel.Opaque in lEffect.Channels);
  lEffect := TNameSdkEffect.Join(nil, True);
  Assert.IsTrue(TNameEffectChannel.Opaque in lEffect.Channels);
  lObserver := TNameSdkEffect.PassiveEffect;
  lObserver.Channels := [TNameEffectChannel.ReceiverMetadata, TNameEffectChannel.ProducedName];
  lObserver.Targets := [TNameEffectTargetKind.ClassType];
  lEffect := TNameSdkEffect.Join([lObserver], False);
  Assert.IsTrue(TNameEffectChannel.Opaque in lEffect.Channels);
  Assert.IsTrue(TNameEffectChannel.ReceiverMetadata in lEffect.Channels);
  Assert.IsTrue(TNameEffectChannel.ProducedName in lEffect.Channels);
  Assert.IsTrue(lEffect.Targets = [Low(TNameEffectTargetKind)..High(TNameEffectTargetKind)]);
end;

procedure TSdkEffectsTests.ClassMetadataDoesNotObserveRecordOrRoutine;
var
  lEffect: TNameSdkEffect;
begin
  lEffect := TNameSdkEffect.PassiveEffect;
  lEffect.Channels := [TNameEffectChannel.ReceiverMetadata, TNameEffectChannel.ProducedName];
  lEffect.Targets := [TNameEffectTargetKind.ClassType, TNameEffectTargetKind.UnitName];
  Assert.IsTrue(lEffect.Observes(TNameEffectTargetKind.ClassType));
  Assert.IsFalse(lEffect.Observes(TNameEffectTargetKind.OtherType));
  Assert.IsFalse(lEffect.Observes(TNameEffectTargetKind.Routine));
end;

procedure TSdkEffectsTests.InitialPinMismatchRetainsActualInputCurrentness;
var
  lRequest: TNameSdkGenerationRequest;
  lCatalog: TNameSdkCatalog;
  lArtifact, lFileName: string;
begin
  lRequest := ArtifactRequest(lArtifact);
  lRequest.ExpectedSourceIdentity := StringOfChar('0', 64);
  lCatalog := TNameSdkCatalog.Create(lRequest);
  try
    lCatalog.Generate;
    Assert.IsFalse(lCatalog.Validated);
    Assert.IsTrue(lCatalog.InputsUnchangedSinceAnalysis,
      'Reviewed-pin mismatch does not imply actual inputs changed during this query');
    lFileName := TPath.Combine(lRequest.SdkRoot, 'new-input.txt');
    TFile.WriteAllText(lFileName, 'changed');
    Assert.IsFalse(lCatalog.InputsUnchangedSinceAnalysis);
    lCatalog.Generate;
    Assert.IsFalse(lCatalog.InputsUnchangedSinceAnalysis,
      'Regeneration must never replace the original actual-input baseline');
  finally
    lCatalog.Free;
  end;
end;

procedure TSdkEffectsTests.InitialCompilerMismatchDoesNotRebaselineActualInputs;
var
  lRequest: TNameSdkGenerationRequest;
  lCatalog: TNameSdkCatalog;
  lArtifact: string;
begin
  lRequest := ArtifactRequest(lArtifact);
  lRequest.CompilerFileName := TPath.Combine(TPath.GetDirectoryName(lArtifact), 'compiler-input.bin');
  TFile.WriteAllText(lRequest.CompilerFileName, 'initial compiler');
  lRequest.ExpectedCompilerHash := StringOfChar('0', 64);
  lCatalog := TNameSdkCatalog.Create(lRequest);
  try
    lCatalog.Generate;
    Assert.IsFalse(lCatalog.Validated);
    Assert.IsTrue(lCatalog.InputsUnchangedSinceAnalysis);
    TFile.WriteAllText(lRequest.CompilerFileName, 'changed compiler');
    Assert.IsFalse(lCatalog.InputsUnchangedSinceAnalysis);
    lCatalog.TryLoad(lArtifact);
    Assert.IsFalse(lCatalog.InputsUnchangedSinceAnalysis,
      'A failed artifact load must never replace the original actual-input baseline');
  finally
    lCatalog.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TSdkEffectsTests);

end.
