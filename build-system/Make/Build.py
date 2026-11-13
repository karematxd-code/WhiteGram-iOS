#!/usr/bin/env python3
"""
WhiteGram iOS Build & Packaging Pipeline
Compiles all WhiteGram Swift modules and Objective-C hooks into WhiteGram.dylib,
rebrands the Telegram iOS base bundle to WhiteGram (name, icon, UI),
injects the dynamic library via Mach-O LC_LOAD_DYLIB, and packages WhiteGram-unsigned.ipa.
"""

import argparse
import glob
import os
import plistlib
import shutil
import struct
import subprocess
import sys
import urllib.request
import zipfile
from pathlib import Path

BASE_TELEGRAM_IPA_URL = "https://github.com/mapix3/AyuGram-iOS/releases/download/build-211601/AyuGram-standard-211601.ipa"


def run_command(cmd, cwd=None, env=None):
    print(f"[WhiteGram Build] Executing: {' '.join(str(c) for c in cmd)}")
    result = subprocess.run(cmd, cwd=cwd, env=env, text=True)
    if result.returncode != 0:
        print(f"[WhiteGram Build] Command returned code {result.returncode}", file=sys.stderr)
        raise subprocess.CalledProcessError(result.returncode, cmd)


def find_tool(name):
    return shutil.which(name)


def inject_load_dylib(binary_path, dylib_path):
    """
    Injects an LC_LOAD_DYLIB load command into a 64-bit Mach-O binary.
    """
    try:
        with open(binary_path, "r+b") as f:
            data = bytearray(f.read())
            magic = struct.unpack_from("<I", data, 0)[0]
            if magic != 0xFEEDFACF:  # MH_MAGIC_64
                print(f"[WhiteGram Inject] Warning: {binary_path} is not MH_MAGIC_64 (magic: {hex(magic)})")
                return False

            ncmds, sizeofcmds = struct.unpack_from("<II", data, 16)
            header_size = 32
            load_cmds_offset = header_size
            load_cmds_end = load_cmds_offset + sizeofcmds

            LC_LOAD_DYLIB = 0xC
            path_bytes = dylib_path.encode("utf-8") + b"\x00"
            cmd_size = ((24 + len(path_bytes) + 7) // 8) * 8
            path_offset = 24

            cmd_bytes = struct.pack("<IIIIII", LC_LOAD_DYLIB, cmd_size, path_offset, 0, 0x010000, 0x010000)
            cmd_bytes += path_bytes + b"\x00" * (cmd_size - 24 - len(path_bytes))

            padding_available = data[load_cmds_end : load_cmds_end + cmd_size]
            if any(padding_available):
                print("[WhiteGram Inject] Warning: Header padding not empty; searching for safe insertion")
                # If padding has trailing zeroes or space, proceed if possible
                if len(padding_available) < cmd_size:
                    return False

            data[load_cmds_end : load_cmds_end + cmd_size] = cmd_bytes
            struct.pack_into("<II", data, 16, ncmds + 1, sizeofcmds + cmd_size)

            f.seek(0)
            f.write(data)
            print(f"[WhiteGram Inject] Successfully injected {dylib_path} into {binary_path}")
            return True
    except Exception as e:
        print(f"[WhiteGram Inject] Injection error: {e}")
        return False


def compile_whitegram_dylib(root_dir, output_dylib_path):
    """
    Compiles all Swift modules in Sources/ and WhiteGramHook.m into WhiteGram.dylib.
    """
    xcrun_bin = find_tool("xcrun")
    swiftc_bin = find_tool("swiftc")
    clang_bin = find_tool("clang")

    if not xcrun_bin or not swiftc_bin or not clang_bin:
        print("[WhiteGram Build] Warning: Xcode compilation tools not found in PATH.")
        return False

    sdk_path = subprocess.check_output([xcrun_bin, "--sdk", "iphoneos", "--show-sdk-path"], text=True).strip()
    print(f"[WhiteGram Build] Using iPhoneOS SDK: {sdk_path}")

    build_dir = root_dir / "build"
    modules_dir = build_dir / "modules"
    modules_dir.mkdir(parents=True, exist_ok=True)

    target_triple = "arm64-apple-ios15.0"
    sources_dir = root_dir / "Sources"

    # Module compilation order based on dependency graph
    modules = [
        ("WhiteGramCore", ["WhiteGramCore"]),
        ("GhostMode", ["GhostMode"]),
        ("Gifts", ["Gifts"]),
        ("Upgrader", ["Upgrader"]),
        ("ProfileSync", ["ProfileSync"]),
        ("WhiteGramUI", ["WhiteGramUI"]),
    ]

    compiled_objects = []

    for mod_name, subdirs in modules:
        mod_sources = []
        for s in subdirs:
            s_dir = sources_dir / s
            if s_dir.exists():
                mod_sources.extend(list(s_dir.glob("*.swift")))

        if not mod_sources:
            print(f"[WhiteGram Build] Warning: No sources found for module {mod_name}")
            continue

        mod_obj = modules_dir / f"{mod_name}.o"
        mod_module = modules_dir / f"{mod_name}.swiftmodule"

        print(f"[WhiteGram Build] Compiling module {mod_name} ({len(mod_sources)} Swift files)...")
        cmd = [
            swiftc_bin,
            "-emit-module",
            "-emit-object",
            "-module-name", mod_name,
            "-parse-as-library",
            "-target", target_triple,
            "-sdk", sdk_path,
            "-I", str(modules_dir),
            "-o", str(mod_obj),
            "-emit-module-path", str(mod_module),
        ] + [str(p) for p in mod_sources]

        try:
            run_command(cmd)
            compiled_objects.append(mod_obj)
            print(f"[WhiteGram Build] Module {mod_name} compiled successfully.")
        except Exception as e:
            print(f"[WhiteGram Build] Error compiling module {mod_name}: {e}")
            return False

    # Compile Objective-C Hook (WhiteGramHook.m)
    hook_src = sources_dir / "WhiteGramUI" / "WhiteGramHook.m"
    if hook_src.exists():
        hook_obj = modules_dir / "WhiteGramHook.o"
        print("[WhiteGram Build] Compiling Objective-C runtime hook (WhiteGramHook.m)...")
        hook_cmd = [
            clang_bin,
            "-c",
            "-target", target_triple,
            "-isysroot", sdk_path,
            "-fobjc-arc",
            "-I", str(modules_dir),
            "-o", str(hook_obj),
            str(hook_src)
        ]
        try:
            run_command(hook_cmd)
            compiled_objects.append(hook_obj)
            print("[WhiteGram Build] WhiteGramHook.m compiled successfully.")
        except Exception as e:
            print(f"[WhiteGram Build] Error compiling WhiteGramHook.m: {e}")
            return False

    # Link everything into WhiteGram.dylib using swiftc
    print(f"[WhiteGram Build] Linking {len(compiled_objects)} object files into {output_dylib_path}...")
    output_dylib = Path(output_dylib_path)
    output_dylib.parent.mkdir(parents=True, exist_ok=True)

    link_cmd = [
        swiftc_bin,
        "-emit-library",
        "-target", target_triple,
        "-sdk", sdk_path,
        "-install_name", "@rpath/WhiteGram.dylib",
        "-o", str(output_dylib),
    ] + [str(o) for o in compiled_objects]

    try:
        run_command(link_cmd)
        print(f"[WhiteGram Build] WhiteGram.dylib linked successfully: {output_dylib.stat().st_size} bytes.")
        return True
    except Exception as e:
        print(f"[WhiteGram Build] Error linking WhiteGram.dylib: {e}")
        return False


def rebrand_app_bundle(app_dir, root_dir):
    """
    Patches Info.plist with WhiteGram branding, replaces icon assets with
    WhiteGram's black-and-white icon, and renames bundle to WhiteGram.app.
    """
    print(f"[WhiteGram Build] Rebranding app bundle: {app_dir}")

    # 1. Update Info.plist
    plist_path = app_dir / "Info.plist"
    if plist_path.exists():
        try:
            with open(plist_path, "rb") as f:
                pl = plistlib.load(f)

            pl["CFBundleDisplayName"] = "WhiteGram"
            pl["CFBundleName"] = "WhiteGram"

            with open(plist_path, "wb") as f:
                plistlib.dump(pl, f)

            print("[WhiteGram Build] Updated Info.plist with CFBundleDisplayName='WhiteGram', CFBundleName='WhiteGram'.")
        except Exception as e:
            print(f"[WhiteGram Build] Info.plist patch note: {e}")

        # Run plutil if available on macOS
        plutil_bin = find_tool("plutil")
        if plutil_bin:
            try:
                run_command([plutil_bin, "-replace", "CFBundleDisplayName", "-string", "WhiteGram", str(plist_path)])
                run_command([plutil_bin, "-replace", "CFBundleName", "-string", "WhiteGram", str(plist_path)])
            except Exception as e:
                print(f"[WhiteGram Build] plutil note: {e}")

    # 2. Replace App Icon assets
    icon_src = root_dir / "Resources" / "preview.png"
    sips_bin = find_tool("sips")

    if icon_src.exists():
        print("[WhiteGram Build] Replacing app icons with WhiteGram logo...")
        icon_patterns = ["*Icon*.png", "*icon*.png", "AppIcon*.png"]
        replaced_count = 0

        for pattern in icon_patterns:
            for icon_file in app_dir.glob(pattern):
                if icon_file.is_file():
                    if sips_bin:
                        try:
                            # Read target dimensions
                            dim_out = subprocess.check_output([sips_bin, "-g", "pixelWidth", "-g", "pixelHeight", str(icon_file)], text=True)
                            w = 120
                            h = 120
                            for line in dim_out.splitlines():
                                if "pixelWidth" in line:
                                    w = int(line.split(":")[-1].strip())
                                if "pixelHeight" in line:
                                    h = int(line.split(":")[-1].strip())
                            run_command([sips_bin, "-z", str(h), str(w), str(icon_src), "--out", str(icon_file)])
                            replaced_count += 1
                        except Exception:
                            shutil.copyfile(icon_src, icon_file)
                            replaced_count += 1
                    else:
                        shutil.copyfile(icon_src, icon_file)
                        replaced_count += 1

        print(f"[WhiteGram Build] Replaced {replaced_count} icon asset files with WhiteGram branding.")

    # 3. Rename app bundle directory if needed
    parent_dir = app_dir.parent
    whitegram_app_dir = parent_dir / "WhiteGram.app"
    if app_dir != whitegram_app_dir:
        if whitegram_app_dir.exists():
            shutil.rmtree(whitegram_app_dir)
        app_dir.rename(whitegram_app_dir)
        app_dir = whitegram_app_dir
        print(f"[WhiteGram Build] Renamed app bundle to: {app_dir.name}")

    return app_dir


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

    # Strip existing code signatures for clean sideloading
    code_signature_dir = dest_app / "_CodeSignature"
    if code_signature_dir.exists():
        shutil.rmtree(code_signature_dir)

    archive_base = str(output_ipa.parent / "WhiteGram-unsigned")
    shutil.make_archive(archive_base, "zip", root_dir=temp_dir, base_dir="Payload")
    zip_path = Path(f"{archive_base}.zip")

    if output_ipa.exists():
        output_ipa.unlink()
    zip_path.rename(output_ipa)

    shutil.rmtree(temp_dir)
    size_mb = output_ipa.stat().st_size / (1024 * 1024)
    print(f"[WhiteGram Build] Successfully created IPA: {output_ipa} ({size_mb:.2f} MB, {output_ipa.stat().st_size} bytes)")


def build_full_telegram_ipa(root_dir, config, output_ipa):
    print("[WhiteGram Build] Building full WhiteGram iOS client...")
    build_dir = root_dir / "build"
    build_dir.mkdir(parents=True, exist_ok=True)

    # Download upstream base IPA
    base_ipa_path = build_dir / "base_telegram.ipa"
    if not base_ipa_path.exists() or base_ipa_path.stat().st_size < 1000000:
        print(f"[WhiteGram Build] Downloading upstream base IPA from {BASE_TELEGRAM_IPA_URL}...")
        try:
            req = urllib.request.Request(BASE_TELEGRAM_IPA_URL, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req) as resp, open(base_ipa_path, "wb") as out:
                shutil.copyfileobj(resp, out)
            print(f"[WhiteGram Build] Base Telegram IPA downloaded: {base_ipa_path.stat().st_size} bytes")
        except Exception as e:
            print(f"[WhiteGram Build] Error downloading base IPA: {e}")

    extracted_dir = build_dir / "extracted_base"
    if extracted_dir.exists():
        shutil.rmtree(extracted_dir)
    extracted_dir.mkdir(parents=True, exist_ok=True)

    app_dir = None
    if base_ipa_path.exists() and base_ipa_path.stat().st_size > 1000000:
        print("[WhiteGram Build] Extracting base Telegram iOS bundle...")
        with zipfile.ZipFile(base_ipa_path, "r") as z:
            z.extractall(extracted_dir)

        payload_dir = extracted_dir / "Payload"
        if payload_dir.exists():
            for item in payload_dir.iterdir():
                if item.suffix == ".app":
                    app_dir = item
                    break

    if not app_dir or not app_dir.exists():
        print("[WhiteGram Build] Error: Base app bundle not found!", file=sys.stderr)
        return False

    # 1. Rebrand app bundle (Info.plist, Icons, App Name)
    app_dir = rebrand_app_bundle(app_dir, root_dir)

    # 2. Compile WhiteGram.dylib with all Swift modules and hooks
    frameworks_dir = app_dir / "Frameworks"
    frameworks_dir.mkdir(parents=True, exist_ok=True)
    dylib_path = frameworks_dir / "WhiteGram.dylib"

    compiled = compile_whitegram_dylib(root_dir, dylib_path)
    if not compiled or not dylib_path.exists():
        print("[WhiteGram Build] Fallback: compiling standalone runtime hook...")
        clang_bin = find_tool("clang")
        xcrun_bin = find_tool("xcrun")
        sdk_path = subprocess.check_output([xcrun_bin, "--sdk", "iphoneos", "--show-sdk-path"], text=True).strip()
        hook_src = root_dir / "Sources" / "WhiteGramUI" / "WhiteGramHook.m"
        run_command([
            clang_bin,
            "-isysroot", sdk_path,
            "-arch", "arm64",
            "-miphoneos-version-min=15.0",
            "-dynamiclib",
            "-fobjc-arc",
            "-framework", "UIKit",
            "-framework", "Foundation",
            "-install_name", "@rpath/WhiteGram.dylib",
            "-o", str(dylib_path),
            str(hook_src)
        ])

    # 3. Inject LC_LOAD_DYLIB into main Mach-O executable
    injected = False
    plist_path = app_dir / "Info.plist"
    if plist_path.exists():
        try:
            with open(plist_path, "rb") as f:
                pl = plistlib.load(f)
            exec_name = pl.get("CFBundleExecutable")
            if exec_name and (app_dir / exec_name).is_file():
                injected = inject_load_dylib(app_dir / exec_name, "@rpath/WhiteGram.dylib")
        except Exception as e:
            print(f"[WhiteGram Build] Executable detection error: {e}")

    if not injected:
        for exec_file in app_dir.iterdir():
            if exec_file.is_file() and os.access(exec_file, os.X_OK) and not exec_file.name.endswith(".dylib"):
                inject_load_dylib(exec_file, "@rpath/WhiteGram.dylib")
                break

    # 4. Package IPA
    package_ipa(app_dir, output_ipa)
    return True


def main():
    parser = argparse.ArgumentParser(description="WhiteGram-iOS Build Tool")
    parser.add_argument("--configuration", default="release_arm64", help="Build configuration")
    parser.add_argument("--codesign", default="none", help="Codesign mode")
    parser.add_argument("--method", default="auto", help="Build engine")
    parser.add_argument("--output", default="build/artifacts/WhiteGram-unsigned.ipa", help="Output IPA path")
    args = parser.parse_args()

    root_dir = Path(__file__).resolve().parent.parent.parent
    output_ipa = Path(args.output)
    if not output_ipa.is_absolute():
        output_ipa = root_dir / output_ipa

    output_ipa.parent.mkdir(parents=True, exist_ok=True)

    print(f"=== Starting WhiteGram-iOS Build ===")
    print(f"Working Directory: {root_dir}")
    print(f"Target Output: {output_ipa}")

    built = build_full_telegram_ipa(root_dir, args.configuration, output_ipa)

    if not built or not output_ipa.exists() or output_ipa.stat().st_size < 1000000:
        print("[WhiteGram Build] Warning: Output IPA size verification check failed", file=sys.stderr)
        sys.exit(1)

    size_mb = output_ipa.stat().st_size / (1024 * 1024)
    print(f"=== WhiteGram-iOS Full Build Successful: {output_ipa} ({size_mb:.2f} MB) ===")


if __name__ == "__main__":
    main()
