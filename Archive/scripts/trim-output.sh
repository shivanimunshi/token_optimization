# trim-output.sh — wrappers that cap the output of common verbose commands so
# the agent only ingests signal, not noise.
#
# Source this file:   source ./trim-output.sh
# Then use:           t_vitest backend
#                     t_tsc
#                     t_eslint ui/playbook-ui/src
#                     t_dockerlogs <container>
#                     t_gitdiff
#
# Each wrapper prints at most ~80 lines of the most relevant output.

set -u

# Generic capper: keep first 20 + last 60 lines.
_t_cap() {
  awk 'NR<=20 {print} NR>20 {buf[NR%60]=$0} END {
    if (NR>80) print "... (" NR-80 " lines trimmed) ...";
    start = (NR>60) ? NR-59 : 21;
    for (i=start; i<=NR; i++) print buf[i%60];
  }'
}

t_vitest() {
  # Run vitest scoped to a path or pattern; show fails + summary only.
  npx vitest run "$@" --reporter=basic 2>&1 \
    | grep -E '^(FAIL|PASS|Test Files|Tests|Errors|✗|×|  ❯)' \
    | head -n 80
}

t_tsc() {
  npx tsc --noEmit "$@" 2>&1 | head -n 80
}

t_eslint() {
  npx eslint "$@" --format=compact 2>&1 | head -n 80
}

t_dockerlogs() {
  docker logs --tail 80 "$@" 2>&1
}

t_gitdiff() {
  git --no-pager diff "$@" | _t_cap
}

t_gitlog() {
  git --no-pager log --oneline -n 30 "$@"
}

# Generic: run any command and cap.
t_run() {
  "$@" 2>&1 | _t_cap
}

echo "trim-output.sh loaded. Helpers: t_vitest t_tsc t_eslint t_dockerlogs t_gitdiff t_gitlog t_run"
