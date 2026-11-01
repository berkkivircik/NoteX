# NoteX for macOS

The native macOS edition uses AppKit, Cocoa Scintilla, the shared NoteX formatting
engine, and Lexilla. It does not use Wine, Rosetta, Electron, or a web view.
Preview 3 adds split/clone views, find and replace in files, a preferences editor,
a shortcut editor, and user-defined language and theme editors. The Windows and
macOS editions share the editing and formatting engine and use native interfaces.

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
Split layout, independent view positions, shortcut assignments, custom languages,
and themes are also stored in the session folder, outside NoteX.app.

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
Valid definitions at the end of a file remain visible, including definitions that
the upstream parser omits when a match ends exactly at its search boundary.

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

## Split and clone views

Choose View > Clone to Other View to show the same document in a second editor.
Both views share text, formatting, bookmarks, and undo history. Their selections,
scroll positions, and zoom are independent. View > Split Vertically or Split
Horizontally changes the arrangement; drag the divider to resize the panes.
The document selector above the second editor can show a different open document.
Commands and formatting apply to the focused editor. Close View closes the second
view without discarding the original document. View > Synchronize Scrolling links
the visible positions of the two panes. The split arrangement survives a restart.

## Find and replace in files

Choose Edit > Find in Files. Search a folder, all open documents (including unsaved
tabs), or files referenced by the three project panels. File filters and exclusions
accept semicolon-separated wildcards. Subfolders and hidden files are optional.
Literal, case-sensitive, whole-word, and ICU regular-expression searches are
available. Regex replacements use `$1`, `$2`, and other capture-group references.

Find / Preview searches without changing files. Results include the file, line,
matching text, and proposed replacement. Double-click a result to navigate to it.
The replacement plan captures the replacement text entered before the search;
run the search again if you change the query or replacement.

Apply Previewed Replacements asks for confirmation. It checks that the searched
content is still current, skips dirty saved tabs and externally changed files,
backs up original documents and formatting companions, then saves through the
normal NoteX path. UTF-16 BOMs, formatting companions, and file permission bits
are preserved. Open Documents results, including dirty saved tabs and untitled tabs, are edited
with a single undo action and are not silently saved to disk. Successful changes remain applied if another file fails;
the result report lists skipped files and errors.

Open Backups in the search window opens the recovery directory.
Backups, `recovery.json`, and `report.json` are stored under
`~/Library/Application Support/NoteX/ReplaceBackups/<batch ID>`.
The recovery map is written before each file is changed, so original paths remain
available if the app stops during a batch. The final report records outcomes. Keep these backups
until you have reviewed the changes. Restore copies only after closing the file
in NoteX, and keep its formatting companion beside it.

Search is cancellable and bounded to 10,000 files and 20,000 matches. Unsupported
encodings, binary files, unreadable files, symbolic links, application bundles,
and files larger than 16 MB are skipped. A complex regular expression can be
stopped by the per-document time limit. Narrow the search if a limit is reached.

## Preferences, shortcuts, languages, and themes

NoteX > Preferences edits font, size, indentation, whitespace, wrapping, appearance,
caret behavior, the column guide, new-document encoding and line endings, and the
recovery interval. Reset restores defaults in the draft. Apply saves the changes;
Cancel leaves the current preferences unchanged. A longer recovery interval means
more recent edits can be lost if the process stops before the next snapshot.

NoteX > Shortcut Editor lists native commands, including hidden menu commands.
Choose a command, enter a character or F1–F20, select modifiers, and click Assign.
Apply checks conflicts and saves the draft. An empty key removes an assignment.
Text shortcuts require Command or Control; function keys can be unmodified.
Command-Q remains reserved for Quit. Reset All restores default shortcuts in the
draft. Menu visibility and shortcut assignments can be reset independently.

NoteX > Language Editor creates, duplicates, and deletes user-defined languages.
Configure filename extensions without a leading dot, eight keyword groups,
case sensitivity, line/block comments, ASCII string quote and escape characters,
and folding tokens. Open matching files to apply an extension rule, or choose
View > Choose User-Defined Language for an existing tab. Keyword matching supports
Unicode identifiers. User-defined syntax is styled for documents up to 16 MB.
The built-in Lexilla language selector remains available for standard languages.

NoteX > Theme Editor edits the editor background, text, caret, selection, current
line, line numbers, keyword groups, comments, strings, numbers, and operators.
Keyword bold and comment italic options are included. Choose a theme through
View > Choose Theme. Lexilla semantic style names map built-in syntax to theme
roles; custom languages use all eight keyword colors. Explicit per-range NoteX
formatting takes precedence over syntax colors.

The preferences, language, and theme editors support validated JSON import/export.
Import replaces the current draft; it does not change active settings until Apply.
Names must be unique. Language comment delimiters must be paired. Exported settings
contain configuration, not document text or session recovery data.

## Other features

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

Windows DLL plugins cannot run in the native application. Native settings exports
use JSON; Windows session, shortcut, menu, macro, UDL, and theme configuration files
are not automatically imported. Notepad++ project workspace XML and NoteX formatting
companions are supported as described above. Find in Files uses ICU regex syntax;
Windows uses Boost.Regex, so platform-specific expressions may need adjustment.
Native editing macros do not record every application command. The interface is US English.
Files use UTF-8 or BOM-marked UTF-16; unsupported encodings are rejected rather
than silently converted. The Windows release remains available separately.
