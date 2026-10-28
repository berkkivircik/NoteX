# NoteX

NoteX is a portable Windows text and code editor based on Notepad++ 8.9.8.1.
Previously developed as NppPro, it adds visual text formatting, a redesigned
toolbar, customizable menus, and formatting-aware session recovery.
This is an independent modified distribution maintained by Berk Kivircik.

## Download and run

Download `NoteX-1.3.0-portable-x64.zip` from the
[1.3.0 release](https://github.com/berkkivircik/NoteX/releases/tag/v1.3.0),
extract it to a writable folder, and run `NoteX.exe`. No installer is required.
The public package starts with a fresh profile and no documents or session history.
Windows x64 is required. This release is unsigned.

## Features

- Apply fonts, sizes, bold, italic, underline, strikethrough, and colors to text ranges.
- Set the format for text you type next, copy formatting, and create lists.
- Use line and caret heights that follow the formatting on each line.
- Reorder and hide menu items with persistent menu customization.
- Recover unsaved text and formatting through session snapshots.
- Use English, Turkish, or Spanish interface translations; syntax highlighting
  support is independent of the interface language.

Formatting is stored separately in `.npppro` companion files. Legacy internal
names and configuration filenames remain compatible with NppPro.
The package uses GDI rendering and disables upstream automatic updates.
Optional third-party plugins and the upstream updater are not bundled in this
public release. They are not required for the editor's built-in features.

## Source and build

The repository includes the modified editor, Scintilla, Lexilla, Boost.Regex,
build scripts, tests, and portable packaging inputs. See [BUILD.md](BUILD.md).
The `v1.3.0` tag and `NoteX-1.3.0-source.zip` release asset identify the source
for the matching portable binary. Do not substitute upstream Notepad++ source
or a different NoteX revision when redistributing this binary.

## License and attribution

NoteX is distributed under the **GNU General Public License, version 3**.
See [LICENSE](LICENSE) for the original Notepad++ notice and complete license.
NoteX modifications: Copyright (C) 2026 Berk Kivircik.
Original Notepad++ copyrights, including Don HO's, are preserved.
See [MODIFICATIONS.md](MODIFICATIONS.md), [CHANGELOG.md](CHANGELOG.md),
and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

You may use NoteX commercially, study and modify its source, and redistribute
it under the applicable license terms. No additional license fee or permission
from the NoteX maintainer is required. The software is provided without warranty.
Separate components and fonts retain their own license terms.

NoteX is not an official Notepad++ release and is not endorsed by the upstream
project. Report NoteX issues in this repository. Upstream documentation is
retained in the `UPSTREAM_*.md` files for reference.
