# cs

Start [Claude Code](https://github.com/anthropics/claude-code) with session selection.

`cs` lists your recent Claude Code sessions (date, directory and the first message),
lets you pick one with a selection tool,
moves to the directory of the session and runs `claude --resume <session id>`.

It works on Bash and Zsh, on Linux (GNU tools) and macOS (BSD tools).

```
$ cs
03-14 10:22  .../work/project/app  fix the login redirect bug
03-14 09:05  /home/user/notes      [notes] summarize this meeting
03-13 18:40  /home/user/src/lib    add tests for the parser
03-12 17:15  !/home/user/src/tmp   try the new tokenizer
```

## Requirements

- [claude](https://github.com/anthropics/claude-code) (Claude Code CLI)
- A selection tool (optional, see [Selection tool](#selection-tool))

Only standard commands (`find`, `stat`, `grep`, `awk`, `column` etc.) are used otherwise,
with both GNU and BSD versions supported.

## Installation

### Homebrew

```
$ brew install rcmdnk/rcmdnkpac/cs
```

or tap [rcmdnk/rcmdnkpac](https://github.com/rcmdnk/homebrew-rcmdnkpac) first:

```
$ brew tap rcmdnk/rcmdnkpac
$ brew install cs
```

Recent Homebrew loads formulae from a third-party tap only after you trust it.
If `brew` refuses to load the formula, run:

```
$ brew trust rcmdnk/rcmdnkpac
```

With [brew-file](https://github.com/rcmdnk/homebrew-file), add to your Brewfile:

```
tap 'rcmdnk/rcmdnkpac'
brew 'cs'
```

This installs `cs` to `$(brew --prefix)/etc/cs`
(for example `/opt/homebrew/etc/cs`) and [sentaku](https://github.com/rcmdnk/sentaku) as the selection tool.

### Download

Get `etc/cs` and put it where you like:

```
$ curl -fsSL https://raw.githubusercontent.com/rcmdnk/cs/main/etc/cs -o /path/to/cs
```

or clone the repository:

```
$ git clone https://github.com/rcmdnk/cs.git
```

### Set up

Source it in your `.bashrc` or `.zshrc`:

```bash
source /path/to/cs
```

With Homebrew:

```bash
source "$(brew --prefix)/etc/cs"
```

`cs` must be sourced, not executed, because it changes the directory of the current shell.

## Usage

```
$ cs
```

`cs -h` shows the help and `cs -v` shows the version.

Sessions are read from `~/.claude/projects/*/*.jsonl`
(`$CLAUDE_CONFIG_DIR/projects/*/*.jsonl` when `CLAUDE_CONFIG_DIR` is set) and listed newest first
by the modification time of the session file.
The message is the first prompt of the session;
records of slash commands, system reminders and other injected context are skipped.
A session named with `/rename` shows the name as `[name]` before the message.
A directory that no longer exists is marked with `!`;
such a session is resumed in the current directory.
Select a line, then `cs` moves to the directory of the session
and runs `claude --resume` with its session id.

Only sessions started from the terminal (records with `"entrypoint":"cli"`) are listed.
Sessions started through the Claude Agent SDK (`sdk-py` etc.),
such as subagents or automated reviews, are skipped.
Set `CS_ENTRYPOINT` to list other sessions.

If two sessions produce the same line (same minute, directory and first message),
the newer one is used.

## Selection tool

The selection tool must accept a list from the pipe, let you select a line and print it.

The following tools are searched in this order and the first one found is used:

- [rcmdnk/sentaku](https://github.com/rcmdnk/sentaku) (used with `-s line`)
- [peco/peco](https://github.com/peco/peco)
- [jhawthorn/fzy](https://github.com/jhawthorn/fzy)
- [junegunn/fzf](https://github.com/junegunn/fzf)

You can set the tools with `SELECTION_TOOL` (comma separated) before sourcing `cs`:

```bash
SELECTION_TOOL=fzf,peco
```

If none of the tools is available, the `select` builtin of the shell is used.

## Options

Set them before sourcing `cs` in `.bashrc` or `.zshrc`:

```bash
# Selection tool
SELECTION_TOOL=${SELECTION_TOOL:-sentaku,peco,fzy,fzf}

# Number of sessions to list
CS_MAX_SESSIONS=${CS_MAX_SESSIONS:-20}

# Directory names longer than this are shown as "...<last CS_CWD_MAX_LENGTH-3 characters>"
# (the ! mark of a missing directory is included in the length)
CS_CWD_MAX_LENGTH=${CS_CWD_MAX_LENGTH:-20}

# The first message and the session name are cut to this length
CS_MESSAGE_MAX_LENGTH=${CS_MESSAGE_MAX_LENGTH:-30}

# Only sessions whose records have this entrypoint are listed
CS_ENTRYPOINT=${CS_ENTRYPOINT:-cli}
```

## Test

```
$ ./tests/run_tests.sh
```

The tests run `cs` with Bash and Zsh against fake session files,
a fake `claude` and a fake `sentaku`, so nothing in `~/.claude` is touched.

## License

[Apache License 2.0](LICENSE)
