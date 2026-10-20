#!/usr/bin/env python3
"""With Swift 6.2+, build a fresh core-only consumer and reject external dependencies."""

import json
from pathlib import Path
import shutil
import subprocess
import tempfile

core = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="openfeature-core-") as temporary:
    root = Path(temporary)
    snapshot = root / "swift-sdk"
    snapshot.mkdir()
    # Include uncommitted changes, but never reuse the checkout's resolution state.
    for manifest in core.glob("Package*.swift"):
        shutil.copy2(manifest, snapshot / manifest.name)
    for directory in ("Sources", "Tests"):
        shutil.copytree(core / directory, snapshot / directory)

    # A tagged dependency exercises versioned manifest selection and resolution.
    git = [
        "git", "-C", str(snapshot),
        "-c", "user.name=Dependency isolation check",
        "-c", "user.email=ci@example.invalid",
        "-c", "commit.gpgsign=false",
        "-c", "tag.gpgsign=false",
        "-c", "core.hooksPath=/dev/null",
    ]
    for arguments in (
        ["init", "--quiet"], ["add", "."],
        ["commit", "--quiet", "-m", "Dependency isolation fixture"],
        ["tag", "0.0.0"],
    ):
        subprocess.run(git + arguments, check=True)

    consumer = root / "consumer"
    sources = consumer / "Sources" / "Consumer"
    sources.mkdir(parents=True)
    (consumer / "Package.swift").write_text(f'''// swift-tools-version: 5.5
import PackageDescription
let package = Package(
    name: "Consumer",
    platforms: [.macOS(.v12)],
    dependencies: [.package(url: "{snapshot.as_uri()}", .exact("0.0.0"))],
    targets: [.executableTarget(name: "Consumer", dependencies: [
        .product(name: "OpenFeature", package: "swift-sdk")
    ])]
)
''')
    (sources / "main.swift").write_text("import OpenFeature\n_ = OpenFeatureAPI.shared.getClient()\n")
    options = ["--package-path", str(consumer), "--cache-path", str(root / "cache")]
    subprocess.run(["swift", "package", *options, "resolve"], check=True)

    resolved = json.loads((consumer / "Package.resolved").read_text())
    # Consumers declaring tools versions before Swift 5.6 use the older schema.
    pins = resolved.get("pins", resolved.get("object", {}).get("pins", []))
    locations = [pin.get("location", pin.get("repositoryURL")) for pin in pins]
    if len(locations) != 1 or locations[0] not in (str(snapshot), snapshot.as_uri()):
        raise SystemExit(f"Core-only consumer resolved unexpected packages: {locations}")

    subprocess.run(["swift", "build", *options], check=True)
print("Core dependency isolation passed: a fresh consumer resolves and builds without external packages.")
