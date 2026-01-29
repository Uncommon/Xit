# Xit Architecture

## Table of Contents
- [Overview](#overview)
- [Architecture Principles](#architecture-principles)
- [Layer Structure](#layer-structure)
- [Core Components](#core-components)
- [Design Patterns](#design-patterns)
- [Data Flow](#data-flow)
- [Testing Strategy](#testing-strategy)
- [Key Abstractions](#key-abstractions)

---

## Overview

Xit is a visual Git client for macOS written in Swift, leveraging **libgit2** for Git operations and a hybrid **AppKit/SwiftUI** UI layer. The architecture emphasizes:

- **Protocol-oriented design** for testability and modularity
- **Reactive data flow** using Combine publishers
- **Separation of concerns** between Git operations, business logic, and UI
- **Thread-safe repository operations** with explicit write control

---

## Architecture Principles

### 1. **Protocol-Oriented Programming**
Xit extensively uses protocols to abstract functionality:
- **Repository capabilities** are split into focused protocols (`Branching`, `CommitStorage`, `FileStaging`, etc.)
- **Fake implementations** enable comprehensive unit testing without touching actual Git repositories
- **Composition over inheritance** via protocol composition (`FullRepository` combines all repo capabilities)

### 2. **Separation of Concerns**
```
┌─────────────────────────────────────────┐
│          UI Layer (AppKit/SwiftUI)       │
│  - Window Controllers                    │
│  - View Controllers                      │
│  - SwiftUI Views                         │
└─────────────┬───────────────────────────┘
              │
┌─────────────▼───────────────────────────┐
│       Controller Layer                   │
│  - RepositoryUIController                │
│  - GitRepositoryController               │
│  - Operation Controllers                 │
└─────────────┬───────────────────────────┘
              │
┌─────────────▼───────────────────────────┐
│       Repository Layer                   │
│  - XTRepository (libgit2 wrapper)        │
│  - Git primitive operations              │
│  - File system monitoring                │
└──────────────────────────────────────────┘
```

### 3. **Reactive State Management**
- Combine publishers broadcast repository changes
- UI components observe state via `@ObservedObject` and publisher subscriptions
- File system watchers trigger automatic updates

---

## Layer Structure

### **1. Repository Layer** (`Xit/Repository/`)

The foundation layer that wraps libgit2 and provides Swift-native Git operations.

#### Key Components:

**`XTRepository`**
- Core repository class wrapping `OpaquePointer` (libgit2 git_repository)
- Manages Git repository lifecycle and state
- Thread-safe write operations via `isWriting` flag and mutex

**Protocol Hierarchy:**
```swift
FullRepository = 
    BasicRepository & 
    Branching & 
    CommitStorage & 
    CommitReferencing & 
    FileDiffing &
    FileContents & 
    FileStaging & 
    FileStatusDetection & 
    Merging &
    RemoteManagement & 
    RepoConfiguring & 
    Stashing & 
    SubmoduleManagement &
    Tagging & 
    WritingManagement & 
    Workspace
```

Each protocol represents a focused capability:
- **`Branching`**: Branch creation, deletion, tracking
- **`CommitStorage`**: Commit retrieval and creation
- **`FileStaging`**: Stage/unstage operations
- **`Stashing`**: Stash save/apply/pop/drop
- **`RemoteManagement`**: Remote fetch/push/pull operations
- **`Workspace`**: Checkout operations

**Why this design?**
- Enables precise dependency injection
- Facilitates comprehensive mocking for tests
- Makes capabilities explicit and discoverable

#### Related Files:
- `XTRepository.swift` - Main repository implementation
- `XTRepository+Commands.swift` - Git commands (checkout, stage, etc.)
- `GitODB.swift` - Object database access
- `GitBranch.swift`, `GitCommit.swift`, `GitRemote.swift` - Git primitives
- `RepositoryProtocols.swift` - Protocol definitions

---

### **2. Controller Layer** (`Xit/Repository/`, `Xit/Document/`)

Mediates between UI and repository, managing state, caching, and async operations.

#### **`GitRepositoryController`** (Business Logic Controller)
```swift
final class GitRepositoryController: RepositoryController {
  let xtRepo: XTRepository
  let queue: TaskQueue          // Serial queue for repo operations
  var cache: RepositoryCache    // Cached file changes
  
  // Publishers for repository events
  var headPublisher: AnyPublisher<Void, Never>
  var indexPublisher: AnyPublisher<Void, Never>
  // ...
}
```

**Responsibilities:**
- **Task queue management** - Serializes Git operations to prevent conflicts
- **Caching** - Stores staged/unstaged changes to avoid repeated expensive queries
- **File system monitoring** - Watches `.git/` directory and workspace for changes
- **Publisher coordination** - Broadcasts repository state changes

#### **`RepositoryUIController`** (UI Coordination)
```swift
protocol RepositoryUIController: AnyObject {
  var repository: any FullRepository { get }
  var repoController: GitRepositoryController! { get }
  var selection: (any RepositorySelection)? { get set }
  var selectionPublisher: AnyPublisher<RepositorySelection?, Never> { get }
}
```

**Implemented by:** `XTWindowController`

**Responsibilities:**
- **Selection management** - Current commit/file selection state
- **UI coordination** - Bridges window controller with repository
- **Error display** - Shows repository operation errors to user

#### **Operation Controllers** (`Xit/Operations/`)
Encapsulate complex multi-step operations:
- `StashOperationController` - Stash creation dialog → operation
- `ResetOpController` - Reset confirmation → execution
- `CleanOpController` - Clean untracked files dialog

**Pattern:**
```swift
protocol RepositoryOperation {
  associatedtype Repository
  associatedtype Parameters
  
  var repository: Repository { get }
  func perform(using parameters: Parameters) throws
}
```

---

### **3. UI Layer**

A hybrid AppKit/SwiftUI architecture leveraging the strengths of both frameworks.

#### **Document Architecture**
```
RepoDocument (NSDocument)
    └── XTWindowController (main window)
        ├── SidebarController (branches, remotes, tags)
        ├── HistoryViewController (commit list)
        ├── FileViewController (file list + preview)
        └── TitleBarController (toolbar)
```

#### **Key View Controllers:**

**`XTWindowController`** (`Xit/Document/XTWindowController.swift`)
- Main window controller implementing `RepositoryUIController`
- Owns split view layout
- Coordinates child controllers

**`SidebarController`** (`Xit/Sidebar/SidebarController.swift`)
- Shows branches, remotes, tags, stashes, submodules
- Integrates build status (TeamCity)
- Pull request indicators (Bitbucket Server)

**`HistoryViewController`** (`Xit/HistoryView/`)
- Commit history table with graph visualization
- Search/filter capabilities
- Navigation history (back/forward through selections)

**`FileViewController`** (`Xit/FileView/FileViewController.swift`)
- Three-pane file interface:
  - **Commit list** - Files changed in selected commit
  - **Staging area** - Staged vs unstaged changes
  - **Preview** - Diff, blame, text, or QuickLook preview

#### **SwiftUI Integration**
Modern dialogs and panels use SwiftUI with AppKit interop:

```swift
// Pattern: DataModelView protocol
protocol DataModelView: View {
  associatedtype Model: ObservableObject, Validating
  init(model: Model)
}

// Example: Stash dialog
struct StashPanel: DataModelView {
  @ObservedObject var model: StashPanel.Model
  var body: some View {
    Form {
      TextField("Message:", text: $model.message)
      Toggle("Keep index", isOn: $model.keepIndex)
    }
  }
}
```

**Bridging:** `NSHostingController` embeds SwiftUI views in AppKit windows

---

## Core Components

### **1. Task Queue** (`TaskQueue`)
```swift
let queue: TaskQueue
```
- Serial dispatch queue for repository operations
- Prevents concurrent writes
- Ensures operation ordering

### **2. Repository Cache** (`RepositoryCache`)
```swift
struct RepositoryCache {
  var stagedChanges: [FileChange]?
  var amendChanges: [FileChange]?
  var unstagedChanges: [FileChange]?
  var branches: [String: GitBranch]
}
```
- Caches expensive Git queries
- Invalidated on index/workspace changes
- Thread-safe via `@MutexProtected` property wrapper

### **3. File System Watchers**

**`RepositoryWatcher`** - Monitors `.git/` directory
- Publishes changes to: HEAD, index, reflog, refs, stash
- Uses FSEvents/GCD file monitoring

**`WorkspaceWatcher`** - Monitors working directory
- Detects file changes outside of Xit
- Triggers file list refresh

**`ConfigWatcher`** - Monitors `.git/config`
- Reloads repository configuration
- Updates remote/branch tracking info

### **4. Selections** (`Xit/Selection/`)

Abstraction over different states the UI can display:

```swift
protocol RepositorySelection {
  var repository: any FullRepository { get }
  func list(staged: Bool) -> any FileListModel
}
```

**Implementations:**
- **`CommitSelection`** - Viewing a historical commit
- **`StagingSelection`** - Current working directory/index
- **`StashSelection`** - Stash entry contents

**Why?**
- Unified interface for file lists regardless of source
- Powers file preview across different contexts

---

## Design Patterns

### **1. Protocol-Oriented Architecture**
```swift
// Compose only needed capabilities
typealias Repository = 
    BasicRepository & CommitStorage & FileStaging
```
- Fine-grained dependency injection
- Clear capability requirements

### **2. Repository Pattern**
`XTRepository` abstracts libgit2, providing:
- Swift-native types (`GitOID`, `SHA`)
- Error handling via `throws`
- Reference counting safety

### **3. Accessor Protocols** (Convenience Pattern)
```swift
protocol RepositoryUIAccessor {
  var repoUIController: (any RepositoryUIController)? { get }
}

extension RepositoryUIAccessor {
  var repoController: (any RepositoryController)? 
  { repoUIController?.repoController }
}
```
Used by view controllers to cleanly access repository:
```swift
class FileListController: NSViewController, 
                         RepositoryWindowViewController {
  // Automatically gets repoUIController, repoController, repoSelection
}
```

### **4. Command Pattern** (Operations)
```swift
struct CheckOutRemoteOperation: RepositoryOperation {
  let repository: any Workspace & Branching
  let remoteBranch: RemoteBranchRefName
  
  func perform(using parameters: CheckOutRemotePanel.Model) throws {
    // Create local branch tracking remote
    // Optionally check it out
  }
}
```

### **5. Observer Pattern** (Combine Publishers)
```swift
// Repository broadcasts changes
for await _ in controller.indexPublisher.values {
  updateFileList()
}
```

---

## Data Flow

### **User Action → Repository Update → UI Refresh**

#### Example: Staging a File

```
1. User clicks "Stage" button
   ↓
2. FileListController.stage(_:)
   ↓
3. repository.stage(file: path)
   ↓
4. XTRepository.performWriting { 
     git_index_add_bypath(...) 
   }
   ↓
5. WorkspaceWatcher detects .git/index change
   ↓
6. GitRepositoryController.indexPublisher emits
   ↓
7. FileViewController observes index publisher
   ↓
8. UI updates file list (file moved to staged section)
```

#### Example: Selecting a Commit

```
1. User clicks commit in HistoryTableController
   ↓
2. XTWindowController.select(oid: GitOID)
   ↓
3. selection = CommitSelection(repository, oid)
   ↓
4. selectionPublisher emits new selection
   ↓
5. FileViewController receives selection
   ↓
6. Loads commit's file list
   ↓
7. Displays files + diff preview
```

---

## Testing Strategy

### **Fake Implementations**

Xit uses the `@Faked` macro and manual fake classes for testing:

```swift
class FakeRepo: FileChangesRepo & 
                EmptyCommitReferencing & 
                EmptyFileDiffing {
  var commits: [GitOID: FakeCommit] = [:]
  let localBranch1 = FakeLocalBranch(name: "branch1", oid: "a")
  
  func commit(forOID oid: GitOID) -> FakeCommit? {
    commits[oid]
  }
}
```

**"Empty" Protocols:**
- `EmptyCommitReferencing`, `EmptyFileStaging`, etc.
- Provide no-op default implementations
- Allow fakes to focus on tested capabilities

### **Test Structure**

**`XTTest`** - Base class providing:
- Temporary repository creation/cleanup
- Git command execution helpers
- Common test fixtures

**Domain-Specific Languages (DSLs):**
The `execute(in:)` function uses a result builder to simplify the steps needed
to create a repository in the desired state for a test.

```swift
try execute(in: repository) {
  CommitFiles {
    Write("content", to: .file1)
  }
  CreateBranch("feature")
  Stage(.file2)
}
```

### **UI Tests** (`XitUITests/`)
- Full integration tests using XCTest UI framework
- `GitCLI` helper creates repository state via command-line git
- Tests complete workflows (commit, branch, stash, etc.)

---

## Key Abstractions

### **1. GitOID & SHA**
```swift
struct SHA: Hashable {
  let bytes: [UInt8]  // 20 bytes for SHA-1
}

struct GitOID {
  var oid: git_oid    // libgit2 C struct
}
```
- `SHA`: Pure Swift value type
- `GitOID`: Wraps libgit2's git_oid for interop

### **2. Branch References**
```swift
protocol ReferenceName {
  var name: String { get }
}

struct LocalBranchRefName: ReferenceName {
  let name: String  // e.g., "main"
  var fullPath: String { "refs/heads/\(name)" }
}

struct RemoteBranchRefName: ReferenceName {
  let remote: String  // e.g., "origin"
  let branch: String  // e.g., "main"
}
```
Type-safe branch references prevent mistakes and clarify intent.

### **3. FileChange**
```swift
struct FileChange {
  let path: String
  let status: DeltaStatus  // .added, .modified, .deleted, etc.
  let staged: Bool
}
```
Unified representation of file changes across commits, staging, workspace.

### **4. PatchMaker**
Abstraction over diff generation:
```swift
protocol PatchMaker {
  func makePatch() -> Patch?
}

enum PatchResult {
  case diff(PatchMaker)
  case binary
  case noDifference
}
```
Handles text diffs, binary files, and unchanged files uniformly.

---

## Directory Structure

```
Xit/
├── Document/               # Window controllers, document management
├── FileView/              # File list and preview components
│   ├── File List/         # File tree/list views
│   └── Previews/          # Diff, blame, text, QuickLook viewers
├── HistoryView/           # Commit history table and graph
├── Operations/            # Multi-step operation controllers
├── Preferences/           # Settings panels
├── Repository/            # Core Git repository abstraction
│   ├── XTRepository.swift
│   ├── RepositoryProtocols.swift
│   └── Git*.swift         # libgit2 wrappers
├── Selection/             # Selection abstractions
├── Sidebar/               # Branch/remote/tag sidebar
├── Utils/                 # Extensions and helpers
│   ├── Extensions/
│   └── SwiftUI/           # SwiftUI components
└── html/                  # HTML templates for diff view

XitTests/                  # Unit tests with fakes
XitUITests/                # Integration/UI tests
Xcode-config/              # Build configuration
```

---

## Threading & Concurrency

### **Task Queue Pattern**
```swift
queue.execute {
  // Git operations run serially on background queue
  let commit = repository.commit(forSHA: sha)
}
```

### **Main Thread Enforcement**
UI controllers marked `@MainActor`:
```swift
@MainActor
protocol RepositoryUIController: AnyObject { ... }
```

### **Write Protection**
```swift
func performWriting<T>(_ block: () throws -> T) throws -> T {
  guard !isWriting else { throw RepoError.alreadyWriting }
  isWriting = true
  defer { isWriting = false }
  return try block()
}
```
Prevents concurrent writes that could corrupt the repository.

---

## Extension Points

### **Adding a New Repository Capability**

1. **Define protocol** in `RepositoryProtocols.swift`:
   ```swift
   @Faked
   public protocol MyFeature: AnyObject {
     func doSomething() throws
   }
   ```

2. **Implement in extension**:
   ```swift
   extension XTRepository: MyFeature {
     func doSomething() throws {
       try performWriting {
         // libgit2 calls
       }
     }
   }
   ```

3. **Add to FullRepository**:
   ```swift
   typealias FullRepository = 
       BasicRepository & ... & MyFeature
   ```

4. **Create fake** for testing:
   ```swift
   protocol EmptyMyFeature: MyFeature {}
   extension EmptyMyFeature {
     func doSomething() throws {}
   }
   ```

### **Adding a New UI Panel**

1. **Create SwiftUI view** conforming to `DataModelView`
2. **Define model** conforming to `Validating`
3. **Use `SheetDialog` protocol** for presentation:
   ```swift
   struct MyDialog: SheetDialog {
     typealias ContentView = MyPanel
     var acceptButtonTitle: UIString { .ok }
     func createModel() -> MyPanel.Model? { .init() }
   }
   ```

---

## Build System

- **Xcode project** (`Xit.xcodeproj`)
- **Configuration files** (`Xcode-config/`)
  - `Shared.xcconfig` - Common settings
  - `DEVELOPMENT_TEAM.xcconfig` - Developer-specific (gitignored)
- **libgit2 build** - `build_libgit2.sh` script
- **Code quality tools**:
  - SwiftLint (`.swiftlint.yml`)
  - Periphery (`.periphery.yml`) - Dead code detection

---

## Future Architectural Considerations

### Planned Improvements (from README):
- **Enhanced diff views** - Syntax highlighting, better inline diffs
- **GitHub integration** - Pull requests, fork discovery
- **Interactive rebase** - Will need new operation controllers
- **File history view** - Additional selection type

### Technical Debt:
- **AppKit → SwiftUI migration** - Gradual modernization of views
- **Async/await adoption** - Replace some Combine publishers
- **Memory optimization** - Large repository scalability

---

## Contributing

When contributing to Xit, keep these architecture principles in mind:

1. **Use protocols** for new capabilities
2. **Provide fake implementations** for tests
3. **Respect thread boundaries** - UI on main, repo operations on queue
4. **Use Combine publishers** for state changes
5. **Follow the accessor pattern** for controller access
6. **Write operations must use `performWriting`**
7. **New UI panels should use SwiftUI** where possible

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed development setup.

---

## Additional Resources

- **libgit2 documentation**: https://libgit2.org/docs/
- **Git internals**: https://git-scm.com/book/en/v2/Git-Internals-Plumbing-and-Porcelain
- **Swift Concurrency**: https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html
- **Combine Framework**: https://developer.apple.com/documentation/combine

---

**Last Updated:** 2026-01-29
**Xit Version:** Beta (pre-1.0)
