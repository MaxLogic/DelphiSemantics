"""The native reference runner must protect DAK and its descendants."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    'native_reference', Path(__file__).with_name('ds719-native-reference.py'))
reference = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reference)


class CrashEnvironmentTests(unittest.TestCase):
    def test_native_children_are_safe_with_an_unsafe_parent(self):
        with tempfile.TemporaryDirectory(prefix='dak483-') as folder:
            root = Path(folder)
            # Native fixture overrides must not re-enable crash uploads.
            (root / 'native-environment.json').write_text(json.dumps({
                'MAXLOGIC_MADEXCEPT_AI': '0',
                'DAK_TEST_DISABLE_CRASH_SEND': '0'}))
            with patch.dict(os.environ, {'MAXLOGIC_MADEXCEPT_AI': '0'}):
                with patch.object(reference.subprocess, 'run', return_value=
                                  subprocess.CompletedProcess([], 0, b'good', b'')) as child:
                    reference.run(['DelphiAIKit.exe', '--help'], root, root / 'run.json')
            self.assertEqual('1', child.call_args.kwargs['env']['MAXLOGIC_MADEXCEPT_AI'])
            self.assertEqual('1', child.call_args.kwargs['env']['DAK_TEST_DISABLE_CRASH_SEND'])


if __name__ == '__main__':
    unittest.main()
