# Reconnaissance

This resource is for explicit comprehensive audits. Focused review uses SKILL.md without these artifacts or phases.

## Comprehensive workflow

Map source and material coverage, hunt with HUNTING.md, then validate candidates and final records with VALIDATION-AND-REPORTING.md. Quick and standard combine candidate/final-record review; deep keeps separate fresh passes. Write sorted findings, validate findings and coverage, and derive only applicable reports. Close with valid final records and reports, or record incomplete status and the exact gaps. A close-out request stops new hunting and finishes known-lead dispositions without implying complete coverage.

## Full audit setup

Resolve the skill directory, target root, stable repo name, reviewed commit and dirty state, scope and profile. Create a new output directory outside the target, defaulting to `~/security-audit-skill/<repo-name>/run-<N>`. An explicitly selected in-repository location must be fully ignored by version control.

The parent owns `run-metadata.json`, `architecture.md`, `coverage-ledger.json`, `findings.json` and the applicable reports. Metadata records `run_id`, repo, target, source ref, profile, scope paths, budget (null when unset), `execution_policy: "sandboxed-source-and-local-only"`, selected companions, prior-run paths, owners and run status.

## Run profiles and scope

Choose from the requested depth and actual boundaries; do not default a small trial to a large audit.

- **quick:** for a small cohesive target, first look or focused re-run. The parent can do reconnaissance and hunting directly. Use one hunting pass and one fresh coverage critic; defer discoveries rather than start another wave. One fresh candidate verifier also checks the final record. State that coverage is partial.
- **standard:** for broader repository audits. Split work only across distinct boundaries. One fresh critic follows each hunting wave; its no-work result closes coverage without a second clean critic. One fresh candidate verifier also checks the final record.
- **deep:** for explicitly comprehensive or high-stakes work. Split material subsystems and lifecycle modes, retain a distinct final-clean critic, and separately verify candidate and final records.

A scoped run seeds only material in-scope boundaries; record discovered excluded surfaces as `out_of_scope`. Profiles change breadth and redundancy, never sandbox controls, the candidate evidence bar or independent verification. If delegation is unavailable, source review can proceed but unverified candidates cannot become findings.

### Cost budget

When the user sets an invocation budget, count every delegated call, including retries and critics. Parent source work costs no agent invocation. Before delegation, estimate the actual recon/hunter assignments and reserve the profile's critic and candidate verification calls. There is no four-agent reconnaissance minimum. Keep the plan proportional to observed source; do not construct a scheduling framework.

Assign lowest-trust inputs, valuable protected resources, changed source and prior gaps first; use canonical coverage ID order for ties. Stop assigning hunters when the remaining budget cannot cover critics and validation. Mark untouched work `deferred` with an exact reason. Validate candidates in fingerprint order while budget remains; never silently exceed a strict budget.

If a required critic or candidate verifier cannot run, set `run_status: "incomplete"` and an exact `incomplete_reason`. An unvalidated lead stays only in the ledger, not in findings under any verdict. The partial report identifies its fingerprint, linked units and missing review. Narrowing or closing a run does not erase unfinished coverage.

## Phase 1: Map the source and plan coverage

The parent normally reads source once to establish:

1. Product, principals, ordinary authority, protected resources, entrypoints and major input-to-sink paths.
2. Strongest source-visible validation, identity, ownership, normalization, lifecycle and resource controls, including sibling and fallback paths.
3. Stack, packaging and local test commands; present toolchains, required writes and prohibited network/shared-service effects.
4. What source cannot establish about deployment or host enforcement, and whether the required sandbox and evidence-promotion controls are available.

Delegate a specific unmapped subsystem only when it merits separate reading. Recon agents return source facts with repository-relative file:line references; they do not execute targets or write shared files. Do not launch four agents to obtain four views of the same small executable.

Write a concise `architecture.md` (at most about 1,000 words, no minimum). Include the facts above, starting paths, meaningful comparable-software calibration if locally documented, selected companions and prior coverage consequences. A baseline that shares a defect never disproves it.

Select companion files by a source-visible boundary in their `When to use this file` section, not a language or dependency name. Record global domain exclusions once here, with the fact that excludes them. Do not repeat every irrelevant web/cloud/binary block in every ledger unit.

### Local execution preflight

Before the first target-controlled command, verify one existing sandbox/toolchain can enforce all controls in [SKILL.md](SKILL.md#universal-execution-safety). Record the exact invocation, limits and safe environment allowlist; reuse it while those facts hold. Run one small existing case before writing a harness. Use locally available dependencies only. Missing capabilities block execution, not source review; record the precise gap rather than installing tools or building replacement infrastructure.

### Write isolation

Each executing agent gets `<output-dir>/agents/<agent-id>/scratch/` and parent-owned `artifacts/`. Canonical agent IDs match `^[a-z0-9][a-z0-9_-]{0,63}$` and are not Windows device names (`con`, `prn`, `aux`, `nul`, `com1`–`com9`, `lpt1`–`lpt9`). Read-only workers need no empty scratch scaffolding.

Agents never edit target source, shared run files, retained artifacts or another agent's directory. Target processes see only their assigned scratch as writable; do not expose retained output, credentials, host homes, sockets or shared services.

Only trusted parent-side code promotes minimum non-secret evidence. Before execution, open and retain trusted, non-inheritable directory descriptors for scratch and artifacts; predeclare scratch-relative filenames, per-file and cumulative byte limits. Do not pass these descriptors into the sandbox. After the sandbox and all its processes terminate:

1. Reject absolute, empty, `.`, `..` or symlinked path components.
2. Walk source parents from the retained scratch descriptor with no-follow directory-relative operations; never reopen by pathname.
3. Open each allowed leaf no-follow and nonblocking; require a regular file, link count one and size within both limits.
4. Bound descriptor reads again, copy exactly the verified size, repeat `fstat`, and reject a changed identity, type, link count or size.
5. Walk destination parents from the retained artifacts descriptor no-follow. Exclusively create and verify any missing real directories.
6. Exclusively create the destination leaf no-follow; verify regular type and link count one, then copy without reopening either path.
7. Use equivalent race-safe APIs on non-POSIX systems. If unavailable or any check fails, discard the scratch entry; decisive evidence remains `needs_validation` with the exact blocker.

Never glob or recursively copy scratch, extract archives into artifacts, or promote links, special files, hard-linked, changing or oversized entries. Never capture ambient environment, credentials, authentication state or unrelated host paths. Record only safe allowlisted variables needed to reproduce the check.

This is the single promotion procedure. Workers reference it; prompts do not copy it into every assignment. Source-only work uses no artifact.

## Prior-run input

Read compatible prior metadata, ledger and findings for this repo, and compare each relevant source path, condition and control:

- Unchanged confirmations enter current independent validation with the same fingerprint and `prior_confirmed_same_source`; exclude only that unchanged root cause from hunting.
- Changed confirmations, prior `needs_validation`, deferred, blocked and now-in-scope work become current planned work. Recheck a prior unresolved trace before carrying it; an old verdict is not current proof.
- An unchanged rejection suppresses only that exact claim; new evidence or a changed failed prerequisite reopens it.
- Same-source covered units remain visible. Prior quick/scoped runs contribute only recorded evidence and gaps; missing or incompatible records are not empty coverage.

Record source refs and prior paths in metadata. Carried records still need fresh candidate verification; that verifier owns a previously unassigned carried-record unit and supplies its first current check. Never imply one pass exhausts a target.

## Deterministic coverage ledger

Keep the existing top-level array contract. Seed material source-derived combinations of surface, boundary, subsystem and attack class; do not create a Cartesian product of unrelated classes. Quick uses the fixed subsystem reference `profile/quick/all-in-scope-subsystems`; deep adds lifecycle only where material.

Each dimension has a human label and stable `canonical_refs` value: repository-relative entry/control/package scope, and an exact `FILE.md#class name` reference. Block names use the heading/bold class text, not a rendered HTML slug; companion section names omit parenthetical qualifiers.

References must be Unicode NFC with valid scalars, visible content, no controls/format/default-ignorable characters or surrounding whitespace. RFC3986-encode their UTF-8 bytes (only letters, digits, `-._~` unescaped; uppercase `%HH`), then join surface, boundary, subsystem, attack_class and optional lifecycle with `::`. Never include line, wave, agent, verdict or severity. Sort by ID; reject duplicates, collisions and aliases rather than merge them.

```json
{
  "coverage_id": "...",
  "canonical_refs": {
    "surface": "src/router.ts#POST /users/:id",
    "boundary": "src/authz.ts#requireOwner",
    "subsystem": "packages/api",
    "attack_class": "ATTACK-CLASSES.md#Access control"
  },
  "surface": "Update-user route",
  "boundary": "Object ownership",
  "subsystem": "API",
  "attack_class": "Access control",
  "starting_paths": ["src/router.ts", "src/authz.ts"],
  "ordinary_attack_class_block": "ATTACK-CLASSES.md#Access control",
  "selected_companion_blocks": [],
  "excluded_blocks": [],
  "prior_status": "none",
  "attempts": [],
  "wave": 1,
  "status": "planned",
  "agent_id": null,
  "reviewed_paths": [],
  "local_checks": [],
  "result_fingerprints": [],
  "unresolved": []
}
```

Add both human and canonical lifecycle fields when used. Ordinary block is null only if none applies. Selected companion blocks include the chosen class and its Core discipline, Universal moves and Validation rules. Per-unit `excluded_blocks` contains only material, unit-specific omissions; use `[]` when there are none. Global inapplicable domains live once in architecture, not as repeated negative matrices.

`prior_status` accepts `none`, `new`, `prior_confirmed_same_source`, `prior_confirmed_changed_source`, `prior_needs_validation`, `prior_deferred`, `prior_blocked`, `prior_out_of_scope`, `prior_covered_same_source`, `prior_covered_changed_source` and `prior_rejected_claim_changed`. Use none without compatible prior coverage, new for a new surface in a repo with prior coverage. Additional parent bookkeeping fields are allowed.

| Status | Assignment owner | Paths/checks | Fingerprints | Unresolved |
|---|---|---|---|---|
| planned | null | empty | empty | empty |
| not_applicable, out_of_scope, deferred | null | empty | empty | nonempty reason |
| in_progress | canonical ID | empty | empty | empty |
| blocked | canonical ID | nonempty partial evidence | empty | nonempty blocker |
| covered | canonical ID | nonempty | empty | empty |
| candidate | canonical ID | nonempty | nonempty | optional |

Every check has its own canonical `agent_id`, nonempty repository-relative `reviewed_paths`, invariant, method, result and artifact. Unit paths equal the union of check paths. Source method requires artifact:null. Local method requires a parent-promoted regular file under exactly `agents/<check.agent_id>/artifacts/`; scratch, output-root and another owner's files are not evidence.

Before reopening a covered, candidate or blocked unit, append its exact wave, status, owner, paths, checks, fingerprints and unresolved facts to `attempts`, adding a source-backed `reassignment_reason`. Increment wave, use a fresh owner and empty live evidence. Archived waves strictly increase below the live wave. Preserve prior owners/artifacts only in their archived attempt; never mix them into the replacement. If reassignment cannot run, archive first, then leave the new wave unassigned/deferred with an exact reason.

Validate after seeding, each consolidated update and before reporting:
`node <skill-dir>/validate-coverage-ledger.cjs <output-dir>/coverage-ledger.json`.
The validator bounds bytes, nesting, collection sizes and diagnostics. A pass proves structure, not source coverage.
