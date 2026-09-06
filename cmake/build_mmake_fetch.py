#!/usr/bin/env python3
"""Build a bounded, manifest-described external source tree without make."""

import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.error
import urllib.request
import zipfile


OWNER = ".aros-fetch-owner"
MAX_BYTES = 4 * 1024 * 1024 * 1024
MAX_FILES = 200000


def beneath(path, root):
    try:
        return path.relative_to(root) != Path(".")
    except ValueError:
        return False


def safe_relative(name, allow_spaces=False):
    if (not name or name.startswith("/") or "\\" in name or '"' in name or "'" in name
            or re.search(r"[\x00-\x1f\x7f;$%*?\[\]|]", name)
            or (not allow_spaces and " " in name)):
        raise ValueError(f"Unsafe archive/patch path: {name!r}")
    parts = PurePosixPath(name).parts
    if ".." in parts or OWNER in parts or ".aros-fetch-recipe" in parts or not parts:
        raise ValueError(f"Unsafe archive/patch path: {name!r}")
    return Path(*parts)


def native_path(path, root, legacy):
    if not path.is_absolute() or not beneath(path.resolve(), root.resolve()):
        raise ValueError(f"Fetch output outside native build: {path}")
    if legacy and (path.resolve() == legacy.resolve() or beneath(path.resolve(), legacy.resolve())):
        raise ValueError(f"Fetch output in legacy build: {path}")
    current = path
    while current != root:
        if current.is_symlink():
            raise ValueError(f"Symlink in native fetch output: {current}")
        if current == current.parent:
            raise ValueError(f"Fetch output not lexically inside native build: {path}")
        current = current.parent


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for data in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(data)
    return digest.hexdigest()


def check_destination(target, owner):
    if not target.exists():
        return
    marker = target / OWNER
    if target.is_dir() and not marker.is_symlink():
        if marker.is_file() and marker.read_text() == owner:
            return
        # Ninja creates parent directories for missing byproducts before exec.
        if not marker.exists() and all(path.is_dir() and not path.is_symlink()
                                       for path in target.rglob("*")):
            return
    raise ValueError(f"Refusing to replace an unowned fetch destination: {target}")


def acquire(candidates, control):
    errors = []
    for candidate in candidates:
        if candidate.startswith(("https://", "http://", "ftp://")):
            key = hashlib.sha256(candidate.encode()).hexdigest()
            cached = control / ("download-" + key)
            if cached.is_symlink():
                raise ValueError(f"Symlink in download cache: {cached}")
            if cached.is_file():
                return cached, candidate
            try:
                print(f"Downloading {candidate}", flush=True)
                with urllib.request.urlopen(candidate, timeout=60) as response:
                    with tempfile.NamedTemporaryFile(dir=control, delete=False) as stream:
                        temporary = Path(stream.name)
                        try:
                            total = 0
                            while True:
                                data = response.read(1024 * 1024)
                                if not data:
                                    break
                                total += len(data)
                                if total > MAX_BYTES:
                                    raise ValueError("Archive exceeds native fetch size limit")
                                stream.write(data)
                            stream.close()
                            temporary.replace(cached)
                        finally:
                            temporary.unlink(missing_ok=True)
                return cached, candidate
            except (OSError, urllib.error.URLError) as error:
                errors.append(f"{candidate}: {error}")
        else:
            path = Path(candidate)
            if path.is_file():
                return path, candidate
            errors.append(f"{candidate}: not found")
    raise ValueError("No fetch archive available:\n" + "\n".join(errors))


def extract(archive, staging):
    seen = set()
    total = 0

    def destination(name, size):
        nonlocal total
        relative = safe_relative(name, allow_spaces=True)
        if relative in seen:
            raise ValueError(f"Duplicate archive member: {name}")
        seen.add(relative)
        total += size
        if len(seen) > MAX_FILES or total > MAX_BYTES:
            raise ValueError("Archive exceeds native fetch extraction limits")
        return staging / relative

    if zipfile.is_zipfile(archive):
        with zipfile.ZipFile(archive) as source:
            for member in source.infolist():
                mode = member.external_attr >> 16
                kind = mode & 0o170000
                if kind not in (0, 0o100000, 0o040000):
                    raise ValueError(f"Unsupported archive member type: {member.filename}")
                target = destination(member.filename, member.file_size)
                if member.is_dir():
                    target.mkdir(parents=True, exist_ok=True)
                else:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    with source.open(member) as stream, target.open("xb") as output:
                        shutil.copyfileobj(stream, output)
                    target.chmod((mode & 0o777) or 0o644)
        return
    with tarfile.open(archive, "r:*") as source:
        for member in source:
            if member.name in (".", "./") and member.isdir():
                continue
            if not (member.isfile() or member.isdir()):
                raise ValueError(f"Unsupported archive member type: {member.name}")
            target = destination(member.name, member.size)
            if member.isdir():
                target.mkdir(parents=True, exist_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                with source.extractfile(member) as stream, target.open("xb") as output:
                    shutil.copyfileobj(stream, output)
                target.chmod(member.mode & 0o777)
                os.utime(target, (member.mtime, member.mtime))


def apply_patch(entry, staging, recipe):
    patch = Path(entry["patch"])
    root = Path(recipe["source_root"]).resolve()
    if not beneath(patch.resolve(), root):
        raise ValueError(f"Patch is not an owned source: {patch}")
    for excluded in (recipe["native_root"], recipe["legacy_root"]):
        if excluded and beneath(patch.resolve(), Path(excluded).resolve()):
            raise ValueError(f"Patch is a generated input: {patch}")
    subdir = entry["subdir"]
    directory = staging / safe_relative(subdir) if subdir not in ("", ".") else staging
    if not directory.exists() and not directory.is_symlink():
        # Legacy do_patch ignores a failed cd and applies at destination instead.
        print(f"Patch subdirectory {subdir!r} is absent; using extraction root", flush=True)
        directory = staging
    if not directory.is_dir():
        raise ValueError(f"Missing patch subdirectory: {subdir}")
    strip = 0
    for option in entry["options"]:
        if re.fullmatch(r"-p[0-9]+", option):
            strip = int(option[2:])
        elif option != "-f":
            raise ValueError(f"Unsupported native patch option: {option}")
    headers = 0
    # Force unified input; never let patch auto-detect an executable ed script.
    for line in patch.read_text(errors="surrogateescape").splitlines():
        if line.startswith(("--- ", "+++ ", "Index: ")):
            name = line.split(maxsplit=1)[1].split("\t", 1)[0].split(" ", 1)[0]
            if name != "/dev/null":
                relative = safe_relative(name)
                remaining = relative.parts[strip:]
                if not remaining:
                    raise ValueError(f"Patch strip removes entire path: {name}")
                safe_relative("/".join(remaining))
            headers += line.startswith("--- ")
    if not headers:
        raise ValueError(f"Patch is not a supported unified diff: {patch}")
    with patch.open("rb") as stream:
        subprocess.run([recipe["patch_tool"], "--unified", "--batch", "--forward",
                        "--no-backup-if-mismatch", "--reject-file=-", "-Z",
                        *entry["options"]], cwd=directory, stdin=stream, check=True)


def build(recipe_file):
    recipe = json.loads(recipe_file.read_text())
    root = Path(recipe["native_root"])
    legacy = Path(recipe["legacy_root"]) if recipe["legacy_root"] else None
    control = Path(recipe["control"])
    target = Path(recipe["destination"])
    for path in (control, target):
        native_path(path, root, legacy)
    if beneath(control, target) or beneath(target, control) or target == control:
        raise ValueError("Fetch destination overlaps its control directory")
    control.mkdir(parents=True, exist_ok=True)
    owner = hashlib.sha256((recipe["identity"] + "\n" + str(target)).encode()).hexdigest()
    check_destination(target, owner)
    archive, origin = acquire(recipe["archives"], control)
    # Stage separately so a failed archive/patch never publishes partial sources.
    with tempfile.TemporaryDirectory(prefix="stage-", dir=control) as temporary:
        staging = Path(temporary)
        extract(archive, staging)
        for entry in recipe["patches"]:
            apply_patch(entry, staging, recipe)
        files = sorted(str(path.relative_to(staging)) for path in staging.rglob("*") if path.is_file())
        for name in files:
            safe_relative(name, allow_spaces=True)
        receipt = {"recipe_hash": sha256(recipe_file), "archive": origin,
                   "archive_sha256": sha256(archive), "files": files,
                   "destination": str(target), "recipe": str(recipe_file),
                   "file_hashes": {name: sha256(staging / name) for name in files},
                   "patches": [{"path": entry["patch"], "sha256": sha256(Path(entry["patch"]))}
                               for entry in recipe["patches"]]}
        (staging / OWNER).write_text(owner)
        (staging / ".aros-fetch-recipe").write_text(receipt["recipe_hash"])
        native_path(target, root, legacy)
        check_destination(target, owner)
        if target.exists():
            shutil.rmtree(target)
        target.parent.mkdir(parents=True, exist_ok=True)
        staging.rename(target)
    report = Path(recipe["receipt"])
    native_path(report, control, legacy)
    if report.is_symlink():
        raise ValueError(f"Symlink in fetch receipt: {report}")
    with tempfile.NamedTemporaryFile(mode="w", dir=control, delete=False) as stream:
        json.dump(receipt, stream, indent=2)
        temporary = Path(stream.name)
    temporary.replace(report)
    print(f"Prepared {recipe['identity']}: {len(files)} files in {target}", flush=True)


def verify(report):
    receipt = json.loads(report.read_text())
    recipe_file = Path(receipt["recipe"])
    recipe = json.loads(recipe_file.read_text())
    destination = Path(recipe["destination"])
    legacy = Path(recipe["legacy_root"]) if recipe["legacy_root"] else None
    native_path(destination, Path(recipe["native_root"]), legacy)
    if (sha256(recipe_file) != receipt["recipe_hash"]
            or (destination / ".aros-fetch-recipe").read_text() != receipt["recipe_hash"]):
        raise ValueError("Native fetched-source receipt is stale; rebuild its producer")
    files = set()
    for path in destination.rglob("*"):
        if path.is_symlink():
            raise ValueError(f"Symlink in native fetched sources: {path}")
        if path.is_file() and path not in (destination / OWNER, destination / ".aros-fetch-recipe"):
            files.add(str(path.relative_to(destination)))
    if files != set(receipt["file_hashes"]) or files != set(receipt["files"]):
        raise ValueError("Native fetched-source inventory changed; edit the archive or patch instead")
    for name, digest in receipt["file_hashes"].items():
        path = destination / safe_relative(name, allow_spaces=True)
        if path.is_symlink() or path.resolve() != path or sha256(path) != digest:
            raise ValueError(f"Native fetched source changed; edit the archive or patch instead: {path}")


if __name__ == "__main__":
    try:
        if sys.argv[1] == "--verify":
            verify(Path(sys.argv[2]))
        else:
            build(Path(sys.argv[1]))
    except (OSError, ValueError, tarfile.TarError, zipfile.BadZipFile,
            subprocess.CalledProcessError) as error:
        sys.exit(f"Native fetch failed: {error}")
