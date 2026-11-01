#!/usr/bin/env python3
"""Run real AppKit/Scintilla tests in separate processes and isolated profiles.
Copyright (C) 2026 Berk Kivircik. SPDX-License-Identifier: GPL-3.0-only
"""
import json
import os
import platform
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import hashlib
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "dist/macOS"
APP = OUTPUT / "NoteX.app"
results = [{"macOS": platform.mac_ver()[0], "architecture": platform.machine()}]

def run(app, mode, profile):
    env = dict(os.environ, NOTEX_PROFILE=str(profile), NOTEX_TEST_SOURCE=str(ROOT), NOTEX_TEST_IMAGE=str(OUTPUT / "native-preview.png"))
    try:
        result = subprocess.run([str(app / "Contents/MacOS/NoteX"), "--self-test", mode],
                                env=env, capture_output=True, text=True, timeout=90)
    except subprocess.TimeoutExpired as error:
        print(error.stdout, flush=True)
        print(error.stderr, flush=True)
        raise
    print(result.stdout, flush=True)
    if result.returncode:
        print(result.stderr, flush=True)
    results.append({"mode":mode, "exit":result.returncode, "output":result.stdout, "stderr":result.stderr})
    (OUTPUT / "test-results.json").write_text(json.dumps(results, indent=2), encoding="utf-8")
    if result.returncode:
        raise SystemExit(f"Native test failed: {mode}")

with tempfile.TemporaryDirectory(prefix="notex-native-tests-") as directory:
    work = Path(directory)
    run(APP, "suite", work / "test-suite")
    run(APP, "seed", work / "test-restart")
    run(APP, "restore", work / "test-restart")
    replacement = work / "Replacement/NoteX.app"
    replacement.parent.mkdir()
    shutil.copytree(APP, replacement)
    run(replacement, "restore", work / "test-restart")
    if os.environ.get("CI"):
        # Exercise a real upgrade from the immutable first native release.
        old_zip = work / "previous.zip"
        urllib.request.urlretrieve("https://github.com/berkkivircik/NoteX/releases/download/v1.3.2-macos.1/NoteX-1.3.2-macos-arm64.zip", old_zip)
        assert hashlib.sha256(old_zip.read_bytes()).hexdigest() == "93b4170c541a96dcca15a60c06a2528b492613b0704acb386af0ecec808a9748"
        subprocess.run(["ditto", "-x", "-k", str(old_zip), str(work / "Previous")], check=True)
        run(work / "Previous/NoteX.app", "seed", work / "test-upgrade")
        run(APP, "restore-legacy", work / "test-upgrade")
    # Kill only the child launched here, after the ordinary autosnapshot timer.
    log = work / "crash.log"
    with log.open("w") as output:
        process = subprocess.Popen([str(APP / "Contents/MacOS/NoteX"), "--self-test", "crash-seed"],
            env=dict(os.environ, NOTEX_PROFILE=str(work / "test-crash")), stdout=output, stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic() + 60
            while "READY" not in log.read_text():
                if process.poll() is not None or time.monotonic() > deadline:
                    raise RuntimeError("Crash fixture failed to complete an autosnapshot: " + log.read_text())
                time.sleep(0.2)
            if os.environ.get("CI"):
                # Capture only the hosted runner's synthetic test session.
                subprocess.run(["screencapture", "-x", str(OUTPUT / "native-desktop.png")], check=True, timeout=15)
        finally:
            if process.poll() is None:
                process.kill()
            process.wait(timeout=10)
    run(APP, "restore", work / "test-crash")
    if os.environ.get("CI"):
        for mode in ("ui-function", "ui-project", "ui-menu"):
            log = work / f"{mode}.log"
            with log.open("w") as output:
                process = subprocess.Popen([str(APP / "Contents/MacOS/NoteX"), "--self-test", mode],
                    env=dict(os.environ, NOTEX_PROFILE=str(work / f"test-{mode}")), stdout=output, stderr=subprocess.STDOUT)
                try:
                    deadline = time.monotonic() + 30
                    while "READY" not in log.read_text():
                        if process.poll() is not None or time.monotonic() > deadline:
                            raise RuntimeError("Panel UI test failed: " + log.read_text())
                        time.sleep(0.2)
                    time.sleep(0.5)
                    subprocess.run(["screencapture", "-x", str(OUTPUT / f"{mode}.png")], check=True, timeout=15)
                    print(log.read_text(), flush=True)
                finally:
                    if process.poll() is None:
                        process.kill()
                    process.wait(timeout=10)
print("Native suite, normal restart, application replacement, and post-snapshot process termination passed.")
