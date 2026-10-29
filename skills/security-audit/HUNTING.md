# Vulnerability Hunting

## Phase 2: Run coverage-led hunting waves

Assign material planned units to the parent or focused workers. One owner may cover related units in one subsystem. Change assignments to in_progress with a canonical owner; only the parent updates shared files. Use the priority and budget rules in [RECONNAISSANCE.md](RECONNAISSANCE.md#cost-budget).

## Compact worker assignment

Send only:

- Goal, exact coverage IDs, boundary, starting paths, assigned block references and peer/excluded root causes.
- Relevant architecture facts; absolute paths to this skill's instructions and referenced source material.
- Read-only role, or an explicit approved execution plan with scratch root, limits and parent promotion allowlist.
- The structured result contract below.

The worker reads the actual selected ordinary attack-class block and companion Core discipline, chosen classes, Universal moves and Validation rules. Supply exact file paths and section names, not vague topic names. If it cannot read a resource, paste only the required block. Do not paste the entire ledger, all schema branches, unrelated companions or repeated global exclusions. Keep prompts readable rather than serialize large maps onto one line.

## Hunting method and candidate gate

Trace the assigned lower-trust input through parsing, normalization, identity, authorization, lifecycle, derived copies and the actual sink. Compare sibling, legacy, batch, retry, cancellation and failure paths where they can affect the same invariant. Name the strongest preventing control before proposing a bypass.

For each lead establish principal, starting capability, accepted input/action, intended control, complete source path, affected resource and smallest observable effect. Check boundary disagreements and relevant absent/duplicate/stale/concurrent/error states only where accepted by the interface. Stop when the invariant is settled; return a disposition instead of continuing to expand harm.

Use [SKILL.md](SKILL.md#universal-execution-safety) for every target-controlled command and [Write isolation](RECONNAISSANCE.md#write-isolation) for evidence. Workers can ask the parent to execute the smallest existing test or dummy fixture. No live traffic, installation, credentials, shared resources, stress testing or work beyond the minimum effect. Missing sandbox/promotion capability blocks execution; it does not erase a source-grounded trace.

- Proposed confirmed requires a complete source path, bounded observed result, meaningful boundary impact, conditions and no visible preventing layer.
- Needs-validation requires a specific decisive fact unavailable from source/local observation and an exact safe plan; never assign severity.
- Source refutation is rejection; a missing best practice or ordinary same-principal cost is excluded/hardening.
- Do not strengthen a crash into execution, one local process delay into a shared outage, or intentional authority into privilege gain.
- Reuse one stable fingerprint per root cause: `^[A-Za-z0-9][A-Za-z0-9._:/@+-]*$`, without line, wave, agent, verdict or severity.
- For a high/critical reusable cause, check variants within owned units; return other boundaries as uncovered rather than duplicate peer work.

## Structured hunter result

Return one JSON object:

```json
{
  "units": [{
    "coverage_id": "assigned ID",
    "disposition": "covered|candidate|blocked",
    "reviewed_paths": ["repo/relative/path"],
    "checks": [{
      "agent_id": "canonical owner",
      "reviewed_paths": ["repo/relative/path"],
      "invariant": "specific control checked",
      "method": "source|local",
      "result": "what was established",
      "artifact": null
    }],
    "candidate_fingerprints": [],
    "unresolved": []
  }],
  "candidates": [],
  "hardening": [],
  "uncovered": [{
    "surface": "...",
    "boundary": "...",
    "subsystem": "...",
    "attack_class": "...",
    "starting_paths": ["repo/relative/path"],
    "reason": "source-backed coverage gap"
  }]
}
```

Each assigned ID appears exactly once. Covered needs nonempty owned paths/checks and no candidate/blocker. Candidate needs owned evidence and linked fingerprints. Blocked needs owned partial evidence and an exact blocker, without fingerprints. Unit paths equal the union of check paths. Source checks use artifact:null; local checks use a successfully parent-promoted `agents/<check.agent_id>/artifacts/file`.

Read the relevant branch in [report-schema.json](report-schema.json) for each candidate, using proposed_verdict instead of verdict. A proposed confirmation includes root_cause, intended_behavior, conditions, target-native execution, remediation, severity and confidence. A validation lead instead uses claimed_root_cause, blockers and an applicable local/deployment validation_plan. Both need fingerprint, title, description, ordered trace and evidence. Empty candidates is a valid result.

Trace/evidence files are repository-relative source paths with positive lines. Artifact paths belong in checks, or as observations in execution/description, never in source-citation arrays. A multi-step trace starts at entrypoint and ends at sink; intermediate entries are propagation. See [evidence paths](VALIDATION-AND-REPORTING.md#source-and-artifact-paths).

## Parent consolidation and failure recovery

Validate returned IDs, ownership, path unions, checks and promoted artifacts before updating the ledger. Copy checks into local_checks; retain concrete hardening notes as bookkeeping. Deduplicate candidates by source-derived root cause and stable fingerprint, not by title.

Process valid completed units independently of a failed worker's remaining assignment. No complete result means no covered claim. Keep an unreviewed unit planned, or deferred at close-out; keep valid owned partial evidence blocked. Preserve a partial lead as unconfirmed until independently re-established.

For a format-only problem, return concise validation errors to the same worker once; do not create a fresh agent merely to repair JSON. Never repair substantive evidence or a verdict by assumption. If the worker remains unavailable, the parent may finish source review or assign a narrowly scoped replacement. Record platform/policy blocks accurately; do not disguise or retry a prohibited action. A safe static review does not establish an unobserved runtime effect.

Consolidate ledger updates in batches and run its validator before further assignments. A user request to finish the existing leads triggers close-out: stop new hunting, record unfinished coverage, then validate the known leads and report them.

## Coverage critics

After a hunting wave, one fresh read-only critic receives concise architecture facts, the ledger path, current candidate states and prior gaps. It reads the ledger/source directly; do not embed the full ledger in its prompt. It checks unmapped inputs, sibling/lifecycle paths, unjustified exclusions, closed units without evidence and prior unresolved work. It proposes coverage rather than findings:

```json
{
  "missing_units": [{
    "surface": "...",
    "boundary": "...",
    "subsystem": "...",
    "attack_class": "...",
    "starting_paths": ["repo/relative/path"],
    "selected_companion_blocks": [],
    "excluded_blocks": [],
    "reason": "source-backed gap"
  }],
  "reassign_ids": [],
  "resolved_prior_leads": [],
  "stop": true
}
```

Stop may be true only with no missing units/reassignments. The parent validates scope, canonical IDs and reasons; collisions fail rather than merge. Reopening evidence-bearing units uses the archive rules in RECONNAISSANCE. Resolve a prior lead only with a recorded source-backed reason.

Quick has one pass and one critic; record accepted gaps/reassignments as deferred (`quick_profile_final_critic`) rather than launch another wave. Standard's no-work critic is the final critic. Deep additionally requires a distinct final-clean critic. If another wave is authorized, funded and needed, queue its accepted work in priority order, preserving critic and verifier reserves.

An early close-out may omit a critic, but must mark the run incomplete and name the missing coverage review. Do not let worker counts, failed calls or a stop flag stand in for coverage evidence.
