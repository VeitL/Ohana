# Open SwiftUI Animations Notes for Ohana

Source: `amosgyamfi/open-swiftui-animations` on GitHub.

This is an implementation memory note, not a vendored dependency. Do not copy demo views wholesale into Ohana. Extract animation patterns and adapt them to Ohana's V4 UI tokens, performance rules, and accessibility settings.

## Patterns to Reuse

- `PhaseAnimator` for small, expressive state changes: reaction pops, breathing highlights, icon swaps, and lightweight idle motion.
- `contentTransition(.numericText())` for balances, counters, streaks, prices, and progress numbers.
- `symbolEffect` for SF Symbol feedback: bounce, pulse, breathe, and wiggle on success, notification, reward, and attention icons.
- Spring sequencing for FAB menus and family/member action menus: child items appear one by one with short staggered delays.
- `dashPhase` and `trim` for active borders, loading rings, scan effects, and focused selection states.
- Keyframe or staged spring motion only for high-value feedback such as purchase success, achievement unlock, gacha reward, and milestone celebration.

## Ohana Adaptation Rules

- Always use `GoMotion` tokens first. If a pattern needs a new motion curve, add it as a named token rather than writing one-off spring values in a page.
- Respect Reduce Motion. Ambient loops and decorative effects must fall back to a static view when `accessibilityReduceMotion` is enabled.
- Prefer pure SwiftUI effects. Avoid UIKit emitter layers unless the screen is a rare celebration moment and performance has been verified.
- Keep high-frequency screens calm. Use micro-motion for feedback, not constant large loops.
- Apply animation to meaning:
  - Rewards: pop, numeric transition, small particles.
  - Attention: breathing glow, symbol pulse, moving border.
  - Navigation/FAB: staggered spring entrance.
  - Charts/progress: trim/dash/opacity entry.
  - Settings/forms: only subtle press and state transitions.

## Project Helpers

Use `OhanaMotionEffects.swift` helpers instead of rewriting these patterns:

- `ohanaPhasePop(trigger:)`
- `ohanaBreathingGlow(accent:isActive:)`
- `ohanaMarchingBorder(accent:cornerRadius:isActive:)`
- `ohanaSymbolPulse(trigger:)`
- `ohanaPing(trigger:accent:isEnabled:)`
- `ohanaShine(trigger:cornerRadius:isEnabled:)`
- `ohanaShake(trigger:amount:isEnabled:)`

These helpers are intentionally small and token-driven so they can be used across pages without importing the external demo project.
