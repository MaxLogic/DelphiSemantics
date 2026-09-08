unit DelphiSemantics.Model.Json;

interface

uses
  DelphiSemantics.Model;

function ModelToJson(const aModel: TDelphiSemanticUnitModel): string;
function JsonToModel(const aJson: string): TDelphiSemanticUnitModel;

implementation

uses
  System.JSON, System.SysUtils;

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

function DeclarationToJson(const aDeclaration: TDelphiSemanticDeclaration): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('Name', aDeclaration.Name);
  Result.AddPair('Kind', aDeclaration.Kind);
  Result.AddPair('TypeName', aDeclaration.TypeName);
  Result.AddPair('BaseTypeName', aDeclaration.BaseTypeName);
  Result.AddPair('HelperTargetName', aDeclaration.HelperTargetName);
  Result.AddPair('SectionKind', aDeclaration.SectionKind);
  Result.AddPair('Line', TJSONNumber.Create(aDeclaration.Line));
  Result.AddPair('Column', TJSONNumber.Create(aDeclaration.Column));
  Result.AddPair('Offset', TJSONNumber.Create(aDeclaration.Offset));
  Result.AddPair('EndOffset', TJSONNumber.Create(aDeclaration.EndOffset));
  Result.AddPair('DeclarationRole', aDeclaration.DeclarationRole);
  Result.AddPair('ScopeKind', aDeclaration.ScopeKind);
  Result.AddPair('OwnerName', aDeclaration.OwnerName);
  Result.AddPair('OwnerScopeId', aDeclaration.OwnerScopeId);
  Result.AddPair('SymbolId', aDeclaration.SymbolId);
  Result.AddPair('Mutable', TJSONBool.Create(aDeclaration.Mutable));
end;

function JsonToDeclaration(const aObject: TJSONObject): TDelphiSemanticDeclaration;
begin
  Result.Name := JsonString(aObject, 'Name');
  Result.Kind := JsonString(aObject, 'Kind');
  Result.TypeName := JsonString(aObject, 'TypeName');
  Result.BaseTypeName := JsonString(aObject, 'BaseTypeName');
  Result.HelperTargetName := JsonString(aObject, 'HelperTargetName');
  Result.SectionKind := JsonString(aObject, 'SectionKind');
  Result.Line := JsonInt(aObject, 'Line');
  Result.Column := JsonInt(aObject, 'Column');
  Result.Offset := JsonInt(aObject, 'Offset');
  Result.EndOffset := JsonInt(aObject, 'EndOffset');
  Result.DeclarationRole := JsonString(aObject, 'DeclarationRole');
  Result.ScopeKind := JsonString(aObject, 'ScopeKind');
  Result.OwnerName := JsonString(aObject, 'OwnerName');
  Result.OwnerScopeId := JsonString(aObject, 'OwnerScopeId');
  Result.SymbolId := JsonString(aObject, 'SymbolId');
  Result.Mutable := JsonBool(aObject, 'Mutable');
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
  Result.AddPair('Name', aMember.Name);
  Result.AddPair('Kind', aMember.Kind);
  Result.AddPair('TypeName', aMember.TypeName);
  Result.AddPair('Visibility', aMember.Visibility);
  Result.AddPair('Signature', aMember.Signature);
  Result.AddPair('IsIndexed', TJSONBool.Create(aMember.IsIndexed));
  Result.AddPair('IsDefault', TJSONBool.Create(aMember.IsDefault));
  Result.AddPair('Line', TJSONNumber.Create(aMember.Line));
  Result.AddPair('Column', TJSONNumber.Create(aMember.Column));
  Result.AddPair('Offset', TJSONNumber.Create(aMember.Offset));
  Result.AddPair('EndOffset', TJSONNumber.Create(aMember.EndOffset));
end;

function JsonToMember(const aObject: TJSONObject): TDelphiSemanticMember;
begin
  Result.OwnerName := JsonString(aObject, 'OwnerName');
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
  Result.AddPair('ReturnType', aRoutine.ReturnType);
  Result.AddPair('Line', TJSONNumber.Create(aRoutine.Line));
  Result.AddPair('Column', TJSONNumber.Create(aRoutine.Column));
  Result.AddPair('Offset', TJSONNumber.Create(aRoutine.Offset));
  Result.AddPair('EndOffset', TJSONNumber.Create(aRoutine.EndOffset));
  Result.AddPair('EndLine', TJSONNumber.Create(aRoutine.EndLine));
  Result.AddPair('EndColumn', TJSONNumber.Create(aRoutine.EndColumn));
  Result.AddPair('ScopeId', aRoutine.ScopeId);
  Result.AddPair('ParentScopeId', aRoutine.ParentScopeId);
  Result.AddPair('Parameters', ParametersToJson(aRoutine.Parameters));
end;

function JsonToRoutine(const aObject: TJSONObject): TDelphiSemanticRoutine;
begin
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
  Result.Parameters := JsonToParameters(aObject.GetValue('Parameters') as TJSONArray);
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
    lObject.AddPair('SourceSections', SourceSectionsToJson(aModel.SourceSections));
    lObject.AddPair('InterfaceUses', StringArrayToJson(aModel.InterfaceUses));
    lObject.AddPair('ImplementationUses', StringArrayToJson(aModel.ImplementationUses));
    lObject.AddPair('Declarations', DeclarationsToJson(aModel.Declarations));
    lObject.AddPair('Members', MembersToJson(aModel.Members));
    lObject.AddPair('Routines', RoutinesToJson(aModel.Routines));
    lObject.AddPair('Locals', LocalsToJson(aModel.Locals));
    lObject.AddPair('References', ReferencesToJson(aModel.References));
    lObject.AddPair('WithStatements', WithStatementsToJson(aModel.WithStatements));
    lObject.AddPair('Diagnostics', DiagnosticsToJson(aModel.Diagnostics));
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
    Result.SourceSections := JsonToSourceSections(lObject.GetValue('SourceSections') as TJSONObject);
    Result.InterfaceUses := JsonToStringArray(lObject.GetValue('InterfaceUses') as TJSONArray);
    Result.ImplementationUses := JsonToStringArray(lObject.GetValue('ImplementationUses') as TJSONArray);
    Result.Declarations := JsonToDeclarations(lObject.GetValue('Declarations') as TJSONArray);
    Result.Members := JsonToMembers(lObject.GetValue('Members') as TJSONArray);
    Result.Routines := JsonToRoutines(lObject.GetValue('Routines') as TJSONArray);
    Result.Locals := JsonToLocals(lObject.GetValue('Locals') as TJSONArray);
    Result.References := JsonToReferences(lObject.GetValue('References') as TJSONArray);
    Result.WithStatements := JsonToWithStatements(lObject.GetValue('WithStatements') as TJSONArray);
    Result.Diagnostics := JsonToDiagnostics(lObject.GetValue('Diagnostics') as TJSONArray);
    Result.ScopeModelStatus := JsonString(lObject, 'ScopeModelStatus');
    Result.ScopeModelVersion := JsonString(lObject, 'ScopeModelVersion');
    Result.RejectedDeclarationCount := JsonInt(lObject, 'RejectedDeclarationCount');
  finally
    lValue.Free;
  end;
end;

end.
