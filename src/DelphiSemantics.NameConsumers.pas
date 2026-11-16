unit DelphiSemantics.NameConsumers;

{$SCOPEDENUMS ON}

interface

type
  TNameEffectTargetKind = (ClassType, UnitName, EnumType, EnumElement, Member, OtherType, Routine, Unknown);
  TNameEffectTargetKinds = set of TNameEffectTargetKind;
  TNameEffectChannel = (NameFormal, ReceiverMetadata, ArgumentMetadata, GlobalMetadata,
    ProducedName, Store, Callback, Opaque);
  TNameEffectChannels = set of TNameEffectChannel;
  TNameConsumerGrammar = (Unknown, Identifier, QualifiedIdentifier, ExportName, ResourceName);

  TNameConsumerPrecision = record
    FormalOrdinal: Integer;
    Grammar: TNameConsumerGrammar;
  end;

  TNameSdkEffect = record
    Channels: TNameEffectChannels;
    Targets: TNameEffectTargetKinds;
    // -1 denotes an unknown/all-argument domain, 0 denotes the receiver.
    MetadataFormalOrdinal: Integer;
    Precision: TNameConsumerPrecision;
    Reason: string;
    class function OpaqueEffect(const aReason: string): TNameSdkEffect; static;
    class function PassiveEffect: TNameSdkEffect; static;
    class function Join(const aEffects: TArray<TNameSdkEffect>;
      const aCandidatesComplete: Boolean): TNameSdkEffect; static;
    function IsPassive: Boolean;
    function Observes(const aTarget: TNameEffectTargetKind): Boolean;
  end;

implementation

class function TNameSdkEffect.OpaqueEffect(const aReason: string): TNameSdkEffect;
begin
  Result := Default(TNameSdkEffect);
  Result.Channels := [TNameEffectChannel.Opaque];
  Result.Targets := [Low(TNameEffectTargetKind)..High(TNameEffectTargetKind)];
  Result.MetadataFormalOrdinal := -1;
  Result.Precision.FormalOrdinal := -1;
  Result.Reason := aReason;
end;

class function TNameSdkEffect.PassiveEffect: TNameSdkEffect;
begin
  Result := Default(TNameSdkEffect);
  Result.MetadataFormalOrdinal := -1;
  Result.Precision.FormalOrdinal := -1;
end;

class function TNameSdkEffect.Join(const aEffects: TArray<TNameSdkEffect>;
  const aCandidatesComplete: Boolean): TNameSdkEffect;
var
  lEffect: TNameSdkEffect;
begin
  if Length(aEffects) = 0 then
    Exit(OpaqueEffect('sdk-candidate-closure-unproved'));
  Result := aEffects[0];
  for lEffect in aEffects do
  begin
    Result.Channels := Result.Channels + lEffect.Channels;
    Result.Targets := Result.Targets + lEffect.Targets;
    if Result.MetadataFormalOrdinal <> lEffect.MetadataFormalOrdinal then
      Result.MetadataFormalOrdinal := -1;
    if (Result.Precision.FormalOrdinal <> lEffect.Precision.FormalOrdinal) or
      (Result.Precision.Grammar <> lEffect.Precision.Grammar) then
    begin
      Result.Precision.FormalOrdinal := -1;
      Result.Precision.Grammar := TNameConsumerGrammar.Unknown;
    end;
    if (Result.Reason = '') and (lEffect.Reason <> '') then
      Result.Reason := lEffect.Reason;
  end;
  if not aCandidatesComplete then
  begin
    Include(Result.Channels, TNameEffectChannel.Opaque);
    Result.Targets := [Low(TNameEffectTargetKind)..High(TNameEffectTargetKind)];
    Result.MetadataFormalOrdinal := -1;
    Result.Precision.FormalOrdinal := -1;
    Result.Precision.Grammar := TNameConsumerGrammar.Unknown;
    Result.Reason := 'sdk-candidate-closure-unproved';
  end;
end;

function TNameSdkEffect.IsPassive: Boolean;
begin
  Result := Channels = [];
end;

function TNameSdkEffect.Observes(const aTarget: TNameEffectTargetKind): Boolean;
begin
  // Unknown declaration kinds cannot establish that a name effect is unrelated.
  Result := (Channels <> []) and ((aTarget in Targets) or
    ((aTarget = TNameEffectTargetKind.Unknown) and (Targets <> [])));
end;

end.
