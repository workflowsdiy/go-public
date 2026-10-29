---
name: security-audit
license: MIT
description: Focused security reviews by default. Use for vulnerability reviews and audits; comprehensive coverage, pen-test workflows and structured reports are explicit opt-ins.
---

# Security Audit

Find concrete trust-boundary failures and the smallest effective source fix. Review source; do not modify the target unless the user requests fixes.

## Default: focused review

Use this light path for small cohesive targets, specific security questions and ordinary requests to "audit" a repo. State the reviewed revision, scope and partial coverage. The word "audit" alone does not activate the comprehensive workflow.

1. Read the source once to map lower-trust inputs, their ordinary authority, protected resources and the controls between them.
2. Trace the most consequential paths to their actual sinks. Check the strongest preventing control and relevant sibling, fallback and failure paths.
3. For each lead, establish actor, starting capability, accepted input, complete source path, crossed boundary, affected resource and minimum observable result. Separate security impact from correctness bugs and same-principal cost.
4. Obtain the smallest decisive observation under the execution rules below. Use existing tests or a bounded dummy fixture. Missing sandbox or runtime/deployment facts remain precise validation blockers; they do not trigger a larger audit.
5. Give candidates and raw evidence to one fresh verifier who did not hunt them. Batch related candidates when practical. The verifier rereads source, attempts refutation, requests any decisive safe check and verifies the final disposition, conditions, severity and narrow fix. No candidates means no verifier.
6. Report in chat: confirmed issues, exact validation blockers, source locations, demonstrated conditions/result, suggested fix/regression check and important review limits. Zero issues is valid.

Do not create a run directory, architecture file, ledger, canonical IDs, schema output, coverage critics or report files for this path. Do not read comprehensive-workflow resources merely to perform a focused review. Read only relevant [attack classes](ATTACK-CLASSES.md) or companion sections when the source reveals that boundary.

## Evidence and priority

Use **confirmed** only for a complete source path plus a meaningful bounded observation across a stated boundary, with no visible preventing layer. A fresh verifier must check that claim before it is reported as confirmed.

Use **needs validation** only for a source-grounded lead with a decisive missing fact and an exact safe resolution plan. Give it no severity. Reject source-refuted claims; do not preserve speculation as a blocker or report an ordinary integrity bug as a security finding.

Only confirmed findings receive severity. Likelihood and impact reflect the demonstrated conditions; overall severity cannot exceed demonstrated impact. Do not turn a crash into execution, local delay into a shared outage, or intentional authority into privilege gain. Consult [severity calibration](VALIDATION-AND-REPORTING.md#severity-calibration) only when needed.

## Universal execution safety

These controls apply to focused and comprehensive reviews. Run target-controlled builds, tests, processes, browsers, emulators, fuzzers and fixtures only in an OS-enforced sandbox with:

- no external network; isolated loopback only when needed for the local fixture;
- an empty environment populated from a safe explicit allowlist, with scratch-local HOME, temporary directories and caches;
- read-only source and toolchain, scratch-only writes, and no host homes, credentials, sockets, other agents' directories or shared services exposed;
- explicit low CPU, memory, process, file-size, disk and wall-clock limits.

Use present tools/dependencies and dummy data. Do not install or fetch dependencies, contact deployments or external services, use real identities, stress shared resources, publish artifacts or continue past the minimum effect. If any control is unavailable, do not execute: continue source review and name the exact missing capability. An isolated disposable source copy is allowed when a build must write beside source.

In focused mode, retain no target-controlled files; return observations in chat and clean up scratch. Comprehensive mode retains minimum evidence only through the parent-owned [promotion procedure](RECONNAISSANCE.md#write-isolation).

## Explicit comprehensive workflow

Use the [comprehensive workflow](RECONNAISSANCE.md) only when the user asks for full/comprehensive coverage, a pen test, structured audit records or longitudinal coverage tracking. Explain focused-review limits on a larger target; do not silently expand scope. This workflow retains its ledger, critics, schema validation and profile-specific independent reviews.
