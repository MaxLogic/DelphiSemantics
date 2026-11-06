"""Developer-only dcc64 oracle for Test.TypeVisibilityNative.

The Pascal fixture supplies all five real planner routes. This script generates
bounded inputs and compiles/runs the original and actual published text edits.
It deliberately does not implement Delphi name resolution.
"""
from pathlib import Path
import argparse
import hashlib
import os
import json
import re
import shutil
import subprocess
import time
import xml.etree.ElementTree as ET


SHAPES = ("plain", "field", "pointer", "array", "class-field", "function",
          "property", "helper", "nested", "multi", "pointer-temp", "initialization")
MODES = ("none", "indexed", "unknown", "sdk", "default-alias", "project-alias", "conflict")
HISTORICAL = (
    "m1-varparam-method-record", "m2-unit-level-with", "m3-global-pointer-alias",
    "m4-field-pointer-alias", "m5-type-only-in-unknown-unit", "m6-ds752-varparam-sdk-token",
    "m7-varparam-sdk-pair-token-present", "ce1-inc-refdir", "ce2-inc-includepath",
    "ce3-inc-debugpath", "ce4-default-alias", "ce5-nested-include-base",
    "ce6-project-alias-default-key", "ce6b-project-alias-twice",
    "u-pointer-alias-capture", "u-pointer-alias-reference", "u-pointer-pointee-capture",
)


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(text.replace("\r\n", "\n").replace("\n", "\r\n").encode("ascii"))


def project(root, refs, search="s", aliases="", msbuild_properties=None):
    write(root / "P.dproj", '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">'
          '<PropertyGroup><MainSource>P.dpr</MainSource><DCC_Namespace>System;Winapi</DCC_Namespace>'
          f'<DCC_UnitSearchPath>{search}</DCC_UnitSearchPath><DCC_UnitAlias>{aliases}</DCC_UnitAlias>'
          '</PropertyGroup><ItemGroup>' + ''.join(f'<DCCReference Include="{x}.pas"/>' for x in refs)
          + '</ItemGroup></Project>')
    if msbuild_properties is not None:
        # These rows use the installed Delphi targets and MSBuild, including
        # the targets' evaluated include path rather than a handmade dcc -I.
        path = root / "P.dproj"
        text = path.read_text()
        properties = {"AppType": "Console", "FrameworkType": "None",
                      "ProjectVersion": "20.2", "DS719NativeMSBuild": "true",
                      "DCC_ExeOutput": "native/msbuild", "DCC_DcuOutput": "native/msbuild",
                      **msbuild_properties}
        extra = '<PropertyGroup>' + ''.join(
            '<' + key + '>' + value + '</' + key + '>' for key, value in properties.items()) + '</PropertyGroup>'
        text = text.replace('</Project>', extra +
            '<ItemGroup><DelphiCompile Include="$(MainSource)"/></ItemGroup>' +
            '<Import Project="$(BDS)\\Bin\\CodeGear.Delphi.Targets" '
            "Condition=\"Exists('$(BDS)\\Bin\\CodeGear.Delphi.Targets')\"/></Project>")
        write(path, text)
    units = ', '.join(f"{Path(x).name} in '{x}.pas'" for x in refs)
    write(root / "P.dpr", "program P; {$APPTYPE CONSOLE} uses " + units + "; begin Unit1.Run; end.\n")


def generated(root, shape, mode, before, implementation, absent=False):
    # Layout sizes expose dcc64's chosen declaration independently of DS.
    typename = "TPoint" if mode in ("sdk", "default-alias", "conflict") else "TX"
    shadow = {"sdk": "System.Types", "default-alias": "Types", "project-alias": "K",
              "conflict": "K"}.get(mode, "U")
    if mode == "default-alias":
        # WinTypes is an installed default alias; its TPoint is defined in Windows.
        shadow = "WinTypes"
    aliases = "K=U;" if mode == "project-alias" else ""
    if mode == "conflict":
        aliases = "K=A;K=System.Types;"
    uses = "A" if mode == "none" else (shadow + ", A" if before else "A, " + shadow)
    write(root / "A.pas", f"unit A;\ninterface\ntype\n  {typename} = record\n    X: Integer;\n  end;\nimplementation\nend.\n")
    write(root / "s/U.pas", "unit U;\ninterface\n" +
          ("const Unrelated = 1;\n" if absent else f"type\n  {typename} = record\n    X, Y, Padding: Integer;\n  end;\n") +
          "implementation\nend.\n")
    refs = ["Unit1", "A", "B"]
    if mode == "indexed" or absent:
        refs.append("s/U")
    extra = ""
    declarations = f"""type
  TOuter = record
    Sub: {typename};
  end;
  PX = ^{typename};
  TArr = array[0..1] of {typename};
  THolder = class
  public
    FSub: {typename};
    function GetSub: {typename};
    property Prop: {typename} read GetSub;
  end;
  TRecHelper = record helper for {typename}
    procedure Mark;
  end;
var Item: {typename}; O: TOuter; P: PX; Arr: TArr; H: THolder;
function GetItem: {typename};
function TypeWitness: Integer;
"""
    bodies = f"""function THolder.GetSub: {typename}; begin Result := FSub; end;
procedure TRecHelper.Mark; begin end;
function GetItem: {typename}; begin Result := Item; end;
function TypeWitness: Integer; begin Result := SizeOf({typename}); end;
"""
    selector = {"plain": "Item", "field": "O.Sub", "pointer": "P^", "array": "Arr[1]",
                "class-field": "H.FSub", "function": "GetItem", "property": "H.Prop",
                "helper": "Item", "nested": "Item", "multi": "O, O.Sub",
                "pointer-temp": "P^", "initialization": "Item"}[shape]
    body = "X := 1; Y := 5;"
    if shape == "helper":
        body = "Mark; " + body
    if shape in ("function", "property"):
        body = "Writeln('READ=', X);"
    if shape == "nested":
        body = "X := 1; with O.Sub do begin X := 1; Y := 5; end;"
    statement = f"with {selector} do begin {body} end;"
    run = ("procedure Run;\nvar\n  Y: Integer;\nbegin\n"
           "  Item.X := 0; O.Sub.X := 0; Arr[1].X := 0; P := @Item;\n"
           "  H := THolder.Create;\n  try\n    H.FSub.X := 0; Y := 0;\n  " + statement +
           "\n  Writeln('TYPE=', TypeWitness); Writeln('VALUE=', Y);\n  finally\n    H.Free;\n  end;\nend;\n")
    if shape == "initialization":
        run = "procedure Run; begin Writeln('TYPE=', TypeWitness); Writeln('VALUE=', Y); end;\n"
        extra = f"\ninitialization\nbegin\n  Y := 0;\n  {statement}\nend;\n"
        declarations += "var Y: Integer;\n"
    if implementation:
        declarations = declarations.replace(f"function GetItem: {typename};",
                                            f"function GetItem: {typename}; forward;")
        declarations = declarations.replace("function TypeWitness: Integer;",
                                            "function TypeWitness: Integer; forward;")
        b = "unit B; interface procedure Run; implementation\nuses " + uses + ";\n" + declarations + bodies + run + extra + "end.\n"
        unit = "unit Unit1; interface procedure Run; implementation uses B; procedure Run; begin B.Run; end; end.\n"
    else:
        b = "unit B; interface uses " + uses + ";\n" + declarations + "implementation\n" + bodies + "end.\n"
        unit = "unit Unit1; interface uses A, B; procedure Run; implementation\n" + run + extra + "end.\n"
        if shape == "initialization":
            unit = unit.replace("implementation\n", "implementation\nvar Y: Integer;\n")
    # Keep headers/sections and each variable on separate source lines, matching
    # the maintained native fixtures rather than stressing unrelated extraction.
    for key, value in (("; interface", ";\ninterface\n"), ("interface uses", "interface\nuses"),
                       ("; implementation", ";\nimplementation\n"), ("; procedure Run", ";\nprocedure Run"),
                       ("; O:", ";\nO:"), ("; P:", ";\nP:"), ("; Arr:", ";\nArr:"), ("; H:", ";\nH:")):
        b = b.replace(key, value)
        unit = unit.replace(key, value)
    write(root / "B.pas", b)
    write(root / "Unit1.pas", unit)
    project(root, refs, aliases=aliases)
    # Only generated selectors bind this oracle's target; helpers/outer receivers
    # have a different type and are excluded by their exact declared name.
    return {"private_types": {"B.pas": [[name, "B." + name] for name in (typename, "TOuter", "THolder")] if implementation else []}, "type_name": typename, "identity_sizes": {"4": "A", "12": "U", "8": "Winapi.Windows" if mode == "default-alias" else "System.Types"}}


def r7_cases(repo, root):
    cases = []
    # DS-719 Fix D: a forward class and its completion denote the local type.
    folder = root / 'r7-forward-class-declaration-site'
    write(folder/'A.pas', 'unit A;\ninterface\ntype TX = record Wrong: Integer; end;\nimplementation\nend.\n')
    write(folder/'B.pas', 'unit B;\ninterface\nuses A;\ntype TX = class;\nTHolder = record Item: TX; end;\nTX = class X: Integer; end;\nprocedure Run;\nimplementation\nvar H: THolder;\nprocedure Run;\nbegin\nH.Item := TX.Create;\nwith H.Item do\nbegin\nX := 7;\nend;\nWriteln(H.Item.X);\nH.Item.Free;\nend;\nend.\n')
    write(folder/'Unit1.pas', 'unit Unit1;\ninterface\nprocedure Run;\nimplementation\nuses B;\nprocedure Run; begin B.Run; end;\nend.\n')
    project(folder, ['Unit1', 'A', 'B'])
    cases.append(dict(name=folder.name, root=str(folder), family='r7-forward-class', require_identity=True))
    for name in ('r7-a7-dependent-parent', 'r7-a7-child-alone', 'r7-a7-known-parent-limit'):
        folder = root/name
        shutil.copytree(repo/'tests/fixtures/ds719-uses-order'/name, folder)
        cases.append(dict(name=name, root=str(folder), family='r7-a7-closure',
                          private_types={'Unit1.pas': [['TInner', 'Unit1.TInner']] +
                                         ([['TOuter', 'Unit1.TOuter']] if name.endswith('parent-limit') else [])}))
    retained = ('control-plain', 'local-type-plain', 'rev-init-conditional',
                'rev-init-decl-order-field', 'rev-init-decl-order-var',
                'silent-init-decl-order-sdk', 'silent-routine-decl-order-field-sdk',
                'silent-routine-decl-order-sdk')
    for name in retained:
        folder = root / ('r7-opus-' + name)
        shutil.copytree(repo / 'tests/fixtures/ds719-uses-order' / folder.name, folder)
        case = dict(name=folder.name, root=str(folder), family='r7-retained')
        if name == 'local-type-plain':
            case['private_types'] = {'Unit1.pas': [['TX', 'Unit1.TX']]}
        elif name.startswith('silent-'):
            case['private_types'] = {'B.pas': [['TPoint', 'B.TPoint']]}
        elif name.startswith('rev-init-decl-order'):
            case['private_types'] = {'B.pas': [['TX', 'B.TX']]}
        cases.append(case)
    for sdk in (False, True):
        typename = 'TPoint' if sdk else 'TX'; imported = 'System.Types' if sdk else 'A'
        for kind in ('later-var', 'later-field', 'later-interface', 'pointer-forward',
                     'nested-class', 'nested-record', 'unit-collision', 'split-uses',
                     'inherited-owner', 'default-property'):
            for depth in (1, 2):
                name = f'r7-{kind}-{ "sdk" if sdk else "indexed" }-{depth}'
                folder = root / name
                write(folder/'A.pas', 'unit A;\ninterface\ntype TX = record X, Y, Padding: Integer; end;\nimplementation\nend.\n')
                write(folder/'U.pas', 'unit U;\ninterface\ntype TX = record X: Integer; end;\nimplementation\nend.\n')
                decl = f'var Item: {typename};\n'; selector = 'Item'; extra = ''; prelude = ''; cleanup = ''
                uses = imported; interface_uses = ''
                local_catalog = []
                if kind == 'later-var':
                    decl += f'type {typename} = record X: Integer; end;\n'
                    local_catalog.append([typename, 'B.'+typename])
                elif kind == 'later-field':
                    decl = f'type TOuter = record Sub: {typename}; end;\ntype {typename} = record X: Integer; end;\nvar O: TOuter;\n'
                    selector = 'O.Sub'; local_catalog.append([typename, 'B.'+typename])
                elif kind == 'later-interface':
                    interface_uses = imported
                    decl = f'type {typename} = record X: Integer; end;\n'
                    extra = f'var Item: {typename};\n'
                    uses = ''
                elif kind == 'pointer-forward':
                    # Delphi explicitly permits this forward reference within
                    # one TYPE section. It must not bind the imported homonym.
                    decl = f'type PX = ^{typename};\n  {typename} = record X: Integer; end;\nvar Item: {typename}; P: PX;\n'
                    selector = 'P^'; prelude='P := @Item;\n'
                    local_catalog.append([typename, 'B.'+typename])
                elif kind.startswith('nested-'):
                    owner = 'class' if kind == 'nested-class' else 'record'
                    decl = f'type TContainer = {owner}\npublic\n  type {typename} = record X: Integer; end;\nend;\nvar Item: TContainer.{typename};\n'
                    local_catalog.append(['TContainer.'+typename, 'B.TContainer.'+typename])
                elif kind == 'unit-collision':
                    decl = f'type A = record\n  type {typename} = record X: Integer; end;\nend;\nvar Item: A.{typename};\n'
                    local_catalog.append(['A.'+typename,'B.A.'+typename])
                elif kind == 'split-uses':
                    if sdk:
                        interface_uses = 'System.Types'; uses = 'A'
                        extra = 'var Item: TPoint;\n'; decl=''
                    else:
                        interface_uses = 'A'; uses = 'U'
                        extra = 'var Item: TX;\n'; decl=''
                elif kind == 'inherited-owner':
                    # B declares the owner and its typed member; Unit1 imports
                    # a conflicting homonym at the WITH site (R3 fallback).
                    decl = f'type TBase = class\n  Sub: {typename};\nend;\n'
                    parent='TBase'
                    for index in range(depth):
                        decl += f'TDerived{index} = class({parent}) end;\n'; parent=f'TDerived{index}'
                    decl += f'var H: {parent};\n';selector='H.Sub'
                    prelude=f'H := {parent}.Create;\n';cleanup='H.Free;\n'
                elif kind == 'default-property':
                    decl='type '; extra=''
                    for index in range(depth):
                        result_type=typename if index==0 else f'THolder{index-1}'
                        decl += f'THolder{index} = class\n  Value: {result_type};\n  function GetItem(aIndex: Integer): {result_type};\n  property Items[aIndex: Integer]: {result_type} read GetItem; default;\nend;\n'
                        extra += f'function THolder{index}.GetItem(aIndex: Integer): {result_type};\nbegin\n  Result := Value;\nend;\n'
                    decl += f'var H: THolder{depth-1};\n'
                    prelude=''; cleanup=''
                    for index in range(depth):
                        receiver='H'+'.Value'*index
                        prelude += f'{receiver} := THolder{depth-index-1}.Create;\n'
                        cleanup = f'{receiver}.Free;\n'+cleanup
                    selector='H'+'[0]'*depth
                if kind=='later-interface':
                    # Reference in interface must ignore implementation types.
                    b = f'unit B;\ninterface\nuses {interface_uses};\n{extra}procedure Run;\nimplementation\n{decl}'
                    extra=''
                elif kind=='split-uses':
                    b = f'unit B;\ninterface\nuses {interface_uses};\n{extra}procedure Run;\nimplementation\nuses {uses};\n{decl}'
                    extra=''
                else:
                    b = f'unit B;\ninterface\nprocedure Run;\nimplementation\nuses {uses};\n{decl}'
                if depth==2 and kind not in ('inherited-owner', 'unit-collision','nested-class','nested-record','later-interface','split-uses'):
                    # Alias chain provides independent declared type positions.
                    b = b.replace(f'var Item: {typename};', f'type TAlias0 = {typename};\nTAlias1 = TAlias0;\nvar Item: TAlias1;')
                body = 'Writeln(\'READ=\', X); Outside := 5;' if kind == 'default-property' else 'X := 1; Outside := 5;'
                b += f'var Outside: Integer;\n{extra}procedure Run;\nbegin\n{prelude}  Outside := 0;\n  with {selector} do\n  begin\n    {body}\n  end;\n  Writeln(\'VALUE=\', Outside);\n{cleanup}end;\nend.\n'
                write(folder/'B.pas',b)
                write(folder/'Unit1.pas','unit Unit1;\ninterface\nprocedure Run;\nimplementation\nuses U, B;\nprocedure Run;\nbegin\n  B.Run;\nend;\nend.\n')
                if kind == 'inherited-owner':
                    write(folder/'B.pas', f'unit B;\ninterface\nuses {imported};\n'+decl+'implementation\nend.\n')
                    write(folder/'Unit1.pas', f'unit Unit1;\ninterface\nprocedure Run;\nimplementation\nuses B, U;\nvar Outside: Integer;\nprocedure Run;\nbegin\n{prelude}  Outside := 0;\n  with H.Sub do\n  begin\n    X := 1; Outside := 5;\n  end;\n  Writeln(\'VALUE=\', Outside);\n{cleanup}end;\nend.\n')
                project(folder,['Unit1','A','B','U'])
                cases.append(dict(name=name,root=str(folder),family='r7-'+kind,
                                  private_types={'B.pas':local_catalog},
                                  alias_types=([[f'B.TAlias{i}',f'B.TAlias{i}'] for i in range(2)]
                                      if 'type TAlias0' in b else [])))
    for sdk in (False, True):
        for depth in (1, 2, 3):
            name = f'r7-alias-chain-{ "sdk" if sdk else "indexed" }-{depth}'
            folder = root / name
            write(folder/'A.pas', 'unit A;\ninterface\ntype TX = record X: Integer; end;\nimplementation\nend.\n')
            imported = 'System.Types' if sdk else 'A'
            typename = 'TPoint' if sdk else 'TX'
            aliases = f'TAlias0 = {typename};\n'
            for index in range(1, depth + 1):
                aliases += f'TAlias{index} = TAlias{index-1};\n'
            write(folder/'B.pas', f'unit B;\ninterface\nuses {imported};\ntype {aliases}var Item: TAlias{depth};\nimplementation\nend.\n')
            write(folder/'Unit1.pas', 'unit Unit1;\ninterface\nprocedure Run;\nimplementation\nuses B;\nvar Outside: Integer;\nprocedure Run;\nbegin\n  Outside := 0;\n  with Item do\n  begin\n    X := 1; Outside := 5;\n  end;\n  Writeln(\'VALUE=\', Outside);\nend;\nend.\n')
            project(folder,['Unit1','A','B'])
            cases.append(dict(name=name, root=str(folder), family='r7-alias-chain',
                              alias_types=[[f'B.TAlias{i}', f'B.TAlias{i}'] for i in range(depth+1)]))
    for directive, closing in (('IF Declared(TObject)','IFEND'), ('IFDEF DS719_UNKNOWN_SYMBOL','ENDIF'), ('IFOPT R+','ENDIF')):
        for include in (False, True):
            name = 'r7-conditional-' + directive.split()[0].lower() + ('-include' if include else '-root')
            folder=root/name
            oracle=generated(folder,'plain','indexed',False,True)
            block='{$'+directive+'}\ntype TX = record X, Y, Padding: Integer; end;\n{$'+closing+'}\n'
            if include:
                write(folder/'s/types.inc',block);block='{$I types.inc}\n'
            write(folder/'s/U.pas','unit U;\ninterface\n'+block+'implementation\nend.\n')
            cases.append(dict(name=name,root=str(folder),family='r7-conditional',**oracle))
            control_name=name+'-known-absent'
            control=root/control_name
            shutil.copytree(folder,control)
            write(control/'s/U.pas','unit U;\ninterface\nimplementation\nend.\n')
            cases[-1]['known_absent']=control_name
            cases.append(dict(name=control_name,root=str(control),family='r7-conditional-control',**oracle))
    for depth in (1, 2, 3):
        name = f'r7-inherited-fallback-{depth}'
        folder = root/name
        write(folder/'A.pas', 'unit A;\ninterface\ntype TBase = class X: Integer; end;\nimplementation\nend.\n')
        declarations = ''; parent='TBase'
        for index in range(depth):
            declarations += f'TDerived{index} = class({parent}) end;\n'; parent=f'TDerived{index}'
        write(folder/'B.pas', f'unit B;\ninterface\nuses A;\ntype {declarations}var H: {parent};\nimplementation\nend.\n')
        write(folder/'U.pas', f'unit U;\ninterface\ntype TBase = class Outside: Integer; end;\nimplementation\nend.\n')
        write(folder/'Unit1.pas', f"unit Unit1;\ninterface\nprocedure Run;\nimplementation\nuses B, U;\nvar Outside: Integer;\nprocedure Run;\nbegin\n  H := B.{parent}.Create;\n  Outside := 0;\n  with H do begin X := 1; Outside := 5; end;\n  Writeln('VALUE=', H.X, ' ', Outside);\n  H.Free;\nend;\nend.\n")
        project(folder,['Unit1','A','B','U'])
        cases.append(dict(name=name,root=str(folder),family='r7-inherited-fallback'))
    return cases


def r8_cases(repo, root):
    """Body-binding counterexamples print both the member and its homonym.

    Each pair removes the outer homonym and unindexed imports in its control.
    Native contrast checks below independently prove that changing the binding
    changes output; a catalog annotation alone cannot establish that property.
    """
    cases = []
    for shape in ('field', 'variant-tag', 'property', 'method-call', 'helper-member',
                  'inherited-member', 'include-member'):
        for location in ('outer-local', 'own-global', 'used-global', 'unindexed-global'):
            for control in (False, True):
                name = f'r8-member-homonym-{shape}-{location}' + ('-control' if control else '')
                folder = root/name
                is_class = shape in ('property', 'method-call', 'inherited-member')
                refs = ['Unit1']; imports = ''; outer = ''; local = ''; bodies = ''
                if not control:
                    if location.endswith('global') and location not in ('own-global',):
                        write(folder/'s/U.pas', 'unit U;\ninterface\nvar Count: Integer;\nimplementation\nend.\n')
                        imports = 'uses U;\n'
                        if location == 'used-global':
                            refs.append('s/U')
                    elif location == 'own-global':
                        outer = 'var Count: Integer;\n'
                    else:
                        local = '  Count: Integer;\n'
                members = '    Count, Seen: Integer;\n'
                declaration = 'type\n  TRec = record\n'+members+'  end;\n'
                if shape == 'variant-tag':
                    declaration = 'type\n  TRec = record\n    Seen: Integer;\n    case Count: Integer of\n      0: (Value: Integer);\n  end;\n'
                elif shape == 'include-member':
                    write(folder/'members.inc', members)
                    declaration = 'type\n  TRec = record\n    {$I members.inc}\n  end;\n'
                elif shape == 'property':
                    declaration = 'type\n  TRec = class\n  public\n    Value, Seen: Integer;\n    property Count: Integer read Value;\n  end;\n'
                elif shape == 'method-call':
                    declaration = 'type\n  TRec = class\n  public\n    Value, Seen: Integer;\n    function Count: Integer;\n  end;\n'
                    bodies = 'function TRec.Count: Integer;\nbegin\n  Result := Value;\nend;\n'
                elif shape == 'inherited-member':
                    declaration = 'type\n  TBase = class\n  public\n    Count, Seen: Integer;\n  end;\n  TRec = class(TBase) end;\n'
                elif shape == 'helper-member':
                    declaration = ('type\n  TRec = record\n    Value, Seen: Integer;\n  end;\n'
                                   '  TRecHelper = record helper for TRec\n    function Count: Integer;\n  end;\n')
                    bodies = 'function TRecHelper.Count: Integer;\nbegin\n  Result := Value;\nend;\n'
                storage = 'Value' if shape in ('property', 'method-call', 'helper-member') else 'Count'
                init = '  Rec := TRec.Create;\n' if is_class else ''
                init += f'  Rec.{storage} := 7;\n  Rec.Seen := -1;\n'
                if not control:
                    init += '  Count := 19;\n'
                observed = "Rec.Seen, ' ', Rec."+storage
                if not control:
                    observed += ", ' ', Count"
                source = ('unit Unit1;\ninterface\n'+imports+declaration+'var Rec: TRec;\n'+outer+
                          'procedure Run;\nimplementation\n'+bodies+'procedure Run;\nvar\n  Outside: Integer;\n'+local+
                          'begin\n  Outside := 0;\n'+init+'  with Rec do\n  begin\n    Seen := Count;\n  end;\n'+
                          "  Writeln('VALUE=', "+observed+");\n"+('  Rec.Free;\n' if is_class else '')+'end;\nend.\n')
                write(folder/'Unit1.pas', source); project(folder, refs)
                case = dict(name=name, root=str(folder), family='r8-body-'+shape,
                            expect_plan=control, body_binding=True)
                if not control:
                    # Replacing the body spelling with a known distinct literal
                    # models the alternate binding without implementing lookup.
                    case['binding_contrast'] = ['Seen := Count;', 'Seen := 19;']
                cases.append(case)
    retained = root/'r8-variant-tag-include-count'
    shutil.copytree(repo/'tests/fixtures/ds719-uses-order/r8-variant-tag-include-count', retained)
    cases.append(dict(name=retained.name, root=str(retained), family='r8-count',
                      binding_contrast=['A := Count;', 'A := 19;']))
    # The retained counterexample's Cartesian variants cover named/anonymous
    # records, root/include declarations, fields/tags and three global scopes.
    template = (retained/'Unit1.pas').read_text(encoding='ascii')
    for named in (False, True):
        for include in (False, True):
            for tag in (False, True):
                for location in ('own', 'used', 'unindexed'):
                    name = f'r8-count-{ "named" if named else "anonymous" }-{ "include" if include else "root" }-{ "tag" if tag else "field" }-{location}'
                    folder = root/name; text = template
                    declaration = 'case Count: Integer of\n' if tag else 'Count: Integer;\n'
                    if include:
                        write(folder/'tag.inc', declaration)
                    else:
                        text = text.replace('{$I tag.inc}', declaration)
                    if not tag:
                        text = text.replace('0: (X: Integer);', 'X: Integer;')
                    if named:
                        text = text.replace('var\n  Rec: record', 'type\n  TRec = record').replace('  end;\nvar Count:', '  end;\nvar Rec: TRec;\nvar Count:')
                    refs = ['Unit1']
                    if location != 'own':
                        text = text.replace('interface\n', 'interface\nuses U;\n').replace('var Count: Integer;\n', '')
                        write(folder/'s/U.pas', 'unit U;\ninterface\nvar Count: Integer;\nimplementation\nend.\n')
                        if location == 'used':
                            refs.append('s/U')
                    write(folder/'Unit1.pas', text); project(folder, refs)
                    control = root/(name+'-control')
                    shutil.copytree(folder, control)
                    control_text = text.replace('var Count: Integer;', 'var Other: Integer;')
                    control_text = control_text.replace('  Count := 19;', '  Other := 19;')
                    control_text = control_text.replace("' ', Count", "' ', Other")
                    if location != 'own':
                        write(control/'s/U.pas', (control/'s/U.pas').read_text().replace('Count', 'Other'))
                    write(control/'Unit1.pas', control_text)
                    cases.append(dict(name=name+'-control', root=str(control), family='r8-count-control', expect_plan=True))
                    cases.append(dict(name=name, root=str(folder), family='r8-count', known_absent=name+'-control',
                                      binding_contrast=['A := Count;', 'A := 19;']))
    # Control for the capture path: the compiler-paired SDK Types unit has
    # no TX declaration. A4 still refuses an unpaired project-unit absence.
    folder = root/'r8-sdk-paired-absence-control'
    oracle = generated(folder, 'pointer-temp', 'sdk', False, False)
    for path in folder.rglob('*.pas'):
        write(path, path.read_text().replace('TPoint', 'TX'))
    oracle['type_name'] = 'TX'
    cases.append(dict(name=folder.name, root=str(folder), family='r8-sdk-absence',
                      expect_plan=True, **oracle))
    # Declaration-site split: the WITH unit cannot see either the type or the
    # imports that decide the intermediate field/pointer/array spelling.
    for shape in ('field', 'pointer', 'array', 'class-field'):
        for control in (False, True):
            name = 'r8-declaring-unit-split-'+shape+('-control' if control else '')
            folder = root/name
            oracle = generated(folder, shape, 'indexed' if control else 'unknown', False, False)
            cases.append(dict(name=name, root=str(folder), family='r8-declaring-site',
                              expect_plan=control, **oracle))
    for site in ('method-local', 'method-temp', 'field-type'):
        for sdk in (False, True):
            for control in (False, True):
                name = f'r8-class-nested-{site}-{ "sdk" if sdk else "indexed" }'+('-control' if control else '')
                folder = root/name
                nested = 'TX' if not control else 'TOther'
                imports = 'System.Classes' if sdk else ''
                base = 'TComponent' if sdk else 'TBase'
                declarations = '' if sdk else f'  TBase = class\n  public\n    type {nested} = record X: Integer; end;\n  end;\n'
                fields = '    Item: TX;\n' if site == 'field-type' else ''
                local = 'var\n  Item: TX;\n' if site != 'field-type' else ''
                selector = 'Item'
                if site == 'method-temp':
                    fields += '    function GetItem: TX;\n'
                    selector = 'GetItem'
                source = ('unit Unit1;\ninterface\n'+('uses '+imports+';\n' if imports else '')+
                          'type\n  TX = record X, Padding: Integer; end;\n'+declarations+
                          f'  TDerived = class({base})\n  public\n'+fields+'    procedure Execute;\n  end;\nprocedure Run;\nimplementation\n')
                if site == 'method-temp':
                    source += 'function TDerived.GetItem: TX;\nbegin\n  Result.X := 7;\nend;\n'
                source += ('procedure TDerived.Execute;\n'+local+'begin\n'+('  Item.X := 7;\n' if site != 'method-temp' else '')+
                           f'  with {selector} do\n  begin\n    Writeln(\'READ=\', X);\n  end;\nend;\n'+
                           'procedure Run;\nvar\n  Obj: TDerived;\nbegin\n'+('  Obj := TDerived.Create(nil);\n' if sdk else '  Obj := TDerived.Create;\n')+
                           '  Obj.Execute;\n  Obj.Free;\nend;\nend.\n')
                write(folder/'Unit1.pas',source); project(folder,['Unit1'])
                cases.append(dict(name=name, root=str(folder), family='r8-class-scope',
                                  expect_plan=control))
    for order in ('ab', 'ba', 'au', 'implementation'):
        for control in (False, True):
            name = 'r8-root-var-order-'+order+('-control' if control else '')
            folder=root/name
            for unit in ('A','B','U'):
                write(folder/('s/'+unit+'.pas'), f'unit {unit};\ninterface\ntype TRec = record X: Integer; end;\nvar Item: TRec;\nimplementation\nend.\n')
            units={'ab':'A, B','ba':'B, A','au':'A, U','implementation':'A'}[order]
            refs=['Unit1','s/A','s/B']+(['s/U'] if order!='au' or control else [])
            body = ("procedure Run;\nbegin\n  A.Item.X := 7;\n  "+('U' if order=='au' else 'B')+".Item.X := 19;\n  with Item do X := 5;\n  Writeln('VALUE=', A.Item.X, ' ', "+('U' if order=='au' else 'B')+".Item.X);\nend;\n")
            source='unit Unit1;\ninterface\nuses '+units+';\nprocedure Run;\nimplementation\n'+('uses B;\n' if order=='implementation' else '')+body+'end.\n'
            write(folder/'Unit1.pas',source);project(folder,refs)
            cases.append(dict(name=name,root=str(folder),family='r8-value-root',expect_plan=control))
    for order in ('ab','ba','unknown'):
        for control in (False,True):
            name='r8-helper-order-'+order+('-control' if control else '')
            folder=root/name
            write(folder/'Base.pas','unit Base;\ninterface\ntype TRec = record X: Integer; end;\nimplementation\nend.\n')
            for unit,value in (('A',7),('B',19)):
                write(folder/(unit+'.pas'),f'unit {unit};\ninterface\nuses Base;\ntype THelper = record helper for TRec\n  function Count: Integer;\nend;\nimplementation\nfunction THelper.Count: Integer;\nbegin\n  Result := {value};\nend;\nend.\n')
            units='B, A' if order=='ba' else 'A, B'
            if order=='unknown' and not control:
                units+=', U';write(folder/'s/U.pas','unit U;\ninterface\nimplementation\nend.\n')
            write(folder/'Unit1.pas','unit Unit1;\ninterface\nuses Base, '+units+';\nprocedure Run;\nimplementation\nvar Rec: TRec;\nprocedure Run;\nbegin\n  with Rec do X := Count;\n  Writeln(\'VALUE=\', Rec.X);\nend;\nend.\n')
            project(folder,['Unit1','Base','A','B'])
            cases.append(dict(name=name,root=str(folder),family='r8-helper',expect_plan=control))
    for temp in (False,True):
        for control in (False,True):
            name=('r8-temp-before-local-type' if temp else 'r8-local-later')+('-control' if control else '')
            folder=root/name
            write(folder/'A.pas','unit A;\ninterface\ntype TX = record X, Padding: Integer; end;\nimplementation\nend.\n')
            declaration='type TX = record X: Integer; end;\n'
            if temp:
                source=('unit Unit1;\ninterface\nuses A;\nprocedure Run;\nimplementation\n'+(declaration if control else '')+
                        'procedure Run;\n'+('' if control else declaration)+'var Item: TX;\n'+
                        'function GetItem: TX;\nbegin\n  Result := Item;\nend;\nbegin\n  Item.X := 7;\n  with GetItem do Writeln(\'READ=\', X);\nend;\nend.\n')
            else:
                source=('unit Unit1;\ninterface\nuses A;\nprocedure Run;\nimplementation\nprocedure Run;\n'+(declaration if control else '')+
                        'procedure Nested;\nvar Item: TX;\nbegin\n  Item.X := 7;\n  with Item do X := 5;\n  Writeln(\'VALUE=\', SizeOf(Item), \' \', Item.X);\nend;\n'+('' if control else declaration)+'begin\n  Nested;\nend;\nend.\n')
            write(folder/'Unit1.pas',source); project(folder,['Unit1','A'])
            case=dict(name=name,root=str(folder),family='r8-local-position',expect_plan=control)
            if control:
                case['private_types'] = {'Unit1.pas': [['TX', 'Unit1.TX']]}
            cases.append(case)
    for include in (False, True):
        for control in (False, True):
            name = 'r8-own-conditional-'+('include' if include else 'root')+('-control' if control else '')
            folder=root/name
            oracle=generated(folder,'plain','none',False,True)
            block='{$IF Declared(TObject)}\ntype TX = record X, Y: Integer; end;\n{$IFEND}\n'
            if control:
                block=''
            if include:
                write(folder/'own.inc',block);block='{$I own.inc}\n'
            p=folder/'B.pas';text=p.read_text();text=text.replace('type\n  TOuter',block+'type\n  TOuter')
            write(p,text)
            cases.append(dict(name=name,root=str(folder),family='r8-own-conditional',expect_plan=control,**oracle))
    for depth in (1,2):
        for control in (False,True):
            name=f'r8-anon-dotted-homonym-{depth}'+('-control' if control else '')
            folder=root/name
            # A nested routine named TOuter shadows the unit type TOuter.
            # Its anonymous local Sub gets the exact key TOuter.Sub; the
            # unit type has a legal nested Sub at that same spelling.
            leaf = 'record\n      X, Padding: Integer;\n    end'
            for _ in range(depth-1):
                leaf = 'record\n  public\n    type Sub = '+leaf+';\n  end'
            declarations = ('type\n  TOuter = record\n  public\n    type Sub = '+leaf+'; end;\n') if not control else ''
            nested='X: Integer;\n'
            for _ in range(depth-1):
                nested='Sub: record\n    '+nested+'  end;\n'
            selector='Sub'+'.Sub'*(depth-1)
            source=('unit Unit1;\ninterface\n'+declarations+'procedure Run;\nimplementation\nprocedure Run;\n'+
                    'procedure TOuter;\nvar\n  Sub: record\n  '+nested+'end;\nbegin\n'+
                    f'  {selector}.X := 7;\n  with {selector} do X := 5;\n  Writeln(\'VALUE=\', {selector}.X, \' \', SizeOf({selector}));\nend;\n'+
                    'begin\n  TOuter;\nend;\nend.\n')
            write(folder/'Unit1.pas',source);project(folder,['Unit1'])
            cases.append(dict(name=name,root=str(folder),family='r8-synthetic',expect_plan=control,
                              synthetic_collision=None if control else 'TOuter'+'.Sub'*depth))
    for case in cases:
        assert source_targets(Path(case['root'])), case['name']
        if case.get('binding_contrast'):
            before, after = case['binding_contrast']
            assert before != after and before in (Path(case['root'])/'Unit1.pas').read_text(), case['name']
    return cases


def denial_cases(root):
    cases = []
    for shape in ('call', 'indexed'):
        name = shape + '-collision-denial'
        folder = root / name
        if shape == 'call':
            member = 'function Count: Integer;'
            helper = 'function Count: Integer;'
            bodies = ('function TRec.Count: Integer; begin Result := 11; end;\n'
                      'function THelp.Count: Integer; begin Result := 19; end;\n')
            expression = 'Count()'
        else:
            member = 'Items: array[0..0] of Integer;'
            helper = 'function GetItem(Index: Integer): Integer; property Items[Index: Integer]: Integer read GetItem;'
            bodies = 'function THelp.GetItem(Index: Integer): Integer; begin Result := 19; end;\n'
            expression = 'Items[0]'
        write(folder / 'Unit1.pas', 'unit Unit1;\ninterface\ntype TRec = record ' + member +
              ' end;\nTHelp = record helper for TRec ' + helper + ' end;\n' +
              'procedure Run;\nimplementation\n' + bodies +
              'procedure Run;\nvar R: TRec;\n  OutValue: Integer;\nbegin\n' +
              '  with R do OutValue := ' + expression + ';\n  Writeln(OutValue);\nend;\nend.\n')
        project(folder, ['Unit1'])
        cases.append(dict(name=name, root=str(folder), family='binder-denial', denial_reference=expression.split('(')[0].split('[')[0]))
    return cases


def helper_kind_cases(root):
    cases = []
    folder = root / 'helper-shortstring-not-record'
    write(folder / 'Unit1.pas', 'unit Unit1;\ninterface\n'
          'type TRec = record X: Integer; end;\nTShort = string[255];\n'
          'THelp = record helper for TShort function Count: Integer; end;\n'
          'procedure Run;\nimplementation\n'
          'function THelp.Count: Integer; begin Result := 19; end;\n'
          'procedure Run; var R: TRec; begin with R do Writeln(Count); end;\nend.\n')
    project(folder, ['Unit1'])
    cases.append(dict(name=folder.name, root=str(folder), family='helper-kind', expected_native_error='E2003'))
    folder = root / 'pointer-hop-helper'
    write(folder / 'Unit1.pas', 'unit Unit1;\ninterface\n'
          'type TRec = record X: Integer; end;\nPRec = ^TRec;\n'
          'THelp = record helper for TRec function Next: TRec; end;\n'
          'procedure Run;\nimplementation\n'
          'function THelp.Next: TRec; begin Result.X := 19; end;\n'
          'procedure Run;\nvar\n  R: TRec;\n  P: PRec;\nbegin\n  P := @R;\n'
          '  with P.Next do Writeln(X);\nend;\nend.\n')
    project(folder, ['Unit1'])
    cases.append(dict(name=folder.name, root=str(folder), family='helper-kind', expected_native_output='19\r\n'))
    return cases


def helper_evidence_cases(repo, root):
    cases = []
    fixtures = repo / 'tests/fixtures/ds719-helper-evidence'
    for shape, filename, output in (
            ('branch-hole', 'BranchHole.dpr', '19\r\n7\r\n'),
            ('probe', 'Probe.dpr', '19\r\n'),
            ('external-switch', 'ExternalDefine.dpr', '19\r\n7\r\n'),
            ('external-caller', 'ExternalDefine.dpr', '19\r\n7\r\n')):
        name = 'helper-' + shape
        folder = root / name
        folder.mkdir(parents=True)
        shutil.copy2(fixtures / filename, folder / filename)
        switches = '-DREVIEW_FEATURE' if shape == 'external-switch' else ''
        write(folder / 'P.dproj',
              '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">'
              '<PropertyGroup><MainSource>' + filename + '</MainSource>'
              '<DCC_AdditionalSwitches>' + switches + '</DCC_AdditionalSwitches>'
              '</PropertyGroup></Project>')
        case = dict(name=name, root=str(folder), family='helper-declaration-evidence',
                    expected_native_output=output)
        if shape == 'probe':
            case['native_only'] = True  # The exact Probe.dpr contains no WITH.
        if shape.startswith('external-'):
            case['native_defines'] = ['REVIEW_FEATURE']
        if shape == 'external-caller':
            case['caller_defines'] = ['REVIEW_FEATURE']
        cases.append(case)
    return cases


def multiline_var_cases(root):
    folder = root / 'multiline-initialized-var-root'
    write(folder / 'Unit1.pas', 'unit Unit1;\ninterface\n'
          'type TRec = record X: Integer; end;\n  PRec = ^TRec;\n'
          'const MaxText = 2;\n'
          'var TextFiles: array [1 .. MaxText] of PRec = (\n'
          '  nil,\n  nil\n);\n'
          'procedure Run;\nimplementation\n'
          'procedure Run;\nvar R: TRec;\nbegin\n  R.X := 23; TextFiles[1] := @R;\n'
          '  with TextFiles[1]^ do Writeln(X);\nend;\nend.\n')
    project(folder, ['Unit1'])
    return [dict(name=folder.name, root=str(folder), family='multiline-var',
                 expect_plan=True, expected_native_output='23\r\n')]


def msbuild_include_cases(repo, root):
    cases = []
    for retained in json.loads((repo / 'tests/fixtures/ds719-msbuild-includes.json').read_text()):
        folder = root / retained['name']
        for filename, text in retained['files'].items():
            write(folder / filename, text)
        environment = {key: value.replace('{D}', str(folder))
                       for key, value in retained.get('environment', {}).items()}
        (folder / 'native-environment.json').write_text(json.dumps(environment))
        cases.append({**{key: value for key, value in retained.items()
                         if key not in ('files', 'environment')}, 'root': str(folder)})
    return cases


def raw_compiler_include_search_path(root):
    # Shared by the actual raw-dcc invocation and its DS caller. Raw invocations
    # disable cfg loading, so these explicit -I directories are the complete list.
    ns = {"m": "http://schemas.microsoft.com/developer/msbuild/2003"}
    xml = ET.parse(root / 'P.dproj')
    def prop(key):
        values = xml.findall('./m:PropertyGroup/m:' + key, ns)
        return values[-1].text or '' if values else ''
    refs = [str((root / item.attrib['Include']).parent)
            for item in xml.findall('.//m:DCCReference', ns)]
    return [str(root), *[str(root / path) for path in prop('DCC_IncludePath').split(';') if path],
            *refs, *[str(root / path) for path in prop('DelphiDebugDCUPath').split(';') if path]]


def compiler_include_search_path(folder):
    # dcc command-line -I precedes response-file -I regardless of @ placement.
    # Within each source, repeated -I and semicolon entries retain first-listed order.
    # Our controlled native rows accept only measured include switches; unknown
    # contributors fail the fixture rather than silently certifying a partial list.
    import ctypes
    def words(text):
        count = ctypes.c_int()
        shell = ctypes.WinDLL('shell32', use_last_error=True)
        shell.CommandLineToArgvW.argtypes = [ctypes.c_wchar_p, ctypes.POINTER(ctypes.c_int)]
        shell.CommandLineToArgvW.restype = ctypes.POINTER(ctypes.c_wchar_p)
        kernel = ctypes.WinDLL('kernel32', use_last_error=True)
        kernel.LocalFree.argtypes = [ctypes.c_void_p]
        kernel.LocalFree.restype = ctypes.c_void_p
        pointer = shell.CommandLineToArgvW('dcc ' + text, ctypes.byref(count))
        if not pointer:
            raise ctypes.WinError(ctypes.get_last_error())
        try:
            return [pointer[i] for i in range(1, count.value)]
        finally:
            kernel.LocalFree(pointer)
    def paths(tokens, response=False):
        direct, deferred = [], []
        for token in tokens:
            if token.startswith('-I') and len(token) > 2:
                direct.extend(part for part in token[2:].split(';') if part)
            elif token.startswith('@') and len(token) > 1 and not response:
                filename = folder / token[1:]
                deferred.extend(paths(words(filename.read_text(encoding='utf-8-sig').replace('\r', ' ').replace('\n', ' ')), True))
            else:
                raise RuntimeError('Complete compiler include list unavailable: ' + token)
        return direct + deferred
    lines = (folder / 'captured-additional.txt').read_text(encoding='utf-8-sig').splitlines()
    assert lines[0] == 'DS719_BEGIN' and lines[-1] == 'DS719_END', lines
    switches = ';'.join(lines[1:-1])
    extras = paths(words(switches))
    captured = (folder / 'captured-include.txt').read_text(encoding='utf-8-sig').splitlines()
    return ';'.join(extras + captured)


def msbuild_include_invocation(root, bds, target, tag):
    targets = root / 'include-capture.targets'
    write(targets, '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">'
          '<Target Name="CaptureInclude" DependsOnTargets="__RemoveLatestBackSlashFromPaths;__GenerateUnitSearchPathFile">'
          '<WriteLinesToFile File="captured-include.txt" Lines="$(IncludePath)" Overwrite="true"/>'
          '<WriteLinesToFile File="captured-additional.txt" Lines="DS719_BEGIN;$(DCC_AdditionalSwitches);DS719_END" Overwrite="true"/>'
          '</Target><Target Name="IncludeAtDcc" BeforeTargets="_PasCoreCompile">'
          '<WriteLinesToFile File="at-dcc-include.txt" Lines="$(IncludePath)" Overwrite="true"/>'
          '</Target></Project>')
    command = root / (tag + '.cmd')
    write(command, '@echo off\ncall "' + str(bds / 'bin/rsvars.bat') + '"\n'
          '"C:\\Windows\\Microsoft.NET\\Framework\\v4.0.30319\\MSBuild.exe" P.dproj /nologo /v:m /t:' + target +
          ' /p:Config=Debug /p:Platform=Win64 /p:DCC_ForceExecute=true /p:DCC_UseMSBuildExternally=true'
          ' /p:GlobalOptionFile="' + str(targets) + '" /p:CmdsFileOutput="' + str(root / (tag + '.cmds')) + '"\nexit /b %errorlevel%\n')
    return run(['cmd', '/d', '/c', command], root, root / (tag + '-compile.json'))


def ds772_define_cases(root):
    cases = []
    for shape in ('field', 'import'):
        for evidence in ('missing', 'present', 'empty'):
            name = f'ds772-{shape}-{evidence}'
            folder = root / name
            feature = evidence != 'empty'
            refs = ['Unit1']
            if shape == 'field':
                declarations = ('type\n  TRec = record\n'
                    '{$IFDEF REVIEW_FEATURE}\n    Count: Integer;\n{$ELSE}\n    Other: Integer;\n{$ENDIF}\n'
                    'end;\n')
                imports = ''
                setup = '{$IFDEF REVIEW_FEATURE} Item.Count := 1; {$ELSE} Item.Other := 1; {$ENDIF}'
                observation = '{$IFDEF REVIEW_FEATURE} Write(Item.Count); {$ELSE} Write(Item.Other); {$ENDIF}'
            else:
                write(folder / 'Base.pas', 'unit Base;\ninterface\ntype\n  TRec = record\n    Actual: Integer;\n  end;\nimplementation\nend.\n')
                write(folder / 'HelperUnit.pas', 'unit HelperUnit;\ninterface\nuses Base;\n'
                    'type\n  TRecHelper = record helper for TRec\n'
                    '    function GetCount: Integer;\n    procedure SetCount(Value: Integer);\n'
                    '    property Count: Integer read GetCount write SetCount;\n  end;\n'
                    'implementation\nfunction TRecHelper.GetCount: Integer;\nbegin\n  Result := Actual;\nend;\n'
                    'procedure TRecHelper.SetCount(Value: Integer);\nbegin\n  Actual := Value;\nend;\nend.\n')
                declarations = ''
                imports = 'uses Base {$IFDEF REVIEW_FEATURE}, HelperUnit {$ENDIF};\n'
                setup = 'Item.Actual := 1;'
                observation = 'Write(Item.Actual);'
                refs += ['Base', 'HelperUnit']
            write(folder / 'Unit1.pas', 'unit Unit1;\ninterface\n' + imports + declarations +
                'procedure Run;\nimplementation\nprocedure Run;\n'
                'var\n  Item: TRec;\n  Count: Integer;\nbegin\n  Count := 100;\n  ' + setup + '\n'
                'with Item do Count := Count + 1;\n' + observation + "\n  Writeln('/', Count);\nend;\nend.\n")
            project(folder, refs, msbuild_properties={
                'DCC_AdditionalSwitches': '-DREVIEW_FEATURE' if feature else ''})
            cases.append(dict(name=name, root=str(folder), family='ds772-compiler-defines',
                define_evidence=evidence, expected_native_output='2/100\r\n' if feature else '1/101\r\n',
                identity_names=['TRec'], identity_probe_interface_import=True,
                expect_plan=evidence == 'present' or (shape == 'field' and evidence == 'empty'),
                require_named_refusal=evidence == 'missing', routes=list(range(5))))
    return cases


def ds772_apptype_cases(root):
    cases = []
    for shape in ('console', 'gui', 'include', 'shared-console', 'shared-gui'):
        name = f'ds772-apptype-field-{shape}'
        folder = root / name
        directive = '{$APPTYPE GUI}' if shape in ('gui', 'shared-gui') else '{$APPTYPE CONSOLE}'
        if shape == 'include':
            write(folder / 'kind.inc', directive + '\n')
            directive = '{$I kind.inc}'
        write(folder / 'u0.pas', 'unit u0;\ninterface\nimplementation\n' + directive + '\nend.\n')
        write(folder / 'Unit1.pas', 'unit Unit1;\ninterface\ntype TRec = record\n'
              '{$IFDEF CONSOLE} Count: Integer; {$ELSE} Other: Integer; {$ENDIF}\nend;\n'
              'procedure Run;\nimplementation\nprocedure Run;\nvar Item: TRec; Count: Integer;\nbegin\n'
              'Count := 100; {$IFDEF CONSOLE} Item.Count := 1; {$ELSE} Item.Other := 1; {$ENDIF}\n'
              'with Item do Count := Count + 1;\n'
              '{$IFDEF CONSOLE} Write(Item.Count); {$ELSE} Write(Item.Other); {$ENDIF}\n'
              "Writeln('/', Count);\nend;\nend.\n")
        project(folder, ['u0', 'Unit1'], msbuild_properties={'DCC_ConsoleTarget': 'true' if shape in ('gui', 'shared-gui') else 'false'})
        # The unit directive, rather than the DPR or switch, changes the state
        # seen by the later unit. Keep the compilation order explicit.
        write(folder / 'P.dpr', "program P; uses u0 in 'u0.pas', Unit1 in 'Unit1.pas'; begin Unit1.Run; end.\n")
        if shape.startswith('shared-'):
            write(folder / 'shared.inc', '{$I local.kind}\n')
            write(folder / 'first/local.kind', '')
            write(folder / 'local.kind', directive + '\n')
            write(folder / 'first/first.pas', 'unit first; interface implementation {$I shared.inc} end.\n')
            write(folder / 'u0.pas', 'unit u0; interface implementation {$I shared.inc} end.\n')
            write(folder / 'P.dpr', "program P; uses first in 'first/first.pas', u0 in 'u0.pas', Unit1 in 'Unit1.pas'; begin Unit1.Run; end.\n")
        cases.append(dict(name=name, root=str(folder), family='ds772-compiler-defines',
            define_evidence='present', console_unknown=True,
            expected_native_output='1/101\r\n' if shape in ('gui', 'shared-gui') else '2/100\r\n',
            identity_names=['TRec'], identity_probe_interface_import=True,
            expect_plan=False, require_named_refusal=True, routes=list(range(5))))
    return cases


def generate(repo, root, full, only="", include_evidence="certified"):
    cases = []
    for si, shape in enumerate(SHAPES):
        for mi, mode in enumerate(MODES):
            for before in (False, True):
                # Pairwise deterministic coverage, not a Cartesian explosion.
                if not full and not (mode == "unknown" and not before and si < 10):
                    continue
                section = bool((si + mi + int(before)) % 2)
                name = f"generated-{shape}-{mode}-{'before' if before else 'after'}-{'impl' if section else 'intf'}"
                folder = root / name
                oracle = generated(folder, shape, mode, before, section)
                row = {"name": name, "root": str(folder), "family": "selector-visibility", **oracle}
                if mode == "unknown":
                    control = root / (name + "-known-absent")
                    control_oracle = generated(control, shape, mode, before, section, absent=True)
                    cases.append({"name": name + "-known-absent", "root": str(control), "family": "monotone-control", **control_oracle})
                    row["known_absent"] = name + "-known-absent"
                cases.append(row)
    # The planner also has a historical generic-array capture fallback. Keep a
    # deterministic pair for that source spelling; it must obey the same rule.
    generic_pair = []
    for absent in (True, False):
        name = "generic-array-unknown-after-intf" + ("-known-absent" if absent else "")
        folder = root / name
        oracle = generated(folder, "array", "unknown", False, False, absent)
        path = folder / "B.pas"
        text = path.read_text(encoding="ascii")
        assert "Arr: TArr;" in text
        write(path, text.replace("Arr: TArr;", "Arr: TArray<TX>;"))
        path = folder / "Unit1.pas"
        text = path.read_text(encoding="ascii")
        assert "  Item.X := 0;" in text
        write(path, text.replace("  Item.X := 0;", "  SetLength(Arr, 2);\n  Item.X := 0;"))
        row = {"name": name, "root": str(folder), "family": "generic-capture", **oracle}
        if not absent:
            row["known_absent"] = generic_pair[0]["name"]
        generic_pair.append(row)
    cases.extend(generic_pair)
    typed_pair = []
    for initialized_var, absent in ((False, True), (False, False), (True, True), (True, False)):
        prefix = "initialized-var" if initialized_var else "typed-constant"
        name = prefix + "-pointer-array-unknown" + ("-known-absent" if absent else "")
        folder = root / name
        oracle = generated(folder, "array", "unknown", False, False, absent)
        path = folder / "B.pas"
        text = path.read_text(encoding="ascii")
        assert "Arr: TArr;" in text
        if initialized_var:
            text = text.replace("Arr: TArr;", "Arr: array[0..1] of PX = (nil, nil);")
        else:
            text = text.replace("Arr: TArr;", "")
            text = text.replace("var Item:", "{$J+} const Arr: array[0..1] of PX = (nil, nil);\nvar Item:")
        write(path, text)
        path = folder / "Unit1.pas"
        text = path.read_text(encoding="ascii")
        text = text.replace("  Item.X := 0;", "  Arr[1] := @Item;\n  Item.X := 0;")
        text = text.replace("with Arr[1] do", "with Arr[1]^ do")
        text = text.replace("Arr[1].X", "Item.X")
        write(path, text)
        row = {"name": name, "root": str(folder), "family": "typed-constant-capture", **oracle}
        if not absent:
            row["known_absent"] = typed_pair[-1]["name"]
        typed_pair.append(row)
    cases.extend(typed_pair)
    if full:
        fixture_root = repo / "tests/fixtures/ds719-uses-order"
        for name in HISTORICAL:
            source = fixture_root / name
            if not source.is_dir():
                raise RuntimeError(f"Missing historical fixture: {source}")
            folder = root / ("historical-" + name)
            shutil.copytree(source, folder)
            cases.append({"name": "historical-" + name, "root": str(folder), "family": "historical"})
            pointer = name in ("m3-global-pointer-alias", "m4-field-pointer-alias")
            typename = ("PRec" if pointer else "TRec" if name.startswith("u-pointer") else
                        "TSearchRec" if name.startswith("m6-") else
                        "TPoint" if name.startswith("m7-") else "TRect" if name in
                        ("ce4-default-alias", "ce6-project-alias-default-key", "ce6b-project-alias-twice") else "TX")
            cases[-1].update(identity_probe={"file": "Unit1.pas", "name": typename,
                                            "pointer": pointer},
                             identity_names=["TRec", "TBig"] if pointer else [typename])
        for shape in ("field", "pointer-alias", "array-elem", "class-field", "multi"):
            names = {"field": "r6-n1-field-path", "pointer-alias": "r6-n4-pointer-alias",
                     "array-elem": "r6-n6-array-elem", "class-field": "r6-n9-class-field", "multi": "r6-a4-multi"}
            for mode in ("unknown", "shadow", "absent"):
                name = names[shape] + "-" + mode
                folder = root / name
                shutil.copytree(fixture_root / name, folder)
                row = {"name": name, "root": str(folder), "family": "opus-r6",
                       "identity_probe": {"file": "B.pas", "name": "TX"}, "identity_names": ["TX"]}
                if mode == "unknown":
                    row["known_absent"] = names[shape] + "-absent"
                cases.append(row)
        for shape in ("anon-partial-field", "anon-partial-enum", "rmpv-compiling-anon-field"):
            folder = root / shape
            declarations = "var\n  Rec: record\n    var A: Integer;\n    case Count: Integer of\n      0: (X: Integer);\n  end;\n"
            body = "with Rec do A := Count;"
            if shape == "anon-partial-enum":
                declarations = declarations.replace("A: Integer", "A: (Zero, One)")
                body = "with Rec do begin A := Low(A); X := Count; end;"
            write(folder / "Unit1.pas", "unit Unit1;\ninterface\nprocedure Run;\n" + declarations +
                  "implementation\nprocedure Run;\nvar\n  lOutside: Integer;\nbegin\n  Rec.Count := 0;\n  " + body +
                  "\n  Writeln(Ord(Rec.A), ' ', Rec.X);\nend;\nend.\n")
            refs = ["Unit1"]
            if shape == "rmpv-compiling-anon-field":
                write(folder / "ControlUnit.pas", "unit ControlUnit;\ninterface\n"
                      "type TControl = record Value: Integer; const Count = 7; end;\nvar Item: TControl;\n"
                      "implementation\nprocedure Run;\nbegin\n  with Item do Value := 1;\nend;\ninitialization\n  Run;\nend.\n")
                refs.append("ControlUnit")
            project(folder, refs)
            cases.append({"name": shape, "root": str(folder), "family": "anonymous-record-E2003"})
    cases.extend(r7_cases(repo, root))
    cases.extend(denial_cases(root))
    cases.extend(helper_kind_cases(root))
    cases.extend(helper_evidence_cases(repo, root))
    cases.extend(multiline_var_cases(root))
    cases.extend(msbuild_include_cases(repo, root))
    if full:
        cases.extend(ds772_define_cases(root))
        cases.extend(ds772_apptype_cases(root))
    # Recovery design 0.24: native regressions for B1, M1 and Fix D follow-ups.
    for retained in json.loads((repo / 'tests/fixtures/ds719-freeze-findings.json').read_text()):
        case = {key: value for key, value in retained.items() if key not in ('files', 'refs')}
        folder = root / case['name']
        for name, source in retained['files'].items():
            write(folder / name, source)
        project(folder, retained['refs'], msbuild_properties=retained.get('msbuild_properties'))
        case['root'] = str(folder)
        cases.append(case)
    if full:
        cases.extend(r8_cases(repo, root))
        # DS-719 recovery 3q: the paired-control obligation is separate from
        # expect_plan. Refusing for a different named cause can pass only the
        # collision-absent obligation (recovery coordinator ruling 0.5).
        helper_fixtures = repo / 'tests/fixtures/ds719-helper-collisions'
        if helper_fixtures.exists():
            for item in json.loads((helper_fixtures / 'cases.json').read_text()):
                folder = root / item['name']
                shutil.copytree(helper_fixtures / item['folder'], folder)
                project(folder, item['refs'])
                case = {key: value for key, value in item.items()
                        if key not in ('folder', 'refs')}
                case['root'] = str(folder)
                cases.append(case)
        # Historical positive controls are independent of the generated rows.
        for name in ('b-after-sysutils', 'e-impl-unit2-wins', 'ua', 'au-absent', 'g-ancestry-before-classes'):
            folder = root/('historical-'+name)
            shutil.copytree(repo/'tests/fixtures/ds719-uses-order'/name, folder)
            cases.append(dict(name=folder.name, root=str(folder), family='historical',
                              expect_plan=name in ('b-after-sysutils', 'e-impl-unit2-wins', 'ua')))
    for case in cases:
        name = case['name']
        case['expect_plan'] = case.get('expect_plan', False) or (
            name.startswith('generated-') and '-none-' in name or
            name.startswith('r7-alias-chain-indexed-') or
            re.fullmatch(r'r7-later-(var|field)-indexed-1', name) is not None)
    if only:
        prefixes = tuple(prefix.strip() for prefix in only.split(",") if prefix.strip())
        assert prefixes, "Empty native selection"
        cases = [case for case in cases if case["name"].startswith(prefixes)]
    for case in cases:
        folder = Path(case['root'])
        if 'define_evidence' in case:
            # These include-free rows exercise the real DAK settings producer.
            # Do not label the old include-only helper's partial option grammar
            # as evidence for their additional -D arguments.
            continue
        xml = ET.parse(folder / 'P.dproj')
        ns = {'m': 'http://schemas.microsoft.com/developer/msbuild/2003'}
        msbuild = any(item.text == 'true' for item in xml.findall('.//m:DS719NativeMSBuild', ns))
        if msbuild:
            bds = Path(os.environ.get('BDS', r'C:\Program Files (x86)\Embarcadero\Studio\23.0'))
            capture = msbuild_include_invocation(folder, bds, 'CaptureInclude', 'capture')
            assert capture['exit'] == 0, capture
            case['compiler_include_search_path'] = compiler_include_search_path(folder)
        else:
            case['compiler_include_search_path'] = ';'.join(raw_compiler_include_search_path(folder))
    if include_evidence != "certified":
        # DS-778/779: every planner route must withhold include-dependent proof
        # when its caller cannot certify MSBuild's exact ordered include list.
        assert only and all(case['name'] in ('msbuild-include-P1', 'msbuild-include-P2')
                            for case in cases), "Evidence variants require the bounded P1/P2 rows"
        for case in cases:
            if include_evidence == "absent":
                del case['compiler_include_search_path']
            else:
                case['compiler_include_search_path'] = '$(DS719PROBEDIR);s1'
            case.pop('expect_refusal')
            case.pop('require_identity')
            case['expect_directive_cause'] = 'UNIT_DIRECTIVE_UNPROVED'
            case['expect_directive_fact'] = dict(unit='Unit1', cause='UNIT_DIRECTIVE_UNPROVED')
    # DS-719 A-367: these exact positives require the exact listed refusal.
    for case in cases:
        if case['name'] in ('r7-later-var-indexed-1', 'r7-later-field-indexed-1'):
            case.pop('expect_plan', None)
            case['expect_refusal'] = ('selector-type-not-resolved'
                                      if case['name'] == 'r7-later-var-indexed-1'
                                      else 'property-selector')
    # Full dispatch includes retained Freeze regressions; selection never changes this roster.
    assert cases and (len(cases) == 681 if full and not only else len(cases) <= 500), len(cases)
    if os.environ.get('DS719_NATIVE_ALL_ROUTES') == '1':
        for case in cases:
            case.pop('excluded_routes', None)
            case['routes'] = list(range(5))
    # DS-788: fixture-owned declarations, never exported planner identities.
    # These bounded corpus shapes declare either a unit variable Rec or a
    # routine-local Sub. Generic inference obtains their anonymous TypeInfo.
    for case in cases:
        source = Path(case['root']) / 'Unit1.pas'
        if not source.exists():
            continue
        text = source.read_text(encoding='utf-8-sig')
        catalog = []
        if re.search(r'\bRec\s*:\s*record\b', text, re.I):
            catalog.append(['Unit1.Rec', 'Unit1.Unit1.Rec'])
        if case['name'].startswith('r8-anon-dotted-homonym-'):
            depth = int(case['name'].split('-')[4])
            expression = '.'.join(['Sub'] * depth)
            catalog.append([expression, 'Unit1.TOuter.' + expression])
        if catalog:
            case['anonymous_types'] = {'Unit1.pas': catalog}
    (root / "cases.json").write_text(json.dumps(cases, indent=2), encoding="utf-8")
    print(f"Generated {len(cases)} cases")


def run(command, cwd, log):
    start = time.perf_counter()
    environment = dict(os.environ)
    environment_file = Path(cwd) / 'native-environment.json'
    if environment_file.exists():
        environment.update(json.loads(environment_file.read_text()))
    process = subprocess.run(list(map(str, command)), cwd=cwd, capture_output=True, env=environment,
                             creationflags=subprocess.CREATE_NO_WINDOW, timeout=90)
    row = {"command": list(map(str, command)), "cwd": str(cwd), "exit": process.returncode,
           "seconds": time.perf_counter() - start, "stdout": process.stdout.decode("utf-8", errors="replace"),
           "stderr": process.stderr.decode("utf-8", errors="replace")}
    log.write_text(json.dumps(row, indent=2), encoding="utf-8")
    return row


def native(root, bds, tag, defines=()):
    ns = {"m": "http://schemas.microsoft.com/developer/msbuild/2003"}
    xml = ET.parse(root / "P.dproj")
    def prop(key):
        values = xml.findall("./m:PropertyGroup/m:" + key, ns)
        return values[-1].text or "" if values else ""
    refs = [str((root / x.attrib["Include"]).parent) for x in xml.findall(".//m:DCCReference", ns)]
    search = [str(root), *[str(root / x) for x in prop("DCC_UnitSearchPath").split(";") if x], *refs,
              str(bds / "lib/win64/release")]
    includes = raw_compiler_include_search_path(root)
    debug_paths = [str(root / x) for x in prop("DelphiDebugDCUPath").split(";") if x]
    search.extend(debug_paths)
    aliases = re.sub(r"\$\([^)]+\)", "", prop("DCC_UnitAlias") + prop("DCC_UnitAliases"))
    targets = ET.parse(bds / "bin/CodeGear.Common.Targets")
    defaults = []
    for item in targets.findall(".//m:UnitAliases", ns):
        condition = item.attrib.get("Condition", "")
        if not condition or "cWin64Platform" in condition:
            defaults.extend(x for x in (item.text or "").split(";") if x and "$" not in x)
    aliases += ";" + ";".join(defaults)
    # Each invocation owns a distinct executable. Replacing a just-exited image
    # can fail with F2039 while Windows/AV releases it; do not hide that by retry.
    slot = ("0" if tag == "original" else "1" if tag == "identity-probe" else
            "7" if tag == "binding-contrast" else str(2 + int(tag.split("-")[1])))
    output = root / "native" / slot; output.mkdir(parents=True, exist_ok=True)
    main = prop("MainSource") or "P.dpr"
    command = [bds / "bin/dcc64.exe", "-B", "-Q", "--no-config", "-NSSystem;Winapi;System.Win;Xml",
               "-U" + ";".join(search), "-I" + ";".join(includes),
               "-A" + ";".join(x for x in aliases.split(";") if x),
               "-E" + str(output), "-N0" + str(output), root / main]
    if defines:
        command.append("-D" + ";".join(defines))
    if prop("DS719NativeMSBuild") == "true":
        # Keep each native image independent while restoring the project input
        # before the next planner/cache route observes it.
        path = root / "P.dproj"
        original_project = path.read_bytes()
        text = original_project.decode("ascii")
        for key in ("DCC_ExeOutput", "DCC_DcuOutput"):
            text = re.sub(r'<' + key + r'>.*?</' + key + r'>',
                          lambda match: '<' + key + '>' + str(output) + '</' + key + '>', text)
        write(path, text)
        host = os.environ.get('DAK_BUILD_HOST', r'F:\projects\MaxLogic\DelphiAiKit\bin\DelphiAIKit.exe')
        command = [host, 'build', '--project', path, '--delphi', '23.0',
                   '--config', 'Debug', '--platform', 'Win64', '--target', 'Rebuild',
                   '--ai', '--log-dir', output / 'build-logs']
        for define in defines:
            command.extend(['--define', define])
        try:
            if prop('DS719CapturedIncludeCase') == 'true':
                build = msbuild_include_invocation(root, bds, 'Rebuild', tag)
                if build['exit'] == 0:
                    captured = (root / 'captured-include.txt').read_text(encoding='utf-8-sig').splitlines()
                    actual = (root / 'at-dcc-include.txt').read_text(encoding='utf-8-sig').splitlines()
                    assert captured == actual, (root, captured, actual)
            else:
                build = run(command, root, root / (tag + "-compile.json"))
        finally:
            path.write_bytes(original_project)
    else:
        build = run(command, root, root / (tag + "-compile.json"))
    if build["exit"]:
        return {"build": build, "runtime": None}
    runtime = run([output / (Path(main).stem + ".exe")], root, root / (tag + "-runtime.json"))
    return {"build": build, "runtime": runtime}


def apply_edits(root, plan):
    grouped = {}
    for statement in plan["statements"]:
        if statement["status"] == "planned":
            for edit in statement["edits"]:
                grouped.setdefault(edit["file"], []).append(edit)
    for filename, edits in grouped.items():
        path = Path(filename).resolve()
        assert path.is_relative_to(root.resolve()), path
        raw = path.read_bytes(); text = raw.decode("utf-8-sig")
        offsets = [0]
        for line in text.splitlines(keepends=True):
            offsets.append(offsets[-1] + len(line))
        changes = []
        for edit in edits:
            start = offsets[edit["sl"] - 1] + edit["sc"] - 1
            # Frozen test exporters omit kind. Final statement replacements
            # span a WITH statement; only declaration inserts use a point range
            # at column 1 (FindRoutineDeclarationRange).
            kind = edit.get("kind")
            if kind is None:
                point = (edit["sl"], edit["sc"]) == (edit["el"], edit["ec"])
                assert not point or edit["sc"] == 1, "Unknown legacy point edit"
                kind = "declare-temp" if point else "replace-statement"
            assert kind in ("declare-temp", "replace-statement"), kind
            end = start if kind == "declare-temp" else offsets[edit["el"] - 1] + edit["ec"]
            changes.append((start, end, edit["text"]))
        # Shared declaration edits may occur in more than one statement DTO.
        unique = sorted(set(changes), reverse=True)
        previous = len(text) + 1
        for start, end, replacement in unique:
            assert end <= previous, "Overlapping published edits"
            text = text[:start] + replacement + text[end:]
            previous = start
        path.write_bytes((b"\xef\xbb\xbf" if raw.startswith(b"\xef\xbb\xbf") else b"") + text.encode("utf-8"))


# Independent lexical inventory. It never reads DS exports or resolves names.
_TOKEN = re.compile(r"(?P<multiline_quotes>'{3}(?:'{2})*)(?:\r\n|\r|\n).*?(?P=multiline_quotes)(?!')|//[^\r\n]*|\{[^}]*\}|\(\*.*?\*\)|'(?:''|[^'])*'|[A-Za-z_][A-Za-z_0-9]*|[^\s]", re.S)


def source_targets(folder):
    targets = []
    for path in sorted([*folder.rglob('*.pas'), *folder.rglob('*.dpr')]):
        if 'native' in path.relative_to(folder).parts or path.name == 'Ds719NativeProbe.pas':
            continue
        text = path.read_bytes().decode('utf-8-sig')
        tokens = [m for m in _TOKEN.finditer(text)
                  if not m.group().startswith(('//', '{', '(*'))]
        for i, token in enumerate(tokens):
            if token.group().lower() != 'with':
                continue
            depth = 0; selectors = []; start = token.end(); cursor = i + 1
            while cursor < len(tokens):
                value = tokens[cursor].group().lower()
                if depth == 0 and value in (',', 'do'):
                    selectors.append(text[start:tokens[cursor].start()].strip())
                    start = tokens[cursor].end()
                    if value == 'do':
                        break
                elif value in ('(', '['):
                    depth += 1
                elif value in (')', ']'):
                    depth -= 1
                cursor += 1
            assert cursor < len(tokens) and all(selectors), (path, token.start())
            line = text.count('\n', 0, token.start()) + 1
            column = token.start() - text.rfind('\n', 0, token.start())
            # Our bounded source grammar uses compound bodies or simple
            # statements, plus nested WITH. Refuse an unsupported grammar.
            def body_end(index):
                value = tokens[index].group().lower()
                if value in ('begin', 'try', 'case'):
                    nesting = 1; index += 1
                    while nesting:
                        value = tokens[index].group().lower()
                        if value in ('begin', 'try', 'case'):
                            nesting += 1
                        elif value == 'end':
                            nesting -= 1
                        index += 1
                    return tokens[index - 1].end()
                if value == 'with':
                    while tokens[index].group().lower() != 'do':
                        index += 1
                    return body_end(index + 1)
                assert value not in ('if', 'while', 'for', 'repeat'), (path, value)
                depth = 0
                while index < len(tokens):
                    value = tokens[index].group().lower()
                    if depth == 0 and value in (';', 'end', 'else', 'until'):
                        return tokens[index - 1].end()
                    if value in ('(', '['): depth += 1
                    if value in (')', ']'): depth -= 1
                    index += 1
                raise AssertionError((path, 'unterminated WITH body'))
            relative = path.relative_to(folder).as_posix()
            targets.append({'file': relative, 'line': line, 'column': column,
                            'selectors': selectors, 'start': token.start(),
                            'end': body_end(cursor + 1)})
    # Binder DTOs carry the complete enclosing WITH context, outermost first.
    # Derive that shape from source intervals, independently of exported DTOs.
    # Each context slot retains its original selector position for the oracle.
    for target in targets:
        parents = sorted((other for other in targets if other['file'] == target['file']
                          and other['start'] < target['start'] < other['end']),
                         key=lambda other: other['start'])
        target['context'] = [dict(text=expression,
                                 origin=(owner['file'].lower(), owner['line'], owner['column'], index))
                             for owner in [*parents, target]
                             for index, expression in enumerate(owner['selectors'])]
    return targets


def target_key(row, folder):
    path = Path(row['file']).resolve()
    assert path.is_relative_to(folder.resolve()), path
    return (path.relative_to(folder.resolve()).as_posix().lower(),
            row.get('line', row.get('sl')), row.get('column', row.get('sc')))


def check_coverage(plan, targets, folder):
    expected = {(t['file'].lower(), t['line'], t['column']): t for t in targets}
    statements = {}; selectors = {}; errors = []
    for statement in plan['statements']:
        key = target_key(statement, folder)
        if key in statements: errors.append(('duplicate-statement', key))
        statements[key] = statement
    if set(statements) != set(expected):
        errors.append(('statement-coverage', {'missing': sorted(set(expected)-set(statements)),
                                             'extra': sorted(set(statements)-set(expected))}))
    for selector in plan['selectors']:
        key = (*target_key(selector, folder), selector['index'])
        if key in selectors: errors.append(('duplicate-selector', key))
        selectors[key] = selector
        target = expected.get(key[:3])
        if target and 0 <= key[3] < len(target['context']) and 'text' in selector:
            normalize = lambda text: ''.join(m.group().lower() for m in _TOKEN.finditer(text)
                                             if not m.group().startswith(('//', '{', '(*')))
            if normalize(selector['text']) != normalize(target['context'][key[3]]['text']):
                errors.append(('selector-correspondence', key))
    expected_selectors = {(*key, i) for key, t in expected.items() for i in range(len(t['context']))}
    if set(selectors) != expected_selectors:
        errors.append(('selector-coverage', {'missing': sorted(expected_selectors-set(selectors)),
                                            'extra': sorted(set(selectors)-expected_selectors)}))
    return statements, selectors, errors


PROBE_SOURCE = '''unit Ds719NativeProbe;
interface
uses System.Rtti, System.TypInfo;
type
  TProbe = class
    class function Identity<T>(const aValue: T): PTypeInfo; static;
    class procedure Emit<T>(const aValue: T; const aKey: string;
      const aPrivateTypes: array of PTypeInfo; const aNames: array of string); static;
  end;
implementation
class function TProbe.Identity<T>(const aValue: T): PTypeInfo;
begin
  Result := TypeInfo(T);
end;
class procedure TProbe.Emit<T>(const aValue: T; const aKey: string;
  const aPrivateTypes: array of PTypeInfo; const aNames: array of string);
var
  lContext: TRttiContext;
  lType: TRttiType;
  lName: string;
  i: Integer;
begin
  lContext := TRttiContext.Create;
  try
    lType := lContext.GetType(TypeInfo(T));
    if lType.IsPublicType then
      lName := lType.QualifiedName
    else
      lName := '';
    for i := 0 to High(aPrivateTypes) do
      if lType.Handle = aPrivateTypes[i] then
      begin
        if lName <> '' then
          lName := lName + '|';
        lName := lName + aNames[i];
      end;
    if lName = '' then
      lName := '<unidentified>';
    Writeln('DS719_ID=', aKey, '=', lName);
  finally
    lContext.Free;
  end;
end;
end.
'''


def native_identity(case, bds, targets):
    """Let dcc64 infer each actual selector's type at its original scope.

    This run alone is instrumented; original/rewrite output remains untouched.
    Multi-selector probes nest the preceding WITH scopes. Nonpublic RTTI has
    no qualified name: case-owned declaration catalogs compare TypeInfo handles
    instead, never spelling resolution or a DS-reported name. Unexecuted or
    uncatalogued receivers cannot authorize a plan.
    """
    folder = Path(case['root']); originals = {}; changes = {}
    write(folder / 'Ds719NativeProbe.pas', PROBE_SOURCE)
    for target in targets:
        path = folder / target['file']
        if path not in originals:
            originals[path] = path.read_bytes()
        private = (case.get('private_types', {}).get(target['file'], []) +
                   case.get('alias_types', []))
        anonymous = case.get('anonymous_types', {}).get(target['file'], [])
        handles = ', '.join(['System.TypeInfo(' + name + ')' for name, _ in private] +
                            ['Ds719NativeProbe.TProbe.Identity(' + expression + ')'
                             for expression, _ in anonymous])
        names = ', '.join("'" + identity + "'" for _, identity in [*private, *anonymous])
        prefix = 'begin '
        for index, expression in enumerate(target['selectors']):
            key = f"{target['file'].lower()}:{target['line']}:{target['column']}:{index}"
            prefix += f"Ds719NativeProbe.TProbe.Emit({expression}, '{key}', [{handles}], [{names}]); "
            if index + 1 < len(target['selectors']):
                prefix += f'with {expression} do begin '
        prefix += 'end; ' * (len(target['selectors']) - 1)
        changes.setdefault(path, []).extend([(target['start'], prefix), (target['end'], ' end')])
    try:
        for path, inserts in changes.items():
            text = originals[path].decode('utf-8-sig')
            for offset, insertion in sorted(inserts, reverse=True):
                text = text[:offset] + insertion + text[offset:]
            # A conditional implementation USES must remain the first declaration.
            # These native rows add the observer to the interface instead.
            if case.get('identity_probe_interface_import'):
                match = re.search(r'\binterface\b', text, re.I)
            else:
                match = re.search(r'\bimplementation\b', text, re.I)
            if match is None and path.suffix.lower() == '.dpr':
                match = re.search(r'\bprogram\s+[A-Za-z_][A-Za-z_0-9]*\s*;', text, re.I)
            assert match, path
            tail = text[match.end():]
            uses = re.match(r'\s*uses\b', tail, re.I)
            if uses:
                tail = tail[:uses.end()] + ' Ds719NativeProbe,' + tail[uses.end():]
            else:
                tail = '\r\nuses Ds719NativeProbe;\r\n' + tail
            path.write_bytes((text[:match.end()] + tail).encode('utf-8'))
        receipt = native(folder, bds, 'identity-probe', case.get('native_defines', ()))
        assert receipt['build']['exit'] == 0, receipt['build']
        assert receipt['runtime']['exit'] == 0, receipt['runtime']
        identities = {}
        for key, identity in re.findall(r'DS719_ID=([^=\r\n]+)=([^\r\n]+)', receipt['runtime']['stdout']):
            assert key not in identities or identities[key] == identity, (key, identity)
            identities[key] = identity
        return identities, receipt
    finally:
        for path, raw in originals.items():
            path.write_bytes(raw)


def statement_causes(statement):
    """Keep actual exported causes; never infer a collision from a generic code."""
    return {key: statement.get(key, '') for key in ('cause', 'reason', 'safety')}


def collision_causes(statement):
    # Collision-specific codes must say collision. Broad unverified-member
    # refusals also protect open roots and cannot prove collision causality.
    return [value for value in statement_causes(statement).values()
            if isinstance(value, str) and 'collision' in value.casefold()]


def pair_route_result(plan, role):
    """An additional pair obligation; this never satisfies expect_plan."""
    statements = plan.get('statements', [])
    observations = [dict(status=s.get('status', ''),
                         remaining_cause=s.get('cause') or s.get('safety') or s.get('reason', ''),
                         **statement_causes(s)) for s in statements]
    planned = any(s.get('status') == 'planned' for s in statements)
    if not statements or any(s.get('status') not in ('planned', 'skipped')
                             for s in statements):
        return dict(result='fail', cause='pair-result-missing-or-invalid',
                    statements=observations)
    if role == 'control':
        if any(collision_causes(s) for s in statements):
            cause = 'paired-control-collision-remains'
        elif any(s['status'] != 'planned' and
                 not any(statement_causes(s).values()) for s in statements):
            cause = 'paired-control-refusal-unnamed'
        else:
            return dict(result='pass', obligation='collision-absent',
                        statements=observations)
    elif role == 'collision':
        # Before 3d a plan is observed, compiled and run, never accepted as a
        # collision refusal. The dual-binary dispatch decides any carry.
        if planned:
            return dict(result='fail', cause='collision-refusal-required',
                        classification='planned-needs-native-check',
                        statements=observations)
        if all(s['status'] == 'skipped' and collision_causes(s)
               for s in statements):
            return dict(result='pass', obligation='collision-refusal',
                        statements=observations)
        cause = 'collision-cause-not-reported'
    else:
        cause = 'pair-role-invalid'
    return dict(result='fail', cause=cause, statements=observations)


def rewrite_must_stop(case, rewrite, original_output, stop_runtime):
    mismatch = (rewrite['build']['exit'] != 0 or
                rewrite['runtime']['exit'] != 0 or
                rewrite['runtime']['stdout'] != original_output)
    return mismatch and (bool(case.get('pair_role')) or stop_runtime)


def approved_batch_observation(case, route, cause, plan, target=None):
    """0.17 replaces only the listed obligation with its strict observed contract."""
    rows = json.loads(Path(__file__).with_name('ds719-batch3-expectations.json').read_text(encoding='utf-8'))['rows']
    matches = [r for r in rows if r['case'] == case['name'] and r['route'] == route
               and r['target'] == target]
    if not matches:
        return None
    assert len(matches) == 1, (case['name'], route, cause, target)
    expected = matches[0]
    statements = [s for s in plan['statements'] if target is None or
                  [Path(s['file']).name.lower(), s['sl'], s['sc']] == target]
    actual = [dict(file=Path(s['file']).name.lower(), sl=s['sl'], sc=s['sc'],
                   el=s['el'], ec=s['ec'], status=s['status'], reason=s['reason'],
                   safety=s['safety'], edit_count=len(s['edits'])) for s in statements]
    # A refused final statement must have no publication through any payload.
    for statement, observed in zip(statements, actual):
        if statement['status'] == 'skipped':
            observed['refusal_payload_empty'] = (
                statement['replacement'] == '' and statement['temp_count'] == 0 and
                statement['recipe_status'] == 'skipped' and
                statement['recipe_replacement'] == '' and
                statement['recipe_edit_count'] == 0 and statement['recipe_temp_count'] == 0)
    return dict(result='pass' if actual == expected['statements'] else 'fail',
                cause='approved-batch-contract', approval=expected['approval'],
                expected=expected['statements'], statements=actual, observed_cause=cause)


def ds772_fact_errors(case, plan):
    if case.get('family') != 'ds772-compiler-defines':
        return []
    errors = []
    evidence = case['define_evidence']
    models = [m for m in plan.get('models', []) if m['unit'] == 'Unit1']
    if len(models) != 1 or models[0].get('define_complete') != (evidence != 'missing'):
        errors.append('native-define-completeness-required')
    if (evidence == 'missing' or case.get('console_unknown')) and len(models) == 1:
        key = 'directive_count_cause' if '-field-' in case['name'] else 'directive_import_cause'
        expected = 'DECLARATIONS_DIRECTIVE_UNPROVED' if '-field-' in case['name'] else 'IMPORTS_DIRECTIVE_UNPROVED'
        if models[0].get(key) != expected:
            errors.append('native-directive-denial-required')
    references = [r for r in plan.get('references', []) if r['name'].casefold() == 'count']
    expected = 'unsupported' if case.get('console_unknown') else {'missing': 'unsupported', 'present': 'member', 'empty': 'lexical'}[evidence]
    if len(references) != 2 or any(r['classification'] != expected for r in references):
        errors.append('native-reference-classification-required')
    if evidence == 'missing' or case.get('console_unknown'):
        if any(r.get('code') != 'SELECTOR_MEMBERS_UNVERIFIED' for r in references):
            errors.append('native-persisted-member-denial-required')
        for statement in plan.get('statements', []):
            if (statement.get('replacement') or statement.get('temp_count') or statement.get('edits') or
                    statement.get('recipe_replacement') or statement.get('recipe_edit_count') or
                    statement.get('recipe_temp_count')):
                errors.append('native-refusal-published-edits')
    return errors


def compare(root, bds, baseline=None, allowed_changes=None, stop_runtime=False):
    start = time.perf_counter(); failures = []; rows = []; losses = 0
    stopped = False
    cases = json.loads((root / 'cases.json').read_text())
    by_name = {c['name']: c for c in cases}
    inventories = {c['name']: source_targets(Path(c['root'])) for c in cases}
    def failure(case, route, field, cause, **details):
        failures.append(dict(case=case['name'], route=route, field=field, cause=cause, **details))
    def load(case, route):
        path = Path(case['root']) / f'route-{route}.json'
        try:
            plan = json.loads(path.read_text(encoding='utf-8-sig'))
            statements, selectors, errors = check_coverage(plan, inventories[case['name']], Path(case['root']))
            for cause, detail in errors:
                failure(case, route, 'coverage', cause, detail=detail)
            return plan, statements, selectors
        except (OSError, ValueError, KeyError, AssertionError) as error:
            failure(case, route, 'coverage', 'route-invalid-or-missing', error=str(error))
            return None, {}, {}
    for case in cases:
        folder = Path(case['root']); targets = inventories[case['name']]
        assert targets or case.get('native_only'), ('No WITH targets in case', case['name'])
        source = {p: p.read_bytes() for p in [*folder.rglob('*.pas'), *folder.rglob('*.dpr')]}
        original = native(folder, bds, 'original', case.get('native_defines', ()))
        if case.get('expected_native_error'):
            code = case['expected_native_error']
            build = original['build']
            if build['exit'] == 0 or code not in build['stdout'] + build['stderr']:
                failure(case, None, 'oracle', 'expected-native-error-missing', expected=code, native=original)
            for route in case.get('routes', list(range(5))):
                plan, statements, selectors = load(case, route)
                if plan is None:
                    continue
                planned = any(s['status'] == 'planned' for s in plan['statements'])
                if planned:
                    failure(case, route, 4, 'invalid-original-planned', native=original)
                rows.append(dict(case=case['name'], route=route, planned=planned,
                                 family=case['family'], original=original,
                                 expected_native_error=code,
                                 refused_statements=sum(s['status'] != 'planned' for s in plan['statements'])))
            continue
        if original['build']['exit'] or original['runtime']['exit']:
            failure(case, None, 'oracle', 'original-compile-or-run', native=original)
            continue
        output = original['runtime']['stdout']
        if 'expected_native_output' in case and output != case['expected_native_output']:
            failure(case, None, 'oracle', 'original-output', expected=case['expected_native_output'], actual=output)
        if case.get('native_only'):
            assert not targets, ('Native-only case unexpectedly has WITH', case['name'])
            for route in range(5):
                plan, statements, selectors = load(case, route)
                if plan is None:
                    continue
                if plan['statements'] or selectors:
                    failure(case, route, 'coverage', 'native-only-unexpected-plan')
                rows.append(dict(case=case['name'], route=route, planned=False,
                                 family=case['family'], original=original,
                                 refused_statements=0, native_only=True))
            continue
        if case.get('binding_contrast'):
            path = folder/'Unit1.pas'; raw = path.read_bytes()
            before, after = case['binding_contrast']
            try:
                text = raw.decode('ascii')
                assert text.count(before) == 1, (case['name'], before)
                write(path, text.replace(before, after))
                contrast = native(folder, bds, 'binding-contrast')
                if (contrast['build']['exit'] or contrast['runtime']['exit'] or
                        contrast['runtime']['stdout'] == output):
                    failure(case, None, 'oracle', 'homonym-output-not-distinct', native=contrast)
            finally:
                path.write_bytes(raw)
        try:
            identities, identity_receipt = native_identity(case, bds, targets)
        except Exception as error:
            failure(case, None, 'oracle', 'identity-probe', error=str(error))
            continue
        for route in case.get('routes', list(range(5))):
            plan, statements, selectors = load(case, route)
            if plan is None:
                continue
            for cause in ds772_fact_errors(case, plan):
                failure(case, route, 4, cause)
            if case.get('synthetic_collision'):
                # Recovery design 0.24: the two homonym subjects (ten routes)
                # must strictly refuse; equal synthetic text is not an identity.
                expected = (('selector-type-not-resolved', 'ANONYMOUS_SELECTOR_NAME_COLLISION')
                            if case['name'].endswith('-1') else ('property-selector', 'property-selector'))
                for statement in plan['statements']:
                    if (statement['status'] != 'skipped' or statement['edits'] or
                            statement.get('captures') or
                            statement.get('reason') != expected[0] or
                            statement.get('safety') != expected[1]):
                        failure(case, route, 4, 'synthetic-collision-refusal-required', statement=statement)
            planned = any(s['status'] == 'planned' for s in plan['statements'])
            row = dict(case=case['name'], route=route, planned=planned,
                       family=case['family'], refused_statements=sum(s['status'] != 'planned' for s in plan['statements']),
                       original=original, identities=identities, identity_probe=identity_receipt,
                       expected_statements=len(targets), expected_selectors=sum(len(t['context']) for t in targets))
            if case.get('pair_role'):
                observation = pair_route_result(plan, case['pair_role'])
                approved = approved_batch_observation(case, route, observation.get('cause', ''), plan)
                if approved is not None:
                    observation = approved
                row['pair'] = case['pair']
                row['pair_role'] = case['pair_role']
                row['pair_result'] = observation
                if observation['result'] == 'fail':
                    failure(case, route, 4, observation['cause'], observation=observation)
            if case.get('expect_directive_fact'):
                expected = case['expect_directive_fact']
                models = [m for m in plan.get('models', []) if m['unit'] == expected['unit']]
                if (len(models) != 1 or models[0].get('directive_import_cause') != expected['cause']):
                    failure(case, route, 4, 'directive-fact-required', expected=expected, models=models)
            if case.get('expect_directive_cause'):
                for statement in plan['statements']:
                    if (statement['status'] != 'skipped' or statement['edits'] or
                            statement.get('captures') or
                            case['expect_directive_cause'] not in statement_causes(statement).values()):
                        failure(case, route, 4, 'directive-cause-required',
                                expected=case['expect_directive_cause'], statement=statement)
            if case.get('require_named_refusal'):
                for statement in plan['statements']:
                    if (statement['status'] != 'skipped' or statement['edits'] or
                            statement.get('captures') or not statement.get('reason') or
                            not statement.get('safety')):
                        failure(case, route, 4, 'freeze-named-refusal-required', statement=statement)
            if case.get('expect_refusal'):
                for statement in plan['statements']:
                    if (statement['status'] != 'skipped' or statement['edits'] or
                            statement.get('reason') != case['expect_refusal'] or
                            statement.get('safety') != case['expect_refusal']):
                        failure(case, route, 4, 'approved-refusal-contract',
                                approval='A-367', expected=case['expect_refusal'], statement=statement)
            if case.get('expect_plan'):
                for statement in plan['statements']:
                    target = list(target_key(statement, folder))
                    approved = approved_batch_observation(case, route, 'positive-control-refused', plan, target)
                    if approved is not None:
                        if approved['result'] != 'pass':
                            failure(case, route, 4, approved['cause'], observation=approved)
                    elif statement['status'] != 'planned':
                        failure(case, route, 4, 'positive-control-refused',
                                reason=statement.get('reason'), target=target_key(statement, folder))
            # Target selection NEVER depends on the returned type/unit/name or
            # whether the planner emitted any statement. Every source selector
            # has its own compiler oracle key; mismatches require refusal.
            for key, selector in selectors.items():
                statement = statements.get(key[:3])
                if statement is None:
                    continue  # Coverage already failed; no vacuous pass.
                target = next((t for t in targets if
                               (t['file'].lower(), t['line'], t['column']) == key[:3]), None)
                origin = target['context'][key[3]]['origin'] if target and 0 <= key[3] < len(target['context']) else key
                identity = identities.get(':'.join(map(str, origin)))
                actual = selector['unit'] + '.' + selector['name']
                if not selector['unit'] and not selector['name']:
                    # Legacy anonymous bindings expose TypeName rather than a
                    # declared identity. Compare that spelling only against the
                    # independent, compiled declaration catalog, fail closed.
                    actual = selector.get('source_unit', '') + '.' + selector.get('type_name', '')
                    catalog = case.get('anonymous_types', {}).get(target['file'], []) if target else []
                    if actual.lower() not in {name.lower() for _, name in catalog}:
                        actual = '<missing-declaration-identity>'

                if (not identity or identity == '<unidentified>' or actual.lower() not in identity.lower().split('|')):
                    row.setdefault('identity_refusals', []).append(dict(target=key, compiler=identity, ds=actual))
                    if statement['status'] == 'planned' or case.get('require_identity'):
                        failure(case, route, 3, 'identity-unavailable' if not identity or identity == '<unidentified>' else 'compiler-identity',
                                target=key, compiler=identity, ds=selector,
                                identity_unavailable_reason='Anonymous or nonpublic compiler RTTI has no public name and no matching case-owned TypeInfo catalog' if not identity or identity == '<unidentified>' else '')
            if planned:
                try:
                    apply_edits(folder, plan)
                    rewrite = native(folder, bds, f'route-{route}-rewrite', case.get('native_defines', ()))
                    row['rewrite'] = rewrite
                    if rewrite['build']['exit']:
                        failure(case, route, 1, 'rewrite-compile')
                    elif rewrite['runtime']['exit'] or rewrite['runtime']['stdout'] != output:
                        failure(case, route, 1, 'runtime-output', original_output=output,
                                rewrite_output=rewrite['runtime']['stdout'])
                    stopped = rewrite_must_stop(case, rewrite, output, stop_runtime)
                finally:
                    for path, raw in source.items(): path.write_bytes(raw)
            else:
                losses += 1
            if case.get('known_absent'):
                control = by_name[case['known_absent']]
                _, known, known_selectors = load(control, route)
                if set(statements) != set(known) or set(selectors) != set(known_selectors):
                    failure(case, route, 'coverage', 'paired-correspondence')
                for key in set(statements) & set(known):
                    if statements[key]['status'] == 'planned' and known[key]['status'] != 'planned':
                        failure(case, route, 2, 'monotonicity', target=key, known_absent=control['name'])
            rows.append(row)
            if stopped:
                break
        print(case['name'], flush=True)
        if stopped:
            break
    # Pin refusals by case and route. An aggregate family count could hide one
    # lost positive case behind an unrelated newly planned case in that family.
    coverage = {f"{r['case']}|{r['route']}": r['refused_statements'] for r in rows}
    families = {}
    for row in rows:
        families[row['family']] = families.get(row['family'], 0) + row['refused_statements']
    if baseline:
        previous = json.loads(Path(baseline).read_text(encoding='utf-8-sig'))
        allowed = {}
        causes = {'A7-closure', 'A5-renumber', 'compiler-rule', 'witness-unknown',
                  'imports-unproved', 'type-names-unknown'}
        if allowed_changes:
            for line in Path(allowed_changes).read_text().splitlines():
                if not line.strip() or line.startswith('#'):
                    continue
                name, route, cause = line.split('|')
                assert cause in causes, line
                allowed[f'{name}|{route}'] = cause
        for key, count in coverage.items():
            if key not in previous['coverage_by_case_route']:
                failures.append(dict(case=key.split('|')[0], route=int(key.split('|')[1]),
                                     field=4, cause='ratchet-baseline-missing'))
            elif count > previous['coverage_by_case_route'][key] and key not in allowed:
                failures.append(dict(case=key.split('|')[0], route=int(key.split('|')[1]),
                                     field=4, cause='coverage-ratchet', refused=count))
        old = {json.dumps([f['case'], f['route'], f['field'], f['cause']], sort_keys=True)
               for f in previous['failures']}
        new = {json.dumps([f['case'], f['route'], f['field'], f['cause']], sort_keys=True)
               for f in failures}
        if new-old:
            failures.append(dict(case='<ratchet>', route=None, field=4, cause='failure-set-expanded',
                                 added=sorted(new-old)))
    result = dict(case_count=len(cases), route_count=len(rows), fields=[1, 2, 3, 4], failures=failures,
                  stopped_on_runtime_mismatch=stopped,
                  complete=not stopped,
                  coverage_by_case_route=coverage, coverage_by_family=families,
                  coverage_loss=losses, coverage_loss_definition='refused compilable-original routes; upper bound, not proven-safe rewrites',
                  seconds=time.perf_counter() - start, rows=rows)
    (root / 'comparison.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps({k: v for k, v in result.items() if k != 'rows'}))
    return int(bool(failures))


def challenge(root, bds):
    """Challenge the real native comparison with corrupted real route exports."""
    cases = json.loads((root/'cases.json').read_text())
    base = next(c for c in cases if c['name'] == 'r7-alias-chain-indexed-2')
    results = []
    output = root/'comparator-challenges'; output.mkdir()
    for mutation in ('baseline', 'wrong-name', 'deleted-dto', 'missing-selector',
                     'alias-wrong-unit', 'wrong-unit', 'runtime', 'monotonicity', 'route-loss',
                     'nested-context-loss', 'binding-flip', 'refuse-all', 'approved-plan-refused', 'anonymous-wrong-binding'):
        folder = output/mutation; folder.mkdir()
        subject = (next(c for c in cases if c['name'] == 'anon-partial-field')
                   if mutation == 'anonymous-wrong-binding' else
                   next(c for c in cases if c['name'] == 'r8-helper-collision-p9-weak-alias')
                   if mutation == 'approved-plan-refused' else
                   next(c for c in cases if c['name'] == 'generated-nested-none-after-intf')
                   if mutation == 'nested-context-loss' else
                   next(c for c in cases if c['name'] == 'r8-member-homonym-field-own-global')
                   if mutation == 'binding-flip' else base)
        row = json.loads(json.dumps(subject)); row['root'] = str(folder/'subject'); row['name']=subject['name'] if mutation == 'approved-plan-refused' else 'subject'
        row.pop('known_absent', None)
        shutil.copytree(subject['root'], row['root'], ignore=shutil.ignore_patterns('native', '*.sqlite*', '*-compile.json', '*-runtime.json'))
        if mutation == 'anonymous-wrong-binding':
            source = Path(row['root']) / 'Unit1.pas'
            text = source.read_text(encoding='ascii')
            # Preserve line/column identity of every existing WITH target.
            text = text.replace('  lOutside: Integer;', '  lOutside: Integer; Other: record A: Integer; end;')
            write(source, text)
            row['anonymous_types']['Unit1.pas'].append(['Other', 'Unit1.Run.Other'])
        for route in range(5):
            path = Path(row['root'])/f'route-{route}.json'
            raw = path.read_text(encoding='utf-8-sig').replace(json.dumps(subject['root'])[1:-1], json.dumps(row['root'])[1:-1])
            plan = json.loads(raw)
            if mutation != 'nested-context-loss':
                assert any(s['status']=='planned' for s in plan['statements']), ('Non-vacuity requires real published plans', route)
            else:
                targets = source_targets(Path(row['root']))
                inner = next(t for t in targets if len(t['context']) > len(t['selectors']))
                key = (inner['file'].lower(), inner['line'], inner['column'], 0)
                matches = [s for s in plan['selectors'] if (*target_key(s, Path(row['root'])), s['index']) == key]
                assert len(matches) == 1, ('Missing inherited-selector mutation target', key)
                plan['selectors'].remove(matches[0])
            if mutation=='wrong-name': plan['selectors'][0]['name']='TWrong'
            if mutation == 'anonymous-wrong-binding':
                plan['selectors'][0].update(unit='Unit1', name='Run.Other')
            if mutation=='deleted-dto': plan['statements']=[]; plan['selectors']=[]
            if mutation=='missing-selector': plan['selectors']=[]
            if mutation in ('alias-wrong-unit','wrong-unit'):
                if mutation=='alias-wrong-unit':
                    assert plan['selectors'][0]['name'].startswith('TAlias'), plan
                plan['selectors'][0]['unit']='WrongUnit'
            if mutation=='runtime':
                count=0
                for statement in plan['statements']:
                    for edit in statement['edits']:
                        edit['text'], changed = re.subn(r'\b5\b','91',edit['text']); count+=changed
                assert count, 'Runtime mutation did not change an actual published edit'
            if mutation=='binding-flip':
                count=0
                for statement in plan['statements']:
                    for edit in statement['edits']:
                        edit['text'], changed = re.subn(r'\b(?:\w+\^?\.)+Count\b', 'Count', edit['text'], flags=re.I)
                        count += changed
                assert count, 'Binding mutation did not change an actual qualified member reference'
            if mutation == 'approved-plan-refused':
                for statement in plan['statements']:
                    statement.update(status='skipped', reason='receiver-member-not-found',
                                     safety='HELPER_COLLISION_UNVERIFIED', edits=[], replacement='',
                                     temp_count=0, recipe_status='skipped', recipe_replacement='',
                                     recipe_edit_count=0, recipe_temp_count=0)
            if mutation=='refuse-all':
                row['expect_plan']=True
                for statement in plan['statements']:
                    statement['status']='skipped'; statement['edits']=[]
            path.write_text(json.dumps(plan),encoding='utf-8')
        inputs=[row]
        if mutation=='monotonicity':
            control=json.loads(json.dumps(row));control['name']='known-absent';control['root']=str(folder/'control')
            shutil.copytree(row['root'],control['root'])
            for route in range(5):
                path=Path(control['root'])/f'route-{route}.json'
                plan=json.loads(path.read_text().replace(json.dumps(row['root'])[1:-1],json.dumps(control['root'])[1:-1]))
                for statement in plan['statements']: statement['status']='skipped';statement['edits']=[]
                path.write_text(json.dumps(plan))
            row['known_absent']=control['name'];inputs.append(control)
        if mutation=='route-loss':
            path=Path(row['root'])/'route-4.json';path.rename(path.with_suffix('.missing'))
        (folder/'cases.json').write_text(json.dumps(inputs,indent=2))
        command=[str(Path(__file__).resolve()),'compare',str(folder),'--bds',str(bds)]
        import sys
        process=run([sys.executable,'-B',*command],folder,folder/'receipt.json')
        result=json.loads((folder/'comparison.json').read_text())
        expected = { 'baseline': None, 'anonymous-wrong-binding': 'compiler-identity', 'wrong-name': 'compiler-identity',
            'deleted-dto': 'statement-coverage', 'missing-selector': 'selector-coverage',
            'alias-wrong-unit': 'compiler-identity', 'wrong-unit': 'compiler-identity',
            'runtime': 'runtime-output', 'monotonicity': 'monotonicity',
            'route-loss': 'route-invalid-or-missing', 'nested-context-loss': 'selector-coverage',
            'binding-flip': 'runtime-output', 'refuse-all': 'positive-control-refused',
            'approved-plan-refused': 'approved-batch-contract'}[mutation]
        detected = (process['exit']==0 and not result['failures']) if expected is None else (
            process['exit']==1 and any(f['cause']==expected and
                (mutation != 'anonymous-wrong-binding' or f['field'] == 3) for f in result['failures']))
        results.append(dict(mutation=mutation,exit=process['exit'],detected=detected,
                            expected=expected,failures=len(result['failures']),seconds=process['seconds']))
    (root/'comparator-mutations.json').write_text(json.dumps(results,indent=2))
    print(json.dumps(results,indent=2))
    return int(not all(r['detected'] for r in results))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("operation", choices=("generate", "compare", "challenge"))
    parser.add_argument("root", type=Path)
    parser.add_argument("--repo", type=Path)
    parser.add_argument("--bds", type=Path)
    parser.add_argument("--full", action="store_true")
    parser.add_argument("--only", default="")
    parser.add_argument("--include-evidence", choices=("certified", "absent", "unresolved"), default="certified")
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--allowed-changes", type=Path)
    parser.add_argument("--stop-runtime", action="store_true")
    args = parser.parse_args()
    args.root.mkdir(parents=True, exist_ok=True)
    if args.operation == "generate":
        generate(args.repo, args.root, args.full, args.only, args.include_evidence)
    elif args.operation == "challenge":
        raise SystemExit(challenge(args.root, args.bds))
    else:
        raise SystemExit(compare(args.root, args.bds, args.baseline, args.allowed_changes, args.stop_runtime))
