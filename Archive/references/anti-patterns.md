# Anti-Patterns (Token Burners)

These habits silently inflate context. Treat each as a red flag.

## Discovery
- ❌ Calling `semantic_search` first "just to see the codebase".
- ❌ Re-running a search with slightly different wording instead of refining the first results.
- ❌ Running `grep_search` without `includePattern` across the whole monorepo.
- ❌ Loading `specs/` or `Project specs/` when the task is code-only.

## Reading
- ❌ `read_file` with no `startLine`/`endLine` on files >300 lines.
- ❌ Reading both source and test when only one is needed.
- ❌ Reading config files (`package.json`, `tsconfig.json`) every task — cache in memory.
- ❌ Feeding a large JSON/log/config file to AI to answer a narrow question — write a 1-line script instead.
- ❌ Using `semantic_search` or `read_file` when a `grep`/`jq`/`awk` CLI call would give the same answer as a 1-line output.

## Editing
- ❌ Multiple sequential `replace_string_in_file` when `multi_replace_string_in_file` would batch them.
- ❌ Inflated `oldString` blocks (>10 lines of context).
- ❌ Editing via terminal `sed` — bypasses diff review and costs the same tokens.

## Terminal
- ❌ `npm test` (whole suite) when one file is in play.
- ❌ Running `git log`, `git diff` without `--no-pager` or `| head`.
- ❌ Piping `docker logs` raw — always `--tail 100`.
- ❌ Printing large JSON; pipe through `jq '.field'` or `head -c 2000`.
- ❌ Letting verbose build/test output land in context unfiltered — pipe through `rtk` or `grep -E 'error|FAIL' | head -n 50`.
- ❌ Running 3+ sequential grep/read calls on the same module when a single CodeAct script would collapse them.

## Output / Reply
- ❌ Echoing files back to the user in the reply.
- ❌ Long preambles ("I will now...", "Here is what I found...").
- ❌ Restating the diff after the edit tool already showed it.

## Memory
- ❌ Not writing `/memories/repo/` notes after a hard-won discovery.
- ❌ Writing prose memories instead of one-line facts.
- ❌ Letting outdated memory entries linger — update or delete.

## Subagents
- ❌ Asking a subagent to "explore and tell me everything" — give it a single specific question.
- ❌ Spawning a subagent for a 30-line file you could read directly.
