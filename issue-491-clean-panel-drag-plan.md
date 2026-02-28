# Plan: Clean Panel Drag-Out (Issue #491)

## Objective
Enable dragging files from the Clean panel to Finder/other apps by exporting selected items as file URLs while preserving existing Clean behaviors.

## Context & Assumptions
- Clean panel is backed by `CleanList` (NSTableView) and coordinated by `CleanPanelController`.
- Rows represent repo paths (files/directories), already known relative to the working tree.
- Multi-selection is supported; drag should use the current selection, or the clicked row if it is not selected (Finder-like behavior).
- App uses Swift/AppKit; repository path resolution is available (e.g., `repository.fileURL(_:)`).

## Implementation Status
- ✅ Drag registration for file URLs in `CleanList` setup.
- ✅ Pasteboard writers emit file URLs using a resolver threaded from `CleanPanel`/`CleanPanelController`.
- ✅ Add drag source masks (copy/move) and clicked-row vs. selection handling.
- ⏳ Refresh Clean list after move operations via `draggingSession(_:endedAt:operation:)`.

## Proposed Implementation
1) **Register drag types** (done): In `CleanList` table setup, register `NSPasteboard.PasteboardType.fileURL` (or UTType.fileURL) for drag-out.
2) **Provide pasteboard writers** (done): Implement `tableView(_:pasteboardWriterForRow:)` (or `tableView(_:writeRowsWith:to:)`) to return writers that expose absolute file URLs for the row. Support multiple selected rows.
3) **Resolve file URLs** (done): From `CleanList.Coordinator`, use a resolver provided by `CleanPanelController` (closure/delegate) that maps repo-relative paths to absolute URLs via the repository.
4) **Drag source masks** (done): Implement `draggingSession(_:sourceOperationMaskFor:)` to allow `.copy` (and optionally `.move` if appropriate). Use table-provided drag images; ensure selection is preserved on drag start.
5) **Handle clicked vs. selection** (done): If the drag begins on an unselected row, treat that row as the drag set; otherwise use the current selection.
6) **Missing paths policy** (decided): Items are expected to exist on disk; no extra guards beyond resolver are needed.
7) **Post-drag updates on move**: In `draggingSession(_:endedAt:operation:)`, if the operation includes `.move`, refresh/reload the Clean list (or re-query the repo) to remove moved items and reflect new state.

## UI/UX Notes
- Rely on NSTableView’s default drag image; optional `draggingSession(_:willBeginAt:)` if cursor/image tweaks are needed.
- Support directories and files uniformly via file URLs.

## Testing Approach
- **Unit**: In `XitTests`, add a test using `FakeRepo` to populate `CleanList`, call the pasteboard writer(s), and assert the pasteboard contains expected file URLs for multi-row selection.
- **Optional UI**: UITest that opens Clean panel, selects items, starts a drag toward a dummy target, and inspects pasteboard/file URL contents if feasible.

## Decisions
- Assumption: files exist on disk; items should not appear in the Clean list if missing. Drag will surface actual files/directories only.
- Ignored and untracked items are equally eligible for drag-out; no distinction needed for payload eligibility.
