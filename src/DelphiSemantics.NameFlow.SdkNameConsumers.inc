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
  if SameText(aQualifiedName, 'System.Classes.ReadComponentRes') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.FormalOrdinal := 1;
    aEffect.Precision.Grammar := TNameConsumerGrammar.Identifier;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'System.Classes.ReadComponentResEx') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.FormalOrdinal := 2;
    aEffect.Precision.Grammar := TNameConsumerGrammar.Identifier;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'System.Classes.InitComponentRes') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.FormalOrdinal := 1;
    aEffect.Precision.Grammar := TNameConsumerGrammar.Identifier;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'System.Classes.TResourceStream.Create') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.FormalOrdinal := 2;
    aEffect.Precision.Grammar := TNameConsumerGrammar.Identifier;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'System.Classes.TReader.FindMethod') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.FormalOrdinal := 2;
    aEffect.Precision.Grammar := TNameConsumerGrammar.Identifier;
    aEffect.Targets := [TNameEffectTargetKind.Member];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'System.Classes.TReader.FindMethodInstance') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.FormalOrdinal := 2;
    aEffect.Precision.Grammar := TNameConsumerGrammar.Identifier;
    aEffect.Targets := [TNameEffectTargetKind.Member];
    Exit(True);
  end;
// Generated Winapi.Windows interface sweep, Delphi 23.0; DS-803 round 4.
// Class-name and resource-name families remain conservative across their overloads.
  if SameText(aQualifiedName, 'Winapi.Windows.CreateDialog') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.CreateDialogA') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.CreateDialogParam') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.CreateDialogParamA') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.CreateDialogParamW') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.CreateDialogW') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.CreateMDIWindow') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.CreateMDIWindowA') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.CreateMDIWindowW') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.CreateWindow') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.CreateWindowA') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.CreateWindowEx') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.CreateWindowExA') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.CreateWindowExW') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.CreateWindowW') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.DialogBox') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.DialogBoxA') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.DialogBoxParam') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.DialogBoxParamA') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.DialogBoxParamW') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.DialogBoxW') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.EnumResourceLanguages') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.EnumResourceLanguagesA') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.EnumResourceLanguagesW') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.EnumResourceNames') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.EnumResourceNamesA') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.EnumResourceNamesW') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.FindResource') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.FindResourceA') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.FindResourceEx') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.FindResourceExA') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.FindResourceExW') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.FindResourceW') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.FindWindow') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.FindWindowA') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.FindWindowEx') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.FindWindowExA') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.FindWindowExW') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.FindWindowW') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.GetClassInfo') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.GetClassInfoA') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.GetClassInfoEx') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.GetClassInfoExA') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.GetClassInfoExW') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.GetClassInfoW') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.GetClassName') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.GetClassNameA') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.GetClassNameW') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.LoadBitmap') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.LoadBitmapA') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.LoadBitmapW') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.LoadCursor') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.LoadCursorA') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.LoadCursorW') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.LoadIcon') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.LoadIconA') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.LoadIconW') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.LoadImage') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.LoadImageA') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.LoadImageW') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.LoadMenu') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.LoadMenuA') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.LoadMenuW') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.RealGetWindowClass') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.RealGetWindowClassA') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.RealGetWindowClassW') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.UnregisterClass') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.UnregisterClassA') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.UnregisterClassW') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.UpdateResource') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.UpdateResourceA') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.UpdateResourceW') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
