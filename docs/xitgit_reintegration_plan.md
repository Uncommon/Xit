# Re-integrate `XitGit` Back Into `Xit`

## Summary
Revert the package migration by moving all production code, models, utilities, and test support from `XitGit` back into the main app and test targets, then remove all Swift Package wiring and delete the package.

Target end state:

- `Xit` owns all former `XitGit` production source again.
- `XitTests` owns all former package tests and shared test support again.
- `XitUITests` continues using app-owned code only.
- No `XitGit`, `XitGitTestSupport`, or local package references remain in the project.
- Existing type names and behavior are preserved as much as possible to minimize functional churn.

## Step-by-Step Plan

### 1. Capture and classify the current package-owned surface area
Status: complete.

Package-owned production and test code has been inventoried and assigned these destinations.

#### 1.1 Move back into `Xit/Repository`
- Repository core:
  - `XTRepository.swift`
  - `XTRepository+Commands.swift`
  - `XTRepository+Commits.swift`
  - `XTRepository+Files.swift`
  - `XTRepository+Iterators.swift`
  - `XTRepository+MergePushPull.swift`
  - `XTRepository+Refs.swift`
  - `XTRepository+Staging.swift`
- Repository/controller layer:
  - `RepositoryProtocols.swift`
  - `RepositoryController.swift`
  - `RepositoryWatcher.swift`
  - `WorkspaceWatcher.swift`
  - `ConfigWatcher.swift`
  - `TaskQueue.swift`
  - `Cache.swift`
  - `RemoteProgressPublisher.swift`
- Git wrappers and C-facing repository support:
  - `Blame.swift`
  - `CLIRunner.swift`
  - `FileChange.swift`
  - `FileChangeNode.swift`
  - `FileMonitor.swift`
  - `GiRevWalk.swift`
  - `GitBlob.swift`
  - `GitBranch.swift`
  - `GitBuffer.swift`
  - `GitCloner.swift`
  - `GitCommit.swift`
  - `GitConfig.swift`
  - `GitDiff.swift`
  - `GitDiffDelta.swift`
  - `GitDiffHunk.swift`
  - `GitDiffStats.swift`
  - `GitEnums.swift`
  - `GitExtensions.swift`
  - `GitIndex.swift`
  - `GitODB.swift`
  - `GitPatch.swift`
  - `GitRefLog.swift`
  - `GitRefSpec.swift`
  - `GitReference.swift`
  - `GitRemote.swift`
  - `GitStash.swift`
  - `GitStatusList.swift`
  - `GitSubmodule.swift`
  - `GitTag.swift`
  - `GitTree.swift`
  - `GitVersionedOptions.swift`
  - `GitWorkTree.swift`
  - `PatchMaker.swift`
  - `TreeLoader.swift`
  - `RefType.swift`
  - `ReferenceName.swift`
  - `RepoError.swift`
  - `SHA.swift`
  - `OID.swift`
  - `StringOID.swift`
  - `Signature.swift`
  - `SubmoduleEnums.swift`
- Repository-adjacent shared models:
  - `Models/CommitSelection.swift`
  - `Models/FileListModel.swift`
  - `Models/RepositorySelection.swift`
  - `Models/StagingListModel.swift`
  - `Models/StagingSelection.swift`
  - `Models/StashSelection.swift`
  - `Models/WorkspaceTreeBuilder.swift`
- Repository-adjacent data structures/helpers:
  - `PathTreeData.swift`
  - `PathTreeNode.swift`
  - `StringFakes.swift`

#### 1.2 Move into `Xit/Utils` or `Xit/Utils/Extensions`
- `ArrayExtensions.swift` -> `Xit/Utils/Extensions`
- `CombineExtensions.swift` -> `Xit/Utils/Extensions`
- `DataExtensions.swift` -> `Xit/Utils/Extensions`
- `StringExtensions.swift` -> `Xit/Utils/Extensions`
- `URLExtensions.swift` -> `Xit/Utils/Extensions`
- `CStringInterop.swift` -> `Xit/Utils`
- `FileEventStream.swift` -> `Xit/Utils`
- `KeychainStorage.swift` -> `Xit/Utils`
- `LowerCaseString.swift` -> keep as app utility in `Xit/Utils`
- `MutexProtected.swift` -> `Xit/Utils`
- `PreferencesCompat.swift` -> `Xit/Utils`
- `PublisherGroup.swift` -> `Xit/Utils`
- `QueueUtils.swift` -> `Xit/Utils`
- `Signpost.swift` -> `Xit/Utils`

#### 1.3 Move package test support into `XitTests`
- `XitGit/Sources/XitGit/TestSupport/RepoActionBuilder.swift`
- `XitGit/Sources/XitGit/TestSupport/RepoActions.swift`
- `XitGit/Sources/XitGit/TestSupport/RepositoryController+Wait.swift`
- `XitGit/Sources/XitGitTestSupport/XTTest.swift`

These become normal `XitTests` support files again; no compatibility wrappers should remain.

#### 1.4 Move package tests into `XitTests`
- Test files to merge back:
  - `ArrayExtensionsTest.swift`
  - `BlameTest.swift`
  - `BranchTest.swift`
  - `CacheTest.swift`
  - `CommitRootTest.swift`
  - `ConfigTest.swift`
  - `FileListModelTest.swift`
  - `GitRefSpecTest.swift`
  - `GitSwiftTests.swift`
  - `IndexTreeTest.swift`
  - `LibGit2Test.swift`
  - `PatchTest.swift`
  - `ReferenceNameTests.swift`
  - `SHATest.swift`
  - `StringExtensionsTest.swift`
  - `TaskQueueTest.swift`
  - `XTFileChangesModelTest.swift`
  - `XTRepositoryHunkTest.swift`
  - `XTRepositoryMergeTest.swift`
  - `XTRepositoryTest.swift`
  - `XTStashTest.swift`
  - `XTTagTest.swift`
  - `XitGitTests.swift`
- Test resources to merge back into `XitTests` resources:
  - `Resources/lorem.txt`
  - `Resources/lorem2.txt`

#### 1.5 Delete instead of move
- Remove the package-only bridge and compatibility files rather than rehoming them:
  - `Xit/Repository/XitGitExtensions.swift`
  - `Xit/Utils/XitGitBridging.swift`
- Remove package infrastructure rather than translating it into app code:
  - `XitGit/Package.swift`
  - `XitGit/Package.resolved`
  - `XitGit/Sources/Clibgit2/*`
  - all Swift Package metadata/build output under `XitGit/.swiftpm`, `XitGit/.build`, and `XitGit/build`
- No app/package compatibility shims will be retained after reintegration.

### 2. Move low-level repository and support types back first
- Move leaf types and helpers back before any higher-level code:
  - `SHA`, `OID`, `StringOID`, `ReferenceName`, `RepoError`, `GitEnums`, `LowerCaseString`
  - string/data/array/URL/C-string interop helpers
  - path-tree helpers and non-UI data structures
- Restore these to app-owned source locations so later files can compile against local types instead of package imports.
- Keep symbol names unchanged unless a collision forces a rename.

### 3. Move core repository implementation back into `Xit`
- Move the repository layer from `XitGit/Sources/XitGit` into `Xit/Repository`:
  - `XTRepository` and all `XTRepository+*` files
  - all `Git*` wrapper types
  - `GiRevWalk`
  - `RepositoryProtocols`
  - `RepositoryController`
  - watcher types (`RepositoryWatcher`, `WorkspaceWatcher`, `ConfigWatcher`)
  - `TaskQueue`, `PatchMaker`, `TreeLoader`, `FileChange`, `FileChangeNode`
- Restore direct app target membership for these files.
- Remove package-specific import assumptions while preserving runtime behavior.

### 4. Move package-owned app-facing models back into the app
- Move the former package `Models` folder contents into app-owned locations:
  - `RepositorySelection`
  - `CommitSelection`
  - `StagingSelection`
  - `StashSelection`
  - `FileListModel`
  - `StagingListModel`
  - `WorkspaceTreeBuilder`
- Place each model where it best matches current usage:
  - repository-adjacent non-UI model code can live in `Xit/Repository`
  - UI-adjacent view model support can move nearer to its consuming feature if that avoids another bridge layer
- Update app files to use local symbols again instead of imported package symbols.

### 5. Move utilities back and remove migration-only splits
- Move package-owned non-UI utility files back into `Xit/Utils` and `Xit/Utils/Extensions`:
  - `CombineExtensions`
  - `MutexProtected`
  - `QueueUtils`
  - `Signpost`
  - `FileEventStream`
  - `KeychainStorage`
  - `PreferencesCompat`
  - any package-owned extension/helper files that are now app-global concerns
- Remove migration-only bridge code and splits that existed solely to cross the package boundary, including files such as `Xit/Repository/XitGitExtensions.swift` and package-specific bridging helpers once their functionality is local again.

### 6. Switch application code back to app-local ownership
- Remove `import XitGit` from all app files once the moved types are locally available.
- Remove `import XitGitTestSupport` from app tests once test support is local again.
- Tighten access control back down where it was only broadened to satisfy package boundaries.
- Revert package-only compatibility patterns where the app no longer needs them.

### 7. Merge package test support back into `XitTests`
- Move shared test harness code from the package back into `XitTests`:
  - `XTTest`
  - `RepoActions`
  - `RepoActionBuilder`
  - repository wait helpers
  - `TestFileName`
  - test-only error and helper types
- Remove thin wrappers that currently exist only to import package test-support types.
- Ensure `XitTests` can compile without any package test-support product.

### 8. Merge package test cases back into `XitTests`
- Move every suite under `XitGit/Tests/XitGitTests` into `XitTests`.
- Reunify tests that were split during migration so related repository coverage lives together again.
- Keep UI automation only in `XitUITests`.
- Preserve existing test names where practical to minimize churn in future debugging and history review.

### 9. Remove Swift Package integration from the Xcode project
- Delete the local package reference from `Xit.xcodeproj/project.pbxproj`.
- Remove all package product dependencies and framework links for:
  - `XitGit`
  - `XitGitTestSupport`
  - `Clibgit2`
- Remove any package-derived framework embedding or copy behavior from the app, unit-test, and UI-test targets.
- Reassign source membership so all moved files belong directly to `Xit` or `XitTests`.

### 10. Delete the package only after the app is clean
- After builds and tests pass with local source ownership, delete:
  - `XitGit/Package.swift`
  - `XitGit/Package.resolved`
  - `XitGit/Sources`
  - `XitGit/Tests`
  - remaining package-specific metadata
- Remove the `XitGit` directory entirely as the final cleanup step.
- Do not delete any package file until its content has been fully relocated or intentionally discarded.

### 11. Update documentation and architecture notes
- Keep this plan document as the reintegration reference.
- Remove or supersede package-migration documents so the repo no longer presents `XitGit` as the target architecture.

## Validation

### Builds
- Run `xcodebuild -project Xit.xcodeproj -scheme Xit -configuration Debug -destination 'platform=macOS,arch=arm64' build`
- Run `xcodebuild -project Xit.xcodeproj -target XitTests -configuration Debug -destination 'platform=macOS,arch=arm64' build`
- Run `xcodebuild -project Xit.xcodeproj -scheme XitUITests -configuration Debug -destination 'platform=macOS,arch=arm64' build-for-testing`

### Tests
- Run the reintegrated repository and unit suites under `XitTests`
- Explicitly run historically fragile areas:
  - merge tests
  - stash tests
  - blame tests
  - sidebar/file-list/data-source tests
- Verify `XitUITests` still builds successfully

### Manual smoke test
- Open a repository
- Switch and select branches/refs
- Stage and unstage files
- Commit a change
- Open history and file diff/blame views
- Exercise at least one fetch/pull/push flow and one stash flow

## Assumptions
- `XitGit` will be fully removed rather than retained as an archive or dormant package.
- All migrated package tests will be merged back into `XitTests`.
- The reversal should minimize behavioral change and avoid redesign unless local reintegration exposes a concrete defect.
