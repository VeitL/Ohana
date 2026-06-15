# Evaluation Policy

An improvement is not proven by intent. It needs evidence matched to scope.

## Acceptable Evidence

- A failing test or fixture that now passes.
- A bad fixture caught by an audit and a good fixture allowed by the same audit.
- A checklist item tied to an observed miss and used in a later task.
- A command output proving the relevant gate passed.
- A before/after comparison showing the repeated user correction no longer occurs.

## Evidence Rules

- Match the check to the claim. A path-specific check cannot prove whole-repo behavior.
- Prefer deterministic checks over prose reminders.
- Include both positive and negative examples when adding an audit.
- Treat missing, indirect, or uncertain evidence as not proven.
- Keep validation cheap when the change is docs or skill-only; do not run app builds unless app code, project configuration, or user request requires it.

## Proposal Language

Avoid: "The agent should remember to be more careful."

Prefer: "When a task touches member write paths, require a writeKind table before edits; missing ambiguous classifications must stop for user approval."
