---
name: go-public
description: Take a private repository to a clean, branded public GitHub release without leaking anything. Covers making it lean and general, licences and credit, a required full security-audit and independent reviews, a leak scan of every object ever committed and of what GitHub already holds (scan.sh), an inventory of everything outside git that a visibility flip exposes (settings.sh), branding and video, publishing one clean commit from a fresh repository, a stranger install test before and after, the safety settings, and what to do if something sensitive was already public. Use when the owner asks to make a repo public, open-source it, get it ready for public release, or check whether a repo is safe to publish. Not for deploying an app or for cleanup alone (unbloat).
---

# Go public

Assume anything that is ever public has been copied: GitHub serves pushed commits by SHA after a squash and force
push, forks and pull-request refs keep them, and archives such as Software Heritage and GH Archive mirror public
repos. So the public repository only ever receives one commit that has already passed every check, and nothing that
was ever pushed privately is made public.

**Modes.** "Is it ready", "check" or "audit" changes nothing: pin the source (step 1), scan it, build a throwaway
publication candidate in the scratchpad as in step 6 and scan that, run the reviews in step 5 and the inventory in
step 7, and report what would have to change. "Get it ready": do steps 1 to 8 and stop at the approval in step 9.
"Make it public": all of it, still stopping at step 9 unless the owner has already approved those exact actions.

**Gates.** A step passes only against a named commit. Any change to the tree afterwards (README, banner, a fix)
sends the work back to step 4. A review that fails, times out or can't run blocks the release; it is never skipped.
Unavailable native compatibility checks follow step 8; they do not waive an unresolved security finding or a
required independent review.

**Prerequisites.** Install both shipped skill folders, `go-public` and `security-audit`. The audit folder must
include its companion files, report schema and validators. Node.js runs those validators.
Set `GO_PUBLIC_SKILL_DIR` to the absolute directory containing this `SKILL.md`, resolving symlinks; helper commands
below use it, and the bundled audit is its sibling `../security-audit`.

## 0. Ask the owner first, once

Ask these together and record the answers. Never decide them yourself:

- **Licence**, and whether third-party material may be redistributed (step 3 lists what to check).
- **Public identity** for commits, and the **copyright holder** for the licence (a person or an organisation; it
  can differ from the commit identity). If `~/.config/go-public/identity` exists it holds the owner's usual commit
  identity (`Name <email>`): confirm it rather than assume it.
- **Owner and repository name**, and whether a fresh repository may take that name (step 7).
- **Explainer video**: yes or no.

The scan's personal strings live outside every repository, in `~/.config/go-public/patterns.txt` (or
`$GO_PUBLIC_PATTERNS`), one extended regex per line: home paths, usernames, machine names, private IPs and hosts,
private project names, personal emails. If it is missing, create it from `patterns.example.txt` with the owner.

## 1. Pin the target

Write down the source: the local path and, if it has a GitHub repository, its `owner/repo` and ID
(`gh api repos/<owner>/<repo> --jq .id`). Use them in every ask and report. If the request, the remote and the ID
disagree, stop and ask. The public destination gets its own name and ID when step 9 creates it.

## 2. Lean and general

- Use `unbloat` if installed. Otherwise review tracked code and docs for unused or duplicated content, local
  configuration and process artifacts; remove only provable bloat and verify with the project's checks.
- Remove anything tied to the owner's own setup: machine names, IPs, usernames, home paths, private project names,
  internal hosts in CI config and lockfiles. Settings move to an ignored env file whose keys the README documents.
  Sample data, fixtures, notebooks (outputs too) and screenshots count.
- Cut tuning for one personal use case that a general user wouldn't need.
- Untrack local config (`.claude/`, `.handoff/`, `.env`, logs, outputs, model weights, `.DS_Store`) and ignore it.

## 3. Licences and credit

- Add the licence the owner chose.
- For every piece of someone else's work (copied code, dependencies you vendor, model weights, datasets, fonts,
  images, audio), read its actual licence and notice files at the pinned revision. Keep their full licence text
  and NOTICE files, keep their copyright lines, and credit them in the README. Show the owner the wording.
- No licence, an unclear one, or one that forbids redistribution means it stays out. Metadata such as a Hugging Face
  model card or `gh repo view --json licenseInfo` only points to the licence: read the licence itself, and treat a
  failed or empty lookup as unknown, not as permission.
- Pin downloads (models, datasets) to a revision so a stranger gets what was tested.
- The project's own images, icons, sample outputs and fonts: confirm with the owner who made each and that it may
  be published.

## 4. Brand, then freeze

Branding comes before the reviews, so the reviews see the final tree.

- README: name, a one-line tagline, the problem it solves and for whom, install, a short example, credits. Add a
  light and dark banner (`<picture>` with `prefers-color-scheme`) and only badges that resolve.
- Preview it: `gh api markdown -f text="$(cat README.md)" -f mode=gfm -f context=<owner>/<repo>`, in a browser.
- Video, if wanted: make it outside the repo with available video tooling, watch it through for anything private on
  screen or in the voice-over, and strip its metadata. Never commit it. GitHub only plays README video that is
  uploaded as an attachment: the owner drags the file into a comment or README editor on GitHub, without
  submitting, and the README uses the `https://github.com/user-attachments/assets/...` URL. An attachment
  uploaded while the repo is private may not play publicly; step 10 checks it logged out.
- Commit. This commit is what steps 5 to 8 test. Note its SHA and tree (`git rev-parse HEAD HEAD^{tree}`).

## 5. Reviews

Each review names the pinned commit; preparation and publication use the frozen commit from step 4. Audit/check
mode reports required changes only. Otherwise, fix findings in the working repository, with regression tests
where applicable, then return to step 4.

- Read `$GO_PUBLIC_SKILL_DIR/../security-audit/SKILL.md` and its full-audit references. Use this bundled copy
  rather than an unrelated installed audit skill. If the skill, companion files, schema or validators are
  unavailable, stop this gate.
- Invoke it explicitly: "Run a full repository security audit of <absolute source path> at <pinned SHA>, using
  the standard profile and all repository paths. Follow all six phases and retain the reports outside both the
  source and publication repositories." Use a new external run directory and preserve compatible prior runs
  for revalidation. The audit inspects source read-only; apply fixes through the mode-specific loop above.
- This gate passes only when the audit records match the source path and pinned commit with a clean worktree,
  the run is complete, its main report and any applicable detail or validation reports exist, both audit validators
  pass, all in-scope coverage and candidate decisions are resolved, and the current records contain no
  `confirmed` or `needs_validation` findings.
  A quick, scoped, incomplete or blocked pass cannot satisfy this gate. Validator success alone is not clearance.
- An independent read-only review by another model or agent that hasn't seen the work (for Codex:
  `codex exec -s read-only`, run in the background with a time limit). Ask for bugs, leaks, and README claims
  the code doesn't back.
- A fresh-reader pass on the README by a subagent: does each claim hold, does the install work as written?

## 6. Build the publication repository

Never publish from the working repository: it holds the history, backup branches and remote-tracking refs that
must stay private. Build a separate repository that contains one commit and nothing else:

```bash
PUB=<scratch>/publish/<repo>                      # outside the working repository
git -C <repo> archive --format=tar HEAD | (mkdir -p "$PUB" && tar -x -C "$PUB")
cd "$PUB" && git init -q -b main && git add -A
GIT_AUTHOR_NAME="<name>" GIT_AUTHOR_EMAIL="<email>" GIT_COMMITTER_NAME="<name>" GIT_COMMITTER_EMAIL="<email>" \
  git commit -q -m "<project> <version>: initial public release"
test "$(git rev-parse HEAD^{tree})" = "<tree from step 4>"   # same tree, or find what export-ignore dropped
```

Then scan it, and the working repository too:

```bash
"$GO_PUBLIC_SKILL_DIR/scan.sh" "$PUB" --identity "<name> <email>"   # must exit 0
"$GO_PUBLIC_SKILL_DIR/scan.sh" <repo>                             # history findings: see below
```

`scan.sh` mirrors every ref (and every ref on the repo's GitHub remotes, pull-request refs included) into a
temporary copy and checks every blob ever committed, commit and tag text, identities, file and ref names, symlink
targets, submodules, LFS pointers and media metadata, with gitleaks on a trusted config and the personal
patterns. It exits 0 clean, 1 with findings, 2 when it could not finish; treat 2 as a failure. It lists what it
can't inspect (text inside images or audio, encrypted archives, LFS payloads, submodule contents): review those by
hand. Fix every `!` in the publication repository and rerun until it exits 0.

In the working repository, history findings are expected. What matters there: **a secret anywhere in its history
must be revoked or rotated now**, even though the history stays private, because it may already have reached
GitHub, a fork or a backup.

## 7. Choose the destination

```bash
"$GO_PUBLIC_SKILL_DIR/settings.sh" <owner>/<repo> inventory
```

It lists everything outside git that a visibility flip would expose: description, topics and a custom social
preview image, forks, collaborators, deploy keys, webhooks, Actions secrets, variables, runners, run logs,
artifacts and caches, releases, issues and pull requests, discussions, Pages and the wiki. Packages and linked
gists need checking by hand. This tells the owner what the private repository holds; it doesn't make it safe.

The destination is always a repository created fresh in step 9 for this release. Never flip an existing
repository: GitHub keeps objects a rewrite removed from its refs, so its current refs and inventory can't prove
what it holds. If the existing repository should keep the public name, it is renamed and stays private: record
its ID first, and afterwards confirm it is still private and has no forks. Reusing the name breaks the old
name's redirect, so old clones then point at the public repository: repoint them (step 11).

## 8. Stranger test, before publishing

Test the publication commit the way a stranger would, from a local clone, in the background so the owner's screen
stays free:

```bash
env -i HOME="$(mktemp -d)" PATH="$PATH" GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0 \
  git clone -q "$PUB" <scratch>/stranger
```

With that empty `HOME` (and an empty `CLAUDE_CONFIG_DIR` for a Claude plugin), install the way the README says
and run every README example and the project's tests, on each platform the README claims. For a Claude plugin, use
the shell form of `/plugin`: `claude plugin marketplace add <path or owner/repo>` and `claude plugin install`.
macOS has no `timeout`; limit long commands with `perl -e 'alarm shift; exec @ARGV' <seconds> <command>`.

Use existing authorized test environments and installed toolchains, including available local, remote or container
environments. Target-controlled checks must meet the audit skill's execution controls. Do not provision VMs,
download OS images, enable host virtualization features or build custom sandbox infrastructure for these checks.

For each claimed platform, record the tested commit, actual OS/runtime, command and result. A Linux container
tests Linux even on a macOS or Windows host; its pass cannot establish native compatibility. When a platform,
dependency, GPU or required isolation control is unavailable, do only the safe checks the existing environment
supports (such as source inspection, build or syntax checks). Mark each unavailable check **not run — native
compatibility unverified**, with the exact reason; partial checks are not a native pass. This limitation alone
does not block release unless the owner made that native check a requirement. If it leaves an in-scope security
lead or required audit coverage unresolved, step 5 still blocks release. Never turn the gap into infrastructure
work. A fix means a new commit in the working repository and back to step 4.

## 9. One approval, then publish

Put everything outward-facing in one ask, with exact values: the source repository's ID and any rename, the name
of the fresh destination, the commit SHA being pushed, the public identity, the visibility flip, the description,
topics and settings. Wait for a clear yes; "can we…?" is not one. If a classifier or permission check refuses a
step, stop and ask. Then, checking each result before the next:

```bash
gh repo rename <name>-private -R <owner>/<repo> --yes        # only if the source keeps the public name
gh repo create <owner>/<repo> --private --description "<description>"
gh api repos/<owner>/<repo> --jq '"\(.id) \(.visibility) \(.fork) \(.size)"'   # record the ID: private, not a fork, empty
gh api -X PUT repos/<owner>/<repo>/actions/permissions -F enabled=false        # no workflow runs before review
gh repo edit <owner>/<repo> --add-topic <topic> ...          # description and topics before anyone can see them
git -C "$PUB" remote add origin <url>
git -C "$PUB" push origin HEAD:refs/heads/main               # only this ref: never --all, --mirror or --tags
git -C "$PUB" ls-remote --refs origin                        # exactly refs/heads/main, at the approved SHA
"$GO_PUBLIC_SKILL_DIR/scan.sh" "$PUB" --identity "<name> <email>"   # now also checks what GitHub holds
"$GO_PUBLIC_SKILL_DIR/settings.sh" <owner>/<repo> inventory        # nothing to review: the repo is new
gh repo edit <owner>/<repo> --visibility public --accept-visibility-change-consequences
"$GO_PUBLIC_SKILL_DIR/settings.sh" <owner>/<repo> apply "<description>" <topic> <topic> ...
```

`apply` turns on secret scanning, push protection, private vulnerability reporting and a read-only workflow token,
adds a "Protect main" ruleset that blocks force pushes and deletion, then checks every setting and exits non-zero
if one is missing. Actions stays off until the owner has reviewed the workflows and decided to turn it on
(`gh api -X PUT repos/<owner>/<repo>/actions/permissions -F enabled=true`); with the flip done, their logs are
public from the first run.

## 10. Check it as a stranger

- Repeat step 8 from the public HTTPS URL, and confirm the clone's `HEAD` is the approved SHA.
- Fetch every README link and image with GET: `curl -fsSL -o /dev/null <url>` fails on errors. The exception is
  `github.com/user-attachments/...`: curl gets a 404 for those even when they work, so they are checked only in a
  browser that isn't signed in to GitHub (the built-in browser pane is not): open the README and confirm the video
  plays, for example with `document.querySelector('article video')`, `play()`, and `readyState` 4 with
  `currentTime` moving. If it doesn't play, it was uploaded while the repo was private: upload it again.
- `settings.sh <owner>/<repo> check` exits 0.
- Installed plugins record the published SHA (`gitCommitSha`); it must match `main`.

## 11. After the release

- Work on the public project from fresh clones of the public repository. Clones that hold the private history
  point only at the private repository; remove any remote that points at the public one, so a bulk push or a merge
  can't carry private history across. The ruleset doesn't stop a new branch or a merge that brings it back:
  run `scan.sh` on a clone before pushing anything that didn't start from the public root.
- Later fixes are normal commits with a version bump, so installs update.

## A repository that is already public

Run the audit mode on it. `scan.sh` asks GitHub for every local commit no current ref reaches (old squashes, force
pushes, deleted branches) and reports the ones it still serves, which is the real public history.
`settings.sh check` asserts the settings, Actions included. What to do about readable old commits is the owner's
call: if nothing in them is sensitive, accept it; if something is, follow the next section, and if the owner wants
the old history gone for sure, make the repository private now and publish again through steps 6 to 10.

## If something sensitive was already public

Revoke or rotate any credential first, before any cleanup, and check where it was used. Then follow GitHub's
"Removing sensitive data from a repository" guide (git-filter-repo, then GitHub Support for cached views and
pull-request refs). Support only acts on sensitive data that rotation can't fix, never on forks, and can't reach
copies in archives or other people's clones. Tell the owner plainly what can't be taken back.

## Report

Use the owner's report format. The result names the public URL, the repository ID, the published SHA, the `scan.sh`
and `settings.sh check` exits, the security audit's report path, reviewed SHA, run status, validator results and
unresolved blockers, the stranger test results before and after, and every inventory item and how it was resolved.
"Left" names any step not run, with the reason.
