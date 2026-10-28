# Building and packaging NoteX

## Requirements

- Windows x64.
- Visual Studio 2022 or Build Tools 2022 with MSVC v143, C++ desktop tools,
  and a Windows SDK. The release build uses C++20 and the static MSVC runtime.
- PowerShell and Python 3.9 or later. Python scripts use only the standard library.

All editor and embedded library sources are in this repository. No private SDK,
local user profile, plugin DLL, or installed Notepad++ is needed.

## Build

From the repository root:

```powershell
& .\PowerEditor\Test\NppPro\build-release.ps1
```

The script finds Visual Studio using `vswhere.exe`. Alternatively, pass
`-BuildTools 'C:\path\to\Visual Studio Build Tools'`.
It runs solution Clean and Build separately, then the native integration tests.
The binary is generated at `PowerEditor/bin64/notepad++.exe`.
You may also open `PowerEditor/visual.net/notepadPlus.sln` and select Release/x64.

## Create a fresh portable package

```powershell
python .\PowerEditor\Packaging\NppPro\package.py --output .\dist\NoteX
python .\PowerEditor\Packaging\NppPro\verify_package.py .\dist\NoteX
python .\PowerEditor\Test\NppPro\smoke_release.py --binary .\dist\NoteX\NoteX.exe
```

The output must be a new or empty directory. The script never copies an active
installation. It copies only reviewed source-tree assets and fresh defaults,
adds licenses and source-access instructions, and writes a SHA-256 manifest.
Do not use an existing user profile as a packaging input.
English is the initial interface language; Turkish and Spanish are also included.
Session snapshots and GDI rendering are enabled. Automatic updates are disabled.

## Modify and install your own build

Edit the source and repeat the build and packaging commands. Extract your package
to a new writable directory and run `NoteX.exe`. No activation key, signature
check, account, or installation lock is required for a modified build.
The distributed build is not signed. Do not overwrite user settings, sessions,
backups, documents, or `.npppro` companion files during an upgrade.

## Release the matching source

Follow [RELEASING.md](RELEASING.md). Publish source for the exact revision used
to compile the binary, including the build and packaging inputs. Compiler tools
and Windows system libraries are external prerequisites. A matching source
revision does not imply byte-for-byte reproducibility: compiler versions and
embedded build timestamps can affect the executable.
