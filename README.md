# remember-cursor

A GNU TeXmacs plugin that remembers the cursor position of every document and
restores it when the file is opened again.

Tested with TeXmacs 2.1.4 (Guile 3).

**The feature will now be included in TeXmacs natively**
([texmacs/texmacs#113](https://github.com/texmacs/texmacs/pull/113), with a
preference in Edit > Preferences > Other). Once you use a TeXmacs version
that has it, remove this plugin. Until then, the plugin gives the same
feature to existing installations. The patch series, its tests and their
results are in [upstream/](upstream/).

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
  against the document before control returns to the editor. If the file
  changed elsewhere and the path is no longer valid, the cursor goes to the
  start of the deepest subtree that still exists.
- The bracket highlighting of the program modes replaces
  `notify-cursor-moved` instead of extending it. The plugin loads those
  modules first, so that its own definition is the most recent one; it
  records the position and then hands over to them.
- Switching to a buffer that is already open, loading in the background, and
  loads that stop to ask about an autosave file are left untouched.

Set `remember-cursor-enabled?` to `#f` to turn the plugin off.

### Limitation

TeXmacs initializes user plugins about a second after start-up, after the
files given on the command line have been loaded. For those files the saved
position is restored when the plugin starts, and only if the cursor has not
been moved in the meantime. Files opened later are restored at once. The
upstream patch does not have this limitation.

## Testing

`upstream/test-cursor-memory.sh` drives a real TeXmacs through its scenarios.
To test the plugin on an unpatched TeXmacs:

```sh
PLUGIN_DIR="$PWD/remember-cursor" upstream/test-cursor-memory.sh "$(command -v texmacs)"
```

Results on TeXmacs 2.1.4: [upstream/results/plugin-texmacs-2.1.4.txt](upstream/results/plugin-texmacs-2.1.4.txt).

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
