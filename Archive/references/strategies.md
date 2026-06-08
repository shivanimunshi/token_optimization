# Token-Saving Strategies

## Scoped Reads
- Find the symbol first: `grep_search` with a regex like `function\s+createApp|class\s+ProjectService`.
- Then `read_file` with `startLine`/`endLine` covering ~20 lines of context around the hit.
- For multi-symbol edits, collect all hit line numbers, then issue **one parallel batch** of ranged reads.

## Batched Edits
- Use `multi_replace_string_in_file` when ≥2 edits land in the same or sibling files. Each individual `replace_string_in_file` re-uploads context.
- Keep each `oldString` minimal but uniquely anchored (3 lines context, no more).

## Subagent Offloading
- For "trace this flow end-to-end" or "find every place X is called", invoke `explore_subagent`. The subagent burns its own context and returns a summary (typically 1–5% of what your main thread would consume crawling).
- Use `runSubagent` for any heavy multi-file refactor scoping — same principle.

## Output Trimming
- Terminal: `cmd 2>&1 | tail -n 80` for failures; `| grep -E 'FAIL|Error|✗'` for test runs.
- Git: always `git --no-pager <cmd>`.
- Vitest: `npx vitest run path/to/file -t "specific test"` instead of full suite.
- Node logs: pipe to `head -c 4096` to cap by bytes.

## Search Layering (cheapest → most expensive)
1. `file_search` (paths only).
2. `grep_search` (lines that match).
3. `read_file` with range.
4. `explore_subagent` (delegated, summarized).
5. `semantic_search` (last resort — returns large blobs).
6. Full-file `read_file` (avoid).

## Memory As Cache
- After confirming a non-obvious fact (e.g., "repository factory is at `backend/src/repositories/projectRepositoryFactory.js` and switches on `STORAGE_MODE`"), write a one-liner to `/memories/repo/`.
- On the next task, you start with the answer already in context (200 lines auto-loaded).

## Summarize, Don't Echo
- Never paste back a file the user can already see. Reference it with a link + line numbers.
- For long tool output, extract the 1–3 lines that matter and discard the rest from the reply.

## Script-Analyze Pattern (avoids static tokens)
When you need a specific fact from a large file, write a targeted script instead of reading the file:
```bash
# Fact: which services call mongoClient directly?
grep -rn 'mongoClient\.' backend/src/services/ | grep -v '__tests__'

# Fact: how many in-memory projects are stored?
jq '.projects | length' backend/data/projects.json

# Fact: all exported function names in a module
grep -n '^\(async \)\?function \|^const .* = \(async \)\?' backend/src/services/projectService.js | head -20
```
The script emits 1–20 lines; reading the file would emit hundreds of tokens of unneeded code.

## CLI Tools vs. AI Reads (static vs. dynamic tokens)
- **Static tokens**: every byte of a file read into context, even if irrelevant.
- **Dynamic tokens**: only what a CLI tool emits — the filtered answer.
- Prefer CLI tools when the question has a structured, extractable answer (key lookup, pattern match, count).
- Use `jq` for JSON, `grep` for patterns, `awk`/`python3 -c` for transforms, `wc -l` for counts.

## Shell Output Compression (rtk)
- Install: `npm install -g @rtk-ai/rtk`
- Usage: `cmd 2>&1 | rtk` — intelligently summarizes verbose output, preserving errors.
- Fallback (no rtk): `cmd 2>&1 | grep -E 'error|FAIL|✗|warning' | head -n 50`
- Reference: https://github.com/rtk-ai/rtk

## Collapsing Tool Calls (CodeAct)
- Reference: https://github.com/jsturtevant/copilot-codeact-plugin
- Write one JavaScript/Python code block that performs N reads/greps in a single execution.
- Apply when ≥3 sequential dependent tool calls share the same directory/module scope.
- Each eliminated tool call saves ~1 round-trip overhead of request + response tokens.
