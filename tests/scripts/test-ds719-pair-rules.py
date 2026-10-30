"""Pins for the DS-719 paired-control obligation, separate from plan acceptance."""
from pathlib import Path
import importlib.util
import os
import unittest


module_path = Path(os.environ.get('DS719_PAIR_RULE_MODULE',
                   str(Path(__file__).with_name('ds719-native-reference.py'))))
spec = importlib.util.spec_from_file_location('reference', module_path)
reference = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reference)


class PairRules(unittest.TestCase):
    def test_control_records_different_refusal_without_claiming_a_plan(self):
        for cause in ('OWNER_INHERITED_MEMBERS_UNVERIFIED',
                      'controlled-with-statement', 'ALIAS_RECEIVER_MEMBERS_UNVERIFIED',
                      'receiver-member-unqualified'):
            with self.subTest(cause=cause):
                plan = {'statements': [{'status': 'skipped', 'safety': cause}]}
                result = reference.pair_route_result(plan, 'control')
                self.assertEqual('pass', result['result'])
                self.assertEqual('collision-absent', result['obligation'])
                self.assertEqual('skipped', result['statements'][0]['status'])
                self.assertEqual(cause, result['statements'][0]['safety'])
                self.assertNotIn('expect_plan', result)

    def test_collision_cause_remaining_fails_control(self):
        for key in ('cause', 'reason', 'safety'):
            with self.subTest(key=key):
                plan = {'statements': [{'status': 'skipped', key: 'helper-collision'}]}
                result = reference.pair_route_result(plan, 'control')
                self.assertEqual('fail', result['result'])
                self.assertEqual('paired-control-collision-remains', result['cause'])

    def test_only_collision_refusal_proves_collision_case(self):
        for cause, expected in [('helper-collision', 'pass'),
                                ('OWNER_INHERITED_MEMBERS_UNVERIFIED', 'fail'),
                                ('TYPE_VALUE_MEMBERS_UNVERIFIED', 'fail')]:
            with self.subTest(cause=cause):
                result = reference.pair_route_result(
                    {'statements': [{'status': 'skipped', 'cause': cause}]}, 'collision')
                self.assertEqual(expected, result['result'])

    def test_planning_collision_requires_native_check_and_3d_refusal(self):
        result = reference.pair_route_result(
            {'statements': [{'status': 'planned'}]},
            'collision')
        self.assertEqual('fail', result['result'])
        self.assertEqual('collision-refusal-required', result['cause'])
        self.assertEqual('planned-needs-native-check', result['classification'])

    def test_pair_native_failure_stops_without_optional_runtime_flag(self):
        for receipt in ({'build': {'exit': 1}},
                        {'build': {'exit': 0}, 'runtime': {'exit': 1, 'stdout': '19'}},
                        {'build': {'exit': 0}, 'runtime': {'exit': 0, 'stdout': '11'}}):
            with self.subTest(receipt=receipt):
                self.assertTrue(reference.rewrite_must_stop(
                    {'pair_role': 'collision'}, receipt, '19', False))
        self.assertFalse(reference.rewrite_must_stop(
            {'pair_role': 'collision'},
            {'build': {'exit': 0}, 'runtime': {'exit': 0, 'stdout': '19'}}, '19', False))

    def test_missing_or_unnamed_result_cannot_pass(self):
        for plan in ({'statements': []},
                     {'statements': [{'status': 'skipped'}]},
                     {'statements': [{'status': 'unknown', 'reason': 'named'}]}):
            with self.subTest(plan=plan):
                self.assertEqual('fail', reference.pair_route_result(plan, 'control')['result'])


if __name__ == '__main__':
    unittest.main()
