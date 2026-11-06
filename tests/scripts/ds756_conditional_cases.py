"""DS-756/723/775 compiler regressions, consumed by the five-route oracle."""


def conditional_cases(root, write, project):
    rows = []
    predicates = [(name.lower(), directive, value)
                  for name, value in [('UNICODE', True), ('CONDITIONALEXPRESSIONS', True),
                                      ('NATIVECODE', True), ('ASSEMBLER', True),
                                      ('VER360', True), ('CONSOLE', True), ('MSWINDOWS', True),
                                      ('WIN64', True), ('CPUX64', True), ('WIN32', False),
                                      ('POSIX', False)]
                  for directive in ('IFDEF ' + name, 'IF Defined(' + name + ')')]
    predicates += [('compiler-eq', 'IF CompilerVersion = 36.0', True),
                   ('compiler-lt', 'IF CompilerVersion < 36', False),
                   ('compiler-ge', 'IF CompilerVersion >= 36', True),
                   ('compiler-ne', 'IF CompilerVersion <> 36', False),
                   ('compiler-reverse', 'IF 35.0 < CompilerVersion', True),
                   ('rtl-eq', 'IF RTLVersion = 36.0', True),
                   ('rtl-gt', 'IF RTLVersion > 36', False),
                   ('rtl-le', 'IF RTLVersion <= 36.0', True)]
    for index, (label, predicate, value) in enumerate(predicates):
        name = f'ds756-{label}-{index}'
        source = ('unit Unit1;\ninterface\ntype TRec = record\n'
                  '{$' + predicate + '} Count: Integer; {$ELSE} Other: Integer; {$ENDIF}\nend;\n'
                  'procedure Run;\nimplementation\nprocedure Run;\nvar Item: TRec; Count: Integer;\nbegin\n'
                  'Count := 100; {$' + predicate + '} Item.Count := 1; {$ELSE} Item.Other := 1; {$ENDIF}\n'
                  'with Item do Count := Count + 1;\n'
                  '{$' + predicate + '} Write(Item.Count); {$ELSE} Write(Item.Other); {$ENDIF}\n'
                  "Writeln('/', Count);\nend;\nend.\n")
        rows.append(dict(name=name, source=source, expect_plan=True, define_evidence='present',
                         expect_no_skipped_includes=label.startswith(('compiler-', 'rtl-')),
                         expected_native_output='2/100\r\n' if value else '1/101\r\n'))
    for scope in ('missing-evidence', 'local-shadow', 'escaped-shadow', 'import-shadow', 'opaque-import', 'include-shadow'):
        declarations = 'const CompilerVersion = 99.0;\n' if scope in ('local-shadow', 'escaped-shadow') else ''
        if scope == 'escaped-shadow':
            declarations = 'const &CompilerVersion = 99.0;\n'
        imports = 'uses OtherUnit;\n' if scope == 'import-shadow' else 'uses System.SysUtils;\n' if scope == 'opaque-import' else ''
        files = {'OtherUnit.pas': 'unit OtherUnit; interface const CompilerVersion = 99.0; implementation end.\n'} if scope == 'import-shadow' else {}
        if scope == 'include-shadow':
            files['shadow.inc'] = 'const CompilerVersion = 99.0;\n'
            declarations = '{$I shadow.inc}\n'
        source = ('unit Unit1;\ninterface\n' + imports + declarations +
                  'type TRec = record {$IF CompilerVersion = 36.0} Count: Integer; {$ELSE} Other: Integer; {$ENDIF} end;\n'
                  'procedure Run;\nimplementation\nprocedure Run;\nvar Item: TRec; Count: Integer;\nbegin\n'
                  'Count := 100; {$IF CompilerVersion = 36.0} Item.Count := 1; {$ELSE} Item.Other := 1; {$ENDIF}\n'
                  'with Item do Count := Count + 1;\n'
                  '{$IF CompilerVersion = 36.0} Write(Item.Count); {$ELSE} Write(Item.Other); {$ENDIF}\n'
                  "Writeln('/', Count);\nend;\nend.\n")
        rows.append(dict(name='ds756-scope-' + scope, source=source, files=files,
                         refs=['OtherUnit', 'Unit1'] if scope == 'import-shadow' else ['Unit1'],
                         expect_plan=False, require_named_refusal=True,
                         define_evidence='missing' if scope == 'missing-evidence' else 'present',
                         expected_native_output='2/100\r\n' if scope in ('missing-evidence', 'opaque-import') else '1/101\r\n'))
    for shape in ('if', 'while', 'for', 'with', 'single', 'active', 'false'):
        for feature in (False, True):
            name = f'ds723-{shape}-' + ('set' if feature else 'unset')
            prefix = {'if': 'if Flag then ', 'while': 'while Flag do ',
                      'for': 'for i := 1 to 0 do ', 'with': 'with Inner do ',
                      'single': 'if Flag then ', 'active': 'if Flag then ',
                      'false': 'if Flag then '}[shape]
            condition = {'active': 'IF True', 'false': 'IF False'}.get(shape, 'IFDEF FEATURE')
            header = '{$' + condition + '}' + prefix + '{$ENDIF}'
            source = ('unit Unit1;\ninterface\ntype\n  TRec = record\n    Count: Integer;\n  end;\n'
                      'procedure Run;\nimplementation\nprocedure Work(var Item: TRec);\n'
                      'var\n  Inner: TRec;\n  Flag: Boolean;\n  i: Integer;\n'
                      'begin\nInner.Count := 3; Flag := False;\n{DS723_IDENTITY}\n'
                      + header + 'with Item do Count := 5;\n'
                      + "Writeln(Item.Count, '/', Inner.Count);\nend;\n"
                      + 'procedure Run;\nvar\n  Item: TRec;\nbegin\nItem.Count := 1; Work(Item);\nend;\nend.\n')
            if shape == 'single':
                # Alias receivers already use direct qualification (DS-731).
                source = ('unit Unit1;\ninterface\ntype\n  TRec = record\n    Count: Integer;\n  end;\n'
                          '  TAlias = TRec;\nprocedure Run;\nimplementation\nvar Item: TAlias;\n'
                          'procedure Run;\nvar Flag: Boolean;\nbegin\nItem.Count := 1; Flag := False;\n{DS723_IDENTITY}\n'
                          + header + 'with Item do Count := 5;\n'
                          + "Writeln(Item.Count, '/3');\nend;\nend.\n")
            governed = shape == 'active' or (shape not in ('false', 'with') and feature)
            rows.append(dict(name=name, source=source, expect_plan=True, define_evidence='missing',
                             expect_no_temps=shape == 'single',
                             expect_control_wrapper=shape != 'single',
                             conditional_with_prefix=shape == 'with',
                             identity_prelude_marker='{DS723_IDENTITY}',
                             alias_types=[('TAlias', 'Unit1.TAlias')] if shape == 'single' else [],
                             expected_native_output='1/3\r\n' if governed else '5/3\r\n',
                             properties={'DCC_AdditionalSwitches': '-DFEATURE' if feature else ''}))
    structures = {
        'k1r': ('type TX = record Q: Integer; {$I split.inc} X: Integer; end;\n',
                {'split.inc': '{$IFOPT R-}end; TZ = record{$ENDIF}'}),
        'k2r': ('type TX = record Q: Integer; {$IFOPT R-}end; TZ = record{$ENDIF} X: Integer; end;\n', {}),
        'ancestor': ('type TBase = class Q: Integer; end;\n'
                     'TX = class {$IFOPT R+}(TBase){$ENDIF} X: Integer; end;\n', {}),
        'helper': ('type TX = record type TNested = record Q: Integer; end; var Q: Integer; end;\n'
                   'TH = record helper for TX {$IFOPT R+}.TNested{$ENDIF} function ReadQ: Integer; end;\n', {}),
    }
    for shape, (declarations, files) in structures.items():
        if shape in ('k1r', 'k2r'):
            # Exact historical false-member shape: Q is lexical under dcc64,
            # but dropping the structural span makes it look like TX.Q.
            split = '{$I split.inc}' if shape == 'k1r' else '{$IFOPT R-}end; TZ = record{$ENDIF}'
            declarations = 'unit A;\ninterface\ntype TX = record X: Integer; ' + split + '\nQ: Integer; end;\nimplementation\nend.\n'
            source = ('unit Unit1;\ninterface\nprocedure Run;\nimplementation\nuses A;\n'
                      'var Q: Integer; Item: TX;\nprocedure Run;\nbegin\n'
                      "Q := 0; FillChar(Item, SizeOf(Item), 0); with Item do Q := 5; Writeln('VALUE=', Q);\nend;\nend.\n")
            rows.append(dict(name='ds775-historical-' + shape, source=source,
                             files={'A.pas': declarations, **files}, refs=['A', 'Unit1'],
                             expect_plan=False, require_named_refusal=True, define_evidence='missing',
                             expect_member_activity='A', expected_native_output='VALUE=5\r\n', properties={'DCC_RangeChecking': 'false'}))
            continue
        if shape == 'ancestor':
            run = "Item := TX.Create; try with Item do X := 5; Writeln(Item.X); finally Item.Free; end;"
        elif shape == 'helper':
            run = 'Item.Q := 2; with Item do Q := ReadQ + 1; Writeln(Item.Q);'
        else:
            run = 'FillChar(Item, SizeOf(Item), 0); with Item do X := 5; Writeln(Item.X);'
        source = ('unit Unit1;\ninterface\n' + declarations + 'procedure Run;\nimplementation\n' +
                  ('function TH.ReadQ: Integer; begin Result := Q; end;\n' if shape == 'helper' else '') +
                  'procedure Run;\nvar Item: ' + ('TZ' if shape in ('k1r', 'k2r') else 'TX') + ';\nbegin\n' +
                  run + '\nend;\nend.\n')
        # R- selects the split forms; R+ selects the ancestor/helper alternatives.
        rows.append(dict(name='ds775-' + shape, source=source, files=files, expect_plan=False,
                         expect_member_activity='Unit1',
                         require_named_refusal=True, define_evidence='missing',
                         properties={'DCC_RangeChecking': 'false' if shape in ('k1r', 'k2r', 'helper') else 'true'}))
    if root is None:
        return rows
    for row in rows:
        folder = root / row['name']
        write(folder / 'Unit1.pas', row.pop('source'))
        for name, source in row.pop('files', {}).items():
            write(folder / name, source)
        project(folder, row.pop('refs', ['Unit1']),
                msbuild_properties={'DCC_ConsoleTarget': 'true', **row.pop('properties', {})})
        row.update(root=str(folder), family='ds756-conditional', routes=list(range(5)),
                   identity_names=['TRec', 'TX', 'TZ', 'TBase', 'TY'], identity_probe_interface_import=True)
    return rows
