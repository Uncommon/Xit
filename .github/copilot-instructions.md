# GitHub Copilot / Copilot Chat instructions for Xit

Short purpose
-------------
Xit is a native macOS Git client written primarily in Swift and Cocoa (AppKit) with a small Objective-C/Bridging-Header surface and a bundled libgit2 C dependency. Use these instructions to help produce focused, repository-aware suggestions, edits, and tests that fit the project's conventions.

Quick plan for assistant responses
---------------------------------
- Prefer short, actionable answers. When code changes are required, prepare edits that can be applied with single-file patches (not whole-file rewrites) and reference the exact file(s) changed.
- When asked to implement features or fixes, produce: (1) a short checklist of steps, (2) the minimal file edits, and (3) tests or a verification command to run.

Primary languages & frameworks
------------------------------
- Swift (macOS AppKit)
- Objective-C headers / bridging (see `Xit-Bridging-Header.h`)
- C (libgit2) included under `libgit2/` and `libgit2-mac.a`
- Tests use XCTest in the `XitTests/` target

Environment & build notes
-------------------------
- This is a macOS app. Prefer an up-to-date Xcode for local builds.
- Typical local workflows:
  - Open the workspace/project in Xcode and build/run the `Xit` scheme.
  - Example CLI build (may need to be adapted to local Xcode version and signing):
    - Build: `xcodebuild -project Xit.xcodeproj -scheme Xit -configuration Debug build`
    - Run tests: `xcodebuild -project Xit.xcodeproj -scheme Xit -configuration Debug test`
  - If libgit2 needs rebuilding, run `./build_libgit2.sh` from the repo root.
- Do not change developer team, signing, or provisioning settings in Xcode project files without explicit instruction.

Important files & directories
-----------------------------
- `Xit/` — main app source. Look here first for UI, controllers, models.
- `Xit.xcodeproj/` — Xcode project. `project.pbxproj` contains build settings.
- `Xit-Bridging-Header.h` — Objective-C/Swift bridging declarations.
- `libgit2/`, `libgit2-mac.a`, `build_libgit2.sh` — native libgit2 dependency and helper.
- `XitTests/` — unit tests and test helpers (use these as references and to add tests).
- `Xcode-config/` — shared xcconfig files (teams, settings).
- `README.md`, `CONTRIBUTING.md`, `Usage Notes.md` — project-level documentation.

Coding style & conventions
-------------------------
- Follow the existing Swift style in the `Xit/` tree and as indicated by .swiftlint.yml. If unsure, mirror adjacent files in the same folder.
- Prefer small, well-scoped methods. Keep UI code separated from model/business logic where possible.
- Use descriptive names for functions and variables; follow Swift capitalization conventions (camelCase for methods/props, UpperCamelCase for types).
- When touching Objective-C bridging or C-based libgit2 code, prefer minimal surface changes and add clear comments. libgit2 should only be changed on rare occasions since it is a 3rd party library.
- When adding tests: use `XitTests/` and XCTest; include both a happy-path test and at least one edge-case test where practical.

Common tasks & how to run them
------------------------------
- Build in Xcode: open `Xit.xcodeproj`, select the `Xit` scheme, and click Run.
- CLI build: `xcodebuild -project Xit.xcodeproj -scheme Xit -configuration Debug build`
- Run tests in Xcode: select the `XitTests` scheme / test target and run tests.
- CLI tests: `xcodebuild -project Xit.xcodeproj -scheme Xit -configuration Debug test`
- Rebuild libgit2: `./build_libgit2.sh` (may require specific dev tools installed)

How the assistant should generate code edits
-------------------------------------------
- Prefer single-file edits using patch-style diffs. When providing changes, reference the file path and explain the minimal rationale.
- Avoid wholesale file rewrites. Use `// ...existing code...` markers when describing edits in plain text.
- If creating new files, include comments that explain usage.
- When adding or changing public API, include a small unit test in `XitTests/` demonstrating the behavior.
- Always provide commands to run to verify changes (build and tests).

Example prompts (good)
----------------------
- "Implement an XCT test in `XitTests/SidebarDataModelTest.swift` that covers empty repo handling and assert the model returns an empty list." — Answer should include a short checklist, the unit test file edits, and the xcodebuild test command.
- "Refactor `Sidebar/SidebarController.swift` to move data loading into a separate `SidebarDataLoader` class. Provide the small class, updated controller file edits, and tests." — Provide minimal, focused edits and tests.
- "Fix a crash that happens when opening a repo with a missing `.git` folder — where would you look and what minimal patch would you propose?" — Provide investigative steps, file locations, and a small suggested fix.

Example prompts (bad / avoid)
-----------------------------
- "Rewrite the entire project to SwiftUI." (too broad; ask for a scoped migration plan instead)
- "Change the signing identity to X" (do not change team/signing without explicit instruction)

Assistant behavior and tone
---------------------------
- Be concise and pragmatic. Show only what's necessary to accomplish the request.
- Reference specific files and line ranges when possible.
- When uncertain about versions or CI details, ask a single clarifying question rather than guessing.
- If multiple solutions exist, provide the simplest safe option first, then optional improvements.

Security, licensing & forbidden actions
--------------------------------------
- Never exfiltrate or commit secrets (API keys, keychain credentials, provisioning profiles).
- Do not modify licensing files (`COPYING`, `LICENSE`) or the `AUTHORS` list without explicit instructions.
- Do not change Xcode project signing/team/entitlements unless asked and authorized.
- Avoid network calls in suggested patches (downloading dependencies) unless the user explicitly requests them and provides credentials or permits network access.

Minimal PR changelog template
-----------------------------
Title: short summary (50 chars max)

Body:
- What changed (1–2 bullets)
- Why (1 bullet)
- How to test (commands or steps)
- Related files: list changed files

Example:
Title: Fix sidebar crash when repository missing .git

Body:
- Avoid crash by validating repo path before creating repository object
- Prevents NSException when file system layout is unexpected
- Test: open `Xit` in Xcode and run `XitTests/SidebarDataModelTest` or run `xcodebuild test -project Xit.xcodeproj -scheme Xit -configuration Debug test`
- Files: `Sidebar/SidebarController.swift`, `XitTests/SidebarDataModelTest.swift`

Small housekeeping & conventions
-------------------------------
- If you update Swift APIs or add dependency code, also add or update unit tests in `XitTests/`.
- Keep commit messages short and focused. Use present-tense verbs: "Fix", "Add", "Refactor".

---

Last updated: 2026-01-24
