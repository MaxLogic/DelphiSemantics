"""Fail-closed regression cases for native pointer verification metadata (DS-787)."""
from pathlib import Path
import copy
import importlib.util
import os
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('native_reference', Path(__file__).with_name('ds719-native-reference.py'))
native = importlib.util.module_from_spec(spec)
spec.loader.exec_module(native)


class VerificationMetadataTests(unittest.TestCase):
    def test_pointer_initializations_require_complete_native_recipes(self):
        owner = Path(os.environ['DS_TEST_OUTPUT_ROOT'])
        owner.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='ds787-', dir=owner) as directory:
            root = Path(directory)
            source = root / 'Unit1.pas'
            plain = 'lWithFooPtr := @Item;'
            typed = '{$IFOPT T-}{$T+}' + plain + '{$T-}{$ELSE}' + plain + '{$ENDIF}'
            edit = dict(file=str(source), sl=1, sc=1, el=1, ec=1,
                        kind='replace-statement', text=plain,
                        verification=[dict(offset=1, plain=plain, typed=typed)])
            statement = dict(status='planned', file=str(source), edits=[edit],
                             pointer_initializations=[plain])
            valid = dict(statements=[statement])
            for scenario in ('missing-key', 'empty', 'missing-inventory', 'wrong-wrapper', 'quoted-only', 'duplicate', 'valid'):
                with self.subTest(scenario=scenario):
                    plan = copy.deepcopy(valid)
                    current = plan['statements'][0]
                    recipe = current['edits'][0]
                    if scenario == 'missing-key':
                        del recipe['verification']
                    elif scenario == 'empty':
                        recipe['verification'] = []
                    elif scenario == 'missing-inventory':
                        del current['pointer_initializations']
                    elif scenario == 'wrong-wrapper':
                        recipe['verification'][0]['typed'] = plain
                    elif scenario == 'duplicate':
                        recipe['text'] = plain + '\n' + plain
                    elif scenario == 'quoted-only':
                        recipe['text'] = "Writeln('" + plain + "');"
                        recipe['verification'][0]['offset'] = recipe['text'].index(plain) + 1
                    original = b'x\r\n'
                    source.write_bytes(original)
                    if scenario == 'valid':
                        native.apply_edits(root, plan)
                        self.assertEqual((typed + '\r\n').encode(), source.read_bytes())
                    else:
                        with self.assertRaises((AssertionError, KeyError)):
                            native.apply_edits(root, plan)
                        self.assertEqual(original, source.read_bytes(), 'Refuse before writing any unverified source')


if __name__ == '__main__':
    unittest.main()
