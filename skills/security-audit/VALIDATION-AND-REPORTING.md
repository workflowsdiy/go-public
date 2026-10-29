# Validation, Structured Output, Verification, and Reporting

## Severity calibration

Only confirmed issues receive severity; overall severity cannot exceed demonstrated impact.

- **critical:** unauthenticated code execution, full data-store access or takeover of arbitrary accounts.
- **high:** full defeat of an explicit security control with real consequences, such as cross-tenant access, stored script execution affecting other users, authenticated code execution or an unauthenticated remote stop of a shared service.
- **medium:** a real boundary violation with limited blast radius, uncommon preconditions or consequences confined to narrow resources.
- **low:** non-secret internal disclosure or sustained effort for minimal gain.
- **informational:** a confirmed minimal-impact observation, useful mainly inside a larger finding.

Distinguish full defeat of a control from weakening it. If the concrete damage is unclear, lower the severity. Keep priority separate from confidence and certainty.

The structured workflow below is for comprehensive audits. Focused review uses SKILL.md and reports in chat without schemas or audit artifacts.

## Phase 3: Independently validate every candidate

After coverage review or a recorded early stop, consolidate current and carried candidates by fingerprint/root cause. Give each candidate to a fresh verifier that did not hunt it. The parent may have hunted it; the independent verifier may not. Send the candidate, relevant source/architecture facts, linked checks/artifact paths, exact relevant companion validation sections and paths to this file, SKILL.md and report-schema.json. Do not provide another verifier's conclusion or unrelated records.

The verifier re-reads every cited source location, reconstructs the strongest controls and tries to refute the claimed boundary/impact. Independently reproduce the minimum decisive result when possible, or ask the parent to coordinate it under the approved sandbox. Every execution and retained artifact follows SKILL.md and [Write isolation](RECONNAISSANCE.md#write-isolation); read-only review needs no scratch directories.

Verify:

1. Real lower-trust entry, native input shape and ordered complete source-to-sink path.
2. Every condition, preventing layer, affected principal/resource and actual bounded observation.
3. Realistic likelihood, demonstrated impact, confidence and the smallest effective source fix.
4. For needs_validation, whether the exact blocker is genuinely outside available source/local observation; reject refuted claims rather than park them.
5. Stable fingerprint and the complete schema branch, including source/artifact path separation below.

Return exactly:
```json
{"decision": "confirmed|needs_validation|rejected", "record": {}}
```
The record must match that verdict's branch in report-schema.json. Confirm only a complete path plus meaningful bounded result; reject refutation, impossible prerequisites or absent meaningful security impact. Needs-validation has a decisive missing fact and a safe exact resolution plan, not severity.

## Source and artifact paths

The two namespaces have different purposes:

```json
{
  "source_evidence_example": {
    "file": "src/check.mjs",
    "line": 42,
    "description": "The source executes the admitted pattern."
  },
  "ledger_local_check_example": {
    "agent_id": "verify-regex",
    "reviewed_paths": ["src/check.mjs"],
    "invariant": "Matching terminates within its limit.",
    "method": "local",
    "result": "The bounded dummy input timed out.",
    "artifact": "agents/verify-regex/artifacts/result.txt"
  }
}
```

These are examples of nested entries, not extra finding fields. Trace/evidence file values always identify repository-relative current source; never place an absolute path or an output artifact there. Describe retained runtime observations and their output-relative artifact paths in execution.observed_result (or description/reason for non-confirmed branches). A source-only ledger check has artifact:null. Only a parent-promoted local artifact can support method:local.

## Phase 4: Write and validate findings.json

The parent validates each verifier response immediately, before another handoff. Read report-schema.json before writing; its branches have additionalProperties:false.

- Confirmed uses root_cause, intended_behavior, conditions, execution, remediation, severity and confidence. Execution names the native interface, minimum actual input/invocation and factual observed_result.
- Needs-validation uses claimed_root_cause, trace, evidence, nonempty blockers and an applicable nonempty validation_plan.local or validation_plan.deployment. Include both only when each resolves a distinct fact.
- Rejected uses claimed_root_cause, trace, evidence and reason. Retain refuted claims to avoid repeating them without changed evidence.

All branches need verdict, fingerprint, title and description. Never mix branch-only fields. Trace/evidence source locations have positive lines; multi-step traces begin with entrypoint, end with sink and use propagation between them. Overall severity never exceeds demonstrated impact.

Write one record per fingerprint, sorted by fingerprint. Validate:
```sh
node <skill-dir>/validate-findings.cjs <output-dir>/findings.json
node <skill-dir>/validate-coverage-ledger.cjs <output-dir>/coverage-ledger.json
```
The validators bound input sizes, nesting, collection counts and diagnostics. A pass proves format/consistency, not truth.

A format/path error goes back to the same verifier with the validator diagnostic for correction; it does not require a new independent review. Preserve the reviewed claims and identity. Do not invent source evidence, silently change verdict/impact or accept an invalid record. If no valid response is obtained, leave an unresolved ledger candidate and report incomplete. Unvalidated candidates never enter findings under any verdict.

Record the verifier's decision in linked units, adding checks under the verifier's ID and keeping path unions exact. Assignment ownership stays with the hunter; a previously unassigned carried-record unit gets the verifier as its owner.

## Phase 5: Verify the final record

Quick and standard combine this with Phase 3: the independent verifier checks the actual complete record, including remediation and schema, before returning it. Parent formatting and validated serialization do not need another fresh agent.

Deep uses one separate fresh record verifier per confirmed or needs-validation record. It receives that record, raw source/evidence and relevant instructions, without previous verifier discussion. Recheck source locations, real interface/input, conditions, preventing controls, affected resource, observed result, severity and source fix. For needs-validation also recheck that each blocker remains decisive and its plan is exact and safe. Rejected records need no further pass.

Return exactly one:
```json
{"decision": "verified", "fingerprint": "..."}
```
```json
{"decision": "replace", "reason": "...", "record": {}}
```

Any later material replacement that strengthens a verdict or changes root cause, trace, execution input/result, demonstrated impact or severity requires another fresh verifier that neither hunted nor proposed that replacement. Nonmaterial wording/source-line corrections may be applied directly. Never use a formatting correction to introduce stronger claims. Revalidate applied changes; if independent resolution is unavailable, remove the disputed record from findings, keep its unresolved candidate and report incomplete.

## Phase 6: Report and close

Derive prose only from valid independently decided records, ledger evidence and retained hardening notes. The main REPORT.md states source/profile/scope, source/local-only execution, invocation spend versus any budget, prior-run use, confirmed issues, needs-validation leads, concrete non-findings and important coverage/verification limits. Give each confirmed issue its source location, lower-trust principal, exact bounded native reproduction, conditions, result, priority and smallest fix. Do not force an HTTP endpoint or deployment plan onto a local CLI/library.

Include the per-platform check results and unavailable native checks required by [SKILL.md](SKILL.md#universal-execution-safety). Keep compatibility limits visible even when the source review is complete; do not mark missing security validation as covered or remove it from scope to obtain completion.

Create FINDINGS-DETAIL.md only when medium-or-higher findings need the complete trace/reproduction separate from the summary. Create NEEDS-VALIDATION.md only when unresolved records need a separate handoff. Do not create empty placeholder reports or duplicate every record into several files.

Set run_status complete only when all candidate dispositions and required profile reviews are final, all in-scope coverage is resolved under the profile, applicable reports exist and both validators pass. A quick/scoped run still states its partial breadth. Otherwise set incomplete with its exact reason; identify every unvalidated fingerprint, deferred/blocked area and missing review. A partial run may report independently verified findings, but never label unresolved candidates as findings or imply complete coverage.

Stop hunting when asked to close out. Finish the known-lead dispositions that can be settled within scope, report remaining limits explicitly, and remove temporary inputs/build outputs created by the run. Zero confirmed records is a valid result; do not invent low findings to fill a report.
