# NoteX modification notice

Modified distribution: NoteX 1.3.1.
Modifier: Berk Kivircik. Latest modification date: October 31, 2026.
NoteX modifications: Copyright (C) 2026 Berk Kivircik.
The modified work as a whole is distributed under GNU GPL version 3.
Original copyright, license, and warranty notices remain in place.

## Upstream base

- Project: Notepad++.
- Release: v8.9.8.1.
- Repository: https://github.com/notepad-plus-plus/notepad-plus-plus
- Base commit: `dd40fe45598791e9aa38f3aeb200e10fb3d6338a`.

This repository starts with a reviewed source snapshot. It does not include the
maintainer's local Git history or personal workspace. Upstream authorship is
preserved through the original files, notices, and the exact base reference.

## Changes from the upstream base

The editor adds a visual formatting toolbar, per-range styles, pending insertion
formats, formatting-aware clipboard and undo operations, companion-file storage,
snapshot recovery integration, custom menu ordering/visibility, and updated tabs
and toolbar presentation. Scintilla changes implement style storage, edit tracking,
line/caret metrics, and rendering. Editor web-search commands are disabled.
The NoteX publication updates branding, legal notices, build discovery, and clean
packaging. Legacy `.notex` files and menu settings remain compatible.

## Modified upstream code and project files

These files contain dated NoteX notices in addition to their original notices:

- `PowerEditor/src/MISC/Common/NppConstants.h`
- `PowerEditor/src/Notepad_plus.cpp`
- `PowerEditor/src/Notepad_plus.h`
- `PowerEditor/src/Notepad_plus.rc`
- `PowerEditor/src/Notepad_plus_Window.cpp`
- `PowerEditor/src/Notepad_plus_Window.h`
- `PowerEditor/src/NppBigSwitch.cpp`
- `PowerEditor/src/NppCommands.cpp`
- `PowerEditor/src/NppNotification.cpp`
- `PowerEditor/src/Parameters.h`
- `PowerEditor/src/ScintillaComponent/Buffer.cpp`
- `PowerEditor/src/WinControls/AboutDlg/AboutDlg.cpp`
- `PowerEditor/src/WinControls/AboutDlg/AboutDlg.h`
- `PowerEditor/src/WinControls/ContextMenu/ContextMenu.cpp`
- `PowerEditor/src/WinControls/Preference/preferenceDlg.cpp`
- `PowerEditor/src/WinControls/TabBar/TabBar.cpp`
- `PowerEditor/src/WinControls/ToolBar/ToolBar.cpp`
- `PowerEditor/src/resource.h`
- `PowerEditor/src/winmain.cpp`
- `PowerEditor/visual.net/notepadPlus.Cpp.props`
- `PowerEditor/visual.net/notepadPlus.vcxproj`
- `scintilla/src/ContractionState.cxx`
- `scintilla/src/ContractionState.h`
- `scintilla/src/Document.cxx`
- `scintilla/src/Document.h`
- `scintilla/src/EditModel.cxx`
- `scintilla/src/EditModel.h`
- `scintilla/src/EditView.cxx`
- `scintilla/src/EditView.h`
- `scintilla/src/Editor.cxx`
- `scintilla/src/Editor.h`
- `scintilla/src/MarginView.cxx`
- `scintilla/src/PositionCache.cxx`
- `scintilla/src/PositionCache.h`
- `scintilla/src/Style.h`
- `scintilla/src/ViewStyle.cxx`
- `scintilla/src/ViewStyle.h`
- `scintilla/win32/ScintillaWin.cxx`

## Added implementation and support files

- `PowerEditor/src/NoteXMenu.h`: menu customization and persistence.
- `PowerEditor/src/NoteXSidecar.h`: formatting companion-file persistence.
- `PowerEditor/src/NoteXTools.h`: formatting controls and editing commands.
- `scintilla/include/NoteXFormat.h`: formatting model and serialization.
- `PowerEditor/Test/NoteX/`: native tests, clean build, and smoke scripts.
- `PowerEditor/Packaging/NoteX/`: clean package recipe and reviewed runtime assets.
- Root documentation, licenses, release instructions, and privacy exclusions.

Modified source files identify this publication date. Earlier individual edit
dates are not asserted. Unchanged upstream components retain their original terms.

Upstream CI/release automation and redundant update-reference source ZIPs are
excluded. The optional LuaScript DLLs used only by upstream URL-detection tests
are omitted; those upstream tests require their own separately obtained tools.
The embedded libraries used to build NoteX remain included in full.

The NoteX palette theme carries restored DarkModeDefault/Zenburn attribution
and the original GPLv2 resource license. The upstream DansLeRuSH-Dark theme is
omitted because its header includes noncommercial terms. Markdown UDLs retain
their Edditoria attribution and include the complete MIT license.

The repository root LICENSE uses the standard GPLv3 text for license detection.
The original Notepad++ license file, including its copyright preamble, is retained
verbatim at LICENSES/Notepad-plus-plus-LICENSE.txt. The v1.3.0 release tag remains
unchanged and continues to identify its exact published source and artifacts.

The 1.3.1 naming migration also changes Parameters.cpp and the progress-window
class identifier in FindReplaceDlg.cpp. Previous formatting wire versions and
clipboard payloads remain readable; new output uses NoteX names and signatures.
