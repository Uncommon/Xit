# Liquid Glass Adoption Plan

This plan reflects the current post-merge UI state in this repo.

## Scope
- Included: main window chrome, sidebar, history/file panes, preview surfaces, commit entry/header, operation sheets, preferences, and shared SwiftUI/AppKit UI helpers.
- Excluded: none. Sidebar work is now in scope after the merge from main.

## Files Reviewed
- Main window and title bar:
  - `Xit/Document/XTWindowController.swift`
  - `Xit/Document/XTWindowController+TitleBar.swift`
  - `Xit/Document/TitleBarController.swift`
  - `Xit/Document/XTWindowController.storyboard`
- Sidebar:
  - `Xit/Sidebar/*`
- History and commit list:
  - `Xit/HistoryView/HistoryViewController.storyboard`
  - `Xit/HistoryView/HistoryCellView.swift`
  - `Xit/HistoryView/RefTokenView.swift`
  - `Xit/HistoryView/HistorySearchBar.swift`
  - `Xit/Utils/SwiftUI/HostingTitlebarController.swift`
- File pane and previews:
  - `Xit/FileView/FileViewController.xib`
  - `Xit/FileView/File List/FileListView.xib`
  - `Xit/FileView/CommitEntryController.xib`
  - `Xit/FileView/CommitHeader.swift`
  - `Xit/FileView/Previews/WebViewController.swift`
  - `Xit/html/colors.css`
  - `Xit/html/blame.css`
  - `Xit/html/text.css`
- Operations and dialogs:
  - `Xit/Operations/*.xib`
  - `Xit/Operations/ClonePanel.swift`
  - `Xit/Operations/CleanPanel.swift`
  - `Xit/Operations/SheetDialog.swift`
  - `Xit/Operations/CleanPanelController.swift`
  - `Xit/Operations/ClonePanelController.swift`
- Preferences:
  - `Xit/Preferences/PrefsWindowController.swift`
  - `Xit/Preferences/Preferences.storyboard`
  - `Xit/Preferences/AccountsPrefsPane.swift`
  - `Xit/Preferences/GeneralPrefsPane.swift`
  - `Xit/Preferences/PreviewsPrefsPane.swift`
- Test/AX sensitivity:
  - `Xit/AXIdentifiers.swift`
  - `XitUITests/Components.swift`

## Key Findings
- Earlier Liquid Glass adoption tasks are either complete, merged, or no longer needed after visual review.
- Sidebar work is now unblocked and can be updated directly.
- The sidebar search field layout needs follow-up after the merge.
- History list ref tags are not currently showing after the merge and need to be restored before further history polish.
- A command icon audit is still open for menu bar and context menu actions.
- The search toolbar item should be revisited to see whether the expanding Liquid Glass search style can support the additional controls used here (arrow buttons and search type popup).

## Current Work Items

### 1. Sidebar search field layout
Files:
- `Xit/Sidebar/*`
- `Xit/Document/XTWindowController.storyboard`

Actions:
- Update the merged sidebar search field layout to fit the current sidebar structure and spacing.
- Keep the merged sidebar work intact; adjust layout, alignment, and sizing only as needed.
- Preserve accessibility and search behavior while updating the visual layout.

Why:
- The sidebar is now in scope, and the merged search layout still needs cleanup.

### 2. History list ref tags restore
Files:
- `Xit/HistoryView/HistoryViewController.storyboard`
- `Xit/HistoryView/HistoryCellView.swift`
- `Xit/HistoryView/RefTokenView.swift`

Actions:
- Restore history list ref tag rendering after the merge.
- Verify the merge did not break token insertion, visibility, coloring, or layout in history rows.
- Reconcile any conflicts between the merged sidebar/history changes and the existing Phase 2 token styling updates.

Why:
- History list readability depends on those ref tags, and this is currently a functional regression.

### 3. Menu bar and context menu icons
Files:
- Command/menu definitions across the app
- Menu bar item and context menu builders

Actions:
- Add more icons to menu bar commands or context menu commands where doing so improves scanability without clutter.
- Prefer icons on the highest-frequency or most visually ambiguous actions.
- Keep icon use consistent with AppKit menu conventions and existing symbol choices.

Why:
- This is still an obvious affordance gap in the current UI.

### 4. Search toolbar item
Files:
- `Xit/Document/XTWindowController.storyboard`
- `Xit/Document/TitleBarController.swift`
- `Xit/HistoryView/HistorySearchBar.swift`
- Related toolbar/search support code

Actions:
- Investigate adopting the Liquid Glass expanding Search toolbar item style.
- Validate whether it can coexist with the extra search controls used here:
  - previous/next arrow buttons
  - search type popup
- If the expanding style cannot support the full control set cleanly, keep the current search interaction model and limit changes to iconography and layout polish.

Why:
- Search is one of the remaining high-visibility toolbar surfaces and now needs a post-merge design pass.

### 5. Siesta removal follow-up
Files:
- `Xit/Services/Services.swift`
- `Xit/Services/BasicAuthService.swift`
- `Xit/Utils/Extensions/SiestaExtensions.swift`
- `Xit.xcodeproj/project.pbxproj`

Actions:
- Replace the `Siesta.Service`-based `IdentifiableService` base type with a plain app-owned service base.
- Rewrite `BasicAuthService` authentication checks to use a non-Siesta transport, keeping the existing observable status surface used by Accounts preferences.
- Remove `Siesta` compatibility glue once `BasicAuthService` no longer depends on it.
- Remove the `Siesta` project dependency after the replacement compiles cleanly.

Why:
- Services will return in the future, but the current app should stop depending on `Siesta` while preserving the higher-level service/account architecture.

## Phased Implementation Plan

### Phase 0-3 status
- Complete or no longer needed:
  - Shared Liquid Glass helpers and accessibility fallbacks landed.
  - Web preview transparency and interaction fixes landed.
  - History/file-list token and separator refresh landed.
  - Sheet and preference work that proved unnecessary or visually counterproductive was dropped.
  - Earlier toolbar/header items that no longer make sense after the merge are closed unless re-opened by one of the current work items below.

### Phase 4: Post-merge follow-up
Files:
- `Xit/Sidebar/*`
- `Xit/Document/XTWindowController.storyboard`
- `Xit/Document/TitleBarController.swift`
- `Xit/HistoryView/*`
- Command/menu builders across the app

Tasks:
- Update sidebar search field layout now that sidebar work is merged.
- Restore history list ref tags after the merge.
- Add more icons to menu bar or context menu commands where appropriate.
- Investigate adopting the Liquid Glass expanding Search toolbar item with the extra arrow/search-type controls.
- Remove the `Siesta` dependency with the smallest worthwhile refactor:
  - keep service protocols and account UI surface
  - replace only the `Siesta`-bound base/auth implementation
- Verify AX IDs and UITests remain stable.
- Validate dark/light mode, increased contrast, and Reduce Transparency.
- Check scroll and redraw performance in history and diff/blame views.

Exit criteria:
- No regressions in UI tests and no noticeable performance regressions in large repos.
- Sidebar search layout, history ref tags, command icon coverage, and toolbar search treatment are all resolved or intentionally ruled out.

## Validation Checklist
- Main window toolbar IDs still pass UI tests (`repoWindow`, `remoteOps`, `branchPopup`).
- Commit entry IDs still pass UI tests (`messageField`, `commitButton`, `amendCheck`, `stripCheck`).
- Clean/Reset/Push sheets retain existing accessibility identifiers.
- History and file list remain readable in light/dark mode with Reduce Transparency enabled.
