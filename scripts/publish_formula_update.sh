#!/usr/bin/env bash
# publish_formula_update.sh — publish an updated Formula/ tree as one converging open PR.
#
# The guarantee (narrowed per review): NEVER retire the last mergeable candidate before
# its replacement exists; CONVERGE to exactly one open candidate when stale closes
# succeed; on a close failure, fail red naming the replacement and every retained stale
# URL. Replacement-before-retirement guarantees nonzero availability; it cannot guarantee
# continuously-exactly-one across two non-atomic GitHub writes, so reruns retry
# retirement until the set converges. The branch name is derived from the Formula BYTES,
# but a name is a lookup key, not proof of content: any same-name branch is fetched and
# its Formula bytes verified before reuse, and a wrong-content/same-name conflict is
# refused loudly. The workflow token cannot merge under main protection (measured), so
# this ends by FAILING with the PR URL for a person to merge. Exit 0 only when Formula/
# is unchanged.
#
# State machine:
#   1. resolve the open candidate set into a CHECKED result; fail closed if unknown
#   2. reuse the exact-byte PR if one is open (content verified, not name-trusted),
#      retrying retirement of stale candidates so reruns converge
#   3. recover a remote branch that has no PR — only after verifying its Formula bytes
#      match the computed update (no recommit, no re-push)
#   4. for newer bytes: push, test, and create the replacement PR FIRST
#   5. only after the replacement URL exists, close stale candidates; a close failure
#      is red and names the replacement plus every URL still open
set -euo pipefail
GH="${GH:-gh}"
GIT="${GIT:-git}"
TEST_WORKFLOW="${TEST_WORKFLOW:-test-formulae.yml}"
PREFIX="automation/formula-updates-"
TITLE="chore: update formulae"

if $GIT diff --quiet -- Formula; then
  echo "Formula/ unchanged; nothing to publish"
  exit 0
fi
# The digest FRAMES each file as "<sha256(content)> <path>" before hashing the list:
# an unframed concatenation lets two different trees ({a="ab",b="cd"} vs {a="a",b="bcd"})
# compare equal without any SHA collision. Equality always uses the FULL digest;
# the 12-hex prefix is only the branch-name suffix.
formula_digest_local() {
  local f
  for f in Formula/*.rb; do
    printf '%s %s\n' "$(shasum -a 256 < "$f" | cut -d" " -f1)" "$f"
  done | shasum -a 256 | cut -d" " -f1
}
fp_full="$(formula_digest_local)"
branch="${PREFIX}${fp_full:0:12}"

# 1. Candidate enumeration is load-bearing: an unknown open set must stop the run
#    BEFORE any publication, or a transient API failure reads as "no candidates".
#    The bound is explicit and its saturation is a refusal: gh pr list defaults to 30
#    rows, and a truncated page hides a candidate at row 31 while the machine claims
#    the set is complete. A bounded read reports whether it hit its bound.
PR_LIST_LIMIT="${PR_LIST_LIMIT:-200}"
if ! all_prs="$($GH pr list --state open --limit "$PR_LIST_LIMIT" --json number,headRefName,url --jq '.[] | [.number, .headRefName, .url] | @tsv')"; then
  echo "::error::cannot enumerate open PRs; refusing to publish while the open set is unknown" >&2
  exit 1
fi
row_count="$(printf '%s\n' "$all_prs" | awk 'NF' | wc -l | tr -d ' ')"
if [ "$row_count" -ge "$PR_LIST_LIMIT" ]; then
  echo "::error::open PR enumeration returned ${row_count} rows at the ${PR_LIST_LIMIT}-row bound; the set may be truncated, refusing to publish" >&2
  exit 1
fi
same_url=""
stale_rows=()
while IFS=$'\t' read -r num head url; do
  [ -n "$num" ] || continue
  case "$head" in "$PREFIX"*) ;; *) continue ;; esac
  if [ "$head" = "$branch" ]; then same_url="$url"; else stale_rows+=("${num}"$'\t'"${url}"); fi
done <<< "$all_prs"

retained() {
  local urls=""
  local row
  for row in "${stale_rows[@]:-}"; do [ -n "$row" ] && urls="${urls} ${row#*$'\t'}"; done
  [ -n "$urls" ] && echo " Retained candidate(s):${urls}." || true
}
die() { echo "::error::$1$(retained)" >&2; $GIT checkout -q -- Formula || true; exit 1; }

# A name is a lookup key; the content behind it is verified before any reuse.
assert_remote_formula_matches() { # $1 = branch, $2 = context for the refusal
  $GIT fetch -q origin "refs/heads/$1" || die "could not fetch ${1} to verify its Formula bytes ($2)"
  local remote_fp f
  remote_fp="$(for f in $($GIT ls-tree -r --name-only FETCH_HEAD -- Formula); do
      printf '%s %s\n' "$($GIT show "FETCH_HEAD:$f" | shasum -a 256 | cut -d" " -f1)" "$f"
    done | shasum -a 256 | cut -d" " -f1)"
  [ "$remote_fp" = "$fp_full" ] || die "remote branch ${1} carries Formula digest ${remote_fp}, not the computed ${fp_full}: wrong-content/same-name conflict ($2); refusing to reuse"
}

# Retire stale candidates; failures accumulate in UNCLOSED so the caller names them.
UNCLOSED=""
UNVERIFIED=""
close_stales() { # $1 = the replacement URL that already exists
  local row num url
  for row in "${stale_rows[@]:-}"; do
    [ -n "$row" ] || continue
    num="${row%%$'\t'*}"; url="${row#*$'\t'}"
    if ! $GH pr close "$num" --comment "Superseded by ${1}." --delete-branch >/dev/null; then
      # gh pr close --delete-branch is a composite: it can close the PR and then fail
      # on the branch deletion. The read-back is three-state, and each state gets its
      # own honest wording: only an OBSERVED OPEN is branded unconverged; an
      # unreadable state is reported as unknown, never as observed-open.
      state="$($GH pr view "$num" --json state --jq .state 2>/dev/null || echo UNKNOWN)"
      case "$state" in
        CLOSED|MERGED)
          echo "::warning::PR #${num} closed but its branch cleanup failed; the branch may remain" >&2 ;;
        OPEN)
          UNCLOSED="${UNCLOSED} ${url}"
          echo "::warning::could not close superseded PR #${num} (${url}; read-back: still OPEN)" >&2 ;;
        *)
          UNVERIFIED="${UNVERIFIED} ${url}"
          echo "::warning::close of PR #${num} failed and its state could not be read back (${url})" >&2 ;;
      esac
    fi
  done
}
finish_red() { # $1 = the mergeable candidate URL
  local msg="formula update needs a merge by a person: ${1}."
  [ -n "$UNCLOSED" ] && msg="${msg} Stale candidate(s) observed still OPEN, set has not converged:${UNCLOSED}."
  [ -n "$UNVERIFIED" ] && msg="${msg} Close state UNKNOWN (read-back failed; not claiming open or closed) for:${UNVERIFIED}."
  echo "::error::${msg}" >&2
  exit 1
}

# 2. Same bytes, PR already open: verify the content behind the name, retry retirement
#    of any stale candidates (this is how a rerun converges), and report.
if [ -n "$same_url" ]; then
  assert_remote_formula_matches "$branch" "open PR ${same_url}"
  close_stales "$same_url"
  finish_red "$same_url"
fi

# 3./4. Publish the replacement fully before touching anything that exists.
if $GIT ls-remote --exit-code origin "refs/heads/$branch" >/dev/null 2>&1; then
  # A previous run pushed a branch under this name and died before its PR was
  # created. Verify the content, then reuse it as the recovery key — never re-push.
  assert_remote_formula_matches "$branch" "recovery of a pushed branch with no PR"
  echo "recovering pushed branch ${branch} that has no PR"
else
  $GIT config user.name "github-actions[bot]"
  $GIT config user.email "41898282+github-actions[bot]@users.noreply.github.com"
  $GIT switch -q -C "$branch" || die "could not create branch ${branch}"
  $GIT add Formula
  $GIT commit -q -m "$TITLE" || die "could not commit the formula update"
  $GIT push -q origin "$branch" || die "could not push ${branch}"
fi

test_run_url="$($GH workflow run "$TEST_WORKFLOW" --ref "$branch")" \
  || die "could not dispatch ${TEST_WORKFLOW} on ${branch}"
test_run_id="${test_run_url##*/}"
[[ "$test_run_id" =~ ^[0-9]+$ ]] || die "could not resolve the formula test run from: ${test_run_url}"
$GH run watch "$test_run_id" --exit-status >/dev/null \
  || die "formula tests failed or could not be watched (run ${test_run_id}) on ${branch}"

pr_url="$($GH pr create --base main --head "$branch" --title "$TITLE" \
  --body "Automated formula update. The branch passed brew audit/install/test in run ${test_run_id}. Needs a person to merge: the workflow token cannot satisfy main's required checks.")" \
  || die "could not open the PR for ${branch}"

# 5. The replacement exists; now stale candidates may retire. A close failure leaves the
#    set unconverged: red, naming the replacement and every URL still open; the next run
#    with the same bytes retries retirement in step 2.
close_stales "$pr_url"
finish_red "$pr_url"
