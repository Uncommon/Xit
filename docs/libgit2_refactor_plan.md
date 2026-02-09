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

**Excluded / Needs Review:**
- `RepositoryController.swift`: **STAY**. This is the AppKit controller managing the repo.
- `RepositoryWatcher.swift`, `WorkspaceWatcher.swift`: **Check**. If they depend on `FSEvents` or AppKit, they might need refactoring or stay in an intermediate layer or a separate package target.
- `ConfigWatcher.swift`: **Check** dependencies.

### 3.2. Critical Dependency Breaks

**A. `XTRepository` -> `RepositoryController`**
Currently, `XTRepository` imports `Xit` classes or holds a reference to `controller`.
```swift
// Current
public weak var controller: RepositoryController? = nil
// references controller.cache.stagedChanges
```
**Fix:** Introduce a `RepositoryCaching` protocol.
```swift
public protocol RepositoryCaching: AnyObject {
    var stagedChanges: [FileChange]? { get set }
    var branches: [String: GitBranch] { get set }
    // ...
}
class XTRepository {
    weak var cacheDelegate: RepositoryCaching?
}
```

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

**Refinement Task (Before Phase 3):**
4.  [ ] **Sever `RepositoryController` Dependency:** Change `XTRepository` to depend solely on `RepositoryCaching` or an abstract delegate, avoiding the `RepositoryController` type symbol (which pulls in `TaskQueue`).


### Phase 2: Create Swift Package
1.  Run `swift package init --type library --name XitGit` in the root (or manually create folder structure).
2.  Setup `Package.swift`:
    - Define `Clibgit2` target.
    - Define `XitGit` target depending on `Clibgit2`.
3.  Add `module.modulemap` to `Sources/Clibgit2`.
4.  Add the package to the Xcode Workspace (drag folder in or "Add Local Package").

### Phase 3: Migration (The Move)
*Move files in batches to manage compiler errors.*

1.  **Batch 1 (Leafs):** `SHA.swift`, `OID.swift`, `RepoError.swift`, `GitEnums.swift`.
    - Move files to `XitGit/Sources/XitGit/`.
2.  **Batch 2 (Wrappers):** `GitObject` subclasses (`GitCommit`, `GitTree`, etc.).
3.  **Batch 3 (Core):** `XTRepository` and protocols.
    - Update imports to use `import Clibgit2` instead of relying on the bridging header.

### Phase 4: Re-integration
1.  Link `Xit` app target against `XitGit` library product.
2.  Link `Xit` app target against `libgit2-mac.a` (so symbols are present at runtime).
3.  Remove `<git2.h>` from `Xit-Bridging-Header.h`.
4.  Add `import XitGit` to files in the main app that use the repo.
5.  **Tests:** Move relevant tests to `XitGit/Tests/XitGitTests`. Configure the test target to link `libgit2` (this requires passing linker flags in `Package.swift` or just running tests via the main app's test plan initially).

## 5. Verification
- **Build:** Both targets must build cleanly.
- **Tests:** Run standard test suite.
- **Runtime:** Verify standard app flows (Open Repo, Commit, History).
