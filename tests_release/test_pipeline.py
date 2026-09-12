"""Exercise failure gates without Apple credentials or a real App upload."""
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class PipelineTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        (self.root / 'scripts').mkdir()
        (self.root / 'bin').mkdir()
        for name in ('release.sh', 'release_support.py'):
            shutil.copy(ROOT / 'scripts' / name, self.root / 'scripts' / name)
        (self.root / 'scripts/signing-identity.sh').write_text('select_signing_identity() { return 0; }\n')
        (self.root / 'scripts/build-app.sh').write_text('#!/bin/bash\nexit 0\n')
        app = self.root / 'dist/distribution/LidFold.app/Contents'
        (app / 'MacOS').mkdir(parents=True)
        (app / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleShortVersionString': '1.2.3'}))
        binary = app / 'MacOS/LidFold'
        binary.write_text('#!/bin/bash\nexit 0\n')
        binary.chmod(0o755)
        fake = self.root / 'bin/fake'
        fake.write_text('#!' + sys.executable + '\n' + '''
import json, os, pathlib, shutil, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
stage = name + (' ' + ' '.join(args[:2]) if name == 'xcrun' else '')
with open(os.environ['TRACE'], 'a') as log:
    log.write(stage + '\\n')
if stage == os.environ.get('FAIL_STAGE'):
    sys.exit(1)
if name == 'xcrun':
    if args[0] == '--find': print('/fixture/' + args[1])
    elif args[:2] == ['notarytool', 'submit']:
        print(json.dumps({'status': os.environ.get('NOTARY_STATUS', 'Accepted')}))
elif name == 'ditto':
    if args[0] == '-c': pathlib.Path(args[-1]).write_bytes(b'fixture archive')
    else: shutil.copytree(args[0], args[1])
''')
        fake.chmod(0o755)
        for name in ('xcrun', 'ditto', 'codesign', 'spctl'):
            (self.root / 'bin' / name).symlink_to(fake)
        self.env = {**os.environ, 'PATH': str(self.root / 'bin') + os.pathsep + os.environ['PATH'],
                    'LIDFOLD_NOTARY_PROFILE': 'fixture', 'TRACE': str(self.root / 'trace')}

    def run_release(self, **extra):
        return subprocess.run(['bash', str(self.root / 'scripts/release.sh')],
                              env={**self.env, **extra}, text=True, capture_output=True)

    def test_success_publishes_checksum_only_after_all_gates(self):
        result = self.run_release()
        self.assertEqual(result.returncode, 0, result.stderr)
        output = self.root / 'dist/releases/1.2.3'
        self.assertTrue((output / 'LidFold-1.2.3-arm64.zip').exists())
        self.assertIn('LidFold-1.2.3-arm64.zip', (output / 'SHA256SUMS').read_text())
        trace = (self.root / 'trace').read_text()
        self.assertLess(trace.index('xcrun stapler validate'), trace.index('spctl'))
        self.assertFalse((self.root / '.build/release.lock').exists())

    def test_rejected_notarization_never_produces_release(self):
        result = self.run_release(NOTARY_STATUS='Invalid')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / 'dist/releases/1.2.3').exists())
        self.assertNotIn('stapler', (self.root / 'trace').read_text().replace('xcrun --find stapler', ''))

    def test_failures_before_publication_leave_no_archive(self):
        for stage in ('codesign', 'xcrun notarytool submit', 'xcrun stapler staple', 'xcrun stapler validate', 'spctl'):
            with self.subTest(stage=stage):
                result = self.run_release(FAIL_STAGE=stage)
                self.assertNotEqual(result.returncode, 0, stage)
                self.assertFalse((self.root / 'dist/releases/1.2.3').exists())
                self.assertFalse((self.root / '.build/release.lock').exists())

    def test_existing_version_is_never_overwritten(self):
        output = self.root / 'dist/releases/1.2.3'
        output.mkdir(parents=True)
        sentinel = output / 'keep'
        sentinel.write_text('existing release')
        result = self.run_release()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(sentinel.read_text(), 'existing release')
        self.assertEqual(len(list(output.iterdir())), 1)

    def test_parallel_release_lock_is_preserved(self):
        lock = self.root / '.build/release.lock'
        lock.mkdir(parents=True)
        result = self.run_release()
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(lock.exists())


if __name__ == '__main__':
    unittest.main()
