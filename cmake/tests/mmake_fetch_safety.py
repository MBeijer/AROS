"""Exercise the native fetch builder with local archives; no network or OS code."""

import importlib.util
import io
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile
import unittest
import zipfile


BUILDER = Path(__file__).resolve().parents[1] / "build_mmake_fetch.py"
spec = importlib.util.spec_from_file_location("fetch", BUILDER)
fetch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fetch)


class FetchTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="aros-fetch-safety-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root / "source"
        self.build = self.root / "build"
        self.target = self.build / "external"
        self.control = self.build / "fetch"
        self.source.mkdir()
        self.control.mkdir(parents=True)
        self.archive = self.source / "pkg.tar.gz"
        self.recipe = self.control / "recipe.json"
        self.receipt = self.control / "receipt.json"
        self.data = dict(identity="fixture", destination=str(self.target),
                         native_root=str(self.build), legacy_root=str(self.build / "legacy"),
                         source_root=str(self.source), control=str(self.control),
                         patch_tool=shutil.which("patch"), archives=[str(self.archive)],
                         patches=[], receipt=str(self.receipt))
        self.tar()

    def tar(self, name="pkg/value.h", kind=tarfile.REGTYPE, duplicate=False):
        with tarfile.open(self.archive, "w:gz") as archive:
            member = tarfile.TarInfo(name)
            member.type = kind
            member.linkname = "../../escape"
            member.size = 6 if kind == tarfile.REGTYPE else 0
            for _ in range(2 if duplicate else 1):
                archive.addfile(member, io.BytesIO(b"old\nxx"))

    def run_build(self, expected=None):
        self.recipe.write_text(json.dumps(self.data))
        result = subprocess.run([sys.executable, str(BUILDER), str(self.recipe)],
                                capture_output=True, text=True)
        if expected:
            self.assertNotEqual(result.returncode, 0, result.stdout)
            self.assertIn(expected, result.stderr)
        else:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_archive_paths_and_types(self):
        for name in ("../escape", "/escape", "pkg/../../escape", "pkg/a;b", "pkg/a\tb",
                     "pkg/a?b", "pkg/]==]", "pkg/a[b]", "pkg/a*b", "pkg/a|b",
                     "pkg/" + fetch.OWNER, "pkg/.aros-fetch-recipe"):
            with self.subTest(name=name):
                self.tar(name)
                self.run_build("Unsafe archive/patch path")
                self.assertFalse(self.target.exists())
                self.assertFalse(self.receipt.exists())
        for kind in (tarfile.SYMTYPE, tarfile.LNKTYPE, tarfile.FIFOTYPE, tarfile.CHRTYPE):
            with self.subTest(kind=kind):
                self.tar(kind=kind)
                self.run_build("Unsupported archive member type")
        self.tar(duplicate=True)
        self.run_build("Duplicate archive member")

    def test_zip(self):
        self.archive = self.source / "pkg.zip"
        self.data["archives"] = [str(self.archive)]
        with zipfile.ZipFile(self.archive, "w") as archive:
            archive.writestr("pkg/value.h", "zip\n")
        self.run_build()
        self.assertEqual((self.target / "pkg/value.h").read_text(), "zip\n")
        with zipfile.ZipFile(self.archive, "w") as archive:
            member = zipfile.ZipInfo("pkg/link")
            member.external_attr = 0o120777 << 16
            archive.writestr(member, "../../escape")
        self.run_build("Unsupported archive member type")
        self.assertEqual((self.target / "pkg/value.h").read_text(), "zip\n")

    def test_archive_spaces_and_patch_root_fallback(self):
        self.tar("data/Test Archive.zip")
        self.run_build()
        fetch.verify(self.receipt)
        self.assertEqual((self.target / "data/Test Archive.zip").read_bytes(), b"old\nxx")
        self.tar()
        patch = self.source / "fix.diff"
        patch.write_text("--- a/pkg/value.h\n+++ b/pkg/value.h\n@@ -1,2 +1,2 @@\n-old\n+new\n xx\n\\ No newline at end of file\n")
        self.data["patches"] = [dict(patch=str(patch), subdir="absent", options=["-p1"])]
        self.run_build()
        fetch.verify(self.receipt)
        self.assertEqual((self.target / "pkg/value.h").read_bytes(), b"new\nxx")
        for subdir in ("../escape", "/escape", "has space"):
            with self.subTest(subdir=subdir):
                self.data["patches"][0]["subdir"] = subdir
                self.run_build("Unsafe archive/patch path")
                self.assertEqual((self.target / "pkg/value.h").read_bytes(), b"new\nxx")

    def test_ownership_and_recovery(self):
        self.target.mkdir()
        sentinel = self.target / "unowned"
        sentinel.write_text("preserve")
        self.run_build("unowned fetch destination")
        self.assertEqual(sentinel.read_text(), "preserve")
        sentinel.unlink()
        (self.target / "pkg").mkdir()
        self.run_build()
        fetch.verify(self.receipt)
        added = self.target / "pkg/unowned.h"
        added.write_text("injected")
        with self.assertRaisesRegex(ValueError, "inventory changed"):
            fetch.verify(self.receipt)
        added.unlink()
        added.symlink_to(self.source, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, "Symlink in native fetched sources"):
            fetch.verify(self.receipt)
        added.unlink()
        (self.target / "pkg/value.h").write_text("edited")
        with self.assertRaisesRegex(ValueError, "Native fetched source changed"):
            fetch.verify(self.receipt)
        self.run_build()
        fetch.verify(self.receipt)
        (self.target / fetch.OWNER).write_text("another producer")
        self.run_build("unowned fetch destination")

    def test_destination_containment(self):
        for destination in (self.build, self.source / "external", self.build / "legacy/external",
                            self.control, self.control / "child"):
            with self.subTest(destination=destination):
                self.data["destination"] = str(destination)
                self.run_build("Fetch")
        alias = self.build / "alias"
        alias.symlink_to(self.source, target_is_directory=True)
        self.data["destination"] = str(alias / "external")
        self.run_build("outside native build")
        self.assertFalse((self.source / "external").exists())
        alias.unlink()
        alias.symlink_to(self.control, target_is_directory=True)
        self.run_build("Symlink in native fetch output")

    def test_failed_patch_preserves_tree(self):
        self.run_build()
        before = self.receipt.read_bytes()
        patch = self.source / "fix.diff"
        self.data["patches"] = [dict(patch=str(patch), subdir="pkg", options=["-p1"])]
        for contents, reason in (
                ("--- a/../../escape\n+++ b/../../escape\n@@ -1 +1 @@\n-x\n+y\n", "Unsafe archive/patch path"),
                ('--- "../escape"\n+++ "../escape"\n@@ -1 +1 @@\n-x\n+y\n', "Unsafe archive/patch path"),
                ("1c\nnew\n.\nw\n", "not a supported unified diff"),
                ("--- a/value.h\n+++ b/value.h\n@@ -1 +1 @@\n-wrong\n+new\n", "returned non-zero")):
            patch.write_text(contents)
            self.run_build(reason)
            self.assertEqual(self.receipt.read_bytes(), before)
            self.assertEqual((self.target / "pkg/value.h").read_text(), "old\nxx")
        outside = self.root / "outside.diff"
        outside.write_text("preserve")
        patch.unlink()
        patch.symlink_to(outside)
        self.run_build("not an owned source")

    def test_archive_candidate_order(self):
        self.data["archives"] = [str(self.source / "missing"), str(self.archive), "https://invalid.invalid/unused"]
        self.run_build()
        self.assertEqual(json.loads(self.receipt.read_text())["archive"], str(self.archive))
        self.data["archives"] = [str(self.source / "missing")]
        self.run_build("No fetch archive available")


if __name__ == "__main__":
    unittest.main()
