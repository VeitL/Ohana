# Pow Animation Notes for Ohana

Source: `EmergeTools/Pow` on GitHub.

This is an implementation memory note, not a vendored dependency. Pow is useful because it names small, reusable SwiftUI effects clearly: a value changes, and the affected view responds with a meaningful visual or haptic cue. In Ohana, keep that idea but implement only token-driven helpers inside the app.

## Patterns to Reuse

- Change effects: trigger motion from a value change instead of from unrelated state. Use this for task status, reward balance, selected item, errors, and confirmation.
- `spray` / `rise`: use only for rare rewards, gacha, achievement unlock, and treat celebrations. Avoid particle clutter on high-frequency care cards.
- `ping`: use for attention, newly assigned tasks, pending confirmations, and count badges.
- `shake`: use for validation errors, failed purchase, locked privacy, and wrong PIN feedback.
- `shine`: use for newly equipped items, newly available actions, confirmed rewards, and success states.
- `spin` / `jump`: use sparingly for playful icons such as gacha, app icon selection, and reward reveals.
- Pop/blur/boing transitions: adapt to Ohana overlays, toasts, reward chips, and small insertions. Keep page navigation calm.

## Ohana Adaptation Rules

- Do not import Pow unless the user explicitly requests adding it as a package dependency.
- Use `GoMotion` tokens and `OhanaMotionEffects.swift` helpers first.
- Effects must have a semantic purpose: reward, attention, success, error, or state transition.
- Respect Reduce Motion. Decorative shine, ping, and shake must become static or very subtle.
- Avoid long-running particle systems in scrolling pages, Task Center, home cards, and settings.
- Keep the UI V4 rule: smooth continuity, no hard cuts, but no noisy motion on dense views.

## Project Helpers

Use these app-native helpers instead of rewriting page-local variants:

- `ohanaPhasePop(trigger:)`
- `ohanaBreathingGlow(accent:isActive:)`
- `ohanaMarchingBorder(accent:cornerRadius:isActive:)`
- `ohanaSymbolPulse(trigger:)`
- `ohanaPing(trigger:accent:isEnabled:)`
- `ohanaShine(trigger:cornerRadius:isEnabled:)`
- `ohanaShake(trigger:amount:isEnabled:)`
- `AnyTransition.ohanaPop`
- `AnyTransition.ohanaSoftBlur`

## Suggested Mapping

- Purchase success: numeric text transition + shine + light toast pop.
- Balance change: `contentTransition(.numericText())` + phase pop.
- Pending family task review: ping on the reward chip.
- Wrong PIN or insufficient balance: shake the action area and show a compact toast.
- New reward item equipped: marching border + shine.
- Task Center system-journey item: breathing glow only when action or reward is ready.
