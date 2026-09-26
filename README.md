# remember-cursor

A GNU TeXmacs plugin that remembers the cursor position of every document and
restores it when the file is opened again.

Tested with TeXmacs 2.1.4 (Guile 3).

## Installation

Clone the repository, then copy (or symlink) the `remember-cursor` directory
into your TeXmacs plugins directory and restart TeXmacs:

```sh
git clone https://github.com/GliAcopo/texmacs-remember-cursor.git
ln -s "$PWD/texmacs-remember-cursor/remember-cursor" ~/.TeXmacs/plugins/remember-cursor
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

## Development

This plugin was developed with the assistance of Claude Opus 5.5, an AI model
by Anthropic, used through Claude Code. The design, the code and the tests
were reviewed and verified by the author on TeXmacs 2.1.4.

## License

Copyright (C) 2026 Jacopo Rizzuto.

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version. See [LICENSE](LICENSE).
