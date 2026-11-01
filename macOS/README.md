# NoteX for macOS

The native macOS edition uses AppKit, Cocoa Scintilla, the shared NoteX formatting
engine, and Lexilla. It does not use Wine, Rosetta, Electron, or a web view.
Preview 2 adds native menu customization, Function List, and project panels.
The Windows and macOS editions share the editing and formatting engine, but
their application interfaces do not yet have complete feature parity.

## Install

Requires an Apple Silicon Mac and macOS 14 or later. Extract the release ZIP,
move NoteX.app to Applications, and open it. The application is ad-hoc signed,
not Apple Developer ID signed or notarized. If macOS blocks it, review the
download source and use System Settings > Privacy & Security > Open Anyway.
Do not disable Gatekeeper globally.

## Documents and updates

Session snapshots, including unsaved text, formatting, cursor positions, bookmarks,
project trees, menu layouts, preferences, and saved editing macros,
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

## Menus and panels

Choose NoteX > Customize Menus to hide commands and reorder top-level menus or
commands within a menu. Apply saves the layout; Cancel keeps the previous layout.
The application menu, Quit, and menu recovery commands remain accessible.
NoteX > Reset Menu Layout restores the defaults.

View > Function List shows functions and classes for the active document. Double-click
a symbol to navigate to its definition. Filter narrows the tree; A–Z switches between
name order and source order. Rules lets you select a custom Notepad++ Function List
XML parser or return to automatic selection. The app bundles the upstream parser
rules and uses Boost.Regex. Parsing runs off the UI thread and supports documents
up to 16 MB. A syntax lexer does not necessarily have a Function List parser.

View > Project Panel 1, 2, or 3 opens an independent workspace. Add creates a project;
Folder creates a logical group; Files adds existing files or directories. Rename,
Remove, and the arrows organize references without renaming or deleting disk files.
Double-click a file to open it. Open XML and Save XML import and export Notepad++
workspace files. Relative paths resolve beside the XML file. Absolute Windows paths
remain references until you select the file and use Relink to choose its Mac location.
An externally changed workspace is protected against silent replacement.

View > Folder as Workspace browses selected directories. Refresh rereads the directory
tree. Hidden files and symbolic links are skipped. The sidebar selector switches
between the five views; View > Toggle Sidebar hides or shows it.

## Other additions

- Macro records editing commands, replays the last recording, and saves named macros.
  Saved macros can be repeated or deleted. Playback is one undo action.
- NoteX > Preferences controls the default font, size, tab width, tabs/spaces,
  line numbers, whitespace, automatic indentation, brace matching, and word completion.
- Bookmarks supports toggle, next, previous, and clear. The editor margins also support
  bookmarks and syntax folding; View includes Fold All and Unfold All.
- File includes Save All, Reload from Disk, Print, and formatted RTF/HTML export.
- Format includes Copy Formatting, Paste Formatting, and Copy as Rich Text.
- Edit includes duplicate/delete line, case conversion, whitespace trimming,
  selected-line sorting, duplicate-line removal, and word completion.
- Encoding converts UTF-8/BOM and UTF-16 LE/BE and LF/CRLF/CR line endings.

## Compatibility limits

This preview is not a claim of complete Windows feature parity. Windows DLL plugins,
Windows shortcut/menu/macro configuration import, split/clone document views, the
full Windows search-in-files interface, user-defined language/theme editors, and
the complete Windows preferences/shortcut mapper are not available. Native editing
macros do not record every application command. The interface is US English.
Files use UTF-8 or BOM-marked UTF-16; unsupported encodings are rejected rather
than silently converted. The Windows release remains available separately.
