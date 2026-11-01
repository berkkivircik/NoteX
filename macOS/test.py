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

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "dist/macOS"
APP = OUTPUT / "NoteX.app"
results = [{"macOS": platform.mac_ver()[0], "architecture": platform.machine()}]

def run(app, mode, profile):
    env = dict(os.environ, NOTEX_PROFILE=str(profile), NOTEX_TEST_SOURCE=str(ROOT), NOTEX_TEST_IMAGE=str(OUTPUT / "native-preview.png"))
    result = subprocess.run([str(app / "Contents/MacOS/NoteX"), "--self-test", mode],
                            env=env, capture_output=True, text=True, timeout=90)
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
print("Native suite, normal restart, application replacement, and post-snapshot process termination passed.")
