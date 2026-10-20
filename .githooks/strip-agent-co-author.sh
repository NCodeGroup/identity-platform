#!/usr/bin/env sh
#
# strip-agent-co-author.sh - strip agent co-author trailers from a commit message.
#
# Commits in this repository are attributed to the people who authored them.
# A `Co-authored-by: Copilot <...>` trailer makes the repository host count the
# agent account as a contributor, and a squash merge carries the branch's
# trailers onto main, where removing them means rewriting published history.
#
# See https://github.com/NCodeGroup/Identity/blob/main/docs/adr/0128-commits-are-attributed-to-people-not-agents.md
#
# Runs in pre-commit's commit-msg stage (.pre-commit-config.yaml); `pre-commit install`
# installs it. Don't set core.hooksPath: pre-commit refuses to install while it is set.
# The `env` shebang matters: on Windows, pre-commit finds `sh` on PATH only through
# `/usr/bin/env` and cannot run a literal `/bin/sh`.

set -eu

msg_file="$1"

# The agent identities that appear in co-author trailers: the `Copilot` user
# account and the `copilot-swe-agent[bot]` coding-agent account.
agent_trailer='^[[:space:]]*Co-authored-by:[[:space:]]*(Copilot|copilot-swe-agent)(\[bot\])?[[:space:]]*<'

if ! grep -qiE "$agent_trailer" "$msg_file"; then
    exit 0
fi

# `git stripspace` collapses the blank line the removed trailer leaves behind,
# matching git's own message cleanup. Comment lines are preserved so the editor
# flow still works; git strips those itself afterwards.
stripped="$msg_file.no-agent-trailer"
grep -ivE "$agent_trailer" "$msg_file" | git stripspace >"$stripped"
mv "$stripped" "$msg_file"

echo "strip-agent-co-author: removed a Co-authored-by trailer for an agent account." >&2
