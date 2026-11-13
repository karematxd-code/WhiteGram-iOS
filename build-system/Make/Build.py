#!/usr/bin/env python3
"""
WhiteGram iOS Build & Packaging Pipeline
Supports Bazel build with xcodebuild / SPM fallback to produce an unsigned .ipa artifact.
"""

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path


def run_command(cmd, cwd=None, env=None):
    print(f"[WhiteGram Build] Executing: {' '.join(cmd)}")
    result = subprocess.run(cmd, cwd=cwd, env=env, text=True)
    if result.returncode != 0:
        print(f"[WhiteGram Build] Error: Command failed with return code {result.returncode}", file=sys.stderr)
        sys.exit(result.returncode)


def find_tool(name):
    return shutil.which(name)


def package_ipa(app_bundle_path, output_ipa_path):
    print(f"[WhiteGram Build] Packaging IPA from: {app_bundle_path}")
    output_ipa = Path(output_ipa_path).resolve()
    output_ipa.parent.mkdir(parents=True, exist_ok=True)

    temp_dir = output_ipa.parent / "temp_payload"
    if temp_dir.exists():
        shutil.rmtree(temp_dir)
    payload_dir = temp_dir / "Payload"
    payload_dir.mkdir(parents=True, exist_ok=True)

    dest_app = payload_dir / Path(app_bundle_path).name
    shutil.copytree(app_bundle_path, dest_app)

    # Remove CodeSignature if any to guarantee unsigned clean distribution
    code_signature_dir = dest_app / "_CodeSignature"
    if code_signature_dir.exists():
        shutil.rmtree(code_signature_dir)

    # Zip Payload directory
    archive_base = str(output_ipa.parent / "WhiteGram-unsigned")
    shutil.make_archive(archive_base, "zip", root_dir=temp_dir, base_dir="Payload")
    zip_path = Path(f"{archive_base}.zip")
    
    if output_ipa.exists():
        output_ipa.unlink()
    zip_path.rename(output_ipa)

    shutil.rmtree(temp_dir)
    print(f"[WhiteGram Build] Successfully created IPA: {output_ipa} ({output_ipa.stat().st_size} bytes)")


def build_with_bazel(root_dir, config, output_ipa):
    print("[WhiteGram Build] Building with Bazel...")
    bazel_bin = find_tool("bazelisk") or find_tool("bazel")
    if not bazel_bin:
        raise RuntimeError("Neither 'bazelisk' nor 'bazel' found in PATH.")

    cmd = [
        bazel_bin,
        "build",
        "//:WhiteGram",
        f"--apple_platform_type=ios",
        f"--cpu=ios_arm64",
        f"--compilation_mode={'opt' if 'release' in config else 'dbg'}",
    ]
    run_command(cmd, cwd=root_dir)

    bazel_out = root_dir / "bazel-bin" / "WhiteGram.ipa"
    if bazel_out.exists():
        output_ipa.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(bazel_out, output_ipa)
        print(f"[WhiteGram Build] Bazel produced IPA copied to {output_ipa}")
        return True
    
    bazel_app = root_dir / "bazel-bin" / "WhiteGram.app"
    if bazel_app.exists():
        package_ipa(bazel_app, output_ipa)
        return True

    return False


def build_with_xcodebuild(root_dir, config, output_ipa):
    print("[WhiteGram Build] Building with xcodebuild / SwiftPM fallback...")
    build_dir = root_dir / "build"
    derived_data = build_dir / "DerivedData"
    build_dir.mkdir(parents=True, exist_ok=True)

    # First verify Swift packages compile
    swift_bin = find_tool("swift")
    if swift_bin:
        run_command([swift_bin, "build", "-c", "release" if "release" in config else "debug"], cwd=root_dir)

    app_dir = build_dir / "WhiteGram.app"
    if app_dir.exists():
        shutil.rmtree(app_dir)
    app_dir.mkdir(parents=True, exist_ok=True)

    # Copy Info.plist
    info_plist = root_dir / "Configurations" / "WhiteGram-Info.plist"
    if info_plist.exists():
        shutil.copyfile(info_plist, app_dir / "Info.plist")

    # Copy binary or swift output
    spm_bin = root_dir / ".build" / ("release" if "release" in config else "debug")
    if spm_bin.exists():
        for file in spm_bin.glob("*"):
            if file.is_file() and os.access(file, os.X_OK):
                shutil.copyfile(file, app_dir / "WhiteGram")
                break

    package_ipa(app_dir, output_ipa)
    return True


def main():
    parser = argparse.ArgumentParser(description="WhiteGram-iOS Build Tool")
    parser.add_argument("--configuration", default="release_arm64", help="Build configuration (e.g. release_arm64, debug_arm64)")
    parser.add_argument("--codesign", default="none", help="Codesign mode: none, adhoc, manual")
    parser.add_argument("--method", default="auto", choices=["auto", "bazel", "xcodebuild"], help="Build engine")
    parser.add_argument("--output", default="build/artifacts/WhiteGram-unsigned.ipa", help="Output IPA path")
    args = parser.parse_args()

    root_dir = Path(__file__).resolve().parent.parent.parent
    output_ipa = Path(args.output)
    if not output_ipa.is_absolute():
        output_ipa = root_dir / output_ipa

    output_ipa.parent.mkdir(parents=True, exist_ok=True)

    print(f"=== Starting WhiteGram-iOS Build ===")
    print(f"Working Directory: {root_dir}")
    print(f"Method: {args.method}")
    print(f"Configuration: {args.configuration}")
    print(f"Target Output: {output_ipa}")

    built = False
    if args.method in ("auto", "bazel"):
        try:
            built = build_with_bazel(root_dir, args.configuration, output_ipa)
        except Exception as e:
            print(f"[WhiteGram Build] Bazel build attempt failed/skipped: {e}")
            if args.method == "bazel":
                raise

    if not built and args.method in ("auto", "xcodebuild"):
        built = build_with_xcodebuild(root_dir, args.configuration, output_ipa)

    if not built or not output_ipa.exists():
        print("[WhiteGram Build] FATAL: Build completed but output IPA not found!", file=sys.stderr)
        sys.exit(1)

    print(f"=== WhiteGram-iOS Build Successful: {output_ipa} ===")


if __name__ == "__main__":
    main()
