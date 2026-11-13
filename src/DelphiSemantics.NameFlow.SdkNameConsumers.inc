// Generated from the reviewed Delphi 23.0 name-formal audit (DS-803).
// Positive lower bounds only. SDK hashes guard passive summaries, not these refusals.
  if SameText(aQualifiedName, 'System.Rtti.TRttiType.GetMethods') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.FormalOrdinal := 1;
    aEffect.Precision.Grammar := TNameConsumerGrammar.Identifier;
    aEffect.Targets := [TNameEffectTargetKind.Member];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'System.Rtti.TRttiType.GetIndexedProperty') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.FormalOrdinal := 1;
    aEffect.Precision.Grammar := TNameConsumerGrammar.Identifier;
    aEffect.Targets := [TNameEffectTargetKind.Member];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'System.Rtti.TRttiType.GetNamedObject') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.FormalOrdinal := 1;
    aEffect.Precision.Grammar := TNameConsumerGrammar.Identifier;
    aEffect.Targets := [Low(TNameEffectTargetKind)..High(TNameEffectTargetKind)];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'System.Rtti.TRttiType.GetNamedObjects') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.FormalOrdinal := 1;
    aEffect.Precision.Grammar := TNameConsumerGrammar.Identifier;
    aEffect.Targets := [Low(TNameEffectTargetKind)..High(TNameEffectTargetKind)];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'System.Rtti.TRttiNamedObject.HasName') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.FormalOrdinal := 1;
    aEffect.Precision.Grammar := TNameConsumerGrammar.Identifier;
    aEffect.Targets := [Low(TNameEffectTargetKind)..High(TNameEffectTargetKind)];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'System.Rtti.TRttiPackage.FindType') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.FormalOrdinal := 1;
    aEffect.Precision.Grammar := TNameConsumerGrammar.QualifiedIdentifier;
    aEffect.Targets := [TNameEffectTargetKind.ClassType, TNameEffectTargetKind.OtherType, TNameEffectTargetKind.EnumType, TNameEffectTargetKind.UnitName];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'System.TypInfo.TTypeInfoFieldAccessor.HasName') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.FormalOrdinal := 1;
    aEffect.Precision.Grammar := TNameConsumerGrammar.Identifier;
    aEffect.Targets := [Low(TNameEffectTargetKind)..High(TNameEffectTargetKind)];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'System.TypInfo.GetSetElementValue') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.FormalOrdinal := 2;
    aEffect.Precision.Grammar := TNameConsumerGrammar.Identifier;
    aEffect.Targets := [TNameEffectTargetKind.EnumType, TNameEffectTargetKind.EnumElement];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'System.Classes.TComponent.FindSortedComponent') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.FormalOrdinal := 1;
    aEffect.Precision.Grammar := TNameConsumerGrammar.Identifier;
    aEffect.Targets := [TNameEffectTargetKind.Member];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'System.Classes.FindGlobalComponent') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.FormalOrdinal := 1;
    aEffect.Precision.Grammar := TNameConsumerGrammar.Identifier;
    aEffect.Targets := [TNameEffectTargetKind.Member];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'System.Classes.IsUniqueGlobalComponentName') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.FormalOrdinal := 1;
    aEffect.Precision.Grammar := TNameConsumerGrammar.Identifier;
    aEffect.Targets := [TNameEffectTargetKind.Member];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'System.Classes.FindNestedComponent') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.FormalOrdinal := 2;
    aEffect.Precision.Grammar := TNameConsumerGrammar.QualifiedIdentifier;
    aEffect.Targets := [TNameEffectTargetKind.Member];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'System.Classes.GetComponentFieldAddress') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.FormalOrdinal := 2;
    aEffect.Precision.Grammar := TNameConsumerGrammar.Identifier;
    aEffect.Targets := [TNameEffectTargetKind.Member];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'System.Classes.TComponent.ValidateRename') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.FormalOrdinal := 3;
    aEffect.Precision.Grammar := TNameConsumerGrammar.Identifier;
    aEffect.Targets := [TNameEffectTargetKind.Member];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'System.TypInfo.FindPropInfo') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.FormalOrdinal := 2;
    aEffect.Precision.Grammar := TNameConsumerGrammar.Identifier;
    aEffect.Targets := [TNameEffectTargetKind.Member];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'System.TypInfo.GetAliasEnumValue') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.FormalOrdinal := 2;
    aEffect.Precision.Grammar := TNameConsumerGrammar.Identifier;
    aEffect.Targets := [TNameEffectTargetKind.EnumType, TNameEffectTargetKind.EnumElement];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'System.TypInfo.GetEnumNameValue') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.FormalOrdinal := 2;
    aEffect.Precision.Grammar := TNameConsumerGrammar.Identifier;
    aEffect.Targets := [TNameEffectTargetKind.EnumType, TNameEffectTargetKind.EnumElement];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'System.Classes.TComponent.GetIDsOfNames') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.FormalOrdinal := 2;
    aEffect.Precision.Grammar := TNameConsumerGrammar.Identifier;
    aEffect.Targets := [TNameEffectTargetKind.Member];
    Exit(True);
  end;
