# Plan: Extract Libgit2 Wrapper to `XitGit` Module

## 1. Goal
Move the direct `libgit2` (C library) interactions and the Swift wrapper classes from the main `Xit` app target into a dedicated, isolated module (Framework).

**Benefits:**
- **Isolation:** The main app doesn't need to know about C pointers or `git2.h` directly.
- **Build Times:** The repository layer can be built once and linked.
- **Testing:** Easier to test core git logic without the UI layer.
- **Architecture:** Enforces a strict boundary between Model (Git) and Controller/View (AppKit).

## 2. Proposed Module Structure
We will create a **Local Swift Package** named `XitGit` to serve as the new module.

*   **Type**: Swift Package (included in Xcode workspace).
*   **Location**: `XitGit/` (at project root).
*   **Dependencies**:
    *   `libgit2` C headers: Via a `Clibgit2` system library target in the package.
    *   `Combine`, `Foundation`.
*   **Configuration (`Package.swift`)**:
    *   Target `XitGit`: The main Swift source.
    *   Target `Clibgit2`: A system library target defining the `module.modulemap` for libgit2.
*   **Exposed API**:
    *   `XTRepository` (The main entry point).
    *   Value types: `SHA`, `OID`, `GitBranch`, `GitCommit`, etc.
    *   The package will isolate `Clibgit2` imports internally where possible.

## 3. Analysis: Dependencies & Entanglements

### 3.1. Files to Move
The contents of `Xit/Repository/` are the primary candidates.

**Core Wrappers (Move to `XitGit/Sources/XitGit`):**
- `XTRepository.swift` & `XTRepository+*.swift`
- `Git*.swift` (e.g., `GitBlob`, `GitBranch`, `GitCommit`, `GitDiff`...)
- `GiRevWalk.swift`
- `SHA.swift`, `OID.swift`, `StringOID.swift`
- `RepositoryProtocols.swift`
- `RepoError.swift`
- `GitEnums.swift`

**Helpers (Move):**
- `CLIRunner.swift`
- `FileChange.swift`, `FileChangeNode.swift`
- `TreeLoader.swift`, `PatchMaker.swift`
- `TaskQueue.swift` (Verified AppKit-free)
- `FileEventStream.swift` (From Utils, needed by watchers)
- `MutexProtected.swift` (From Utils, needed by controller)
- `CombineExtensions.swift` (From Utils, needed by controller)

**Excluded / Needs Review:**
- `RepositoryWatcher.swift`, `WorkspaceWatcher.swift`, `ConfigWatcher.swift`: **MOVE**. Verified they use `FileEventStream` (Foundation/CoreServices) and strict AppKit dependencies are absent.
- `RepositoryController.swift`: **MOVE**. Verified it primarily coordinates logic and uses `Foundation`/`Combine`. It does *not* bind strictly to AppKit (imports `Foundation`, `Combine`).

### 3.2. Critical Dependency Breaks

**A. `XTRepository` -> `RepositoryController`**
*Resolved by moving both.*
Since `RepositoryController` and `TaskQueue` are moving to `XitGit`, `XTRepository` can maintain its reference to `controller`.

**B. `import Cocoa`**
Many files in `Xit/Repository` import `Cocoa` just for `Foundation` types or unused reasons.
**Fix:** Change `import Cocoa` to `import Foundation` in all moved files. If `AppKit` types (like `NSImage` or `NSColor`) are used, abstract them or move that logic up to the app layer.

**C. C-Bridging (The Package Challenge)**
Swift Packages cannot use the app's `Xit-Bridging-Header.h`.
**Fix:**
- Create `XitGit/Sources/Clibgit2/module.modulemap`.
- Point it to the absolute or relative path of `libgit2/include`.
- In `Package.swift`, define `.systemLibrary(name: "Clibgit2")`.
- Swift files will `import Clibgit2`.

## 4. Execution Plan

### Phase 1: In-Place Decoupling (Risk Reduction)
*Goal: Clean up the code *before* moving it.*

1.  [x] **Refactor Cache:** Define `RepositoryCaching` protocol in `RepositoryProtocols.swift`. Make `RepositoryController` conform to it. Update `XTRepository` to use `weak var cacheDelegate: RepositoryCaching?` instead of the concrete controller.
    *   *Note:* `XTRepository` currently uses a shim `controller` property. This property's type must be changed (abstracted) to remove the dependency on `RepositoryController` protocol (which depends on `TaskQueue`).
2.  [x] **Remove AppKit:** Scan `Xit/Repository/*.swift` for `import Cocoa` and replace with `import Foundation`. Fix any build errors (e.g. `NSColor` usage).
    *   *Status:* Verified. No `import Cocoa` remaining in `Xit/Repository`.
3.  [x] **Audit C-API:** Ensure no *other* parts of the app (UI, ViewModels) are calling `git_` C functions directly. If they are, move that logic into `XTRepository` or helpers.
    *   *Status:* Verified. Direct `git_` usage is confined to `Xit/Repository`.

### Phase 2: Create Swift Package
1.  [x] Run `swift package init`
    *   *Status:* Created `XitGit` directory and initialized package.
2.  [x] Setup `Package.swift`:
    *   *Status:* Configured `Clibgit2` as a standard C target (not system library).
    *   *Status:* Uses `cSettings: [.headerSearchPath("include")]` for `Clibgit2`; no package `unsafeFlags` are currently required.
3.  [x] Prepare `Clibgit2` Wrapper:
    *   *Status:* Created `XitGit/Sources/Clibgit2/include/Clibgit2.h` as an umbrella header that simply `#include <git2.h>`.
    *   *Status:* Added `dummy.c` to satisfy the build system, plus symlinks under `Sources/Clibgit2/include/` to the in-repo libgit2 headers.
4.  [x] Add the package to the Xcode Workspace (drag folder in or "Add Local Package").
    *   *Status:* Done (`XCLocalSwiftPackageReference "XitGit"` and product dependency are present in `Xit.xcodeproj`).

### Phase 3: Migration (The Move)
*Move files in batches to manage compiler errors.*

1.  [x] **Batch 1 (Leafs):** `SHA.swift`, `OID.swift`, `RepoError.swift`, `GitEnums.swift`.
    - *Status:* Moved to `XitGit/Sources/XitGit/`.
2.  [x] **Batch 2 (Wrappers):** `GitObject` subclasses (`GitCommit`, `GitTree`, etc.).
    - *Status:* Moved; `Xit/Repository/` now only contains app-side bridge/extensions (`XitGitExtensions.swift`).
3.  [x] **Batch 3 (Core):** `XTRepository` and protocols.
    - *Status:* `XTRepository`, `XTRepository+*`, controller/watcher/protocol types moved into `XitGit`.
    - *Status:* `XitGit` sources import `Clibgit2` directly.
4.  [x] **Utility split cleanup:**
    - *Status:* Utilities initially copied from `Xit/Utils` were reconciled so package-required helpers stay in `XitGit`, while app-only helpers were moved back to `Xit/Utils/Extensions/MiscExtensions.swift`.

### Phase 4: Re-integration
1.  [x] Link `Xit` app target against `XitGit` library product.
    - *Status:* `XitGit in Frameworks` and package product dependency are present in project settings.
2.  [x] Link `Xit` app target against `libgit2-mac.a` (so symbols are present at runtime).
    - *Status:* `libgit2-mac.a in Frameworks` remains configured.
3.  [x] Remove `<git2.h>` from `Xit-Bridging-Header.h`.
    - *Status:* Done; app bridging header now only imports app-local Objective-C headers.
4.  [x] Add `import XitGit` to files in the main app that use the repo.
    - *Status:* In place for migrated codepaths (including app-side bridge and utility call sites currently relying on package extensions).
5.  [x] **Tests:** Move relevant tests to `XitGit/Tests/XitGitTests`.
    - *Status:* Migrated package-focused leaf tests (`SHATest`, `ReferenceNameTests`, `StringExtensionsTest`, `CacheTest`, `ConfigTest`, `LibGit2Test`) plus a package sanity test.
    - *Status:* Migrated repository integration tests and shared harness support (`XTTest`, `RepoActions`, `RepoActionBuilder`, `TestErrors`, `BranchTest`, `GitSwiftTests`, `PatchTest`, `XTRepositoryHunkTest`, `XTRepositoryMergeTest`, `XTRepositoryTest`, `XTStashTest`, `XTTagTest`, `BlameTest.testStagingBlame`) into `XitGit/Tests/XitGitTests`.
    - *Status:* Added migration of selection/list-model tests to package (`CommitRootTest`, `FileListModelTest`, `IndexTreeTest`, `XTFileChangesModelTest`) and moved selection-focused cases into existing package suites (`BlameTest.testCommitBlame`, merge-selection checks in `XTRepositoryMergeTest`, stash-selection binary diff in `XTStashTest`).
    - *Status:* Remaining tests in `XitTests` are app integration and UI/data-source focused.

## 5. Verification
- **Build:**
  - `swift build` for `XitGit` succeeds.
  - Full `Xit` app target build has not been re-verified in this environment because full Xcode is unavailable (`xcode-select` points to CommandLineTools).
- **Tests:**
  - `swift test` in `XitGit` is currently blocked in this environment (`no such module 'XCTest'` with current CLI toolchain).
  - Package tests execute in the full Xcode environment; CLI verification remains limited by the toolchain issue above.
  - Main app test suites were not executed in this pass.
- **Runtime:**
  - Manual app-flow verification (Open Repo, Commit, History) still pending.
