# Skill Update Policy

Self-improvement is controlled improvement, not automatic self-modification.

## Required Before Any Mutation

1. Identify the authoritative rule or workflow being improved.
2. Show the evidence that the current behavior failed or repeated.
3. Propose the smallest durable change.
4. Explain conflicts with AGENTS.md, governance docs, tests, scripts, or current code.
5. Define rollback.
6. Request explicit user approval.

## Allowed Proposal Targets

- Skill instructions or references.
- Templates used by skills.
- Tests or characterization tests.
- Audit scripts with bad/good fixtures.
- Existing governance docs, when the change belongs there and the user approves.
- Follow-up entries, when the issue is real but out of current scope.

## Disallowed Behavior

- Do not edit skills, rules, scripts, tests, or source silently.
- Do not create a second root rule file.
- Do not claim higher priority than AGENTS.md or repository governance.
- Do not use pure review sessions to mutate files.
- Do not convert a one-off preference into a global rule without evidence.
- Do not store secrets, private user data, full logs, or unnecessary trace content.
