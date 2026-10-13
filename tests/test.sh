#!/usr/bin/env bash
# Test cs with the shell running this script (bash or zsh).
# shellcheck disable=SC2317,SC2329 # helper functions are called through check()
# Run ./run_tests.sh to test with both shells.

cd "$(dirname "$0")" || exit 1
cs_file=$(cd ../etc && pwd)/cs

ret=0
check () {
  local desc="$1"
  shift
  if "$@";then
    echo "  ok: $desc"
  else
    echo "  NG: $desc"
    ret=$((ret + 1))
  fi
}

# Fake HOME with session files, fake claude/sentaku in PATH {{{
testdir=$(mktemp -d)
trap 'rm -rf "$testdir"' EXIT
export CS_TEST_DIR=$testdir
export HOME=$testdir
export PATH="$testdir/bin:$PATH"
mkdir -p "$testdir/bin" "$HOME/work/a" "$HOME/work/b" "$HOME/work/c" "$HOME/work/d" "$HOME/work/e" "$HOME/work/f" "$HOME/work/g h" "$HOME/work/h"
cat > "$testdir/bin/claude" <<'FAKE'
#!/bin/sh
pwd -P > "$CS_TEST_DIR/claude_pwd"
echo "$*" > "$CS_TEST_DIR/claude_args"
FAKE
cat > "$testdir/bin/sentaku" <<'FAKE'
#!/bin/sh
echo "$*" > "$CS_TEST_DIR/sentaku_args"
cat > "$CS_TEST_DIR/list"
sed -n "${PICK}p" "$CS_TEST_DIR/list"
FAKE
cat > "$testdir/bin/fzf" <<'FAKE'
#!/bin/sh
echo "$*" > "$CS_TEST_DIR/fzf_args"
cat > "$CS_TEST_DIR/list"
sed -n "${PICK}p" "$CS_TEST_DIR/list"
FAKE
chmod +x "$testdir/bin/claude" "$testdir/bin/sentaku" "$testdir/bin/fzf"

make_session () { # project id cwd entrypoint content mtime
  local f="$HOME/.claude/projects/$1/$2.jsonl"
  mkdir -p "$(dirname "$f")"
  printf '{"type":"queue-operation","sessionId":"%s"}\n' "$2" > "$f"
  printf '{"type":"user","cwd":"%s","sessionId":"%s","entrypoint":"%s","message":{"role":"user","content":%s}}\n' \
    "$3" "$2" "$4" "$5" >> "$f"
  printf '{"type":"assistant","sessionId":"%s","entrypoint":"%s","message":{"role":"assistant","content":[{"type":"text","text":"ok"}]}}\n' \
    "$2" "$4" >> "$f"
  touch -t "$6" "$f"
}
make_session -work-a aaaa-0001 "$HOME/work/a" cli '"first message a1"' 202601010100
make_session -work-b bbbb-0001 "$HOME/work/b" cli '"first message b1\nsecond line"' 202601010200
make_session -work-c cccc-0001 "$HOME/work/c" sdk-py '"sdk run c1"' 202601010300
make_session -work-a aaaa-0002 "$HOME/work/a" cli '[{"type":"text","text":"first message a2"}]' 202601010030
make_session -work-d dddd-0001 "$HOME/work/d" cli '"literal \\n and \\t in d1"' 202601010130
make_record () { # file type cwd id entrypoint content
  printf '{"type":"%s","cwd":"%s","sessionId":"%s","entrypoint":"%s","message":{"role":"%s","content":%s}}\n' \
    "$2" "$3" "$4" "$5" "$2" "$6" >> "$1"
}
mkdir -p "$HOME/.claude/projects/-work-f"
make_record "$HOME/.claude/projects/-work-f/ffff-0001.jsonl" user "$HOME/work/f" ffff-0001 sdk-py '"started by sdk f1"'
make_record "$HOME/.claude/projects/-work-f/ffff-0001.jsonl" assistant "$HOME/work/f" ffff-0001 sdk-py '[{"type":"text","text":"ok"}]'
make_record "$HOME/.claude/projects/-work-f/ffff-0001.jsonl" user "$HOME/work/f" ffff-0001 cli '"resumed f1"'
touch -t 202601010001 "$HOME/.claude/projects/-work-f/ffff-0001.jsonl"
make_session "-work-g h" gggg-0001 "$HOME/work/g h" cli '"space dir g1"' 202512312358
mkdir -p "$HOME/.claude/projects/-work-h"
printf '{"type":"queue-operation","sessionId":"hhhh-0001"}\n{"type":"system","cwd":"%s","sessionId":"hhhh-0001","entrypoint":"cli"}\n' \
  "$HOME/work/h" > "$HOME/.claude/projects/-work-h/hhhh-0001.jsonl"
touch -t 202512312359 "$HOME/.claude/projects/-work-h/hhhh-0001.jsonl"
# }}}

line_matches () { # line_number pattern
  if ! sed -n "${1}p" "$testdir/list" | grep -q -- "$2";then
    echo "    line $1 is: $(sed -n "${1}p" "$testdir/list")"
    return 1
  fi
}
not_in_list () {
  ! grep -q -- "$1" "$testdir/list"
}
cs_defined () {
  type cs >/dev/null 2>&1
}
abs () {
  (cd "$1" && pwd -P)
}
reset_result () {
  rm -f "$testdir/claude_args" "$testdir/claude_pwd" "$testdir/sentaku_args" "$testdir/fzf_args" "$testdir/list"
}

echo "Source etc/cs"
# shellcheck disable=SC1090
source "$cs_file"
check "cs is defined" cs_defined

echo "Options -v and -h"
reset_result
version_line=$(cs -v)
check "-v prints name, version and date" grep -Eq '^cs v[0-9]+\.[0-9]+\.[0-9]+ [0-9]{2}/[A-Z][a-z]{2}/[0-9]{4}$' <<< "$version_line"
check "--version prints the same" [ "$(cs --version)" = "$version_line" ]
check "-h prints the usage" grep -q '^Usage: cs' <<< "$(cs -h)"
cs --no-such-option > /dev/null 2>&1
check "an unknown option returns 1" [ "$?" -eq 1 ]
check "options do not call claude" [ ! -e "$testdir/claude_args" ]

echo "List and select with sentaku"
reset_result
export PICK=2
cs
check "sentaku is called with -s line" [ "$(cat "$testdir/sentaku_args")" = "-s line" ]
check "7 sessions are listed (sdk-py session is excluded)" [ "$(wc -l < "$testdir/list" | tr -d ' ')" -eq 7 ]
check "sdk-py session is not listed" not_in_list "sdk run"
check "line 1 is the newest session with its mtime" line_matches 1 '^01-01 02:00 .*work/b .*first message b1 second line'
check "line 2 keeps literal backslashes in one row" line_matches 2 '^01-01 01:30 .*work/d .*literal \\n and \\t in d1 *$'
check "line 3 is the next session" line_matches 3 '^01-01 01:00 .*work/a .*first message a1'
check "line 4 is the oldest session (array content)" line_matches 4 '^01-01 00:30 .*work/a .*first message a2'
check "line 5 is the session resumed from the terminal, with its first message" line_matches 5 '^01-01 00:01 .*work/f .*started by sdk f1'
check "line 6 is a session without a user record (empty message)" line_matches 6 '^12-31 23:59 .*work/h *$'
check "line 7 is a session in a directory with a space" line_matches 7 '^12-31 23:58 .*work/g h *space dir g1'
check "the selected line is resumed" [ "$(cat "$testdir/claude_args")" = "--resume dddd-0001" ]
check "claude runs in the session directory" [ "$(cat "$testdir/claude_pwd")" = "$(abs "$HOME/work/d")" ]
check "the current shell moves to the session directory" [ "$(pwd -P)" = "$(abs "$HOME/work/d")" ]
cd "$testdir" || exit 1

echo "Select a session without a user record"
reset_result
export PICK=6
cs
check "the selected line is resumed" [ "$(cat "$testdir/claude_args")" = "--resume hhhh-0001" ]
check "claude runs in the session directory" [ "$(cat "$testdir/claude_pwd")" = "$(abs "$HOME/work/h")" ]
cd "$testdir" || exit 1

echo "Select a session in a directory with a space"
reset_result
export PICK=7
cs
check "the selected line is resumed" [ "$(cat "$testdir/claude_args")" = "--resume gggg-0001" ]
check "claude runs in the session directory" [ "$(cat "$testdir/claude_pwd")" = "$(abs "$HOME/work/g h")" ]
cd "$testdir" || exit 1

echo "Invalid CS_MAX_SESSIONS"
reset_result
CS_MAX_SESSIONS=abc cs 2> "$testdir/err"
rc=$?
check "returns 1" [ "$rc" -eq 1 ]
check "prints a message" grep -q "CS_MAX_SESSIONS must be a number" "$testdir/err"
check "claude is not called" [ ! -e "$testdir/claude_args" ]

echo "Options"
reset_result
export PICK=1
CS_MAX_SESSIONS=2 cs
check "CS_MAX_SESSIONS limits the list" [ "$(wc -l < "$testdir/list" | tr -d ' ')" -eq 2 ]
reset_result
CS_MESSAGE_MAX_LENGTH=5 cs
check "CS_MESSAGE_MAX_LENGTH cuts the message" line_matches 1 'work/b *first$'
check "CS_CWD_MAX_LENGTH cuts the directory" line_matches 1 ' \.\.\..*work/b '
reset_result
CS_CWD_MAX_LENGTH=1000 cs
check "a short enough directory is not cut" line_matches 1 " $HOME/work/b "
cd "$testdir" || exit 1

echo "Other selection tool (no options)"
reset_result
export PICK=1
SELECTION_TOOL=fzf cs
check "fzf is called without options" [ -e "$testdir/fzf_args" ] && [ -z "$(cat "$testdir/fzf_args")" ]
check "the selected line is resumed" [ "$(cat "$testdir/claude_args")" = "--resume bbbb-0001" ]
cd "$testdir" || exit 1

echo "Empty selection"
reset_result
export PICK=99
cs
rc=$?
check "returns 0" [ "$rc" -eq 0 ]
check "claude is not called" [ ! -e "$testdir/claude_args" ]

echo "No matching session"
reset_result
CS_ENTRYPOINT=nope cs 2> "$testdir/err"
rc=$?
check "returns 1" [ "$rc" -eq 1 ]
check "prints a message" grep -q "No claude session found" "$testdir/err"
check "claude is not called" [ ! -e "$testdir/claude_args" ]

echo "Shell select fallback"
reset_result
SELECTION_TOOL=no-such-tool cs <<< "3" > /dev/null 2>&1
check "the selected line is resumed" [ "$(cat "$testdir/claude_args")" = "--resume aaaa-0001" ]
cd "$testdir" || exit 1

echo "nounset (set -u)"
reset_result
export PICK=1
# shellcheck disable=SC1090
(set -u; source "$cs_file" && cs) > "$testdir/nounset.out" 2>&1
rc=$?
check "source and cs work with set -u" [ "$rc" -eq 0 ]
check "the selected line is resumed" [ "$(cat "$testdir/claude_args" 2>/dev/null)" = "--resume bbbb-0001" ]
if [ "$rc" -ne 0 ];then
  sed 's/^/    /' "$testdir/nounset.out"
fi
reset_result
export PICK=2
# shellcheck disable=SC1090
(set -u; source "$cs_file" && SELECTION_TOOL=fzf cs) > "$testdir/nounset.out" 2>&1
rc=$?
check "a tool without options works with set -u" [ "$rc" -eq 0 ]
check "the selected line is resumed" [ "$(cat "$testdir/claude_args" 2>/dev/null)" = "--resume dddd-0001" ]
if [ "$rc" -ne 0 ];then
  sed 's/^/    /' "$testdir/nounset.out"
fi

echo "Multibyte message"
utf8_locale=$(locale -a 2>/dev/null | grep -i -m1 -E '^(C|en_US)\.(UTF-8|utf8)$')
if [ -n "$utf8_locale" ];then
  make_session -work-e eeee-0001 "$HOME/work/e" cli '"日本語のメッセージです"' 202601010010
  make_session -work-e eeee-0002 "$HOME/work/e" cli '"あいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこ"' 202601010005
  reset_result
  export PICK=1
  old_lc_all=${LC_ALL:-}
  export LC_ALL=$utf8_locale
  CS_MESSAGE_MAX_LENGTH=5 cs
  check "the message is cut by characters, not bytes" line_matches 5 'work/e *日本語のメ *$'
  check "a long message is cut at a character boundary" line_matches 6 'work/e *あいうえお *$'
  reset_result
  CS_MESSAGE_MAX_LENGTH=30 cs
  check "30 characters of a long message" line_matches 6 'work/e *あいうえおかきくけこあいうえおかきくけこあいうえおかきくけこ *$'
  check "the selected line is resumed" [ "$(cat "$testdir/claude_args")" = "--resume bbbb-0001" ]
  if [ -n "$old_lc_all" ];then
    export LC_ALL=$old_lc_all
  else
    unset LC_ALL
  fi
  cd "$testdir" || exit 1
else
  echo "  skipped: no UTF-8 locale (C.UTF-8 or en_US.UTF-8) is available"
fi

if [ -n "${ZSH_VERSION:-}" ];then
  echo "zsh with ksharrays"
  setopt ksharrays
  reset_result
  export PICK=4
  cs
  check "the selected line is resumed" [ "$(cat "$testdir/claude_args")" = "--resume aaaa-0002" ]
  unsetopt ksharrays
  cd "$testdir" || exit 1
fi

if [ "$ret" -eq 0 ];then
  echo "All tests passed"
else
  echo "$ret test(s) failed"
fi
exit "$ret"
