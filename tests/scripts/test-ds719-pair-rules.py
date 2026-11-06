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


    def test_covered_child_requires_a_planned_containing_parent(self):
        folder = Path.cwd()
        path = str(folder / 'Unit1.pas')
        targets = [dict(file='Unit1.pas', line=10, column=3, context=[]),
                   dict(file='Unit1.pas', line=12, column=5, context=[])]
        parent = dict(id='outer', file=path, sl=10, sc=3, el=16, ec=6, status='planned')
        child = dict(file=path, sl=12, sc=5, el=15, ec=7,
                     parent='outer', reason='covered-by-parent-rewrite')
        variants = [({}, {}, True), ({'status': 'skipped'}, {}, False),
                    ({'el': 11}, {}, False), ({}, {'parent': 'missing'}, False),
                    ({}, {'reason': 'not-covered'}, False)]
        for parent_change, child_change, valid in variants:
            with self.subTest(parent=parent_change, child=child_change):
                plan = dict(statements=[dict(parent, **parent_change)],
                            covered=[dict(child, **child_change)], selectors=[])
                statements, _, errors = reference.check_coverage(plan, targets, folder)
                self.assertEqual(valid, not errors, errors)
                if valid:
                    self.assertIs(statements[('unit1.pas', 12, 5)], plan['statements'][0])


if __name__ == '__main__':
    unittest.main()
