#!/usr/bin/env python3
"""Build the native NoteX application using only Xcode Command Line Tools.

Copyright (C) 2026 Berk Kivircik. SPDX-License-Identifier: GPL-3.0-only
"""
import concurrent.futures
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
VERSION = "1.3.2"
BUILD = "1"

def main():
    if sys.platform != "darwin":
        raise SystemExit("Build this target on macOS with Xcode Command Line Tools.")
    output = ROOT / "dist" / "macOS"
    if output.exists():
        raise SystemExit("dist/macOS already exists. Use a clean checkout or a new output directory.")
    bundle = output / "NoteX.app" / "Contents"
    resources = bundle / "Resources"
    binary = bundle / "MacOS" / "NoteX"
    binary.parent.mkdir(parents=True)
    resources.mkdir(parents=True)
    objects = output / "objects"
    objects.mkdir()
    sdk = subprocess.check_output(["xcrun", "--show-sdk-path"], text=True).strip()
    flags = ["-std=c++20", "-O2", "-DNDEBUG", "-DLEXILLA_NO_EXPORT", "-arch", "arm64",
             "-mmacosx-version-min=14.0", "-isysroot", sdk, "-Wno-deprecated-declarations"]
    for include in ["scintilla/include", "scintilla/src", "scintilla/cocoa",
                    "lexilla/include", "lexilla/lexlib"]:
        flags += ["-I", str(ROOT / include)]
    sources = sorted((ROOT / "scintilla/src").glob("*.cxx"))
    sources += sorted((ROOT / "scintilla/cocoa").glob("*.mm"))
    sources += sorted((ROOT / "lexilla/lexlib").glob("*.cxx"))
    sources += sorted((ROOT / "lexilla/lexers").glob("Lex*.cxx"))
    sources += [ROOT / "lexilla/src/Lexilla.cxx"]
    sources += sorted((ROOT / "macOS").glob("*.mm"))
    def compile_source(source):
        target = objects / ("_".join(source.relative_to(ROOT).parts) + ".o")
        command = ["xcrun", "clang++", *flags]
        if source.suffix == ".mm":
            command += ["-fobjc-arc"]
        subprocess.run([*command, "-c", str(source), "-o", str(target)], check=True)
        return target
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        compiled = list(pool.map(compile_source, sources))
    subprocess.run(["xcrun", "clang++", *flags, *map(str, compiled), "-framework", "Cocoa",
                    "-framework", "QuartzCore", "-framework", "CoreText", "-o", str(binary)], check=True)
    info = {
        "CFBundleName": "NoteX", "CFBundleDisplayName": "NoteX",
        "CFBundleIdentifier": "com.berkkivircik.NoteX", "CFBundleExecutable": "NoteX",
        "CFBundlePackageType": "APPL", "CFBundleShortVersionString": VERSION,
        "CFBundleVersion": BUILD, "LSMinimumSystemVersion": "14.0",
        "NSHighResolutionCapable": True, "NSPrincipalClass": "NSApplication",
        "NSHumanReadableCopyright": "Copyright © 2026 Berk Kivircik and contributors. GPLv3.",
        "CFBundleDocumentTypes": [{"CFBundleTypeName": "Text document", "CFBundleTypeRole": "Editor",
                                   "LSHandlerRank": "Alternate", "LSItemContentTypes": ["public.text", "public.source-code"]}],
    }
    with (bundle / "Info.plist").open("wb") as file:
        plistlib.dump(info, file)
    for name in ["LICENSE", "THIRD_PARTY_NOTICES.md", "MODIFICATIONS.md"]:
        shutil.copy2(ROOT / name, resources / name)
    shutil.copytree(ROOT / "LICENSES", resources / "LICENSES")
    shutil.copy2(ROOT / "scintilla/License.txt", resources / "Scintilla-LICENSE.txt")
    shutil.copy2(ROOT / "lexilla/License.txt", resources / "Lexilla-LICENSE.txt")
    shutil.copy2(ROOT / "macOS/README.md", resources / "README.md")
    shutil.copytree(ROOT / "PowerEditor/Packaging/NoteX/assets/fonts", resources / "Fonts")
    for source in (ROOT / "scintilla/cocoa/res").glob("*.png"):
        shutil.copy2(source, resources / source.name)
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    (resources / "SOURCE.txt").write_text(
        f"NoteX {VERSION} native macOS preview {BUILD}\nSource revision: {revision}\n"
        f"https://github.com/berkkivircik/NoteX/tree/{revision}\n"
        "Build: python3 macOS/build.py\nLicense: GNU GPL version 3\n", encoding="utf-8")
    subprocess.run(["codesign", "--force", "--sign", "-", str(bundle.parent)], check=True)
    subprocess.run(["codesign", "--verify", "--strict", str(bundle.parent)], check=True)
    subprocess.run(["file", str(binary)], check=True)
    print(bundle.parent, flush=True)

if __name__ == "__main__":
    main()
