# Tool Routing Matrix

Pick the **cheapest** tool that answers the question. Climb the ladder only when the cheaper tool fails.

| Goal | Use | Avoid |
|------|-----|-------|
| Find files by name/pattern | `file_search` (`**/*.test.ts`) | `semantic_search` |
| Find exact string / regex | `grep_search` (`isRegexp: true`) | `semantic_search`, full reads |
| Read known lines | `read_file` with `startLine`/`endLine` | Whole-file reads |
| "How does feature X work?" | `explore_subagent` | Manual multi-`semantic_search` |
| Heavy multi-file refactor scoping | `runSubagent` (research only) | Doing it in main thread |
| Symbol references / rename | `vscode_listCodeUsages`, `vscode_renameSymbol` | grep + manual edits |
| Multiple edits | `multi_replace_string_in_file` | N× `replace_string_in_file` |
| Validate after edit | `get_errors` on the changed file | Full `tsc` / lint run |
| Project-wide errors | `get_errors` (no args) | Running build |
| Run a test | `npx vitest run <file> -t "<name>"` piped to `tail` | `npm test` (whole suite) |

## AI Playbook specifics

- Backend code: start at `backend/src/app.js` for wiring, `backend/src/routes/apiRoutes.js` for endpoints, `backend/src/services/` for logic, `backend/src/repositories/` for persistence.
- Frontend API surface: `ui/playbook-ui/src/app/services/` — never grep for `fetch(` across the whole UI tree; constrain with `includePattern: "ui/playbook-ui/src/app/services/**"`.
- Tests live next to code in `__tests__/` folders — search there before reading source.
- Specs live in `Project specs/` and `specs/`. They are documentation; **do not** load them unless the task is doc-related.

## `includePattern` is your friend

Always scope `grep_search` to the smallest plausible subtree:
- Routes: `backend/src/routes/**`
- Services: `backend/src/services/**`
- UI pages: `ui/playbook-ui/src/app/pages/**`
- UI services: `ui/playbook-ui/src/app/services/**`

An unscoped grep across the repo can return 10× more matches than needed.
