# Archived Design Export — Read Only When Explicitly Targeted

> **OHANA REPO NOTICE (overrides the instructions below):** Inside this
> repository, the UI source of truth is `ui规范.selection.json` (root) plus the
> shared Swift components (`OhanaDesignSystem.swift`, `OhanaFormControls.swift`,
> `ScaleButtonStyle`, `GoMotion`, sheet/popup helpers). This bundle is a design
> REFERENCE exported from Claude Design — use it for inspiration and intent,
> but do NOT implement it "pixel-perfectly" if that conflicts with V4 tokens.
> When in conflict, translate the idea into existing V4 tokens or stop and ask.
> See `AGENTS.md` → "UI Design Source of Truth".

Do not load this bundle for ordinary Ohana implementation or review work. Read
the transcripts and prototype files only when the current user explicitly asks
to inspect this historical export or create an external artifact from it. This
bundle has no authority over product behavior, native SwiftUI structure,
accessibility, localization, or current UI tokens.

This is a **handoff bundle** from Claude Design (claude.ai/design).

A user mocked up designs in HTML/CSS/JS using an AI design tool, then exported this bundle so a coding agent can implement the designs for real.

## What you should do — IMPORTANT

**When the task explicitly targets this export, read the chat transcripts
first.** There is 1 historical transcript in `ohana-design-system/chats/`.
Treat it as dated design context, not current product authority.

Then inspect only the task-relevant files under `ohana-design-system/project/`
and their imports. Revalidate every production decision against `AGENTS.md`,
`docs/specs/product-foundation.md`, and `ui规范.selection.json`.

**If anything is ambiguous, ask the user to confirm before you start implementing.** It's much cheaper to clarify scope up front than to build the wrong thing.

## About the design files

The design medium is **HTML/CSS/JS** — these are prototypes, not production
code. They may inform an explicitly requested artifact, but they are not a
pixel-perfect contract for the native app. Translate accepted ideas into the
current Ohana tokens, components, platform behavior, and accessibility rules.

**Don't render these files in a browser or take screenshots unless the user asks you to.** Everything you need — dimensions, colors, layout rules — is spelled out in the source. Read the HTML and CSS directly; a screenshot won't tell you anything they don't.

## Bundle contents

- `ohana-design-system/README.md` — this file
- `ohana-design-system/chats/` — conversation transcripts (read these!)
- `ohana-design-system/project/` — the `Ohana Design System` project files (HTML prototypes, assets, components)
