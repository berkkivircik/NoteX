# NoteX for macOS

The native macOS edition uses AppKit, Cocoa Scintilla, the shared NoteX formatting
engine, and Lexilla. It does not use Wine, Rosetta, Electron, or a web view.
This is the first macOS preview, based on NoteX 1.3.1. It is not yet a replacement
for every Windows-specific Notepad++ feature.

## Install

Requires an Apple Silicon Mac and macOS 14 or later. Extract the release ZIP,
move NoteX.app to Applications, and open it. The application is ad-hoc signed,
not Apple Developer ID signed or notarized. If macOS blocks it, review the
download source and use System Settings > Privacy & Security > Open Anyway.
Do not disable Gatekeeper globally.

## Documents and updates

Session snapshots, including unsaved text, formatting, and cursor positions,
are stored in `~/Library/Application Support/NoteX`, outside the application.
Quit NoteX normally before replacing NoteX.app. Keep the Application Support
folder. Replacing the application does not replace your session.

Command-Q and closing the window preserve open tabs. Explicitly closing a tab
asks whether to save or discard unsaved changes. Snapshots run while you edit;
an abrupt power failure can still lose edits since the last completed snapshot.
Save important work to a document and maintain backups.

Saved formatting uses the same `.notex` companion format as Windows. Keep the
document and its companion together. A missing font may be substituted by macOS.
Windows session.xml files and absolute Windows paths are not imported.

## Build

Install Xcode Command Line Tools, then run `python3 macOS/build.py` from a clean
source checkout. The output is `dist/macOS/NoteX.app`. No package manager or
downloaded runtime is needed. Run `python3 macOS/test.py` for isolated native
integration tests. Test data is synthetic and never comes from a user profile.

## Scope

Native tabs, Unicode text editing, text formatting, line numbers, syntax lexers,
find/replace, file dialogs, keyboard shortcuts, and session recovery are included.
Windows DLL plugins, the Windows menu-layout configuration, Function List,
workspace/project panels, macros, and the complete Windows preferences dialog
are not included in this preview. The interface is currently US English.
Files use UTF-8 or BOM-marked UTF-16; unsupported encodings are rejected rather
than silently converted. The Windows release remains available separately.
