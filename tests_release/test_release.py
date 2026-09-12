import importlib.util
import json
import plistlib
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("release_support", ROOT / "scripts/release_support.py")
support = importlib.util.module_from_spec(spec)
spec.loader.exec_module(support)


class SigningTests(unittest.TestCase):
    dev = "A" * 40
    release = "B" * 40
    identities = f'1) {dev} "Apple Development: Fixture"\n2) {release} "Developer ID Application: Fixture"'

    def resolve(self, mode, identities, requested=""):
        return subprocess.run(
            ["bash", "-c", '. "$1"; resolve_signing_identity "$2" "$3" "$4" || exit; printf "%s" "$LIDFOLD_SELECTED_IDENTITY"',
             "test", str(ROOT / "scripts/signing-identity.sh"), mode, identities, requested],
            text=True, capture_output=True,
        )

    def test_distribution_chooses_only_developer_id(self):
        result = self.resolve("distribution", self.identities)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, self.release)

    def test_explicit_development_identity_cannot_bypass_distribution_gate(self):
        self.assertNotEqual(self.resolve("distribution", self.identities, self.dev).returncode, 0)

    def test_missing_distribution_certificate_fails(self):
        self.assertNotEqual(self.resolve("distribution", self.identities.splitlines()[0]).returncode, 0)

    def test_ambiguous_development_identity_requires_selection(self):
        self.assertNotEqual(self.resolve("development", self.identities).returncode, 0)
        self.assertEqual(self.resolve("development", self.identities, self.dev).stdout, self.dev)

    def test_ad_hoc_and_unknown_modes_are_rejected(self):
        self.assertNotEqual(self.resolve("development", self.identities, "-").returncode, 0)
        self.assertNotEqual(self.resolve("typo", self.identities).returncode, 0)


class ReleaseDataTests(unittest.TestCase):
    def test_notarization_only_accepts_exact_success(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "result.json"
            for data in ({}, {"status": "Invalid"}, {"status": "In Progress"}, [], {"status": "accepted"}):
                path.write_text(json.dumps(data))
                with self.assertRaises(ValueError):
                    support.accepted_notarization(path)
            path.write_text('{"status":"Accepted"}')
            support.accepted_notarization(path)
            path.write_text('not json')
            with self.assertRaises(ValueError):
                support.accepted_notarization(path)

    def test_version_cannot_escape_output_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "Info.plist"
            for version in ("../outside", "", 3, "1/2/3"):
                path.write_bytes(plistlib.dumps({"CFBundleShortVersionString": version}))
                with self.assertRaises(ValueError):
                    support.app_version(path)
            path.write_bytes(plistlib.dumps({"CFBundleShortVersionString": "0.2.3"}))
            self.assertEqual(support.app_version(path), "0.2.3")

    def test_documentation_local_links_resolve(self):
        import re
        for path in [ROOT / "README.md", ROOT / "README.en.md", ROOT / "CONTRIBUTING.md", *ROOT.glob("docs/*.md")]:
            for target in re.findall(r"\]\(([^)]+)\)", path.read_text()):
                if "://" in target or target.startswith("#"):
                    continue
                self.assertTrue((path.parent / target.split("#")[0]).exists(), f"{path.name}: {target}")


if __name__ == "__main__":
    unittest.main()
