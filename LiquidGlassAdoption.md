# Liquid Glass Adoption Plan (Non-Sidebar UI)

This plan is based on the current UI implementation in this repo and is scoped to non-sidebar surfaces only.

## Scope
- Included: main window chrome, history/file panes, preview surfaces, commit entry/header, operation sheets, preferences, and shared SwiftUI/AppKit UI helpers.
- Excluded: `Xit/Sidebar/*` and sidebar-specific work in `Xit/Document/XTWindowController.storyboard` (handled in a separate branch).

## Files Reviewed
- Main window and title bar:
  - `Xit/Document/XTWindowController.swift`
  - `Xit/Document/XTWindowController+TitleBar.swift`
  - `Xit/Document/TitleBarController.swift`
  - `Xit/Document/XTWindowController.storyboard`
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
- The main toolbar still uses older AppKit control styles (`texturedSquare`, `texturedRounded`) in `XTWindowController.storyboard`.
- A single glass-like surface already exists (`NSVisualEffectView material="headerView"`) in `FileListView.xib`, but this is isolated and not system-wide.
- Multiple views still force opaque fills (`controlBackgroundColor`, `textBackgroundColor`, `windowBackgroundColor`), which limits Liquid Glass depth.
- `WebViewController.swift` forces a hard-coded gray background (`deviceWhite: 0.8`) that breaks translucency.
- History reference tokens and graph drawing use custom gradients/strokes that read as pre-Liquid-Glass.
- Operations are mixed: some SwiftUI sheets are modern; several `.xib` sheets are still legacy-styled.

## Specific Recommendations

### 1. Main window chrome and toolbar controls
Files:
- `Xit/Document/XTWindowController.storyboard`
- `Xit/Document/XTWindowController.swift`
- `Xit/Document/TitleBarController.swift`

Actions:
- Replace legacy toolbar cell styles (`texturedSquare`, `texturedRounded`) with modern unified control styling to sit naturally on glass.
- Keep `fullSizeContentView` behavior from `XTWindowController.updateWindowStyle(_:)`, but add an explicit shared "toolbar glass" pass through code to avoid storyboard churn.
- Group toolbar controls into consistent visual clusters (navigation, remote ops, stash/search/view) with one shared surface treatment instead of independent textured buttons.
- Preserve accessibility IDs (`repoWindow`, `remoteOps`, `branchPopup`, `progress`) to keep UITests stable.

Why:
- This is the highest-visibility surface and currently mixes modern symbols with legacy control chrome.

### 2. History list and reference chips
Files:
- `Xit/HistoryView/HistoryViewController.storyboard`
- `Xit/HistoryView/HistoryCellView.swift`
- `Xit/HistoryView/RefTokenView.swift`

Actions:
- Add a glass-backed header treatment for the history table to match the file list header treatment.
- Reduce opaque table background dependence; make rows and separators rely on semantic colors that work over translucency.
- Rework `RefTokenView` from heavy gradient + emboss + shine into lightweight tinted capsules/tags that keep shape semantics (branch/tag/remote) with subtler depth.
- Keep graph line contrast logic in `HistoryCellView` but replace hard `textBackgroundColor` strokes with a semantic separator strategy suitable for layered material.

Why:
- History is visually dense; current gradients and hard backgrounds compete with Liquid Glass.

### 3. File list and preview chrome unification
Files:
- `Xit/FileView/FileViewController.xib`
- `Xit/FileView/File List/FileListView.xib`
- `Xit/FileView/File List/FileListController.swift`

Actions:
- Keep and modernize the existing file-list `NSVisualEffectView` header as the pattern for other non-sidebar headers.
- Replace "fake chrome" buttons used as header/footer bars in `FileViewController.xib` (`previewHeader`, `previewFooter`) with dedicated material-backed container views.
- Update top-right action buttons and list mode controls to use a unified icon weight and border behavior over glass.

Why:
- File pane currently mixes one modern glass header with several legacy small-square bars and controls.

### 4. Commit header and commit entry surfaces
Files:
- `Xit/FileView/CommitHeader.swift`
- `Xit/FileView/CommitEntryController.xib`

Actions:
- Convert commit header backgrounds from hard `windowBackgroundColor` / `textBackgroundColor` blocks to layered material sections.
- In `CommitEntryController.xib`, replace the custom filled `NSBox` container and hard separator line with a material host + subtle separator stroke.
- Keep existing AX IDs (`commitButton`, `messageField`, `amendCheck`, `stripCheck`) unchanged.

Why:
- Commit area is a large, persistent surface; this is a visible gain after toolbar/history updates.

### 5. Web-based diff, blame, and text preview integration
Files:
- `Xit/FileView/Previews/WebViewController.swift`
- `Xit/html/colors.css`
- `Xit/html/blame.css`
- `Xit/html/text.css`

Actions:
- Remove hard-coded `NSColor(deviceWhite: 0.8, alpha: 1.0)` in `WebViewController.webView(_:didFinish:)`.
- Keep web content legible by pushing semantic color tokens from AppKit and using alpha-capable CSS surface variables.
- Tone down heavy shadow and hard card edges in diff/blame CSS to better match a layered glass environment.

Why:
- Web previews are large and currently look detached from the native container.

### 6. Operations and sheets: unify presentation style
Files:
- Legacy XIB sheets:
  - `Xit/Operations/NewBranchPanelController.xib`
  - `Xit/Operations/RenameBranchPanelController.xib`
  - `Xit/Operations/RemoteSheetController.xib`
  - `Xit/Operations/PushNewPanelController.xib`
  - `Xit/Operations/ResetPanelController.xib`
  - `Xit/Operations/PasswordPanelController.xib`
- SwiftUI sheet scaffolding:
  - `Xit/Operations/SheetDialog.swift`
  - `Xit/Operations/ClonePanel.swift`
  - `Xit/Operations/CleanPanel.swift`

Actions:
- Standardize sheet visuals around one shared container style for both SwiftUI and AppKit-hosted sheets.
- Prefer migrating remaining xib sheets to the existing `SheetDialog` SwiftUI pattern where practical.
- For xib sheets that stay AppKit, wrap the root content in a material-backed view and remove unnecessary hard background fills.
- Keep existing sheet accessibility identifiers (`ResetSheet`, `PushNewSheet`, `cleanWindow`) unchanged.

Why:
- Sheets are currently inconsistent: some modern SwiftUI, some legacy xib visual language.

### 7. Preferences window and pane styling
Files:
- `Xit/Preferences/Preferences.storyboard`
- `Xit/Preferences/PrefsWindowController.swift`
- `Xit/Preferences/AccountsPrefsPane.swift`
- `Xit/Preferences/GeneralPrefsPane.swift`
- `Xit/Preferences/PreviewsPrefsPane.swift`

Actions:
- Apply the same window chrome treatment as the main document window for consistency.
- Replace the `AccountsPrefsPane` bottom bar (`.background(.tertiary)` + border) with a lighter material strip.
- Keep form layouts and control density as-is; update surface treatment first.

Why:
- Preferences should look like part of the same app family, not a different visual era.

## Phased Implementation Plan

### Phase 0: Shared foundation
Files:
- New helper(s) in `Xit/Utils` and `Xit/Utils/SwiftUI`

Tasks:
- Add shared material tokens/modifiers for AppKit and SwiftUI (one source of truth).
- Add availability and accessibility fallbacks (Reduce Transparency and high-contrast friendly colors).
- Define "do not touch" sidebar paths in PR scope to avoid cross-branch churn.

Exit criteria:
- One reusable abstraction for glass surfaces exists and is used by at least one screen.

### Phase 0 implementation status
- Added shared non-sidebar liquid glass helpers:
  - `Xit/Utils/Extensions/CocoaExtensions.swift`
  - `Xit/Utils/Extensions/SwiftUIExtensions.swift`
- Wired into non-sidebar screens:
  - `Xit/Utils/SwiftUI/HostingTitlebarController.swift`
  - `Xit/Operations/SheetDialog.swift`
  - `Xit/Operations/ClonePanel.swift`
- PR scope guard for this phase:
  - Do not change `Xit/Sidebar/*`
  - Do not change sidebar scene content in `Xit/Document/XTWindowController.storyboard`

### Phase 1: Window chrome + preview quick wins
Files:
- `XTWindowController.storyboard`, `XTWindowController.swift`, `TitleBarController.swift`
- `FileViewController.xib`
- `WebViewController.swift`

Tasks:
- Update toolbar control styles and grouping.
- Replace preview header/footer fake chrome bars with real material containers.
- Remove hard-coded webview gray background.

Exit criteria:
- Main window, toolbar, and preview pane read as one visual system.

### Phase 2: History + file list harmonization
Files:
- `HistoryViewController.storyboard`, `HistoryCellView.swift`, `RefTokenView.swift`
- `FileListView.xib`, `FileListController.swift`

Tasks:
- Unify header/list surfaces across history and file list.
- Refresh ref token visuals and separator strategy for translucency.

Exit criteria:
- History and file panes feel consistent and no longer mix old/new chrome styles.

### Phase 3: Sheets and preferences
Files:
- `Operations/*.xib`, `SheetDialog.swift`, SwiftUI panels
- `Preferences/*`

Tasks:
- Bring xib sheets to shared material style or migrate to SwiftUI dialog path.
- Update preferences surfaces to match app chrome.

Exit criteria:
- Sheet and settings visual language matches main document window.

### Phase 4: Polish and hardening
Files:
- Cross-cutting

Tasks:
- Verify AX IDs and UITests remain stable.
- Validate dark/light mode, increased contrast, and Reduce Transparency.
- Check scroll and redraw performance in history and diff/blame views.

Exit criteria:
- No regressions in UI tests and no noticeable performance regressions in large repos.

## Merge and Branch Safety (Sidebar Exclusion)
- Do not modify `Xit/Sidebar/*`.
- Avoid structural edits in sidebar scene sections of `XTWindowController.storyboard`.
- Prefer code-side style hooks where possible to reduce storyboard merge conflicts with the sidebar branch.

## Validation Checklist
- Main window toolbar IDs still pass UI tests (`repoWindow`, `remoteOps`, `branchPopup`).
- Commit entry IDs still pass UI tests (`messageField`, `commitButton`, `amendCheck`, `stripCheck`).
- Clean/Reset/Push sheets retain existing accessibility identifiers.
- History and file list remain readable in light/dark mode with Reduce Transparency enabled.
