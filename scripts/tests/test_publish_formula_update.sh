#!/usr/bin/env bash
# Witnesses for publish_formula_update.sh (Atlas r1 v6+v7, Sentinel r2 v7):
#   happy pair: new bytes → PR, red names it; same bytes → same PR, content verified, no push
#   seam injections at push / dispatch / watch / create: the old candidate is RETAINED and named
#   recovery: a remote branch with no PR is verified by CONTENT then reused without a second push
#   recovery-mismatch edge: same-name branch with WRONG bytes is refused loudly, nothing published
#   reuse-mismatch edge: an open PR whose branch carries wrong bytes is refused, PR not closed
#   close-failure + convergence pair: replacement created, stale close fails → red names BOTH;
#     rerun with same bytes retries retirement and converges to one
#   fail closed: candidate enumeration failure stops the run before any publication
# `gh` and `git` are fakes; recorded state is the "GitHub" under test. Pushes record the
# Formula CONTENT under state/remote/<branch>/ so content verification is a real check.
# Env flags FAIL_LIST/FAIL_PUSH/FAIL_DISPATCH/FAIL_WATCH/FAIL_CREATE/FAIL_CLOSE inject one failure each.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../publish_formula_update.sh"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
mkdir -p "$work/repo/Formula" "$work/bin" "$work/state/remote"
cd "$work/repo"; git init -q -b main; git config user.email t@t; git config user.name t
printf 'class Gitgrip < Formula\n  url "v1"\nend\n' > Formula/gitgrip.rb
git add . && git commit -qm base
: > "$work/state/open.tsv"; : > "$work/state/remote-branches"; echo 0 > "$work/state/counter"; : > "$work/state/log"
cat > "$work/bin/gh" <<'FAKE'
#!/usr/bin/env bash
S="$STATE"; all="$*"; echo "gh $all" >> "$S/log"
case "$1 $2" in
  "pr list")
    [ "${FAIL_LIST:-}" = 1 ] && exit 1
    lim=30; case "$all" in *"--limit "*) lim="${all#*--limit }"; lim="${lim%% *}" ;; esac
    awk -F'\t' 'NF{print $1"\t"$2"\t"$3}' "$S/open.tsv" | head -n "$lim" ;;
  "pr close")
    [ "${FAIL_CLOSE:-}" = 1 ] && exit 1
    n="$3"; h="$(awk -F'\t' -v n="$n" '$1==n{print $2}' "$S/open.tsv")"
    grep -v "^$n	" "$S/open.tsv" > "$S/open.tmp" || true; mv "$S/open.tmp" "$S/open.tsv"
    [ "${FAIL_DELETE:-}" = 1 ] && exit 1   # PR is closed; branch deletion failed
    [[ "$all" == *"--delete-branch"* ]] && { grep -vx "$h" "$S/remote-branches" > "$S/rb.tmp" || true; mv "$S/rb.tmp" "$S/remote-branches"; } ;;
  "pr view") [ "${FAIL_VIEW:-}" = 1 ] && exit 1
    n="$3"; grep -q "^$n	" "$S/open.tsv" && echo OPEN || echo CLOSED ;;
  "pr create")
    [ "${FAIL_CREATE:-}" = 1 ] && exit 1
    head="${all#*--head }"; head="${head%% *}"; n=$(( $(cat "$S/counter") + 1 )); echo "$n" > "$S/counter"
    url="https://example.test/pull/$n"; printf '%s\t%s\t%s\n' "$n" "$head" "$url" >> "$S/open.tsv"; echo "$url" ;;
  "workflow run") [ "${FAIL_DISPATCH:-}" = 1 ] && exit 1; echo "https://example.test/actions/runs/777" ;;
  "run watch") [ "${FAIL_WATCH:-}" = 1 ] && exit 1; exit 0 ;;
  *) echo "fake gh: unhandled $all" >&2; exit 99 ;;
esac
FAKE
cat > "$work/bin/git" <<'FAKE'
#!/usr/bin/env bash
S="$STATE"
case "$1" in
  push) [ "${FAIL_PUSH:-}" = 1 ] && exit 1
    b="${*: -1}"; echo "git push ${*:2}" >> "$S/log"
    grep -qx "$b" "$S/remote-branches" || echo "$b" >> "$S/remote-branches"
    mkdir -p "$S/remote/$b"; rm -f "$S/remote/$b"/*.rb; cp Formula/*.rb "$S/remote/$b/"; exit 0 ;;
  ls-remote) b="${*: -1}"; b="${b#refs/heads/}"; grep -qx "$b" "$S/remote-branches" && exit 0 || exit 2 ;;
  fetch) b="${*: -1}"; b="${b#refs/heads/}"; echo "git fetch $b" >> "$S/log"
    grep -qx "$b" "$S/remote-branches" || exit 1; printf '%s' "$b" > "$S/fetch_head"; exit 0 ;;
  ls-tree) b="$(cat "$S/fetch_head")"
    for f in "$S/remote/$b"/*.rb; do [ -e "$f" ] && echo "Formula/$(basename "$f")"; done; exit 0 ;;
  show) case "${2:-}" in
      FETCH_HEAD:*) b="$(cat "$S/fetch_head")"; f="${2#FETCH_HEAD:}"; cat "$S/remote/$b/$(basename "$f")"; exit $? ;;
      *) exec /usr/bin/git "$@" ;;
    esac ;;
esac
exec /usr/bin/git "$@"
FAKE
cat > "$work/bin/shasum" <<'FAKE'
#!/usr/bin/env bash
# $(cat) would strip trailing newlines and change every digest; stream via a file.
tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
cat > "$tmp"
real="$(/usr/bin/shasum -a 256 < "$tmp" | cut -d" " -f1)"
if [ -n "${SHAM_MAP:-}" ] && [ -f "$SHAM_MAP" ]; then
  line="$(grep "^$real " "$SHAM_MAP" || true)"
  [ -n "$line" ] && { printf '%s  -\n' "${line#* }"; exit 0; }
fi
printf '%s  -\n' "$real"
FAKE
chmod +x "$work/bin/gh" "$work/bin/git" "$work/bin/shasum"
export STATE="$work/state"
run() { local rc=0; GH="$work/bin/gh" GIT="$work/bin/git" bash "$SCRIPT" 2>"$work/err" >"$work/out" || rc=$?; echo "$rc"; }
open_count() { awk 'NF' "$STATE/open.tsv" | wc -l | tr -d ' '; }
open_urls() { awk -F'\t' 'NF{printf "%s ",$3}' "$STATE/open.tsv"; }
url_in_err() { grep -o 'https://example.test/pull/[0-9]*' "$work/err" | head -1; }
pushes() { grep -c 'git push' "$STATE/log" || true; }
dispatches() { grep -c 'gh workflow run' "$STATE/log" || true; }
set_bytes() { git switch -q main; git checkout -q -- Formula; printf 'class Gitgrip < Formula\n  url "%s"\nend\n' "$1" > Formula/gitgrip.rb; }
fp_of() { # framed digest prefix, matching the script: sha256 of "<sha256(content)> <path>" lines
  printf '%s %s\n' "$(printf 'class Gitgrip < Formula\n  url "%s"\nend\n' "$1" | shasum -a 256 | cut -d" " -f1)" "Formula/gitgrip.rb" \
    | shasum -a 256 | cut -d" " -f1 | cut -c1-12; }
framed_fp_of_files() { # args: name=content pairs like a.rb=ab — prints full framed digest
  local pair
  for pair in "$@"; do
    printf '%s\n' "${pair#*=}" | shasum -a 256 | cut -d" " -f1 | while read -r h; do :; done
  done >/dev/null
  for pair in "$@"; do
    printf '%s %s\n' "$(printf '%s\n' "${pair#*=}" | shasum -a 256 | cut -d" " -f1)" "Formula/${pair%%=*}"
  done | shasum -a 256 | cut -d" " -f1
}
seed_remote_files() { # $1 = branch, rest: name=content pairs
  local b="$1"; shift
  grep -qx "$b" "$STATE/remote-branches" || echo "$b" >> "$STATE/remote-branches"
  mkdir -p "$STATE/remote/$b"; rm -f "$STATE/remote/$b"/*.rb
  local pair
  for pair in "$@"; do printf '%s\n' "${pair#*=}" > "$STATE/remote/$b/${pair%%=*}"; done
}
seed_remote() { local b="automation/formula-updates-$(fp_of "$1")"; grep -qx "$b" "$STATE/remote-branches" || echo "$b" >> "$STATE/remote-branches"
  mkdir -p "$STATE/remote/$b"; printf 'class Gitgrip < Formula\n  url "%s"\nend\n' "$2" > "$STATE/remote/$b/gitgrip.rb"; }
need() { local label="$1"; shift; "$@" || { echo "FAIL $label"; sed -n '1,4p' "$work/err" 2>/dev/null; exit 1; }; }

# W1 happy run 1: bytes v2 → PR 1 opened, red names it
set_bytes v2; rc="$(run)"; need "run1 rc=$rc" [ "$rc" = 1 ]
need "run1 url" [ "$(url_in_err)" = "https://example.test/pull/1" ]; need "run1 open" [ "$(open_count)" = 1 ]
# W1 happy run 2: same bytes → content verified behind the name, same URL, no push, one open
set_bytes v2; before="$(pushes)"; rc="$(run)"; need "run2 rc=$rc" [ "$rc" = 1 ]
need "run2 url" [ "$(url_in_err)" = "https://example.test/pull/1" ]
need "run2 open" [ "$(open_count)" = 1 ]; need "run2 no push" [ "$(pushes)" = "$before" ]
grep -q "git fetch automation/formula-updates-$(fp_of v2)" "$STATE/log" || { echo "FAIL run2 never fetched to verify content"; exit 1; }

# W2 seam injections: bytes v3 with PR 1 open; each failure retains PR 1 and names it
for seam in FAIL_PUSH FAIL_DISPATCH FAIL_WATCH FAIL_CREATE; do
  set_bytes v3
  rc="$(env "$seam=1" GH="$work/bin/gh" GIT="$work/bin/git" bash "$SCRIPT" 2>"$work/err" >"$work/out"; echo $?)" || true
  need "$seam rc=$rc" [ "$rc" = 1 ]
  need "$seam retained open=$(open_count) [$(open_urls)]" [ "$(open_urls)" = "https://example.test/pull/1 " ]
  grep -q "Retained candidate(s): https://example.test/pull/1" "$work/err" || { echo "FAIL $seam does not name the retained candidate"; cat "$work/err"; exit 1; }
  : > "$STATE/remote-branches"
done
# re-record PR 1's branch on the remote with its true content (the seam loop cleared names)
seed_remote v2 v2

# W3 recovery: bytes-v3 branch on the remote (correct content) with NO PR → verified, reused,
# no second push, PR created, stale PR 1 closed after
seed_remote v3 v3
set_bytes v3; before="$(pushes)"; rc="$(run)"; need "recovery rc=$rc" [ "$rc" = 1 ]
need "recovery no push" [ "$(pushes)" = "$before" ]
need "recovery url" [ "$(url_in_err)" = "https://example.test/pull/2" ]
need "recovery one open [$(open_urls)]" [ "$(open_count)" = 1 ]
grep -q "recovering pushed branch" "$work/out" || { echo "FAIL recovery not announced"; exit 1; }
grep -q "gh pr close 1" "$STATE/log" || { echo "FAIL recovery did not retire PR 1"; exit 1; }

# W4 fail closed: enumeration failure stops before any publication
set_bytes v4; before="$(pushes)"; created_before="$(cat "$STATE/counter")"
rc="$(env FAIL_LIST=1 GH="$work/bin/gh" GIT="$work/bin/git" bash "$SCRIPT" 2>"$work/err" >"$work/out"; echo $?)" || true
need "list-fail rc=$rc" [ "$rc" = 1 ]
need "list-fail no push" [ "$(pushes)" = "$before" ]
need "list-fail no create" [ "$(cat "$STATE/counter")" = "$created_before" ]
grep -q "refusing to publish while the open set is unknown" "$work/err" || { echo "FAIL list-fail message"; exit 1; }

# W5 recovery-mismatch edge: same-name branch for v5 bytes carries JUNK → refused loudly,
# no push, no dispatch, no create, PR 2 retained and named
seed_remote v5 junk
set_bytes v5; before="$(pushes)"; dis_before="$(dispatches)"; created_before="$(cat "$STATE/counter")"
rc="$(run)"; need "recovery-mismatch rc=$rc" [ "$rc" = 1 ]
grep -q "wrong-content/same-name conflict" "$work/err" || { echo "FAIL mismatch not named"; cat "$work/err"; exit 1; }
need "mismatch no push" [ "$(pushes)" = "$before" ]
need "mismatch no dispatch" [ "$(dispatches)" = "$dis_before" ]
need "mismatch no create" [ "$(cat "$STATE/counter")" = "$created_before" ]
need "mismatch PR2 retained [$(open_urls)]" [ "$(open_urls)" = "https://example.test/pull/2 " ]
grep -q "Retained candidate(s): https://example.test/pull/2" "$work/err" || { echo "FAIL mismatch does not name retained"; exit 1; }

# W6 reuse-mismatch edge: the OPEN PR's branch content is corrupted → refused, PR not closed
seed_remote v3 junk
set_bytes v3; rc="$(run)"; need "reuse-mismatch rc=$rc" [ "$rc" = 1 ]
grep -q "wrong-content/same-name conflict" "$work/err" || { echo "FAIL reuse-mismatch not named"; cat "$work/err"; exit 1; }
need "reuse-mismatch PR2 still open [$(open_urls)]" [ "$(open_urls)" = "https://example.test/pull/2 " ]
seed_remote v3 v3   # restore true content

# W7 close-failure + convergence pair (Sentinel r2): bytes v6 → PR 3 created, stale close of
# PR 2 FAILS → red names BOTH and says not converged; rerun with same bytes retries
# retirement and converges to one
set_bytes v6
rc="$(env FAIL_CLOSE=1 GH="$work/bin/gh" GIT="$work/bin/git" bash "$SCRIPT" 2>"$work/err" >"$work/out"; echo $?)" || true
need "close-fail rc=$rc" [ "$rc" = 1 ]
need "close-fail two open [$(open_urls)]" [ "$(open_count)" = 2 ]
grep -q "needs a merge by a person: https://example.test/pull/3" "$work/err" || { echo "FAIL close-fail does not name replacement"; cat "$work/err"; exit 1; }
grep -q "observed still OPEN, set has not converged: https://example.test/pull/2" "$work/err" || { echo "FAIL close-fail does not name unconverged stale"; cat "$work/err"; exit 1; }
set_bytes v6; rc="$(run)"; need "converge rc=$rc" [ "$rc" = 1 ]
need "converge one open [$(open_urls)]" [ "$(open_urls)" = "https://example.test/pull/3 " ]
need "converge url" [ "$(url_in_err)" = "https://example.test/pull/3" ]

# W8 split-boundary (Atlas v8 r1): local tree {a.rb="ab", b.rb="cd"}; remote branch under the
# SAME name carries {a.rb="a", b.rb="bcd"} — unframed concatenation is identical, framed
# digest differs → must REFUSE. (Under the v8 verifier this witness accepts; discriminating.)
git switch -q main; git checkout -q -- Formula; rm -f Formula/*.rb
printf 'ab' > Formula/a.rb; printf 'cd' > Formula/b.rb
split_fp="$( (for f in Formula/*.rb; do printf '%s %s\n' "$(shasum -a 256 < "$f" | cut -d" " -f1)" "$f"; done) | shasum -a 256 | cut -d" " -f1 | cut -c1-12)"
seed_remote_files "automation/formula-updates-$split_fp" a.rb=a b.rb=bcd
# remote seed uses printf with trailing newline; local files have none — write remote raw:
printf 'a' > "$STATE/remote/automation/formula-updates-$split_fp/a.rb"; printf 'bcd' > "$STATE/remote/automation/formula-updates-$split_fp/b.rb"
before="$(pushes)"; created_before="$(cat "$STATE/counter")"
rc="$(run)"; need "split rc=$rc" [ "$rc" = 1 ]
grep -q "wrong-content/same-name conflict" "$work/err" || { echo "FAIL split-boundary not refused"; cat "$work/err"; exit 1; }
need "split no push" [ "$(pushes)" = "$before" ]
need "split no create" [ "$(cat "$STATE/counter")" = "$created_before" ]
git checkout -q -- Formula; rm -f Formula/a.rb Formula/b.rb; git checkout -q -- Formula

# W9 close-succeeds-delete-fails (Sentinel v8 r2): stale PR 3 open, new bytes v7; the close
# CLOSES the PR but exits 1 (branch deletion failed). Read-back must see CLOSED and the set
# CONVERGES — red names only the replacement, no false "unconverged".
set_bytes v7
rc="$(env FAIL_DELETE=1 GH="$work/bin/gh" GIT="$work/bin/git" bash "$SCRIPT" 2>"$work/err" >"$work/out"; echo $?)" || true
need "delete-fail rc=$rc" [ "$rc" = 1 ]
need "delete-fail one open [$(open_urls)]" [ "$(open_count)" = 1 ]
need "delete-fail url" [ "$(url_in_err)" = "https://example.test/pull/4" ]
grep -q "observed still OPEN" "$work/err" && { echo "FAIL delete-fail falsely reports unconverged"; cat "$work/err"; exit 1; }
grep -q "branch cleanup failed" "$work/err" || { echo "FAIL delete-fail warning missing"; cat "$work/err"; exit 1; }

# W10 beyond-page (Atlas v9 r1): the automation candidate sits at ROW 31 of the open set.
# gh pr list defaults to 30 rows; v9 set no limit, so the fake (default 30) hides the
# candidate and the machine would push a duplicate. v10 passes an explicit bound and finds
# it: same-URL reuse, no push, no second PR. (Discriminating: with the v9 call shape this
# witness creates a duplicate PR.)
for i in $(seq 1 30); do printf '%s\t%s\t%s\n' "$((900+i))" "feature/dummy-$i" "https://example.test/pull/$((900+i))"; done > "$STATE/pad.tsv"
cat "$STATE/open.tsv" >> "$STATE/pad.tsv"; mv "$STATE/pad.tsv" "$STATE/open.tsv"
set_bytes v7; before="$(pushes)"; created_before="$(cat "$STATE/counter")"
rc="$(run)"; need "beyond-page rc=$rc" [ "$rc" = 1 ]
need "beyond-page url" [ "$(url_in_err)" = "https://example.test/pull/4" ]
need "beyond-page no push" [ "$(pushes)" = "$before" ]
need "beyond-page no create" [ "$(cat "$STATE/counter")" = "$created_before" ]
grep -v "	feature/dummy-" "$STATE/open.tsv" > "$STATE/open.tmp"; mv "$STATE/open.tmp" "$STATE/open.tsv"

# W11 saturation refusal: the enumeration returns exactly the bound; the set may be
# truncated, so the run refuses BEFORE any publication.
for i in $(seq 1 4); do printf '%s\t%s\t%s\n' "$((950+i))" "feature/sat-$i" "https://example.test/pull/$((950+i))"; done > "$STATE/sat.tsv"
cat "$STATE/open.tsv" >> "$STATE/sat.tsv"; mv "$STATE/sat.tsv" "$STATE/open.tsv"
set_bytes v9c; before="$(pushes)"; created_before="$(cat "$STATE/counter")"
rc="$(env PR_LIST_LIMIT=5 GH="$work/bin/gh" GIT="$work/bin/git" bash "$SCRIPT" 2>"$work/err" >"$work/out"; echo $?)" || true
need "saturation rc=$rc" [ "$rc" = 1 ]
grep -q "rows at the 5-row bound" "$work/err" || { echo "FAIL saturation not named"; cat "$work/err"; exit 1; }
need "saturation no push" [ "$(pushes)" = "$before" ]
need "saturation no create" [ "$(cat "$STATE/counter")" = "$created_before" ]
grep -v "	feature/sat-" "$STATE/open.tsv" > "$STATE/open.tmp"; mv "$STATE/open.tmp" "$STATE/open.tsv"

# W12 OPEN + view-failure (Sentinel v9 r2): close fails AND read-back fails. The URL must be
# reported as UNKNOWN — not as "observed still OPEN" — because nothing was observed.
set_bytes v11a
rc="$(env FAIL_CLOSE=1 FAIL_VIEW=1 GH="$work/bin/gh" GIT="$work/bin/git" bash "$SCRIPT" 2>"$work/err" >"$work/out"; echo $?)" || true
need "unknown-open rc=$rc" [ "$rc" = 1 ]
grep -q "Close state UNKNOWN" "$work/err" || { echo "FAIL unknown wording missing"; cat "$work/err"; exit 1; }
grep -q "observed still OPEN" "$work/err" && { echo "FAIL UNKNOWN branded as observed OPEN"; cat "$work/err"; exit 1; }
# converge for the next witness: rerun without failures retires the stale
set_bytes v11a; rc="$(run)"; need "unknown-open converge rc=$rc" [ "$rc" = 1 ]
need "unknown-open converged [$(open_urls)]" [ "$(open_count)" = 1 ]

# W13 CLOSED + view-failure: the close actually closed (delete failed) and the read-back
# also fails → honest answer is still UNKNOWN, and the run is red without claiming open.
set_bytes v11b
rc="$(env FAIL_DELETE=1 FAIL_VIEW=1 GH="$work/bin/gh" GIT="$work/bin/git" bash "$SCRIPT" 2>"$work/err" >"$work/out"; echo $?)" || true
need "unknown-closed rc=$rc" [ "$rc" = 1 ]
grep -q "Close state UNKNOWN" "$work/err" || { echo "FAIL unknown-closed wording missing"; cat "$work/err"; exit 1; }
grep -q "observed still OPEN" "$work/err" && { echo "FAIL unknown-closed branded observed OPEN"; cat "$work/err"; exit 1; }
need "unknown-closed actually converged [$(open_urls)]" [ "$(open_count)" = 1 ]

# W14 twelve-hex-equality injection (Sentinel v9 r2): via a controlled shasum, the local and
# remote FRAMED digests share their first 12 hex and differ beyond. Full equality refuses;
# a mutant comparing [:12] accepts — so this witness goes red under the truncation mutant.
set_bytes v11c
lreal="$( (for f in Formula/*.rb; do printf '%s %s\n' "$(/usr/bin/shasum -a 256 < "$f" | cut -d" " -f1)" "$f"; done) | /usr/bin/shasum -a 256 | cut -d" " -f1)"
printf 'class Gitgrip < Formula\n  url "%s"\nend\n' v11d > "$work/rem.rb"
rreal="$(printf '%s %s\n' "$(/usr/bin/shasum -a 256 < "$work/rem.rb" | cut -d" " -f1)" "Formula/gitgrip.rb" | /usr/bin/shasum -a 256 | cut -d" " -f1)"
P="feedfacecafe"
printf '%s %s\n%s %s\n' "$lreal" "${P}1111111111111111111111111111111111111111111111111111" "$rreal" "${P}2222222222222222222222222222222222222222222222222222" > "$STATE/sham.map"
seed_remote_files "automation/formula-updates-$P" gitgrip.rb=SEEDED
cp "$work/rem.rb" "$STATE/remote/automation/formula-updates-$P/gitgrip.rb"
before="$(pushes)"; created_before="$(cat "$STATE/counter")"
rc="$(env SHAM_MAP="$STATE/sham.map" PATH="$work/bin:$PATH" GH="$work/bin/gh" GIT="$work/bin/git" bash "$SCRIPT" 2>"$work/err" >"$work/out"; echo $?)" || true
need "12hex rc=$rc" [ "$rc" = 1 ]
grep -q "wrong-content/same-name conflict" "$work/err" || { echo "FAIL 12hex-prefix pair not refused (truncation mutant would pass here)"; cat "$work/err"; exit 1; }
need "12hex no push" [ "$(pushes)" = "$before" ]
need "12hex no create" [ "$(cat "$STATE/counter")" = "$created_before" ]
grep -vx "automation/formula-updates-$P" "$STATE/remote-branches" > "$STATE/rb.tmp" || true; mv "$STATE/rb.tmp" "$STATE/remote-branches"

# W15 control: unchanged Formula → exit 0
git checkout -q -- Formula
rc="$(run)"; need "control rc=$rc" [ "$rc" = 0 ]
grep -q "Formula/ unchanged" "$work/out" || { echo "FAIL control message"; exit 1; }

echo "PASS: happy pair (content-verified reuse), four seam retentions, verified recovery, recovery-mismatch refusal, reuse-mismatch refusal, close-failure naming + convergence rerun, split-boundary framing refusal, close-succeeds-delete-fails convergence, beyond-page candidate found at an explicit bound, saturation refusal, three-state read-back (UNKNOWN never branded observed-open, both view-failure shapes), twelve-hex-prefix digest pair refused by full equality, fail-closed enumeration, control"
