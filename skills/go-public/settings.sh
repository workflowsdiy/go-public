#!/usr/bin/env bash
# GitHub side of a public release.
# Usage: settings.sh owner/repo inventory    read-only: everything outside the git tree that a visibility flip exposes
#        settings.sh owner/repo apply ["description" topic ...]    safety settings (public repos), then check
#        settings.sh owner/repo check        read-only: asserts every setting apply makes
# Exit 0: all clear. 1: something to review, or a setting is missing. 2: an API call failed.
set -uo pipefail
[ $# -ge 2 ] || { echo "  ERROR: usage: settings.sh owner/repo inventory|apply|check"; exit 2; }
R=$1 mode=$2
shift 2
for t in gh jq git; do command -v $t >/dev/null || { echo "  ERROR: $t is not installed"; exit 2; }; done
tmp=$(mktemp -d) || exit 2
trap 'rm -rf "$tmp"' EXIT
problems=0
flag() { echo "  ! $*"; problems=1; }
# A failed call prints ERROR and fails the caller's assignment: use as x=$(api ...) || exit 2
api() { gh api "$@" 2>"$tmp/err" || { echo "  ERROR: gh api $*: $(head -1 "$tmp/err")" >&2; return 2; }; }

repo=$(api "repos/$R") || exit 2
owner=$(jq -r .owner.login <<< "$repo")
branch=$(jq -r .default_branch <<< "$repo")
vis=$(jq -r .visibility <<< "$repo")

# Flags the list (one line per item, or a total_count) when it is not empty.
review() {
  local label=$1 hint=$2 out; shift 2
  out=$(api "$@") || exit 2
  out=$(grep -v '^$' <<< "$out")
  if [ -n "$out" ] && [ "$out" != 0 ]; then flag "$label: $(tr '\n' ' ' <<< "$out")— $hint"; else echo "  $label: none"; fi
}

inventory() {
  jq -r '"  \(.full_name), id \(.id), \(.visibility), default branch \(.default_branch), fork \(.fork), forks \(.forks_count), homepage \(.homepage // "none")"' <<< "$repo"
  [ "$(jq -r .fork <<< "$repo")" = true ] && flag "this repository is a fork: its network shares objects with $(jq -r .parent.full_name <<< "$repo")"
  jq -r '"  description: \(.description // "none")\n  topics: \((.topics // []) | join(", "))"' <<< "$repo"
  og=$(api graphql -f query="{repository(owner:\"$owner\",name:\"$(jq -r .name <<< "$repo")\"){usesCustomOpenGraphImage}}" \
    --jq .data.repository.usesCustomOpenGraphImage) || exit 2
  [ "$og" = true ] && flag "a custom social preview image is set: check it, it becomes shareable"
  review "forks" "each keeps every commit it saw; ask the owners to delete them" --paginate "repos/$R/forks" --jq '.[].full_name'
  review "collaborators besides $owner" "remove anyone who should not keep access" --paginate "repos/$R/collaborators" --jq ".[] | select(.login != \"$owner\") | .login"
  review "deploy keys" "remove unused keys" --paginate "repos/$R/keys" --jq '.[].title'
  review "webhooks" "check where each sends payloads" --paginate "repos/$R/hooks" --jq '.[].config.url'
  review "Actions secrets" "public workflows from forks must not reach them" --paginate "repos/$R/actions/secrets" --jq '.secrets[].name'
  review "Actions variables" "variables are readable in public logs" --paginate "repos/$R/actions/variables" --jq '.variables[].name'
  review "environments" "check their secrets and protection rules" --paginate "repos/$R/environments" --jq '.environments[].name'
  review "self-hosted runners" "never run public fork workflows on your machines" --paginate "repos/$R/actions/runners" --jq '.runners[].name'
  review "workflow runs" "their logs become public; delete them first" "repos/$R/actions/runs?per_page=1" --jq '.total_count'
  review "artifacts" "they become public; delete them first" "repos/$R/actions/artifacts?per_page=1" --jq '.total_count'
  review "Actions caches" "fork workflows can read them; delete them" "repos/$R/actions/caches?per_page=1" --jq '.total_count'
  review "releases" "notes and assets become public; inspect or delete them" --paginate "repos/$R/releases" --jq '.[].tag_name'
  review "issues and pull requests" "their text, comments and attachments become public" --paginate "repos/$R/issues?state=all" --jq '.[].number'
  [ "$(jq -r .has_discussions <<< "$repo")" = true ] && flag "discussions are on: their text becomes public"
  [ "$(jq -r .has_pages <<< "$repo")" = true ] && flag "GitHub Pages is on: check what it serves and its custom domain"
  if [ "$(jq -r .has_wiki <<< "$repo")" = true ]; then
    flag "the wiki is enabled: a wiki is its own repository with its own history; turn it off (gh repo edit $R --enable-wiki=false) or review it at https://github.com/$R/wiki"
  fi
  echo "  not checked here: packages and container images linked to the repo, and gists it links to (secret gists are not private)"
}

apply() {
  [ "$vis" = public ] || { echo "  ERROR: $R is $vis: apply the settings right after the flip"; exit 2; }
  if [ $# -gt 0 ]; then
    gh repo edit "$R" --description "$1" >/dev/null || exit 2
    shift
    if [ $# -gt 0 ]; then
      printf '%s\n' "$@" | jq -R . | jq -sc '{names: .}' > "$tmp/topics" || exit 2
      api -X PUT "repos/$R/topics" --input "$tmp/topics" >/dev/null || exit 2
    fi
  fi
  echo '{"security_and_analysis":{"secret_scanning":{"status":"enabled"},"secret_scanning_push_protection":{"status":"enabled"}}}' |
    api -X PATCH "repos/$R" --input - >/dev/null || exit 2
  api -X PUT "repos/$R/private-vulnerability-reporting" >/dev/null || exit 2
  api -X PUT "repos/$R/actions/permissions/workflow" -f default_workflow_permissions=read -F can_approve_pull_request_reviews=false >/dev/null || exit 2
  cat > "$tmp/ruleset" <<'EOF'
{"name":"Protect main","target":"branch","enforcement":"active","bypass_actors":[],
 "conditions":{"ref_name":{"include":["~DEFAULT_BRANCH"],"exclude":[]}},
 "rules":[{"type":"deletion"},{"type":"non_fast_forward"}]}
EOF
  ids=$(api --paginate "repos/$R/rulesets?includes_parents=false" --jq '.[] | select(.name == "Protect main") | .id') || exit 2
  case $(grep -c . <<< "$ids") in
    0) api -X POST "repos/$R/rulesets" --input "$tmp/ruleset" >/dev/null || exit 2;;
    1) api -X PUT "repos/$R/rulesets/$ids" --input "$tmp/ruleset" >/dev/null || exit 2;;
    *) echo "  ERROR: several rulesets named Protect main: delete the extras"; exit 2;;
  esac
  repo=$(api "repos/$R") || exit 2
  check
}

check() {
  [ "$vis" = public ] || flag "visibility is $vis"
  jq -r '"  description: \(.description // "none")\n  topics: \(.topics | join(", "))\n  licence: \(.license.spdx_id // "none")"' <<< "$repo"
  [ "$(jq -r '.license.spdx_id // "none"' <<< "$repo")" = none ] && flag "no licence detected"
  for s in secret_scanning secret_scanning_push_protection; do
    v=$(jq -r ".security_and_analysis.$s.status // \"unknown\"" <<< "$repo")
    [ "$v" = enabled ] && echo "  $s: enabled" || flag "$s: $v"
  done
  pvr=$(api "repos/$R/private-vulnerability-reporting" --jq .enabled) || exit 2
  [ "$pvr" = true ] && echo "  private vulnerability reporting: enabled" || flag "private vulnerability reporting: off"
  actions=$(api "repos/$R/actions/permissions" --jq .enabled) || exit 2
  if [ "$actions" = true ]; then
    if gh api "repos/$R/contents/.github/workflows" --silent 2>"$tmp/err"; then
      echo "  Actions: on, workflows present (owner review is required by the release procedure)"
    else
      grep -q 'HTTP 404' "$tmp/err" || { echo "  ERROR: cannot list workflows: $(head -1 "$tmp/err")"; exit 2; }
      flag "Actions is on with no workflows: turn it off (gh api -X PUT repos/$R/actions/permissions -F enabled=false)"
    fi
  else
    echo "  Actions: off"
  fi
  wf=$(api "repos/$R/actions/permissions/workflow" --jq '"\(.default_workflow_permissions) \(.can_approve_pull_request_reviews)"') || exit 2
  [ "$wf" = "read false" ] && echo "  workflow token: read-only" || flag "workflow token permissions: $wf (want read, cannot approve reviews)"
  # The managed ruleset must exist exactly as apply writes it, and must be what blocks both on the default branch.
  ids=$(api --paginate "repos/$R/rulesets?includes_parents=false" --jq '.[] | select(.name == "Protect main") | .id') || exit 2
  if [ "$(grep -c . <<< "$ids")" != 1 ]; then
    flag "expected one ruleset named Protect main, found $(grep -c . <<< "$ids")"
  else
    rs=$(api "repos/$R/rulesets/$ids") || exit 2
    got=$(jq -c '{e: .enforcement, t: .target, b: (.bypass_actors // [] | length), i: .conditions.ref_name.include,
      r: ([.rules[].type] | sort)}' <<< "$rs")
    want='{"e":"active","t":"branch","b":0,"i":["~DEFAULT_BRANCH"],"r":["deletion","non_fast_forward"]}'
    [ "$got" = "$want" ] && echo "  Protect main ruleset: active, no bypass" || flag "Protect main ruleset is $got, want $want"
    rules=$(api "repos/$R/rules/branches/$branch" --jq ".[] | select(.ruleset_id == $ids) | .type") || exit 2
    for t in deletion non_fast_forward; do
      grep -qx "$t" <<< "$rules" && echo "  $branch: $t blocked" || flag "$branch: $t is not enforced by Protect main"
    done
  fi
}

case $mode in
  inventory) inventory;;
  apply) apply "$@";;
  check) check;;
  *) echo "  ERROR: unknown mode $mode"; exit 2;;
esac
exit $problems
