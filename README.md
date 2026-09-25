# remember-cursor

A GNU TeXmacs plugin that remembers the cursor position of every document and
restores it when the file is opened again.

Tested with TeXmacs 2.1.4 (Guile 3).

## Installation

Copy (or symlink) the `remember-cursor` directory into your TeXmacs plugins
directory and restart TeXmacs:

```sh
ln -s "$PWD/remember-cursor" ~/.TeXmacs/plugins/remember-cursor
```

## How it works

- Every cursor movement (`notify-cursor-moved`) updates an in-memory table
  keyed by the absolute path of the file. Only local named files are tracked:
  scratch, `tmfs` and web buffers are ignored.
- The table is written to `~/.TeXmacs/system/remember-cursor.scm` 3 seconds
  after the last movement, when a buffer is closed and when TeXmacs quits.
  It keeps at most 300 files, and drops the least recently used ones first.
- When a file is loaded (`load-buffer-main`), the saved path is checked
  against the document. If the file changed elsewhere and the path is no
  longer valid, the cursor goes to the start of the deepest subtree that
  still exists.
- Switching to a buffer that is already open, loading in the background, and
  loads that stop to ask about an autosave file are left untouched.

Set `remember-cursor-enabled?` to `#f` to turn the plugin off.
