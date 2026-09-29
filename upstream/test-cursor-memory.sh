#!/usr/bin/env bash
# End-to-end tests for the "remember cursor position" patch.
#
# Usage: test-cursor-memory.sh <texmacs launcher>
#
# TEXMACS_PATH (and, for a build with the embedded Guile, GUILE_LOAD_PATH)
# must point at the patched TeXmacs. Every scenario runs TeXmacs with a fresh
# TEXMACS_HOME_PATH and drives it with "-x" scripts. The position is
# recorded when a buffer is saved, auto-saved or closed, and when TeXmacs
# quits. A graphical session (X11 or Wayland) is needed.
#
# To test the stand-alone plugin on an unpatched TeXmacs instead, set
# PLUGIN_DIR to its directory: it is linked into every test home, the state
# file becomes remember-cursor.scm, and the checks of the preference and of
# regtest-cursor-memory (which only exist in the patch) are skipped.
set -uo pipefail

tm="${1:?usage: $0 <texmacs launcher>}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
export TEXMACS_HOME_PATH="$work/home"
plugin="${PLUGIN_DIR:-}"
if [ -n "$plugin" ]; then state="$TEXMACS_HOME_PATH/system/remember-cursor.scm"
else state="$TEXMACS_HOME_PATH/system/cursor-positions.scm"; fi
# user plugins are initialized about 1 s after start-up: let that happen first
start_idle=1000; [ -n "$plugin" ] && start_idle=3000
doc="$work/doc.tm"
other="$work/other.tm"
failures=0

make_doc() { # make_doc <file> <paragraphs> [short paragraph]
  {
    printf '<TeXmacs|2.1.4>\n\n<style|generic>\n\n<\\body>\n'
    for i in $(seq 1 "$2"); do
      if [ "$i" = "${3:-}" ]; then printf '  x\n\n'
      else printf '  Paragraph number %d with some text.\n\n' "$i"; fi
    done
    printf '</body>\n\n<initial|<\\collection>\n</collection>>\n'
  } >| "$1"
}

run() { # run <scheme body> [file]: prints the lines tagged with OUT
  printf '(delayed (:idle %s) %s (quit-TeXmacs))\n' "$start_idle" "$1" >| "$work/script.scm"
  timeout 180 "$tm" -x "(load \"$work/script.scm\")" ${2:+"$2"} 2>&1 |
    sed -n 's/^OUT //p'
}

run_wait() { # like run, but quits only after 6 s without activity
  printf '(delayed (:idle %s) %s (delayed (:idle 6000) (quit-TeXmacs)))\n' \
    "$start_idle" "$1" >| "$work/script.scm"
  timeout 180 "$tm" -x "(load \"$work/script.scm\")" ${2:+"$2"} 2>&1 |
    sed -n 's/^OUT //p'
}

check() { # check <name> <expected> <actual>
  if [ "$2" = "$3" ]; then printf 'PASS  %s\n' "$1"
  else printf 'FAIL  %s: expected [%s], got [%s]\n' "$1" "$2" "$3"
       failures=$((failures + 1)); fi
}

saved() { # saved position of a file (default doc.tm) in the state file
  [ -f "$state" ] || { echo none; return; }
  timeout 180 "$tm" -x "(begin (with e (assoc \"${1:-$doc}\" (load-object \"$state\")) (display* \"OUT \" (if e (cddr e) \"none\") \"\\n\")) (quit-TeXmacs))" 2>&1 |
    sed -n 's/^OUT //p'
}

# scheme expression printing the saved position of doc.tm, read from disk
in_session_saved="(with e (and (url-exists? \"$state\") (assoc \"$doc\" (load-object \"$state\"))) (display* \"OUT \" (if e (cddr e) \"none\") \"\\n\"))"

reset_home() { # fresh home; the first start shows the welcome page, skip it
  rm -rf "$TEXMACS_HOME_PATH"; mkdir -p "$TEXMACS_HOME_PATH"
  if [ -n "$plugin" ]; then
    mkdir -p "$TEXMACS_HOME_PATH/plugins"
    ln -s "$plugin" "$TEXMACS_HOME_PATH/plugins/remember-cursor"
  fi
  run "(noop)" >/dev/null
}
cursor='(display* "OUT " (cursor-path) "\n")'
move='(go-down) (go-down) (go-down) (go-right) (go-right)'
# scripted edits do not mark the buffer as modified: pretend they did
modified='(buffer-pretend-modified (current-buffer))'

# 1. Moving the cursor alone writes nothing; saving the buffer records the
#    position, while TeXmacs is still running.
reset_home; make_doc "$doc" 50
check "nothing written on cursor movement" "none" \
  "$(run_wait "$move (delayed (:idle 4000) $in_session_saved)" "$doc")"
reset_home
check "position saved with the buffer" "(3 2)" \
  "$(run "$move $modified (save-buffer) $in_session_saved" "$doc")"

# 2. Opening the file from the command line restores it.
check "restored when opened from the command line" "(1 3 2)" \
  "$(run "$cursor" "$doc")"

# 3. Opening the file later (File > Open) restores it too.
check "restored when opened with load-buffer" "(1 3 2)" \
  "$(run "(load-buffer (system->url \"$doc\")) $cursor")"

# 4. Quitting right after a movement still saves the position (on-exit).
run "(go-down) (go-down)" "$doc" >/dev/null
check "position saved when quitting at once" "(5 2)" "$(saved)"

# 5. Switching to a buffer that is already open keeps its cursor.
make_doc "$other" 5
check "switching to an open buffer keeps its cursor" "(1 7 2)" \
  "$(run "(go-down) (go-down) (load-buffer (system->url \"$other\")) (load-buffer (system->url \"$doc\")) $cursor" "$doc")"

# 6. Scratch buffers are never recorded.
reset_home
run "(new-document) (go-down) (delayed (:idle 5000) (noop))" >/dev/null
check "scratch buffers are not recorded" "no state" \
  "$([ -s "$state" ] && cat "$state" || echo "no state")"

if [ -z "$plugin" ]; then
# 7-8. With the preference off, nothing is restored or recorded.
reset_home; make_doc "$doc" 50
run "$move (delayed (:idle 5000) (noop))" "$doc" >/dev/null
run '(set-preference "remember cursor position" "off")' >/dev/null
check "preference off: nothing restored" "(1 0 0)" "$(run "$cursor" "$doc")"
run "(go-down) (go-down) (go-down) (go-down) (go-down) (go-down)" "$doc" >/dev/null
check "preference off: nothing recorded" "(3 2)" "$(saved)"
run '(set-preference "remember cursor position" "on")' >/dev/null
fi

# 9. A paragraph shortened outside TeXmacs: end of what is left of it.
reset_home; make_doc "$doc" 50
run "$move" "$doc" >/dev/null
make_doc "$doc" 50 4
check "shortened paragraph: end of what is left" "(1 3 1)" \
  "$(run "$cursor" "$doc")"

# 10. A file truncated outside TeXmacs: start of the last paragraph, no error.
run "$move" "$doc" >/dev/null
make_doc "$doc" 2
check "truncated file: last remaining paragraph" "(1 1 0)" \
  "$(run "$cursor" "$doc")"

# 11. A corrupt state file is ignored.
printf '(("%s" oops' "$doc" >| "$state"
check "corrupt state file is ignored" "(1 0 0)" "$(run "$cursor" "$doc")"

# 12. Closing a buffer records its position.
reset_home; make_doc "$doc" 50; make_doc "$other" 5
check "position saved when the buffer is closed" "(3 2)" \
  "$(run "$move (load-buffer (system->url \"$other\")) (buffer-close (system->url \"$doc\")) $in_session_saved" "$doc")"

# 13. Auto-saving a buffer records its position.
reset_home; make_doc "$doc" 50
check "position saved with the auto-save file" "(3 2)" \
  "$(run "$move $modified (autosave-buffer (current-buffer)) $in_session_saved" "$doc")"
rm -f "$doc~"

# 14. Two instances at the same time keep each other's positions.
reset_home; make_doc "$doc" 50; make_doc "$other" 5
printf '(delayed (:idle %s) %s (delayed (:pause 15000) (quit-TeXmacs)))\n' \
  "$start_idle" "$move" >| "$work/script-a.scm"
timeout 180 "$tm" -x "(load \"$work/script-a.scm\")" "$doc" >/dev/null 2>&1 &
sleep 2
# (the second instance may show the welcome page: open the file explicitly)
run_wait "(load-buffer (system->url \"$other\")) (delayed (:idle 500) (go-down) (go-right))" >/dev/null
wait
check "two instances: first file kept" "(3 2)" "$(saved)"
check "two instances: second file kept" "(1 1)" "$(saved "$other")"

if [ -z "$plugin" ]; then
# 15. The regression tests of the patch.
check "regtest-cursor-memory" "ok" \
  "$(timeout 180 "$tm" -x '(begin (catch #t (lambda () (run-all-tests)) (lambda args #f)) (quit-TeXmacs))' 2>&1 |
     sed -n 's/^Test suite of cursor-memory: //p')"
fi

printf '\n%s\n' "$([ "$failures" = 0 ] && echo "All tests passed." || echo "$failures test(s) failed.")"
exit $((failures > 0))
