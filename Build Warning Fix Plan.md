# Build Warning Fix Plan

## Summary

This document captures the current plan for removing the remaining active build warnings in the app target, while also recording larger refactoring options that are intentionally deferred.

With that change already in place, the remaining app-target warnings are expected to be:

- `Xit/FileView/FileViewController.swift`
  - Capture of `repoSelection` with non-Sendable type `any RepositorySelection` in an isolated closure
- `Xit/HistoryView/HistoryTableController.swift`
  - Capture of `history` with non-Sendable type `GitCommitHistory` in an isolated closure
  - Capture of `history` with non-Sendable type `GitCommitHistory` in a `@Sendable` closure

Stale warnings in `XitTests/KeychainTest.swift` were visible in Xcode navigator history, but they did not appear in the fresh app-target build and are not part of this minimal fix.

## Immediate Goal

Remove the remaining app-target warnings with the smallest defensible code change, without redesigning the app's concurrency model.

## Step-by-Step Implementation

### 1. Confirm the warning baseline

1. Build the app target in Xcode or with the existing approved build command.
2. Confirm the only active warnings are the concurrency warnings listed above.
3. Ignore stale navigator warnings unless they reappear in a fresh build log.

### 2. Fix `FileViewController` warning captures

Target file: `/Users/uncommon/Developer/Xit/Xit/FileView/FileViewController.swift`

Current issue:

- `loadSelectedPreview(force:)` builds `FileSelection` values inside `controller.queue.executeOffMainThread { ... }`.
- `StagingType` is already sendable, but the closure still captures `repoSelection`.
- `executeOffMainThread` requires a `@Sendable` closure, so those captures trigger concurrency warnings.

Implementation steps:

1. Keep the existing selection/path gathering on the main thread.
2. Extract only sendable preview inputs before the queue hop:
   - selected file paths
   - whether the preview is a multi-selection
   - any simple booleans or enum values that remain necessary
3. Do not construct `FileSelection` inside the off-main-thread closure.
4. Move `FileSelection` construction into the `Task { @MainActor in ... }` section immediately before `contentController.load(selection:)`.
5. Reuse the already-available main-actor state there:
   - `repoSelection`
   - `stagingType`
Expected result:

- No non-Sendable app model is captured by the queue's `@Sendable` closure.
- Preview loading behavior stays the same.

### 3. Fix `HistoryTableController` / `CommitHistory` warning captures

Target files:

- `/Users/uncommon/Developer/Xit/Xit/HistoryView/HistoryTableController.swift`
- `/Users/uncommon/Developer/Xit/Xit/HistoryView/CommitHistory.swift`

Current issue:

- `loadHistory()` captures `history` inside queue-driven asynchronous work.
- `TaskQueue.executeAsync` takes a `@Sendable` async closure.
- The current `GitCommitHistory` type is a mutable reference type with locks, but it has no concurrency annotation, so the compiler warns when it is captured.

Implementation steps:

1. Keep the current queue-based history loading approach.
2. Reduce closure layering in `loadHistory()` where practical.
   - Prefer one queue-managed async path instead of queue work followed by another background dispatch before returning to main-thread UI updates.
   - Keep the main-thread reload and selection restoration on the main queue.
3. Add `@unchecked Sendable` to `CommitHistory`.
4. Add a short comment beside that annotation stating why the unchecked conformance is currently acceptable:
   - history processing is intentionally shared across queue work
   - mutable state is coordinated through the existing locks / queue discipline
5. Do not attempt to actor-isolate `CommitHistory` in this minimal pass.
6. Do not broaden this change into a repository-wide `Sendable` audit.

Expected result:

- The compiler stops warning about capturing `history` in the queue closures.
- Existing history loading behavior remains intact.

### 4. Rebuild and verify behavior

1. Rebuild the app target.
2. Confirm the warning count for the app target is 0.
3. Manually verify file preview flows:
   - single file selection
   - multiple file selection
   - staged selection
   - unstaged selection
4. Manually verify history flows:
   - initial history load
   - first visible batch processing
   - table reload after refs change
   - selection restoration after load

### 5. Record remaining non-goals

The minimal change set should not attempt to solve:

- the stale Security deprecation warnings in `XitTests/KeychainTest.swift`
- failing `XitTests` target build issues related to SwiftSyntax / macro dependencies
- broader thread-safety inconsistencies in older history code
- actor migration for UI or repository subsystems

## Acceptance Criteria

- Fresh app-target build reports no warnings.
- Preview behavior is unchanged from the user perspective.
- History view still loads, batches, and updates selection correctly.
- The fix does not introduce a wider refactor or API redesign.

## Deferred Deep Refactor Proposals

These are intentionally out of scope for the minimal warning fix, but they are the right follow-up directions if the codebase is going to keep moving toward stricter concurrency checking.

### Proposal 1: Replace unchecked sendability with snapshot-based history processing

Problem:

- `CommitHistory` mixes mutable shared state, UI-facing reads, and background processing.
- `@unchecked Sendable` suppresses warnings but does not improve the underlying design.

Proposed direction:

1. Split history loading into two phases:
   - repository walk produces immutable commit snapshots
   - graph processing produces immutable render/state snapshots
2. Replace direct shared mutation of `history.entries` during processing with batch results returned from background work.
3. Apply those results on a single owner context:
   - either the main actor
   - or a dedicated serial history actor
4. Expose read-only snapshots to the table view instead of exposing mutable storage directly.

Benefits:

- Removes the need for `@unchecked Sendable`.
- Makes visible-state reads safer and easier to reason about.
- Reduces ad hoc locking in table view code.

Costs:

- Requires redesign of `CommitHistory`, `HistoryTableController`, and some table cell assumptions.
- Likely requires new intermediate history DTOs instead of direct `GitCommit` object sharing.

### Proposal 2: Introduce a dedicated `HistoryLoader` actor

Problem:

- `HistoryTableController` currently owns orchestration details that mix UI control, repository walking, batching, and queue management.

Proposed direction:

1. Create a `HistoryLoader` actor responsible for:
   - walking refs
   - building commit batches
   - processing graph connections
   - publishing progress snapshots
2. Keep `HistoryTableController` as a thin UI adapter:
   - request load
   - receive snapshots
   - update table view and selection
3. Remove most explicit `DispatchQueue` usage from history loading.
4. Move remaining synchronization logic behind actor isolation.

Benefits:

- Clear ownership boundary.
- Better fit for modern Swift concurrency than lock-heavy controller code.
- Easier to test loading behavior independently from AppKit.

Costs:

- Medium-to-large refactor.
- Requires careful migration of progress callbacks and selection timing.

### Proposal 3: Redesign file preview loading around sendable request models

Problem:

- `FileSelection` directly embeds `any RepositorySelection`, which couples preview loading to a non-Sendable UI-centric object graph.

Proposed direction:

1. Introduce a sendable preview request model containing only the data needed to load content:
   - repo identifier or repository handle abstraction
   - selected git path
   - staging mode
   - target commit or staging target
2. Make preview controllers consume a resolved content request or snapshot rather than the current `RepositorySelection` object.
3. Keep UI selection models separate from background preview-fetch models.

Benefits:

- Eliminates a repeated source of non-Sendable captures.
- Makes preview work easier to move off the main actor safely.
- Reduces coupling between AppKit controllers and repository-selection state.

Costs:

- Requires API changes across preview controllers.
- May require a new resolver layer between selection state and preview rendering.

### Proposal 4: Add explicit actor annotations for UI controllers and main-thread-only protocols

Problem:

- Main-thread assumptions exist implicitly across `NSViewController` subclasses, callbacks, and shared models.

Proposed direction:

1. Audit controller types and UI-facing protocols for `@MainActor` compatibility.
2. Annotate main-thread-only protocols and controller entrypoints explicitly.
3. Remove older `DispatchQueue.main.async` calls where actor isolation makes them redundant.
4. Leave only true background repository work outside the main actor.

Benefits:

- Compiler-enforced UI isolation.
- Fewer ambiguous closure contexts.
- Easier reasoning about where state is allowed to change.

Costs:

- Requires staged annotation work to avoid a flood of new warnings.
- May expose existing cross-thread assumptions elsewhere in the app.

### Proposal 5: Stabilize the test-target warning/build story separately

Problem:

- The test target currently has unrelated build failures and stale warning history.
- That makes warning cleanup harder to trust over time.

Proposed direction:

1. Fix test-target dependency/module resolution issues first.
2. Rebuild `XitTests` cleanly.
3. Re-evaluate whether `KeychainTest.swift` still emits deprecation warnings.
4. Replace deprecated Security keychain API usage in tests with a supported testing strategy, or explicitly isolate legacy API coverage if the old API must remain under test.

Benefits:

- Restores confidence in warning tracking.
- Prevents stale test-target warnings from obscuring app-target work.

Costs:

- Separate effort from the app-target concurrency cleanup.

## Recommended Follow-Up Order

If deeper work is scheduled later, the safest order is:

1. Stabilize test-target builds.
2. Introduce sendable preview request models.
3. Refactor history loading toward snapshots or a `HistoryLoader` actor.
4. Expand explicit `@MainActor` annotations after the larger data-flow boundaries are in place.

## Notes

- This plan intentionally prefers a bounded warning removal pass over architectural cleanup.
- The deeper proposals should be treated as separate work items with their own validation and rollout plans.
