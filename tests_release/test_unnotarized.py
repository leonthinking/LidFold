"""Unnotarized downloads must be explicit, isolated, and complete before publication."""
import shutil
import subprocess
import unittest

import test_pipeline

ROOT = test_pipeline.ROOT


class UnnotarizedTests(unittest.TestCase):
    def setUp(self):
        test_pipeline.PipelineTests.setUp(self)
        shutil.copy(ROOT / 'scripts/release-unnotarized.sh', self.root / 'scripts/release-unnotarized.sh')
        (self.root / 'docs').mkdir()
        shutil.copy(ROOT / 'docs/INSTALL.txt', self.root / 'docs/INSTALL.txt')
        # Extend the fixture command set; no Apple credentials or real disk images are used.
        fake = self.root / 'bin/fake'
        with fake.open('a') as output:
            output.write('''
elif name == 'codesign' and args[0] == '-dv':
    print('Signature=' + os.environ.get('SIGNATURE', 'adhoc'), file=sys.stderr)
elif name == 'lipo':
    print(os.environ.get('ARCH', 'arm64'))
elif name == 'hdiutil':
    if args[0] == os.environ.get('FAIL_HDIUTIL'): sys.exit(1)
    if args[0] == 'create': pathlib.Path(args[-1]).write_bytes(b'fixture dmg')
''')
        for name in ('hdiutil', 'lipo'):
            (self.root / 'bin' / name).symlink_to(fake)

    def run_release(self, **extra):
        return subprocess.run(['bash', str(self.root / 'scripts/release-unnotarized.sh')],
                              env={**self.env, **extra}, text=True, capture_output=True)

    def test_complete_download_set_and_no_notarization_claim(self):
        result = self.run_release()
        self.assertEqual(result.returncode, 0, result.stderr)
        folder = self.root / 'dist/releases-unnotarized/1.2.3'
        self.assertEqual({p.name for p in folder.iterdir()}, {
            'LidFold-1.2.3-arm64-unnotarized.dmg',
            'LidFold-1.2.3-arm64-unnotarized.zip', 'SHA256SUMS'})
        result = subprocess.run(['shasum', '-a', '256', '-c', 'SHA256SUMS'], cwd=folder, capture_output=True)
        self.assertEqual(result.returncode, 0)
        self.assertNotIn('xcrun', (self.root / 'trace').read_text())
        self.assertFalse((self.root / '.build/release.lock').exists())

    def test_invalid_signature_architecture_or_image_never_publishes(self):
        for extra in ({'SIGNATURE': 'certificate'}, {'ARCH': 'x86_64'},
                      {'FAIL_HDIUTIL': 'create'}, {'FAIL_HDIUTIL': 'verify'}, {'FAIL_STAGE': 'codesign'}):
            with self.subTest(extra=extra):
                result = self.run_release(**extra)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse((self.root / 'dist/releases-unnotarized/1.2.3').exists())
                self.assertFalse((self.root / '.build/release.lock').exists())

    def test_existing_version_and_other_release_lock_are_preserved(self):
        folder = self.root / 'dist/releases-unnotarized/1.2.3'
        folder.mkdir(parents=True)
        (folder / 'keep').write_text('original')
        self.assertNotEqual(self.run_release().returncode, 0)
        self.assertEqual((folder / 'keep').read_text(), 'original')
        lock = self.root / '.build/release.lock'
        lock.mkdir()
        self.assertNotEqual(self.run_release().returncode, 0)
        self.assertTrue(lock.exists())

    def test_uses_private_output_and_keeps_development_app(self):
        dev = self.root / 'dist/LidFold.app'
        dev.mkdir()
        (dev / 'keep').write_text('authorized app')
        (self.root / 'scripts/build-app.sh').write_text('''#!/bin/bash
set -eu
test "$LIDFOLD_BUILD_MODE" = unnotarized
case "$LIDFOLD_RELEASE_WORKDIR" in "$PWD"/.build/unnotarized.*) ;; *) exit 1 ;; esac
cp -R dist/distribution/LidFold.app "$LIDFOLD_RELEASE_WORKDIR/LidFold.app"
rm -rf dist/distribution/LidFold.app
''')
        self.assertEqual(self.run_release().returncode, 0)
        self.assertEqual((dev / 'keep').read_text(), 'authorized app')


if __name__ == '__main__':
    unittest.main()
