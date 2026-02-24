# Coding Style Guidelines

This project uses Swift with SwiftLint. Keep diffs minimal and match nearby code.

These rules are spelled out here mainly for the benefit of AI tools.

## Core Conventions
- Braces: same line for control flow; own line for functions, types, and extensions.
- `else`/`catch`: always on a new line.
- Layout: target ~80 characters (soft limit 83); indent with two spaces; wrap by one extra indent level.
- Whitespace: avoid trailing whitespace except on intentionally indented blank lines; leave a blank line after contiguous `let`/`var`/`guard` groups before other code; do not rewrap untouched lines.
- Switches: indent `case`/`default` contents.
- Prefer `isEmpty` over `count == 0`; prefer direct `contains`/`first(where:)` over `filter`-based checks.
- Use `force_try`/`force_cast` only when justified; keep usage rare and explicit.

## SwiftLint Behavior (from `.swiftlint.yml`)
- Allows:
  - trailing whitespace on indented blank lines
  - braces on their own line for types/functions
  - closure parameters on their own line
  - optional trailing commas
  - TODOs allowed
- Spacing:
  - closures should have a space before `{`
  - uncuddled `else`/`catch` on a new line
  - `return` may be omitted in simple closures/getters when clear
- Collections:
  - prefer `contains`/`first(where:)` over `filter` + checks
  - prefer `isEmpty` over `count == 0`
- Thresholds:
  - line length soft cap ~83
  - file/type body ~500 lines
  - function body ~60 lines
  - shallow nesting (warn ~3 levels)
  - large tuples discouraged beyond 5 elements
- Casting/try:
  - `force_try` is only a warning
  - use `force_cast` sparingly and justify

## Workflow Tips
- SwiftLint runs on build if installed; keep changes lint-clean.
- Favor small, focused diffs; avoid formatting unrelated code.
