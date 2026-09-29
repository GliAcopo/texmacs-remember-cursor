# Upstream proposal: remember the cursor position in TeXmacs

The same feature as the plugin in this repository, proposed for inclusion in
GNU TeXmacs itself. It is written as a patch series against the `development`
branch and also applies to trunk.

- Pull request: https://github.com/texmacs/texmacs/pull/113
- Savannah patch: (to be submitted)
- Description of the changes, risks and tests: [pull-request.md](pull-request.md)

## Contents

| File | What it is |
|---|---|
| `texmacs-remember-cursor-position.patch` | the 6 commits as one `git format-patch` file (`git am` or `patch -p1`) |
| `test-cursor-memory.sh` | end-to-end test script (17 checks) that drives a real TeXmacs |
| `results/trunk.txt` | results on trunk (`svn_mirror` 148ed74, embedded Guile 1.8) |
| `results/texmacs-2.1.4.txt` | results on TeXmacs 2.1.4 (Guile 3.0.11) |
| `results/plugin-texmacs-2.1.4.txt` | results of the stand-alone plugin on unpatched TeXmacs 2.1.4 |
| `results/run-all-tests-trunk-*.txt` | `run-all-tests` output on trunk, with and without the series |
| `screenshots/` | the restored view in a 1,000-paragraph document, and the new preference |

## Running the tests

```sh
TEXMACS_PATH=<patched TeXmacs dir> ./test-cursor-memory.sh <path to the texmacs launcher>
```

A graphical session is needed. For a CMake build with the embedded Guile, also
set `GUILE_LOAD_PATH` to the `guile-texmacs` directory.
