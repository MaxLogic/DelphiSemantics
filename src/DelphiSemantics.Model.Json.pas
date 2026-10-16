unit DelphiSemantics.Model.Json;

interface

uses
  DelphiSemantics.Model;

function ModelToJson(const aModel: TDelphiSemanticUnitModel): string;
function JsonToModel(const aJson: string): TDelphiSemanticUnitModel;

implementation

uses
  System.JSON, System.StrUtils, System.SysUtils;

function JsonBool(const aObject: TJSONObject; const aName: string): Boolean;
var
  lValue: TJSONValue;
begin
  lValue := aObject.GetValue(aName);
  Result := Assigned(lValue) and SameText(lValue.Value, 'true');
end;

function JsonInt(const aObject: TJSONObject; const aName: string): Integer;
var
  lValue: TJSONValue;
begin
  lValue := aObject.GetValue(aName);
  if not Assigned(lValue) then
    Exit(0);
  Result := StrToIntDef(lValue.Value, 0);
end;

function JsonString(const aObject: TJSONObject; const aName: string): string;
var
  lValue: TJSONValue;
begin
  lValue := aObject.GetValue(aName);
  if Assigned(lValue) then
    Result := lValue.Value
  else
    Result := '';
end;

// DS-659: written only for facts from an include file, so other models serialize unchanged.
procedure AddFactFileName(const aObject: TJSONObject; const aFileName: string);
begin
  if aFileName <> '' then
    aObject.AddPair('FileName', aFileName);
end;

function SourceSectionsToJson(const aSections: TDelphiSemanticSourceSections):
  TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('InterfaceOffset', TJSONNumber.Create(aSections.InterfaceOffset));
  Result.AddPair('ImplementationOffset', TJSONNumber.Create(aSections.ImplementationOffset));
  Result.AddPair('InitializationOffset', TJSONNumber.Create(aSections.InitializationOffset));
  Result.AddPair('FinalizationOffset', TJSONNumber.Create(aSections.FinalizationOffset));
end;

function JsonToSourceSections(const aObject: TJSONObject): TDelphiSemanticSourceSections;
begin
  Result := Default(TDelphiSemanticSourceSections);
  if not Assigned(aObject) then
    Exit;

  Result.InterfaceOffset := JsonInt(aObject, 'InterfaceOffset');
  Result.ImplementationOffset := JsonInt(aObject, 'ImplementationOffset');
  Result.InitializationOffset := JsonInt(aObject, 'InitializationOffset');
  Result.FinalizationOffset := JsonInt(aObject, 'FinalizationOffset');
end;

function StringArrayToJson(const aValues: TArray<string>): TJSONArray;
var
  lValue: string;
begin
  Result := TJSONArray.Create;
  for lValue in aValues do
    Result.Add(lValue);
end;

function JsonToStringArray(const aArray: TJSONArray): TArray<string>;
var
  i: Integer;
begin
  if not Assigned(aArray) then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  SetLength(Result, aArray.Count);
  for i := 0 to Pred(aArray.Count) do
    Result[i] := aArray.Items[i].Value;
end;

function DependencyFactsToJson(const aFacts: TDelphiSemanticUnitDependencyFacts): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('Known', TJSONBool.Create(aFacts.Known));
  Result.AddPair('InterfaceImports', StringArrayToJson(aFacts.InterfaceImports));
  Result.AddPair('ImplementationImports', StringArrayToJson(aFacts.ImplementationImports));
  Result.AddPair('RootImports', StringArrayToJson(aFacts.RootImports));
  Result.AddPair('HasInitialization', TJSONBool.Create(aFacts.HasInitialization));
  Result.AddPair('HasFinalization', TJSONBool.Create(aFacts.HasFinalization));
end;

function IsImportArray(const aValue: TJSONValue): Boolean;
var
  lItem: TJSONValue;
begin
  Result := False;
  if not (aValue is TJSONArray) then
    Exit;
  for lItem in (aValue as TJSONArray) do
    if (lItem.ClassType <> TJSONString) or (Trim(lItem.Value) = '') then
      Exit;
  Result := True;
end;
function JsonToDependencyFacts(const aValue: TJSONValue): TDelphiSemanticUnitDependencyFacts;
var
  lObject: TJSONObject;
begin
  Result := Default(TDelphiSemanticUnitDependencyFacts);
  if not (aValue is TJSONObject) then
    Exit;
  lObject := aValue as TJSONObject;
  Result.Known := (lObject.GetValue('Known') is TJSONBool) and
    JsonBool(lObject, 'Known') and
    IsImportArray(lObject.GetValue('InterfaceImports')) and
    IsImportArray(lObject.GetValue('ImplementationImports')) and
    IsImportArray(lObject.GetValue('RootImports')) and
    (lObject.GetValue('HasInitialization') is TJSONBool) and
    (lObject.GetValue('HasFinalization') is TJSONBool);
  if not Result.Known then
    Exit;
  Result.InterfaceImports := JsonToStringArray(lObject.GetValue('InterfaceImports') as TJSONArray);
  Result.ImplementationImports := JsonToStringArray(lObject.GetValue('ImplementationImports') as TJSONArray);
  Result.RootImports := JsonToStringArray(lObject.GetValue('RootImports') as TJSONArray);
  Result.HasInitialization := JsonBool(lObject, 'HasInitialization');
  Result.HasFinalization := JsonBool(lObject, 'HasFinalization');
end;
function SignatureToJson(const aSignature: TDelphiSemanticProcedureSignature): TJSONObject;
var
  lParameters: TJSONArray;
  lParameter: TDelphiSemanticSignatureParameter;
  lItem: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('Known', TJSONBool.Create(aSignature.Known));
  Result.AddPair('OfObject', TJSONBool.Create(aSignature.OfObject));
  Result.AddPair('Kind', aSignature.Kind);
  Result.AddPair('CallingConvention', aSignature.CallingConvention);
  Result.AddPair('ReturnType', aSignature.ReturnType);
  lParameters := TJSONArray.Create;
  Result.AddPair('Parameters', lParameters);
  for lParameter in aSignature.Parameters do
  begin
    lItem := TJSONObject.Create;
    lParameters.AddElement(lItem);
    lItem.AddPair('Name', lParameter.Name);
    lItem.AddPair('TypeName', lParameter.TypeName);
    lItem.AddPair('Modifier', lParameter.Modifier);
  end;
end;

function JsonToSignature(const aObject: TJSONObject): TDelphiSemanticProcedureSignature;
var
  i: Integer;
  lParameters: TJSONArray;
  lItem: TJSONObject;
begin
  Result := Default(TDelphiSemanticProcedureSignature);
  if not Assigned(aObject) then
    Exit;
  Result.Known := JsonBool(aObject, 'Known');
  Result.OfObject := JsonBool(aObject, 'OfObject');
  Result.Kind := JsonString(aObject, 'Kind');
  Result.CallingConvention := JsonString(aObject, 'CallingConvention');
  Result.ReturnType := JsonString(aObject, 'ReturnType');
  lParameters := aObject.GetValue('Parameters') as TJSONArray;
  if not Assigned(lParameters) then
  begin
    Result.Known := False;
    Exit;
  end;
  SetLength(Result.Parameters, lParameters.Count);
  for i := 0 to Pred(lParameters.Count) do
  begin
    lItem := lParameters.Items[i] as TJSONObject;
    Result.Parameters[i].Name := JsonString(lItem, 'Name');
    Result.Parameters[i].TypeName := JsonString(lItem, 'TypeName');
    Result.Parameters[i].Modifier := JsonString(lItem, 'Modifier');
  end;
end;

function DeclarationToJson(const aDeclaration: TDelphiSemanticDeclaration): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('Name', aDeclaration.Name);
  Result.AddPair('Kind', aDeclaration.Kind);
  Result.AddPair('TypeName', aDeclaration.TypeName);
  Result.AddPair('InterfaceGuid', aDeclaration.InterfaceGuid);
  Result.AddPair('IsDispInterface', TJSONBool.Create(aDeclaration.IsDispInterface));
  Result.AddPair('ProcedureSignature', SignatureToJson(aDeclaration.ProcedureSignature));
  Result.AddPair('BaseTypeName', aDeclaration.BaseTypeName);
  Result.AddPair('HelperTargetName', aDeclaration.HelperTargetName);
  Result.AddPair('AstHelperKind', aDeclaration.AstHelperKind);
  Result.AddPair('SectionKind', aDeclaration.SectionKind);
  Result.AddPair('Line', TJSONNumber.Create(aDeclaration.Line));
  Result.AddPair('Column', TJSONNumber.Create(aDeclaration.Column));
  Result.AddPair('Offset', TJSONNumber.Create(aDeclaration.Offset));
  Result.AddPair('EndOffset', TJSONNumber.Create(aDeclaration.EndOffset));
  if aDeclaration.TypeBodyEndLine > 0 then
  begin
    Result.AddPair('TypeBodyEndLine', TJSONNumber.Create(aDeclaration.TypeBodyEndLine));
    Result.AddPair('TypeBodyEndColumn', TJSONNumber.Create(aDeclaration.TypeBodyEndColumn));
  end;
  Result.AddPair('DeclarationRole', aDeclaration.DeclarationRole);
  Result.AddPair('ScopeKind', aDeclaration.ScopeKind);
  Result.AddPair('OwnerName', aDeclaration.OwnerName);
  Result.AddPair('OwnerScopeId', aDeclaration.OwnerScopeId);
  Result.AddPair('SymbolId', aDeclaration.SymbolId);
  Result.AddPair('Mutable', TJSONBool.Create(aDeclaration.Mutable));
  AddFactFileName(Result, aDeclaration.FileName);
end;

function JsonToDeclaration(const aObject: TJSONObject): TDelphiSemanticDeclaration;
begin
  Result := Default(TDelphiSemanticDeclaration);
  Result.InterfaceGuid := JsonString(aObject, 'InterfaceGuid');
  Result.IsDispInterface := JsonBool(aObject, 'IsDispInterface');
  Result.ProcedureSignature := JsonToSignature(aObject.GetValue('ProcedureSignature') as TJSONObject);
  Result.Name := JsonString(aObject, 'Name');
  Result.Kind := JsonString(aObject, 'Kind');
  Result.TypeName := JsonString(aObject, 'TypeName');
  Result.BaseTypeName := JsonString(aObject, 'BaseTypeName');
  Result.HelperTargetName := JsonString(aObject, 'HelperTargetName');
  Result.AstHelperKind := JsonString(aObject, 'AstHelperKind');
  Result.SectionKind := JsonString(aObject, 'SectionKind');
  Result.Line := JsonInt(aObject, 'Line');
  Result.Column := JsonInt(aObject, 'Column');
  Result.Offset := JsonInt(aObject, 'Offset');
  Result.EndOffset := JsonInt(aObject, 'EndOffset');
  Result.TypeBodyEndLine := JsonInt(aObject, 'TypeBodyEndLine');
  Result.TypeBodyEndColumn := JsonInt(aObject, 'TypeBodyEndColumn');
  Result.DeclarationRole := JsonString(aObject, 'DeclarationRole');
  Result.ScopeKind := JsonString(aObject, 'ScopeKind');
  Result.OwnerName := JsonString(aObject, 'OwnerName');
  Result.OwnerScopeId := JsonString(aObject, 'OwnerScopeId');
  Result.SymbolId := JsonString(aObject, 'SymbolId');
  Result.Mutable := JsonBool(aObject, 'Mutable');
  Result.FileName := JsonString(aObject, 'FileName');
end;

function DeclarationsToJson(const aDeclarations: TArray<TDelphiSemanticDeclaration>): TJSONArray;
var
  lDeclaration: TDelphiSemanticDeclaration;
begin
  Result := TJSONArray.Create;
  for lDeclaration in aDeclarations do
    Result.AddElement(DeclarationToJson(lDeclaration));
end;

function JsonToDeclarations(const aArray: TJSONArray): TArray<TDelphiSemanticDeclaration>;
var
  i: Integer;
begin
  if not Assigned(aArray) then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  SetLength(Result, aArray.Count);
  for i := 0 to Pred(aArray.Count) do
    Result[i] := JsonToDeclaration(aArray.Items[i] as TJSONObject);
end;

function MemberToJson(const aMember: TDelphiSemanticMember): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('OwnerName', aMember.OwnerName);
  Result.AddPair('OwnerScopeId', aMember.OwnerScopeId);
  Result.AddPair('OwnerSymbolId', aMember.OwnerSymbolId);
  Result.AddPair('Name', aMember.Name);
  Result.AddPair('Kind', aMember.Kind);
  Result.AddPair('TypeName', aMember.TypeName);
  Result.AddPair('Visibility', aMember.Visibility);
  Result.AddPair('ProcedureSignature', SignatureToJson(aMember.ProcedureSignature));
  Result.AddPair('Signature', aMember.Signature);
  Result.AddPair('IsIndexed', TJSONBool.Create(aMember.IsIndexed));
  Result.AddPair('IsDefault', TJSONBool.Create(aMember.IsDefault));
  Result.AddPair('Line', TJSONNumber.Create(aMember.Line));
  Result.AddPair('Column', TJSONNumber.Create(aMember.Column));
  Result.AddPair('Offset', TJSONNumber.Create(aMember.Offset));
  Result.AddPair('EndOffset', TJSONNumber.Create(aMember.EndOffset));
  AddFactFileName(Result, aMember.FileName);
end;

function JsonToMember(const aObject: TJSONObject): TDelphiSemanticMember;
begin
  Result := Default(TDelphiSemanticMember);
  Result.ProcedureSignature := JsonToSignature(aObject.GetValue('ProcedureSignature') as TJSONObject);
  Result.OwnerName := JsonString(aObject, 'OwnerName');
  Result.OwnerScopeId := JsonString(aObject, 'OwnerScopeId');
  Result.OwnerSymbolId := JsonString(aObject, 'OwnerSymbolId');
  Result.Name := JsonString(aObject, 'Name');
  Result.Kind := JsonString(aObject, 'Kind');
  Result.TypeName := JsonString(aObject, 'TypeName');
  Result.Visibility := JsonString(aObject, 'Visibility');
  Result.Signature := JsonString(aObject, 'Signature');
  Result.IsIndexed := JsonBool(aObject, 'IsIndexed');
  Result.IsDefault := JsonBool(aObject, 'IsDefault');
  Result.Line := JsonInt(aObject, 'Line');
  Result.Column := JsonInt(aObject, 'Column');
  Result.Offset := JsonInt(aObject, 'Offset');
  Result.EndOffset := JsonInt(aObject, 'EndOffset');
  Result.FileName := JsonString(aObject, 'FileName');
end;

function MembersToJson(const aMembers: TArray<TDelphiSemanticMember>): TJSONArray;
var
  lMember: TDelphiSemanticMember;
begin
  Result := TJSONArray.Create;
  for lMember in aMembers do
    Result.AddElement(MemberToJson(lMember));
end;

function JsonToMembers(const aArray: TJSONArray): TArray<TDelphiSemanticMember>;
var
  i: Integer;
begin
  if not Assigned(aArray) then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  SetLength(Result, aArray.Count);
  for i := 0 to Pred(aArray.Count) do
    Result[i] := JsonToMember(aArray.Items[i] as TJSONObject);
end;

function ParameterToJson(const aParameter: TDelphiSemanticParameter): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('RoutineName', aParameter.RoutineName);
  Result.AddPair('Name', aParameter.Name);
  Result.AddPair('TypeName', aParameter.TypeName);
  Result.AddPair('Modifier', aParameter.Modifier);
  Result.AddPair('Line', TJSONNumber.Create(aParameter.Line));
  Result.AddPair('Column', TJSONNumber.Create(aParameter.Column));
  Result.AddPair('Offset', TJSONNumber.Create(aParameter.Offset));
  Result.AddPair('EndOffset', TJSONNumber.Create(aParameter.EndOffset));
  AddFactFileName(Result, aParameter.FileName);
end;

function JsonToParameter(const aObject: TJSONObject): TDelphiSemanticParameter;
begin
  Result.RoutineName := JsonString(aObject, 'RoutineName');
  Result.Name := JsonString(aObject, 'Name');
  Result.TypeName := JsonString(aObject, 'TypeName');
  Result.Modifier := JsonString(aObject, 'Modifier');
  Result.Line := JsonInt(aObject, 'Line');
  Result.Column := JsonInt(aObject, 'Column');
  Result.Offset := JsonInt(aObject, 'Offset');
  Result.EndOffset := JsonInt(aObject, 'EndOffset');
  Result.FileName := JsonString(aObject, 'FileName');
end;

function ParametersToJson(const aParameters: TArray<TDelphiSemanticParameter>): TJSONArray;
var
  lParameter: TDelphiSemanticParameter;
begin
  Result := TJSONArray.Create;
  for lParameter in aParameters do
    Result.AddElement(ParameterToJson(lParameter));
end;

function JsonToParameters(const aArray: TJSONArray): TArray<TDelphiSemanticParameter>;
var
  i: Integer;
begin
  if not Assigned(aArray) then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  SetLength(Result, aArray.Count);
  for i := 0 to Pred(aArray.Count) do
    Result[i] := JsonToParameter(aArray.Items[i] as TJSONObject);
end;

function RoutineToJson(const aRoutine: TDelphiSemanticRoutine): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('Name', aRoutine.Name);
  Result.AddPair('OwnerName', aRoutine.OwnerName);
  Result.AddPair('SectionKind', aRoutine.SectionKind);
  Result.AddPair('Signature', aRoutine.Signature);
  Result.AddPair('CallingConvention', aRoutine.CallingConvention);
  Result.AddPair('ProcedureSignature', SignatureToJson(aRoutine.ProcedureSignature));
  Result.AddPair('ReturnType', aRoutine.ReturnType);
  Result.AddPair('Line', TJSONNumber.Create(aRoutine.Line));
  Result.AddPair('Column', TJSONNumber.Create(aRoutine.Column));
  Result.AddPair('Offset', TJSONNumber.Create(aRoutine.Offset));
  Result.AddPair('EndOffset', TJSONNumber.Create(aRoutine.EndOffset));
  Result.AddPair('EndLine', TJSONNumber.Create(aRoutine.EndLine));
  Result.AddPair('EndColumn', TJSONNumber.Create(aRoutine.EndColumn));
  Result.AddPair('ScopeId', aRoutine.ScopeId);
  Result.AddPair('ParentScopeId', aRoutine.ParentScopeId);
  Result.AddPair('AstScopeKind', aRoutine.AstScopeKind);
  Result.AddPair('AstSemanticSignature', aRoutine.AstSemanticSignature);
  Result.AddPair('AstSourceSignature', aRoutine.AstSourceSignature);
  Result.AddPair('AstSourceSignatureVerified',
    TJSONBool.Create(aRoutine.AstSourceSignatureVerified));
  Result.AddPair('Parameters', ParametersToJson(aRoutine.Parameters));
  AddFactFileName(Result, aRoutine.FileName);
end;

function JsonToRoutine(const aObject: TJSONObject): TDelphiSemanticRoutine;
begin
  Result := Default(TDelphiSemanticRoutine);
  Result.CallingConvention := JsonString(aObject, 'CallingConvention');
  Result.ProcedureSignature := JsonToSignature(aObject.GetValue('ProcedureSignature') as TJSONObject);
  Result.Name := JsonString(aObject, 'Name');
  Result.OwnerName := JsonString(aObject, 'OwnerName');
  Result.SectionKind := JsonString(aObject, 'SectionKind');
  Result.Signature := JsonString(aObject, 'Signature');
  Result.ReturnType := JsonString(aObject, 'ReturnType');
  Result.Line := JsonInt(aObject, 'Line');
  Result.Column := JsonInt(aObject, 'Column');
  Result.Offset := JsonInt(aObject, 'Offset');
  Result.EndOffset := JsonInt(aObject, 'EndOffset');
  Result.EndLine := JsonInt(aObject, 'EndLine');
  Result.EndColumn := JsonInt(aObject, 'EndColumn');
  Result.ScopeId := JsonString(aObject, 'ScopeId');
  Result.ParentScopeId := JsonString(aObject, 'ParentScopeId');
  Result.AstScopeKind := JsonString(aObject, 'AstScopeKind');
  Result.AstSemanticSignature := JsonString(aObject, 'AstSemanticSignature');
  Result.AstSourceSignature := JsonString(aObject, 'AstSourceSignature');
  Result.AstSourceSignatureVerified := JsonBool(aObject, 'AstSourceSignatureVerified');
  Result.Parameters := JsonToParameters(aObject.GetValue('Parameters') as TJSONArray);
  Result.FileName := JsonString(aObject, 'FileName');
end;

function RoutinesToJson(const aRoutines: TArray<TDelphiSemanticRoutine>): TJSONArray;
var
  lRoutine: TDelphiSemanticRoutine;
begin
  Result := TJSONArray.Create;
  for lRoutine in aRoutines do
    Result.AddElement(RoutineToJson(lRoutine));
end;

function JsonToRoutines(const aArray: TJSONArray): TArray<TDelphiSemanticRoutine>;
var
  i: Integer;
begin
  if not Assigned(aArray) then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  SetLength(Result, aArray.Count);
  for i := 0 to Pred(aArray.Count) do
    Result[i] := JsonToRoutine(aArray.Items[i] as TJSONObject);
end;

function LocalToJson(const aLocal: TDelphiSemanticLocal): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('RoutineName', aLocal.RoutineName);
  Result.AddPair('Name', aLocal.Name);
  Result.AddPair('Kind', aLocal.Kind);
  Result.AddPair('TypeName', aLocal.TypeName);
  Result.AddPair('Line', TJSONNumber.Create(aLocal.Line));
  Result.AddPair('Column', TJSONNumber.Create(aLocal.Column));
  Result.AddPair('Offset', TJSONNumber.Create(aLocal.Offset));
  Result.AddPair('EndOffset', TJSONNumber.Create(aLocal.EndOffset));
  Result.AddPair('RoutineScopeId', aLocal.RoutineScopeId);
  AddFactFileName(Result, aLocal.FileName);
end;

function JsonToLocal(const aObject: TJSONObject): TDelphiSemanticLocal;
begin
  Result.RoutineName := JsonString(aObject, 'RoutineName');
  Result.Name := JsonString(aObject, 'Name');
  Result.Kind := JsonString(aObject, 'Kind');
  Result.TypeName := JsonString(aObject, 'TypeName');
  Result.Line := JsonInt(aObject, 'Line');
  Result.Column := JsonInt(aObject, 'Column');
  Result.Offset := JsonInt(aObject, 'Offset');
  Result.EndOffset := JsonInt(aObject, 'EndOffset');
  Result.RoutineScopeId := JsonString(aObject, 'RoutineScopeId');
  Result.FileName := JsonString(aObject, 'FileName');
end;

function LocalsToJson(const aLocals: TArray<TDelphiSemanticLocal>): TJSONArray;
var
  lLocal: TDelphiSemanticLocal;
begin
  Result := TJSONArray.Create;
  for lLocal in aLocals do
    Result.AddElement(LocalToJson(lLocal));
end;

function JsonToLocals(const aArray: TJSONArray): TArray<TDelphiSemanticLocal>;
var
  i: Integer;
begin
  if not Assigned(aArray) then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  SetLength(Result, aArray.Count);
  for i := 0 to Pred(aArray.Count) do
    Result[i] := JsonToLocal(aArray.Items[i] as TJSONObject);
end;

function ReferenceToJson(const aReference: TDelphiSemanticReference): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('Name', aReference.Name);
  Result.AddPair('RoutineName', aReference.RoutineName);
  Result.AddPair('Role', aReference.Role);
  Result.AddPair('SectionKind', aReference.SectionKind);
  Result.AddPair('Line', TJSONNumber.Create(aReference.Line));
  Result.AddPair('Column', TJSONNumber.Create(aReference.Column));
  Result.AddPair('Offset', TJSONNumber.Create(aReference.Offset));
  Result.AddPair('EndOffset', TJSONNumber.Create(aReference.EndOffset));
  Result.AddPair('EndLine', TJSONNumber.Create(aReference.EndLine));
  Result.AddPair('EndColumn', TJSONNumber.Create(aReference.EndColumn));
  Result.AddPair('RoutineScopeId', aReference.RoutineScopeId);
  AddFactFileName(Result, aReference.FileName);
end;

function JsonToReference(const aObject: TJSONObject): TDelphiSemanticReference;
begin
  Result.Name := JsonString(aObject, 'Name');
  Result.RoutineName := JsonString(aObject, 'RoutineName');
  Result.Role := JsonString(aObject, 'Role');
  Result.SectionKind := JsonString(aObject, 'SectionKind');
  Result.Line := JsonInt(aObject, 'Line');
  Result.Column := JsonInt(aObject, 'Column');
  Result.Offset := JsonInt(aObject, 'Offset');
  Result.EndOffset := JsonInt(aObject, 'EndOffset');
  Result.EndLine := JsonInt(aObject, 'EndLine');
  Result.EndColumn := JsonInt(aObject, 'EndColumn');
  Result.RoutineScopeId := JsonString(aObject, 'RoutineScopeId');
  Result.FileName := JsonString(aObject, 'FileName');
end;

function ReferencesToJson(const aReferences: TArray<TDelphiSemanticReference>): TJSONArray;
var
  lReference: TDelphiSemanticReference;
begin
  Result := TJSONArray.Create;
  for lReference in aReferences do
    Result.AddElement(ReferenceToJson(lReference));
end;

function JsonToReferences(const aArray: TJSONArray): TArray<TDelphiSemanticReference>;
var
  i: Integer;
begin
  if not Assigned(aArray) then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  SetLength(Result, aArray.Count);
  for i := 0 to Pred(aArray.Count) do
    Result[i] := JsonToReference(aArray.Items[i] as TJSONObject);
end;

function PhysicalOccurrenceToJson(
  const aOccurrence: TDelphiSemanticPhysicalReferenceOccurrence): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('Name', aOccurrence.Name);
  Result.AddPair('Role', aOccurrence.Role);
  Result.AddPair('RoutineName', aOccurrence.RoutineName);
  Result.AddPair('RoutineScopeId', aOccurrence.RoutineScopeId);
  Result.AddPair('OutputStartOffset', TJSONNumber.Create(aOccurrence.OutputStartOffset));
  Result.AddPair('OutputEndOffset', TJSONNumber.Create(aOccurrence.OutputEndOffset));
  Result.AddPair('FileName', aOccurrence.FileName);
  Result.AddPair('Line', TJSONNumber.Create(aOccurrence.Line));
  Result.AddPair('Column', TJSONNumber.Create(aOccurrence.Column));
  Result.AddPair('EndLine', TJSONNumber.Create(aOccurrence.EndLine));
  Result.AddPair('EndColumn', TJSONNumber.Create(aOccurrence.EndColumn));
  Result.AddPair('ExpansionId', aOccurrence.ExpansionId);
  Result.AddPair('Verified', TJSONBool.Create(aOccurrence.Verified));
end;

function PhysicalOccurrencesToJson(
  const aOccurrences: TArray<TDelphiSemanticPhysicalReferenceOccurrence>): TJSONArray;
var
  lOccurrence: TDelphiSemanticPhysicalReferenceOccurrence;
begin
  Result := TJSONArray.Create;
  for lOccurrence in aOccurrences do
    Result.AddElement(PhysicalOccurrenceToJson(lOccurrence));
end;

function JsonToPhysicalOccurrences(const aArray: TJSONArray;
  out aStructurallyValid: Boolean; out aInvalidCount: Integer):
  TArray<TDelphiSemanticPhysicalReferenceOccurrence>;
var
  i: Integer;
  lObject: TJSONObject;
  lOccurrence: TDelphiSemanticPhysicalReferenceOccurrence;
  lOccurrenceValid: Boolean;
  lStructurallyInvalid: Boolean;
  lWasVerified: Boolean;
begin
  aStructurallyValid := Assigned(aArray);
  aInvalidCount := 0;
  if not Assigned(aArray) then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  SetLength(Result, aArray.Count);
  for i := 0 to Pred(aArray.Count) do
  begin
    lOccurrence := Default(TDelphiSemanticPhysicalReferenceOccurrence);
    if not (aArray.Items[i] is TJSONObject) then
    begin
      aStructurallyValid := False;
      Inc(aInvalidCount);
      Result[i] := lOccurrence;
      Continue;
    end;
    lObject := aArray.Items[i] as TJSONObject;
    lOccurrence.Name := JsonString(lObject, 'Name');
    lOccurrence.Role := JsonString(lObject, 'Role');
    lOccurrence.RoutineName := JsonString(lObject, 'RoutineName');
    lOccurrence.RoutineScopeId := JsonString(lObject, 'RoutineScopeId');
    lOccurrence.OutputStartOffset := JsonInt(lObject, 'OutputStartOffset');
    lOccurrence.OutputEndOffset := JsonInt(lObject, 'OutputEndOffset');
    lOccurrence.FileName := JsonString(lObject, 'FileName');
    lOccurrence.Line := JsonInt(lObject, 'Line');
    lOccurrence.Column := JsonInt(lObject, 'Column');
    lOccurrence.EndLine := JsonInt(lObject, 'EndLine');
    lOccurrence.EndColumn := JsonInt(lObject, 'EndColumn');
    lOccurrence.ExpansionId := JsonString(lObject, 'ExpansionId');
    lOccurrence.Verified := (lObject.GetValue('Verified') is TJSONBool) and
      JsonBool(lObject, 'Verified');
    lWasVerified := lOccurrence.Verified;
    lOccurrenceValid := True;
    lStructurallyInvalid := (lOccurrence.Name = '') or
      (lOccurrence.OutputStartOffset <= 0) or
      (lOccurrence.OutputEndOffset <= lOccurrence.OutputStartOffset);
    if lStructurallyInvalid then
    begin
      aStructurallyValid := False;
      lOccurrenceValid := False;
    end;
    if (lOccurrence.Role = '') or
      (lOccurrence.FileName = '') or (lOccurrence.Line <= 0) or
      (lOccurrence.Column <= 0) or (lOccurrence.EndLine <> lOccurrence.Line) or
      (lOccurrence.EndColumn - lOccurrence.Column + 1 <>
        lOccurrence.OutputEndOffset - lOccurrence.OutputStartOffset) or
      (lOccurrence.ExpansionId = '') then
      lOccurrenceValid := False;
    if not lOccurrenceValid then
    begin
      lOccurrence.Verified := False;
      if lWasVerified or lStructurallyInvalid then
        Inc(aInvalidCount);
    end;
    Result[i] := lOccurrence;
  end;
end;

function WithStatementToJson(const aStatement: TDelphiSemanticWithStatement): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('Line', TJSONNumber.Create(aStatement.Line));
  Result.AddPair('Column', TJSONNumber.Create(aStatement.Column));
  Result.AddPair('EndLine', TJSONNumber.Create(aStatement.EndLine));
  Result.AddPair('EndColumn', TJSONNumber.Create(aStatement.EndColumn));
  Result.AddPair('BodyLine', TJSONNumber.Create(aStatement.BodyLine));
  Result.AddPair('BodyColumn', TJSONNumber.Create(aStatement.BodyColumn));
  Result.AddPair('BodyEndLine', TJSONNumber.Create(aStatement.BodyEndLine));
  Result.AddPair('BodyEndColumn', TJSONNumber.Create(aStatement.BodyEndColumn));
  Result.AddPair('SelectorText', aStatement.SelectorText);
  Result.AddPair('SelectorCount', TJSONNumber.Create(aStatement.SelectorCount));
  Result.AddPair('NestingDepth', TJSONNumber.Create(aStatement.NestingDepth));
  Result.AddPair('HasScopedDeclaration', TJSONBool.Create(aStatement.HasScopedDeclaration));
  Result.AddPair('BodyText', aStatement.BodyText);
  Result.AddPair('Text', aStatement.Text);
end;

function JsonToWithStatement(const aObject: TJSONObject): TDelphiSemanticWithStatement;
begin
  Result.Line := JsonInt(aObject, 'Line');
  Result.Column := JsonInt(aObject, 'Column');
  Result.EndLine := JsonInt(aObject, 'EndLine');
  Result.EndColumn := JsonInt(aObject, 'EndColumn');
  Result.BodyLine := JsonInt(aObject, 'BodyLine');
  Result.BodyColumn := JsonInt(aObject, 'BodyColumn');
  Result.BodyEndLine := JsonInt(aObject, 'BodyEndLine');
  Result.BodyEndColumn := JsonInt(aObject, 'BodyEndColumn');
  Result.SelectorText := JsonString(aObject, 'SelectorText');
  Result.SelectorCount := JsonInt(aObject, 'SelectorCount');
  Result.NestingDepth := JsonInt(aObject, 'NestingDepth');
  Result.HasScopedDeclaration := JsonBool(aObject, 'HasScopedDeclaration');
  Result.BodyText := JsonString(aObject, 'BodyText');
  Result.Text := JsonString(aObject, 'Text');
end;

function WithStatementsToJson(const aStatements: TArray<TDelphiSemanticWithStatement>): TJSONArray;
var
  lStatement: TDelphiSemanticWithStatement;
begin
  Result := TJSONArray.Create;
  for lStatement in aStatements do
    Result.AddElement(WithStatementToJson(lStatement));
end;

function JsonToWithStatements(const aArray: TJSONArray): TArray<TDelphiSemanticWithStatement>;
var
  i: Integer;
begin
  if not Assigned(aArray) then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  SetLength(Result, aArray.Count);
  for i := 0 to Pred(aArray.Count) do
    Result[i] := JsonToWithStatement(aArray.Items[i] as TJSONObject);
end;

function DiagnosticToJson(const aDiagnostic: TDelphiSemanticModelDiagnostic): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('Code', aDiagnostic.Code);
  Result.AddPair('Message', aDiagnostic.Message);
  Result.AddPair('FileName', aDiagnostic.FileName);
  Result.AddPair('Line', TJSONNumber.Create(aDiagnostic.Line));
end;

function JsonToDiagnostic(const aObject: TJSONObject): TDelphiSemanticModelDiagnostic;
begin
  Result.Code := JsonString(aObject, 'Code');
  Result.Message := JsonString(aObject, 'Message');
  Result.FileName := JsonString(aObject, 'FileName');
  Result.Line := JsonInt(aObject, 'Line');
end;

function DiagnosticsToJson(const aDiagnostics: TArray<TDelphiSemanticModelDiagnostic>): TJSONArray;
var
  lDiagnostic: TDelphiSemanticModelDiagnostic;
begin
  Result := TJSONArray.Create;
  for lDiagnostic in aDiagnostics do
    Result.AddElement(DiagnosticToJson(lDiagnostic));
end;

function JsonToDiagnostics(const aArray: TJSONArray): TArray<TDelphiSemanticModelDiagnostic>;
var
  i: Integer;
begin
  if not Assigned(aArray) then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  SetLength(Result, aArray.Count);
  for i := 0 to Pred(aArray.Count) do
    Result[i] := JsonToDiagnostic(aArray.Items[i] as TJSONObject);
end;

function UnindexedHelpersToJson(
  const aHelpers: TArray<TDelphiSemanticUnindexedHelperFact>): TJSONArray;
var
  lFact: TDelphiSemanticUnindexedHelperFact;
  lObject: TJSONObject;
begin
  Result := TJSONArray.Create;
  for lFact in aHelpers do
  begin
    lObject := TJSONObject.Create;
    lObject.AddPair('Name', lFact.Name);
    lObject.AddPair('HelperKind', lFact.HelperKind);
    lObject.AddPair('TargetName', lFact.TargetName);
    lObject.AddPair('SectionKind', lFact.SectionKind);
    lObject.AddPair('ScopeKind', lFact.ScopeKind);
    lObject.AddPair('OwnerScopeId', lFact.OwnerScopeId);
    lObject.AddPair('FileName', lFact.FileName);
    lObject.AddPair('Line', TJSONNumber.Create(lFact.Line));
    lObject.AddPair('Column', TJSONNumber.Create(lFact.Column));
    Result.AddElement(lObject);
  end;
end;

function HelperFactStringIsPresent(const aObject: TJSONObject; const aName: string): Boolean;
var
  lValue: TJSONValue;
begin
  lValue := aObject.GetValue(aName);
  // TJSONNumber inherits TJSONString. Only a JSON string has this exact class.
  // Empty metadata is emitted for incomplete AST facts and must round-trip.
  Result := Assigned(lValue) and (lValue.ClassType = TJSONString);
end;

function HelperFactCoordinate(const aObject: TJSONObject; const aName: string;
  out aCoordinate: Integer): Boolean;
var
  lValue: TJSONValue;
begin
  aCoordinate := 0;
  lValue := aObject.GetValue(aName);
  // The writer emits Integer tokens, including zero for unknown positions.
  // Reject coercions and out-of-range values rather than manufacturing zero.
  Result := (lValue is TJSONNumber) and TryStrToInt(lValue.Value, aCoordinate) and
    (aCoordinate >= 0);
end;

function JsonToUnindexedHelpers(const aValue: TJSONValue):
  TArray<TDelphiSemanticUnindexedHelperFact>;
var
  lArray: TJSONArray;
  lObject: TJSONObject;
  i, lCount, lLine, lColumn: Integer;
begin
  Result := nil;
  if not (aValue is TJSONArray) then
    Exit;
  lArray := TJSONArray(aValue);
  SetLength(Result, lArray.Count);
  lCount := 0;
  for i := 0 to Pred(lArray.Count) do
  begin
    if not (lArray.Items[i] is TJSONObject) then
      Continue;
    lObject := TJSONObject(lArray.Items[i]);
    // Invalid entries must leave the diagnostic/fact deficit visible to S3.
    if not HelperFactStringIsPresent(lObject, 'Name') or
      not HelperFactStringIsPresent(lObject, 'HelperKind') or
      not HelperFactStringIsPresent(lObject, 'TargetName') or
      not HelperFactStringIsPresent(lObject, 'SectionKind') or
      not HelperFactStringIsPresent(lObject, 'ScopeKind') or
      not HelperFactStringIsPresent(lObject, 'OwnerScopeId') or
      not HelperFactStringIsPresent(lObject, 'FileName') then
      Continue;
    // These are the extractor's complete value sets. Unknown visibility values
    // must not bypass S3 and then disappear in the binder's S4 filtering.
    if not MatchStr(JsonString(lObject, 'HelperKind'), ['', 'record', 'class']) or
      not MatchStr(JsonString(lObject, 'SectionKind'),
        ['interface', 'implementation', 'initialization', 'finalization']) or
      not MatchStr(JsonString(lObject, 'ScopeKind'), ['unit', 'routine']) or
      not HelperFactCoordinate(lObject, 'Line', lLine) or
      not HelperFactCoordinate(lObject, 'Column', lColumn) then
      Continue;
    Result[lCount].Name := JsonString(lObject, 'Name');
    Result[lCount].HelperKind := JsonString(lObject, 'HelperKind');
    Result[lCount].TargetName := JsonString(lObject, 'TargetName');
    Result[lCount].SectionKind := JsonString(lObject, 'SectionKind');
    Result[lCount].ScopeKind := JsonString(lObject, 'ScopeKind');
    Result[lCount].OwnerScopeId := JsonString(lObject, 'OwnerScopeId');
    Result[lCount].FileName := JsonString(lObject, 'FileName');
    Result[lCount].Line := lLine;
    Result[lCount].Column := lColumn;
    Inc(lCount);
  end;
  SetLength(Result, lCount);
end;

function ModelToJson(const aModel: TDelphiSemanticUnitModel): string;
var
  lObject: TJSONObject;
begin
  lObject := TJSONObject.Create;
  try
    lObject.AddPair('Success', TJSONBool.Create(aModel.Success));
    lObject.AddPair('FileName', aModel.FileName);
    lObject.AddPair('UnitName', aModel.UnitName);
    lObject.AddPair('EncodingName', aModel.EncodingName);
    lObject.AddPair('LineEndingName', aModel.LineEndingName);
    lObject.AddPair('LineBreak', aModel.LineBreak);
    lObject.AddPair('SourceText', aModel.SourceText);
    lObject.AddPair('VerifiedActiveSourceText', aModel.VerifiedActiveSourceText);
    lObject.AddPair('ReferenceScanSourceText', aModel.ReferenceScanSourceText);
    lObject.AddPair('SourceSections', SourceSectionsToJson(aModel.SourceSections));
    lObject.AddPair('DependencyFacts', DependencyFactsToJson(aModel.DependencyFacts));
    lObject.AddPair('InterfaceUses', StringArrayToJson(aModel.InterfaceUses));
    lObject.AddPair('ImplementationUses', StringArrayToJson(aModel.ImplementationUses));
    lObject.AddPair('Declarations', DeclarationsToJson(aModel.Declarations));
    lObject.AddPair('Members', MembersToJson(aModel.Members));
    lObject.AddPair('Routines', RoutinesToJson(aModel.Routines));
    lObject.AddPair('Locals', LocalsToJson(aModel.Locals));
    lObject.AddPair('References', ReferencesToJson(aModel.References));
    lObject.AddPair('PhysicalReferenceOccurrences',
      PhysicalOccurrencesToJson(aModel.PhysicalReferenceOccurrences));
    lObject.AddPair('PhysicalReferenceOccurrencesAvailable',
      TJSONBool.Create(aModel.PhysicalReferenceOccurrencesAvailable));
    lObject.AddPair('LocalLabelReferences', ReferencesToJson(aModel.LocalLabelReferences));
    lObject.AddPair('WithStatements', WithStatementsToJson(aModel.WithStatements));
    lObject.AddPair('Diagnostics', DiagnosticsToJson(aModel.Diagnostics));
    if Length(aModel.UnindexedHelpers) > 0 then
      lObject.AddPair('UnindexedHelpers', UnindexedHelpersToJson(aModel.UnindexedHelpers));
    if Length(aModel.TypeValueMembers) > 0 then
      lObject.AddPair('TypeValueMembers', MembersToJson(aModel.TypeValueMembers));
    lObject.AddPair('ScopeModelStatus', aModel.ScopeModelStatus);
    lObject.AddPair('ScopeModelVersion', aModel.ScopeModelVersion);
    lObject.AddPair('RejectedDeclarationCount',
      TJSONNumber.Create(aModel.RejectedDeclarationCount));
    Result := lObject.ToJSON;
  finally
    lObject.Free;
  end;
end;

function JsonToModel(const aJson: string): TDelphiSemanticUnitModel;
var
  lInvalidOccurrenceCount: Integer;
  lOccurrencesValid: Boolean;
  lOccurrencesValue: TJSONValue;
  lObject: TJSONObject;
  lValue: TJSONValue;
begin
  Result := Default(TDelphiSemanticUnitModel);
  lValue := TJSONObject.ParseJSONValue(aJson);
  try
    if not (lValue is TJSONObject) then
      Exit;
    lObject := lValue as TJSONObject;
    Result.Success := JsonBool(lObject, 'Success');
    Result.FileName := JsonString(lObject, 'FileName');
    Result.UnitName := JsonString(lObject, 'UnitName');
    Result.EncodingName := JsonString(lObject, 'EncodingName');
    Result.LineEndingName := JsonString(lObject, 'LineEndingName');
    Result.LineBreak := JsonString(lObject, 'LineBreak');
    Result.SourceText := JsonString(lObject, 'SourceText');
    Result.VerifiedActiveSourceText := JsonString(lObject, 'VerifiedActiveSourceText');
    Result.ReferenceScanSourceText := JsonString(lObject, 'ReferenceScanSourceText');
    Result.SourceSections := JsonToSourceSections(lObject.GetValue('SourceSections') as TJSONObject);
    Result.DependencyFacts := JsonToDependencyFacts(lObject.GetValue('DependencyFacts'));
    Result.InterfaceUses := JsonToStringArray(lObject.GetValue('InterfaceUses') as TJSONArray);
    Result.ImplementationUses := JsonToStringArray(lObject.GetValue('ImplementationUses') as TJSONArray);
    Result.Declarations := JsonToDeclarations(lObject.GetValue('Declarations') as TJSONArray);
    Result.Members := JsonToMembers(lObject.GetValue('Members') as TJSONArray);
    Result.Routines := JsonToRoutines(lObject.GetValue('Routines') as TJSONArray);
    Result.Locals := JsonToLocals(lObject.GetValue('Locals') as TJSONArray);
    Result.References := JsonToReferences(lObject.GetValue('References') as TJSONArray);
    lOccurrencesValue := lObject.GetValue('PhysicalReferenceOccurrences');
    if lOccurrencesValue is TJSONArray then
      Result.PhysicalReferenceOccurrences := JsonToPhysicalOccurrences(
        lOccurrencesValue as TJSONArray, lOccurrencesValid, lInvalidOccurrenceCount)
    else begin
      lOccurrencesValid := False;
      lInvalidOccurrenceCount := Ord(Assigned(lOccurrencesValue));
    end;
    Result.PhysicalReferenceOccurrencesAvailable := lOccurrencesValid and
      (lObject.GetValue('PhysicalReferenceOccurrencesAvailable') is TJSONBool) and
      JsonBool(lObject, 'PhysicalReferenceOccurrencesAvailable');
    Result.LocalLabelReferences := JsonToReferences(lObject.GetValue('LocalLabelReferences') as TJSONArray);
    Result.WithStatements := JsonToWithStatements(lObject.GetValue('WithStatements') as TJSONArray);
    Result.Diagnostics := JsonToDiagnostics(lObject.GetValue('Diagnostics') as TJSONArray);
    if lInvalidOccurrenceCount > 0 then
    begin
      SetLength(Result.Diagnostics, Length(Result.Diagnostics) + 1);
      Result.Diagnostics[High(Result.Diagnostics)].Code :=
        'PHYSICAL_REFERENCE_JSON_UNVERIFIED';
      Result.Diagnostics[High(Result.Diagnostics)].Message :=
        IntToStr(lInvalidOccurrenceCount) + ' malformed physical occurrence(s) stayed unverified.';
      Result.Diagnostics[High(Result.Diagnostics)].FileName := Result.FileName;
    end;
    Result.UnindexedHelpers := JsonToUnindexedHelpers(lObject.GetValue('UnindexedHelpers'));
    Result.TypeValueMembers := JsonToMembers(lObject.GetValue('TypeValueMembers') as TJSONArray);
    Result.ScopeModelStatus := JsonString(lObject, 'ScopeModelStatus');
    Result.ScopeModelVersion := JsonString(lObject, 'ScopeModelVersion');
    Result.RejectedDeclarationCount := JsonInt(lObject, 'RejectedDeclarationCount');
  finally
    lValue.Free;
  end;
end;

end.
