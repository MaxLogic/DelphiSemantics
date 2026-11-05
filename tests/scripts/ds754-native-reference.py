"""Native lifetime and compiler-selected helper regressions for DS-754/DS-755.

The Delphi fixture publishes five real planner routes. We apply those published
edits and compare complete dcc64 runtime output, including reference-count traces.
This is developer-only proof; no name-resolution algorithm is duplicated here.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

spec = importlib.util.spec_from_file_location(
    'native_oracle', Path(__file__).with_name('ds719-native-reference.py'))
oracle = importlib.util.module_from_spec(spec)
spec.loader.exec_module(oracle)


def generate(root, family, bds):
    cases = []
    shapes = ('normal', 'exception') if family == 'ds754' else (
        'sdk-first', 'sdk-late', 'project-first', 'alias-sdk', 'alias-project', 'direct')
    for shape in shapes:
        folder = root / shape
        if family == 'ds754':
            receiver = 'IFoo'
            body = ("try\n    with lValue do Fail;\n  except\n"
                    "    on E: Exception do Writeln('caught ', E.Message);\n  end;"
                    if shape == 'exception' else 'with lValue do Touch;')
            source = """unit Unit1;
interface
uses System.SysUtils;
type
  IFoo = interface(IInterface)
    procedure Touch;
    procedure Fail;
  end;
  IAlias = IFoo;
  TFoo = class(TInterfacedObject, IFoo)
  public
    destructor Destroy; override;
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
    procedure Touch;
    procedure Fail;
  end;
procedure Run;
implementation
destructor TFoo.Destroy;
begin
  Writeln('destroy');
  inherited;
end;
function TFoo._AddRef: Integer;
begin
  Result := inherited _AddRef;
  Writeln('add ', Result);
end;
function TFoo._Release: Integer;
begin
  Writeln('release');
  Result := inherited _Release;
end;
procedure TFoo.Touch;
begin
  Writeln('touch');
end;
procedure TFoo.Fail;
begin
  Writeln('fail');
  raise Exception.Create('expected');
end;
procedure Run;
var
  lValue: RECEIVER;
  lCount: Integer;
begin
  lValue := TFoo.Create;
  Writeln('before');
  BODY
  lCount := lValue._AddRef;
  Writeln('after-count ', lCount);
  lValue._Release;
  Writeln('before-clear');
  lValue := nil;
  Writeln('after-clear');
end;
end.
""".replace('RECEIVER', receiver).replace('BODY', body)
            oracle.write(folder / 'Unit1.pas', source)
            refs = ['Unit1']
            scopes, aliases = 'System;Winapi', ''
        else:
            oracle.write(folder / 'A.pas', """unit A;
interface
type
  TC = class(TObject)
  end;
implementation
end.
""")
            oracle.write(folder / 'MyApp.ADO.Migrate.pas', """unit MyApp.ADO.Migrate;
interface
uses A;
type
  TCHelper = class helper for TC
    function GetLoginUsername: string;
  end;
implementation
function TCHelper.GetLoginUsername: string;
begin
  Result := 'project-helper';
  Writeln(Result);
end;
end.
""")
            site = 'Chosen' if shape.startswith('alias-') else 'ADO.Migrate'
            oracle.write(folder / 'Unit1.pas', """unit Unit1;
interface
uses A, SITE;
procedure Run;
implementation
function GetLoginUsername: string;
begin
  Result := 'lexical';
  Writeln(Result);
end;
procedure Run;
var
  c: TC;
begin
  c := TC.Create;
  try
    with c do GetLoginUsername;
  finally
    c.Free;
  end;
end;
end.
""".replace('SITE', site))
            refs = ['Unit1', 'A', 'MyApp.ADO.Migrate']
            scopes = ('MyApp;FireDAC;System;Winapi' if shape == 'project-first'
                      else 'FireDAC;MyApp;System;Winapi')
            if shape == 'sdk-late':
                scopes = 'FireDAC;' + ';'.join('Unused' + str(i) for i in range(11)) + ';MyApp;System;Winapi'
            aliases = {'alias-sdk': 'Chosen=FireDAC.ADO.Migrate',
                       'alias-project': 'Chosen=MyApp.ADO.Migrate'}.get(shape, '')
            if shape == 'direct':
                oracle.write(folder / 'Unit1.pas', """unit Unit1;
interface
uses ADO.Migrate;
type
  TRec = record
    Value: Integer;
  end;
procedure Run;
implementation
procedure Run;
var
  r: TRec;
begin
  with r do Value := 7;
  Writeln(r.Value);
end;
end.
""")
        oracle.project(folder, refs, search='.', aliases=aliases)
        if family == 'ds755':
            # DCCReference supplies project inventory, not a DPR unit alias.
            # Listing the helper in the DPR pins that identity before -NS.
            oracle.write(folder / 'P.dpr',
                         "program P; {$APPTYPE CONSOLE} uses Unit1; begin Unit1.Run; end.\n")
        path = folder / 'P.dproj'
        oracle.write(path, path.read_text().replace(
            '<DCC_Namespace>System;Winapi</DCC_Namespace>',
            '<DCC_Namespace>' + scopes + '</DCC_Namespace>'))
        if shape in ('sdk-first', 'sdk-late', 'alias-sdk', 'direct'):
            # With only SDK DCUs, dcc64 can prefer an available project source.
            # Supply the real SDK source path in BOTH DS and native contexts.
            padding = (';'.join('UnusedPath' + str(i) for i in range(33)) + ';'
                       if shape == 'sdk-late' else '')
            oracle.write(path, path.read_text().replace(
                '<DCC_UnitSearchPath>.</DCC_UnitSearchPath>',
                '<DCC_UnitSearchPath>' + padding + str(bds / 'source/data/firedac') + ';.</DCC_UnitSearchPath>'))
        row = dict(name=shape, root=str(folder), family=family)
        if family == 'ds754':
            row['refuse'] = True
        else:
            row['expected_output'] = ('7\n' if shape == 'direct' else
                'project-helper\n' if shape in ('project-first', 'alias-project') else 'lexical\n')
            if shape == 'direct':
                row['plan'] = True
        cases.append(row)
    (root / 'cases.json').write_text(json.dumps(cases, indent=2))


def native(folder, bds, tag):
    tree = ET.parse(folder / 'P.dproj')
    ns = {'m': 'http://schemas.microsoft.com/developer/msbuild/2003'}
    def prop(name):
        node = tree.find('./m:PropertyGroup/m:' + name, ns)
        return node.text or '' if node is not None else ''
    output = folder / 'native' / tag
    output.mkdir(parents=True, exist_ok=True)
    search = prop('DCC_UnitSearchPath').replace('$(BDS)', str(bds))
    search = ';'.join(str(folder / item) if not Path(item).is_absolute() else item
                      for item in search.split(';') if item)
    command = [bds / 'bin/dcc64.exe', '-B', '-Q', '--no-config',
               '-NS' + prop('DCC_Namespace'),
               '-U' + search + ';' + str(bds / 'lib/win64/release'),
               '-A' + prop('DCC_UnitAlias'), '-E' + str(output),
               '-N0' + str(output), folder / 'P.dpr']
    build = oracle.run(command, folder, folder / (tag + '-compile.json'))
    runtime = None if build['exit'] else oracle.run(
        [output / 'P.exe'], folder, folder / (tag + '-runtime.json'))
    return dict(build=build, runtime=runtime)


def compare(root, bds):
    rows, failures = [], []
    for case in json.loads((root / 'cases.json').read_text()):
        folder = Path(case['root'])
        original = native(folder, bds, 'orig')
        if original['build']['exit'] or original['runtime']['exit']:
            failures.append(dict(case=case['name'], cause='original', native=original))
            continue
        expected = original['runtime']['stdout']
        if 'expected_output' in case and expected != case['expected_output'].replace('\n', '\r\n'):
            failures.append(dict(case=case['name'], cause='compiler-selection', actual=expected))
        if case['family'] == 'ds754':
            # Destruction must occur before the marker even on exception exit.
            if not ('destroy\r\nafter-clear\r\n' in expected and 'after-count 2\r\n' in expected):
                failures.append(dict(case=case['name'], cause='lifetime-oracle', actual=expected))
        raw = {p: p.read_bytes() for p in folder.glob('*.pas')}
        for route in range(5):
            path = folder / ('route-' + str(route) + '.json')
            if not path.is_file():
                failures.append(dict(case=case['name'], route=route, cause='missing-route'))
                continue
            plan = json.loads(path.read_text(encoding='utf-8-sig'))
            if len(plan['statements']) != 1:
                failures.append(dict(case=case['name'], route=route, cause='statement-count'))
                continue
            statement = plan['statements'][0]
            row = dict(case=case['name'], route=route, status=statement['status'],
                       reason=statement['reason'], original=original)
            rows.append(row)
            if case.get('refuse') and statement['status'] != 'skipped':
                failures.append(dict(case=case['name'], route=route, cause='interface-reference-temp'))
            if case.get('refuse') and statement['status'] == 'skipped' and statement['reason'] != 'receiver-type-not-visible':
                failures.append(dict(case=case['name'], route=route, cause='unrelated-interface-refusal',
                                     reason=statement['reason']))
            if case.get('plan') and statement['status'] != 'planned':
                failures.append(dict(case=case['name'], route=route, cause='direct-control-refused'))
            if statement['status'] != 'planned':
                if (statement['status'] != 'skipped' or not statement['reason'] or
                    statement['replacement'] or statement['edits'] or statement['temp_count']):
                    failures.append(dict(case=case['name'], route=route, cause='invalid-refusal'))
                continue
            try:
                oracle.apply_edits(folder, plan)
                rewrite = native(folder, bds, 'r' + str(route))
                row['rewrite'] = rewrite
                if (rewrite['build']['exit'] or rewrite['runtime']['exit'] or
                    rewrite['runtime']['stdout'] != expected):
                    failures.append(dict(case=case['name'], route=route,
                                         cause='rewrite-compile-runtime', native=rewrite))
            finally:
                for path, content in raw.items():
                    path.write_bytes(content)
    result = dict(rows=rows, failures=failures)
    (root / 'comparison.json').write_text(json.dumps(result, indent=2))
    print(json.dumps(dict(routes=len(rows), failures=len(failures))))
    return bool(failures)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('operation', choices=['generate', 'compare'])
    parser.add_argument('root', type=Path)
    parser.add_argument('--repo', type=Path)
    parser.add_argument('--bds', type=Path)
    parser.add_argument('--only', choices=['ds754', 'ds755'])
    args = parser.parse_args()
    args.root.mkdir(parents=True, exist_ok=True)
    if args.operation == 'generate':
        generate(args.root, args.only, args.bds)
    else:
        sys.exit(compare(args.root, args.bds))
