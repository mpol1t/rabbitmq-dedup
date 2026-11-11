#!/usr/bin/env python3
"""Check automated base-image updates without Docker or network access."""

import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import zipfile


ROOT = Path(__file__).resolve().parent.parent


class BaseUpdateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        shutil.copytree(ROOT / "scripts", self.root / "scripts")
        shutil.copytree(ROOT / "plugins", self.root / "plugins")
        shutil.copy(ROOT / "README.md", self.root / "README.md")
        self.dockerfile = (ROOT / "Dockerfile").read_text()
        # Keep fixture expectations stable when Dependabot advances the real tag.
        self.dockerfile = self.dockerfile.replace(
            self.dockerfile.splitlines()[0],
            "FROM rabbitmq:4.2.9-management-alpine@sha256:" + "b" * 64,
            1,
        )
        self.write_dockerfile(self.dockerfile)

        # Serve a local upstream bundle while retaining checksum/content checks.
        bundle = self.root / "bundle.zip"
        with zipfile.ZipFile(bundle, "w") as archive:
            for plugin in (self.root / "plugins").glob("*.ez"):
                archive.write(plugin, plugin.name)
        digest = hashlib.sha256(bundle.read_bytes()).hexdigest()
        (self.root / "plugins/upstream-release.env").write_text(
            f"PLUGIN_RELEASE=test\nPLUGIN_BUNDLE=bundle.zip\nPLUGIN_SHA256={digest}\n"
        )
        tools = self.root / "bin"
        tools.mkdir()
        curl = tools / "curl"
        curl.write_text('#!/usr/bin/env bash\ncp "$TEST_PLUGIN_BUNDLE" "${@: -1}"\n')
        curl.chmod(0o755)
        self.env = dict(os.environ, PATH=f"{tools}:{os.environ['PATH']}",
                        TEST_PLUGIN_BUNDLE=str(bundle))

    def write_dockerfile(self, text):
        (self.root / "Dockerfile").write_text(text)

    def run_script(self, name, *args):
        return subprocess.run(
            [str(self.root / "scripts" / name), *args],
            env=self.env, text=True, capture_output=True, check=False,
        )

    def test_patch_and_digest_refresh_need_no_readme_edit(self):
        reference = self.dockerfile.splitlines()[0]
        for replacement, tag in (
            (reference.replace(reference.split("sha256:")[1], "a" * 64), "v4.2.9"),
            (reference.replace("4.2.9", "4.2.10"), "v4.2.10"),
        ):
            with self.subTest(reference=replacement):
                self.write_dockerfile(self.dockerfile.replace(reference, replacement))
                result = self.run_script("validate-release.sh", tag)
                self.assertEqual(result.returncode, 0, result.stderr)
                version = self.run_script("read-rabbitmq-version.sh")
                self.assertEqual(version.stdout.strip(), tag.removeprefix("v"))

    def test_rejects_unsupported_or_unpinned_base(self):
        reference = self.dockerfile.splitlines()[0]
        for replacement in (
            reference.replace("4.2.9", "4.3.0"),
            reference.replace("4.2.9", "5.0.0"),
            reference.replace("management-alpine", "management"),
            reference.split("@")[0],
            reference[:-1],
            "FROM rabbitmq:${VERSION}@${DIGEST}",
            reference + "\nFROM alpine:latest",
            reference + "\nfrom alpine:latest",
            reference.replace("rabbitmq:", "untrusted/rabbitmq:"),
            "# no base image",
        ):
            with self.subTest(reference=replacement):
                self.write_dockerfile(self.dockerfile.replace(reference, replacement))
                result = self.run_script("validate-release.sh")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Expected one literal, digest-pinned", result.stderr)

    def test_release_tag_must_still_match_base_version(self):
        result = self.run_script("validate-release.sh", "v4.2.10")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("does not match Dockerfile", result.stderr)

    def test_plugin_documentation_is_still_checked(self):
        readme = self.root / "README.md"
        readme.write_text(readme.read_text().replace("Dedup plugin: `0.7.3`", "Dedup plugin: `0.7.2`"))
        result = self.run_script("validate-release.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("does not match vendored artifact", result.stderr)


if __name__ == "__main__":
    unittest.main()
