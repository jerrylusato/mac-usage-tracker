#!/usr/bin/env python3
"""Validate version tags and describe immutable release packages."""
import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def version():
    if (ROOT / "version.json").exists():
        data = json.loads((ROOT / "version.json").read_text())
        return "mac", data["version"], data["build"]
    text = (ROOT / "app/build.gradle.kts").read_text()
    name = re.search(r'versionName\s*=\s*"([^\"]+)"', text)
    code = re.search(r'versionCode\s*=\s*(\d+)', text)
    if not name or not code:
        raise ValueError("Cannot read Android version")
    return "phone", name.group(1), int(code.group(1))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag")
    parser.add_argument("--validate-only", action="store_true")
    parser.add_argument("files", nargs="*")
    args = parser.parse_args()
    app, name, build = version()
    args.tag = args.tag or "v" + name
    if not re.fullmatch(r"\d+\.\d+\.\d+", name) or args.tag != "v" + name:
        parser.error("Release tag must match the configured version: v" + name)
    if not isinstance(build, int) or build < 1:
        parser.error("Build number must be a positive integer")
    if args.validate_only:
        print(f"Validated {app} {name} (build {build})")
        return
    if not args.files:
        parser.error("At least one release package is required")
    output = ROOT / "dist"
    output.mkdir(exist_ok=True)
    files = []
    for item in args.files:
        path = Path(item).resolve()
        if path.parent != output or not path.is_file() or path.stat().st_size == 0:
            parser.error("Packages must be nonempty files directly inside dist/")
        files.append({"name": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                      "size": path.stat().st_size})
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    manifest = {"app": app, "version": name, "build": build, "tag": args.tag,
                "commit": commit, "files": files}
    (output / "release-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    (output / "SHA256SUMS").write_text("".join(f'{item["sha256"]}  {item["name"]}\n' for item in files))
    print(f"Packaged {app} {name} from {commit}")


if __name__ == "__main__":
    main()
