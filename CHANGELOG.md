# Changelog

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
