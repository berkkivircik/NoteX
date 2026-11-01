# Changelog

## 1.4.1 macOS Preview 4 - 2026-11-01

- Toggle the selected sidebar panel from its View menu command and show its checked state.
- Start new profiles with the sidebar hidden and preserve existing visibility preferences.
- Fit line-number margins to their digit count and font size.
- Add accessible Bulleted List and Numbered List toolbar buttons.
- Keep list changes inside the selected lines, retain focused-clone editing, and group undo.
- Verify upgrading sessions created by the published 1.4.0 native binary.

## 1.4.0 macOS Preview 3 - 2026-11-01

- Add horizontal and vertical split views, shared-document clones, independent
  view state, a second-view document selector, and synchronized scrolling.
- Add background file search across folders, open tabs, and project references,
  with filters, regex, Unicode match navigation, and previewed replacements.
- Protect replace-in-files operations with stale-content checks, recovery copies,
  result reports, encoding preservation, and formatting-aware normal saves.
- Add a native preferences editor with reset and JSON import/export.
- Add a shortcut editor with conflict detection and persistent command assignments.
- Add user-defined language editing, extension associations, keyword groups,
  comments, strings, folding, and Unicode keyword matching.
- Add theme editing, syntax colors, font traits, and JSON import/export.
- Preserve new configuration and split state across restarts and app replacement.
- Preserve existing file permission bits during atomic macOS file writes.
- Keep Windows binaries and historical releases unchanged.

## 1.3.3 macOS Preview 2 - 2026-11-01

- Add persistent native menu visibility and ordering, with Apply, Cancel, and Reset.
- Add Function List using the upstream XML rules and Boost.Regex, including class
  groups, filtering, sorting, custom parsers, and navigation to UTF-8 byte positions.
- Add three independent project panels, Notepad++ workspace XML import/export,
  relative paths, reference management, relinking, and Folder as Workspace.
- Add editing macro recording, named macros, repeat playback, and grouped undo.
- Add editor preferences, bookmarks, folding, automatic indentation, brace matching,
  word completion, line operations, encoding and line-ending conversion.
- Add format copying, rich-text copying, RTF/HTML export, Save All, Reload, and Print.
- Keep project, menu, macro, and bookmark state outside the application bundle.
- Extend isolated native tests to upstream Function List fixtures, workspace safety,
  feature persistence, and upgrading a session created by the published first preview.
- Preserve the Windows release and document remaining platform differences.

## 1.3.2 macOS Preview 1 - 2026-11-01

- Add a native Apple Silicon application with AppKit windows, menus, tabs,
  file dialogs, and Mac keyboard shortcuts; no Windows compatibility runtime.
- Reuse NoteX's Scintilla formatting and undo engine with the Cocoa renderer.
- Add native rich-text clipboard support and the bundled Lexilla syntax lexers.
- Preserve Unicode text, formatting, selections, and open tabs in atomic session
  snapshots outside the application bundle, with a previous-snapshot fallback.
- Read and write Windows-compatible formatting companions. Reject mismatched
  companions, unrelated companion files, and externally changed documents.
- Add isolated native tests for formatting, clipboard, file persistence,
  restart, application replacement, and recovery after process termination.
- Document preview limitations separately from the Windows feature set.
- Keep the Windows 1.3.1 binaries and their corresponding source unchanged.

## 1.3.1 - 2026-10-31

- Complete the NoteX naming migration across source, namespaces, classes, native
  window identities, filenames, themes, scripts, tests, and package inputs.
- Write formatting companions with the `.notex` extension and NoteX signatures.
- Read previous companions and rich clipboard payloads, and migrate valid
  companion filenames without rewriting text or overwriting current companions.
- Migrate the previous menu settings filename and theme preference.
- Include the fix for selected-looking inactive font-family and font-size fields.
- Preserve original upstream copyright and license notices.

## 1.3.0 - 2026-10-28

First public NoteX editor release.
Based on Notepad++ 8.9.8.1.

- Publish the complete modified editor source and build/packaging scripts.
- Rename the visible product, executable package, and version metadata to NoteX.
- Include visual range formatting, pending typing formats, format painting,
  lists, variable line/caret heights, and formatting-aware undo/redo.
- Include companion-file persistence, session snapshot integration, and
  persistent menu customization.
- Preserve GDI defaults, session recovery, and disabled upstream auto-updates.
- Ship English, Turkish, and Spanish interface packages.
- Add dated modification notices, corresponding-source instructions, original
  copyright attribution, and complete font/component license notices.
- Build a fresh public profile without personal documents, histories, screenshots,
  validation logs, optional plugin DLLs, or the upstream updater.

The earlier NoteX feature work is summarized here; this date identifies its
NoteX publication and does not claim that all features were authored on one day.
