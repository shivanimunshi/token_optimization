---
name: token-optimization
description: 'Aggressively minimize token usage (target 80-90% reduction) for AI Playbook development. USE WHEN: planning a new feature or refactor, before exploring the codebase, when reading large files, when tests/builds produce huge logs, when context window pressure is felt, when reviewing how an agent should fetch code/docs, or when the user mentions "tokens", "context", "cost", "slow", "optimize prompts", "cheaper", or "trim context". Provides routing rules (grep/file_search/explore_subagent over semantic_search and full reads), scoped-read patterns, log/output trimming scripts, and an auditable checklist. DO NOT USE FOR: runtime perf optimization, bundle-size reduction, or LLM model-routing inside the product itself (see specs/LLM_*). '
---

# Token Optimization Skill (AI Playbook)

Target: **80–90% fewer tokens** spent per task vs. naive exploration, without losing correctness.

## Model Selection (Highest-Impact Rule)

**Use the right model to halve costs before any other optimization.**

| Model | When |
|---|---|
| **Opus** | Learning a new codebase, deep architecture analysis, complex debugging that Sonnet can't solve |
| **Sonnet** (default) | Writing code, editing, fixing bugs, tests, documentation, deployment, general questions |

**Typical session pattern:** Start with Opus for 10–15 min to understand the codebase (one-time cost), then switch to Sonnet for all implementation. **Saves ~50% vs. all-Opus.**

---

## When To Use
- For every task in the AI Playbook, but especially: edit tasks, code reviews, debugging sessions
- Starting any non-trivial task (feature, bug, refactor, review).
- About to call `semantic_search`, read a whole file, or run a verbose script.
- A tool returned a huge blob (logs, test output, JSON dumps).
- User explicitly asks to reduce cost / context / latency.

## Core Rules (memorize these)

1. **Search before reading.** Use [grep_search](#) (exact/regex) and [file_search](#) (glob) first. Only `read_file` after you know the line ranges you need.
2. **Prefer `explore_subagent`** over chained `semantic_search` calls — it returns a curated digest instead of dumping snippets into your context.
3. **Read in ranges, not whole files.** Default to ≤200 lines; expand only if the symbol straddles the window.
4. **Parallelize independent reads** in a single tool block; never re-search for something already returned.
5. **Trim tool output at the source.** Use `--quiet`/`-q`/`--silent` flags by default. Pipe through `head`, `tail`, `grep`, `awk`, `wc -l`, `--no-pager`, or `| cat` before output hits context.
6. **Use memory, not re-discovery.** Persist verified facts to `/memories/repo/` (see [agent instructions](../../copilot-instructions.md)) so the next turn starts informed.
7. **Stop when you can act.** Once you have file path + symbol + 1 usage site, implement — do not "complete" the map.

## Procedure (apply per task)

1. **Plan** the smallest surface (see §8 of `copilot-instructions.md`). Write the target file(s) you expect to touch.
2. **Triage** with `grep_search` / `file_search` in parallel. Refer to [tool-routing](./references/tool-routing.md).
3. **Targeted reads** using line ranges. See [scoped-reads](./references/strategies.md#scoped-reads).
4. **Edit** with `multi_replace_string_in_file` for batched changes (one tool call vs. N).
5. **Verify** with the narrowest possible test command. See [trim-output](./scripts/trim-output.sh).
6. **Record** reusable facts (paths, conventions, gotchas) in repo memory.

## Quick Wins (highest ROI)

| Habit | Saves |
|---|---|
| Opus → Sonnet model switch | ~50% subscription cost |
| `grep_search` instead of `semantic_search` for known terms | 60–80% on discovery |
| Line-ranged `read_file` instead of full file | 70–95% per read |
| `explore_subagent` for "where is X handled?" | 50–80% on multi-hop search |
| `head -n 50` / `tail -n 50` on logs and test output | 80–99% on verbose output |
| `cp`/`sed`/`cat` bash commands instead of Read+Edit for data files | 90–99% on pure transforms |
| Single `multi_replace_string_in_file` over N edits | N× round-trip tokens |
| Cached `/memories/repo/` notes | 100% on repeated discovery |
| Write analysis script instead of feeding file to AI | 90–99% on large-file analysis |
| CLI tools (jq, grep, awk) emit only needed output (no static tokens) | 70–95% on structured data reads |
| Pipe long shell output through `rtk` or `head`/`tail` | 80–99% on verbose build/test output |
| CodeAct: collapse 3+ sequential tool calls into one code-execution block | 60–80% on multi-step discovery |

## Bash vs. Read+Edit Decision Tree

**Before any file operation, ask in order:**
1. **Creating new file?** → Write tool directly.
2. **Read-only inspection** (JSON, logs, YAML)? → `jq`, `grep`, `python3 -c`, `awk` — bash output is filterable.
3. **Modifying a code file** (`.ts`, `.js`, `.tsx`, `.py`, `.cjs`)? → Read + Edit **always** — user sees a reviewable diff.
4. **Modifying a small file** (<100 lines)? → Read + Edit is fine.
5. **Modifying critical/large data file**? → `sed`/`awk`/`python3` bash commands (99%+ savings).
6. **Copying or merging files**? → `cp`/`cat file1 file2 > combined` — never Read+Write.
7. **Counting / checking existence**? → `wc -l file` / `grep -q "term" file`.

**Quick rule:** if the user would want to see and approve the change → Read+Edit. Pure data wrangling or inspection → bash/python.

| Operation | Wasteful | Efficient |
|---|---|---|
| Copy file | Read + Write | `cp source dest` |
| Replace text in data file | Read + Edit | `sed -i '' 's/old/new/g' file` |
| Append line | Read + Write | `echo "text" >> file` |
| Merge files | Read + Read + Write | `cat file1 file2 > combined` |
| Count lines | Read file | `wc -l file` |
| Check content | Read file | `grep -q "term" file && echo yes` |
| Inspect JSON field | Read + parse mentally | `jq '.field' file` or `python3 -c "import json; ..."` |
| Analyze large file for specific data | Read entire file into AI context | Write a 5-line script (`python3`/`jq`/`awk`) that extracts only the answer |

**Script-Analyze Pattern:** When you need a specific fact from a file >200 lines, write and run a targeted script rather than reading the file into context. The script result is typically 1–10 lines; the file could be thousands.

```bash
# Example: find all routes that return 4xx — script, not read
grep -n 'res\.status(4' backend/src/routes/apiRoutes.js | head -20

# Example: count projects in JSON store
jq '.projects | length' backend/data/projects.json
```

## Override Conditions (when to break efficiency rules)

1. **User explicitly requests full output** ("Show me the entire file / full log").
2. **Filtered output lacks necessary context** (e.g., error references missing line numbers).
3. **File is known to be small** (<200 lines) — reading it whole is fine.
4. **Learning a new codebase** — read 2–5 key files fully to establish understanding, then return to efficient mode.

## Cost Impact Reference

| Approach | Approx. tokens/week | Driver |
|---|---|---|
| Wasteful (read/edit/write everything) | ~500K | Reading files unnecessarily |
| Moderate (filtered reads only) | ~200K | grep/head/tail usage |
| **Efficient (bash + filters + model selection)** | **30–50K** | cp/sed/awk + Sonnet default |

Applying all rules: **90–95% reduction on average.**

## Advanced Techniques

### a) Analysis Scripts Over Feeding Files to AI

When a large file contains the answer to a narrow question, **write a small script** to extract it instead of reading the file into context. The AI receives only the output (1–20 lines) rather than the file's full content (hundreds of tokens).

- Use `python3 -c`, `jq`, `grep`, `awk`, `sed` for quick one-liners.
- Use `run_in_terminal` to execute the script and capture only its output.
- Applies especially to: JSON data stores, log files, large config files, dependency trees.

### b) CLI Tools Reduce Static Token Cost

Every byte of a file read into AI context costs tokens, even if most of the file is irrelevant (**static tokens**). CLI tools emit only the relevant output (**dynamic tokens**).

| Scenario | AI read (static) | CLI tool (dynamic) |
|---|---|---|
| Find a function signature | Read 500-line file | `grep -n 'function myFn' file` → 1 line |
| Get a JSON field value | Read entire JSON | `jq '.field'` → 1 line |
| Check if a key exists | Read file, search mentally | `grep -q 'key' file && echo yes` → 1 line |
| Count test failures | Read full test output | `grep -c 'FAIL'` → 1 number |

**Rule:** prefer CLI tools whenever the question has a structured, extractable answer.

### c) Shell Output Compression with `rtk`

Long shell outputs (npm install, docker build, vitest, tsc) can dump thousands of lines into context. Use **[rtk](https://github.com/rtk-ai/rtk)** to intelligently compress terminal output while preserving errors and key signals:

```bash
# Install once
npm install -g @rtk-ai/rtk

# Usage — pipe any verbose command through rtk
npm test 2>&1 | rtk
docker build . 2>&1 | rtk
npx tsc --noEmit 2>&1 | rtk

# Stack with tail for extreme cases
npm install 2>&1 | rtk | tail -n 30
```

`rtk` uses AI-assisted summarization to reduce output to the actionable lines. Fall back to `grep -E 'error|FAIL|✗' | head -n 50` when `rtk` is not installed.

### d) Collapsing Tool Calls with CodeAct

Each tool call incurs round-trip overhead (request + response tokens). The **[copilot-codeact-plugin](https://github.com/jsturtevant/copilot-codeact-plugin)** lets you write JavaScript/Python that executes in a single call, replacing N sequential tool calls.

**Apply when 3+ tool calls can be replaced by one code block:**

```javascript
// Instead of: grep_search → read_file → grep_search → read_file → ...
// One CodeAct block:
const fs = require('fs');
const files = ['backend/src/routes/apiRoutes.js', 'backend/src/services/projectService.js'];
files.forEach(f => {
  const lines = fs.readFileSync(f, 'utf8').split('\n');
  lines.forEach((l, i) => { if (l.includes('asyncHandler')) console.log(`${f}:${i+1}: ${l.trim()}`); });
});
```

**Decision rule:** if the plan already shows ≥3 sequential dependent reads or greps in the same directory, consolidate into one CodeAct script. For 1–2 tool calls, standard tools are simpler.

## Skills Loading Note

**Myth:** having many skills increases token usage. **Reality:** skills use progressive disclosure — Claude sees only descriptions at session start (~155 tokens for 4 skills). Full skill body loads only when activated. It is safe to have many skills symlinked.

## References
- [Strategies & patterns](./references/strategies.md) — scoped reads, batching, summarization.
- [Tool routing matrix](./references/tool-routing.md) — when to use which tool.
- [Anti-patterns](./references/anti-patterns.md) — what burns tokens silently.

## Scripts
- [audit-context.sh](./scripts/audit-context.sh) — list largest source files (candidates to never read whole).
- [trim-output.sh](./scripts/trim-output.sh) — wrappers that cap stdout from `npm test`, `vitest`, `tsc`, `eslint`, `docker logs`.
- [count-tokens.sh](./scripts/count-tokens.sh) — rough token estimate (`wc -w * 1.3`) for any file or piped input.

## Checklist (paste into plan)

- [ ] Identified target files via `grep_search`/`file_search` (no blind `semantic_search`).
- [ ] Read only the line ranges I need.
- [ ] Batched edits via `multi_replace_string_in_file`.
- [ ] Trimmed every terminal command's output.
- [ ] Recorded reusable findings in `/memories/repo/`.
- [ ] Skipped exploration that does not change the diff.
- [ ] Used analysis script or CLI tool instead of reading large files into AI context.
- [ ] Piped verbose shell output through `rtk` (or `grep`/`head`/`tail` fallback).
- [ ] Collapsed 3+ sequential tool calls into one CodeAct block where applicable.
