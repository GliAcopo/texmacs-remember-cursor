Title: Remember the cursor position of each file

When a long document is opened again, TeXmacs starts at the beginning, and one
has to scroll back to the place where one was working. This series makes
TeXmacs remember the cursor position of every local file and restore it when
the file is loaded again. It can be switched off in the preferences.

![The view after reopening a 1,000-paragraph document](https://raw.githubusercontent.com/GliAcopo/texmacs-remember-cursor/main/upstream/screenshots/restored-view.png)

Test script, results and the same series as a single patch file:
https://github.com/GliAcopo/texmacs-remember-cursor/tree/main/upstream
The series is also submitted on Savannah: <!--SAVANNAH-->

## The series (4 commits, Scheme only)

The series is based on `development` and applies unchanged to current trunk
(`svn_mirror`): `git am` and `patch -p1` both apply it without fuzz on both
branches. No C++ file is touched and nothing needs to be rebuilt.

1. **prog: call former in the notify-cursor-moved overloads** (6 files, +12/−6)
   The six overloads used for bracket highlighting (`prog-edit`, `cpp-edit`,
   `dot-edit`, `fortran-edit`, `python-edit`, `scheme-edit`) replaced
   `notify-cursor-moved` instead of extending it. With "prog:highlight
   brackets" on, no other code could react to cursor movements. Each overload
   now ends with `(former status)`; its own behaviour is unchanged.
2. **files: remember the cursor position of each file** (3 files, +117/−1)
   - `tm-files.scm`: a new section "Remembering the cursor position in
     files", and one call in `load-buffer-load` after a file has been loaded
     from disk.
   - `preferences-menu.scm`, `preferences-widgets.scm`: the new boolean
     preference "remember cursor position" (default "on"), in
     Edit > Preferences > Other and in the Preferences > Other menu.
3. **dic: translate "remember cursor position"** (25 files, one line each)
   All 23 translated languages, plus `english-new.scm`. Each file keeps its
   own encoding: UTF-8 for the languages that `dictionary.cpp` reads as UTF-8,
   Cork for the others (for example `ž`, `ę`, `ă`, `ţ`). Every translation was
   checked with `translate-from-to` in a running TeXmacs.
4. **check: add regression tests for remembering cursor positions** (2 files)
   `tm-files-test.scm` with `regtest-cursor-memory` (13 checks), added to
   `run-all-tests`.

## How it works

- **Recording.** `notify-cursor-moved` stores the cursor path relative to the
  document body in a table keyed by the file name. Only local named files are
  recorded: scratch, web and `tmfs` buffers are skipped.
- **Saving.** The table is written to
  `$TEXMACS_HOME_PATH/system/cursor-positions.scm` 3 seconds after the last
  movement (`delayed :idle`) and when TeXmacs quits (`on-exit`). It keeps the
  300 most recently used files. It is read lazily, the first time it is
  needed.
- **Restoring.** When `load-buffer-load` has loaded a file from disk, the
  saved path is checked against the new document before it is used:
  - if it is still a valid cursor position, the cursor goes there, and the
    view follows;
  - if the file was changed outside TeXmacs, the cursor goes to the start of
    the deepest subtree that still exists along the path;
  - if nothing matches, the cursor stays at the start.
  The restore runs inside `load-buffer-load`, before control returns to the
  event loop.
- **Not restored:** switching to a buffer that is already open, loading with
  `:background`, recovering an autosave file, new files.

## What could break, and how it was checked

| Risk | Handling | Checked by |
|---|---|---|
| A stale path (file edited elsewhere) sends the cursor to an invalid place | Every path is validated against the tree before use; otherwise a valid ancestor or the start is used | scenarios 9, 10; 13 regression checks |
| A corrupt or hand-edited state file stops files from loading | Reading is wrapped in `catch`, and malformed entries are skipped | scenario 11 |
| Recording the start of the document before the saved position is restored | The restore is synchronous inside `load-buffer-load` | scenarios 2, 3 |
| Quitting before the delayed write | `on-exit` records and writes as well | scenario 4 |
| Overriding the cursor of a buffer that is already open | Only the branch of `load-buffer-load` that actually loads from disk restores | scenario 5 |
| Private or temporary buffers ending up in the file | Scratch, web and `tmfs` buffers are skipped | scenario 6 |
| Users who do not want the feature | Preference "remember cursor position"; when off, nothing is restored or written | scenarios 7, 8 |
| Bracket highlighting overloads hiding the hook | Commit 1: they now call `former` | scenario 12; bracket selection compared with and without the series (identical) |
| Disk writes on every movement | At most one write per 3 s pause, only when a position changed | code review |
| Guile 1.8 / Guile 3 differences | Only constructs available in both are used (`catch`, `sort`, `current-time`, TeXmacs macros) | all tests run on trunk (embedded Guile 1.8) and on 2.1.4 (Guile 3.0.11) |
| Merge conflicts with trunk | `check-master.scm` differs between `development` and trunk; the new lines are placed where the context is identical in both | `git am` and `patch -p1` on both branches |

## Tests

**End-to-end** (`test-cursor-memory.sh` in the repository above). The script
runs a real TeXmacs with a fresh `TEXMACS_HOME_PATH` and drives it through `-x`
scripts. The movement commands it uses (`go-down`, `go-right`) go through the
same hook as the keyboard. There are 13 scenarios:

1. position written to disk 3 s after a movement, while TeXmacs is running
2. restored for a file given on the command line
3. restored for a file opened later (`load-buffer`, as File > Open)
4. saved when quitting right after a movement
5. switching to an already open buffer keeps its cursor
6. scratch buffers are not recorded
7. preference off: nothing restored
8. preference off: nothing recorded
9. paragraph shortened outside TeXmacs: start of that paragraph
10. file truncated outside TeXmacs: start of the document, no error
11. corrupt state file: ignored
12. still recorded with "prog:highlight brackets" on
13. `regtest-cursor-memory`

Results: **13/13 pass** on trunk (`svn_mirror` 148ed74, CMake build with the
embedded Guile 1.8, Qt5), and **13/13 pass** on TeXmacs 2.1.4 (Ubuntu
package, Guile 3.0.11) with the same series applied to its `progs`.

**`run-all-tests` on trunk**, with and without the series: the output is
identical except for the 13 new checks. Both runs stop at the same
pre-existing failure, `image / simple link` in `regtest-tmhtml`. The new test
is therefore placed before `regtest-tmhtml`, so that it runs.

**Manual checks on trunk:**
- A 1,000-paragraph document reopened at paragraph 23.14: the view scrolls to
  the cursor (screenshot above).
- The new preference is shown in Other preferences
  ([screenshot](https://raw.githubusercontent.com/GliAcopo/texmacs-remember-cursor/main/upstream/screenshots/preference.png)).
- Bracket selection in a Scheme code block is identical with and without the
  series.

To reproduce on a build:
```sh
TEXMACS_PATH=<patched TeXmacs dir> ./test-cursor-memory.sh <path to the texmacs launcher>
```
For a CMake build with the embedded Guile, also set `GUILE_LOAD_PATH` to the
`guile-texmacs` directory.

## Notes for merging

- There is no C++ change, no new dependency and no file format change. The
  state file is a plain Scheme list written with `save-object`.
- The regression checks reach `cursor-memory-valid?` and
  `cursor-memory-subtree` through `tm-define` (with `:synopsis`). All other
  helpers are private to `tm-files.scm`.
- `TeXmacs/doc/about/changes` is not updated; I left that to you. A possible
  entry: "The cursor position of each file is remembered and restored when the
  file is opened again (Edit > Preferences > Other)."

---

The same feature is available as a stand-alone plugin for existing
installations: https://github.com/GliAcopo/texmacs-remember-cursor

This work was done with the help of Claude Opus 5.5.
