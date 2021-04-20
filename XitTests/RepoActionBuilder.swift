import Foundation
import Xit

protocol RepoAction
{
  func execute(in repository: Repository) throws
}

fileprivate struct EmptyAction: RepoAction
{
  func execute(in repository: Repository) throws {}
}

fileprivate struct ActionList: RepoAction
{
  let actions: [RepoAction]

  func execute(in repository: Repository) throws
  {
    for action in actions {
      try action.execute(in: repository)
    }
  }
}

protocol StageableAction : RepoAction
{
  var file: String { get }
}

enum TestFileName: String
{
  case file1 = "file1.txt"
  case file2 = "file2.txt"
  case file3 = "file3.txt"
  case file4 = "file4.txt"
  case subFile2 = "folder/file2.txt"
  case subSubFile2 = "folder/folder2/file2.txt"
  case added = "added.txt"
  case untracked = "untracked.txt"
  case tiff = "img.tiff"
  case binary = "binary" // no suffix
  case blame = "elements.txt"
}

struct Write: StageableAction
{
  let content: String
  let file: String

  init(_ content: String, to file: String)
  {
    self.content = content
    self.file = file
  }

  init(_ content: String, to name: TestFileName)
  {
    self.content = content
    self.file = name.rawValue
  }

  func execute(in repository: Repository) throws
  {
    let url = repository.fileURL(file)

    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                             withIntermediateDirectories: true,
                                             attributes: nil)
    try content.write(toFile: url.path, atomically: true, encoding: .utf8)
  }
}

struct CopyFile: StageableAction
{
  let source: String?
  let sourceURL: URL?
  let file: String

  init(from source: String, to destination: String)
  {
    self.source = source
    self.sourceURL = nil
    self.file = destination
  }

  init(from source: URL, to destination: String)
  {
    self.source = nil
    self.sourceURL = source
    self.file = destination
  }

  func execute(in repository: Repository) throws
  {
    guard let sourceURL = sourceURL ?? source.map({ repository.fileURL($0) })
    else { throw UnreachableError() }
    let destURL = repository.fileURL(file)

    try FileManager.default.copyItem(at: sourceURL, to: destURL)
  }
}

struct WriteData: StageableAction
{
  let data: Data
  let file: String

  init(_ data: Data, to file: String)
  {
    self.data = data
    self.file = file
  }

  func execute(in repository: Repository) throws
  {
    try data.write(to: repository.fileURL(file))
  }
}

struct MakeTiffFile: StageableAction
{
  let file: String

  init(_ file: String) { self.file = file }
  init(_ name: TestFileName) { self.file = name.rawValue }

  func execute(in repository: Repository) throws
  {
    let tiffURL = repository.fileURL(file)

    try NSImage(named: NSImage.actionTemplateName)?.tiffRepresentation?
                                                   .write(to: tiffURL)
  }
}

struct Delete: StageableAction
{
  let file: String

  init(_ file: String) { self.file = file }
  init(_ name: TestFileName) { self.file = name.rawValue }

  func execute(in repository: Repository) throws
  {
    let url = repository.fileURL(file)

    try FileManager.default.removeItem(at: url)
  }
}

struct Stage: RepoAction
{
  let file: String

  init(_ file: String) { self.file = file }
  init(_ name: TestFileName) { self.file = name.rawValue }

  func execute(in repository: Repository) throws
  {
    try repository.stage(file: file)
  }
}

struct Unstage: RepoAction
{
  let file: String

  init(_ file: String) { self.file = file }
  init(_ name: TestFileName) { self.file = name.rawValue }

  func execute(in repository: Repository) throws
  {
    try repository.unstage(file: file)
  }
}

struct CommitFiles: RepoAction
{
  let message: String
  let amend: Bool
  let actions: [RepoAction]

  /// Commits any files already staged.
  init(_ message: String = "commit", amend: Bool = false)
  {
    self.message = message
    self.amend = amend
    self.actions = []
  }

  /// Executes the given actions, stages any files that were written or deleted,
  /// and then commits.
  init(_ message: String = "commit", amend: Bool = false,
       @RepoActionBuilder actions: () -> [RepoAction])
  {
    self.message = message
    self.amend = amend
    self.actions = actions()
  }

  func execute(in repository: Repository) throws
  {
    for action in actions {
      try executeAndStage(action, in: repository)
    }
    try repository.commit(message: message, amend: amend)
  }

  private func executeAndStage(_ action: RepoAction,
                               in repository: Repository) throws
  {
    if let list = action as? ActionList {
      for action in list.actions {
        try executeAndStage(action, in: repository)
      }
    }
    else {
      try action.execute(in: repository)
      if let stageable = action as? StageableAction {
        try repository.stage(file: stageable.file)
      }
    }
  }
}

struct SaveStash: RepoAction
{
  let message: String

  init(_ message: String = "") { self.message = message }

  func execute(in repository: Repository) throws
  {
    try repository.saveStash(name: message, keepIndex: false,
                             includeUntracked: true, includeIgnored: true)
  }
}

struct ApplyStash: RepoAction
{
  let index: UInt

  init(index: UInt = 0) { self.index = index }

  func execute(in repository: Repository) throws
  {
    try repository.applyStash(index: index)
  }
}

struct PopStash: RepoAction
{
  let index: UInt

  init(index: UInt = 0) { self.index = index }

  func execute(in repository: Repository) throws
  {
    try repository.popStash(index: index)
  }
}

struct DropStash: RepoAction
{
  let index: UInt

  init(index: UInt = 0) { self.index = index }

  func execute(in repository: Repository) throws
  {
    try repository.dropStash(index: index)
  }
}

struct CheckOut: RepoAction
{
  let branch: String
  let sha: String

  init(branch: String)
  {
    self.branch = branch
    self.sha = ""
  }

  init(sha: String)
  {
    self.branch = ""
    self.sha = sha
  }

  func execute(in repository: Repository) throws
  {
    if sha.isEmpty {
      try repository.checkOut(branch: branch)
    }
    else {
      try repository.checkOut(sha: sha)
    }
  }
}

struct CreateBranch: RepoAction
{
  let branch: String
  let checkOut: Bool

  init(_ branch: String, checkOut: Bool = false)
  {
    self.branch = branch
    self.checkOut = checkOut
  }

  func execute(in repository: Repository) throws
  {
    guard let currentBranch = repository.currentBranch
    else { throw UnreachableError() }

    _ = try repository.createBranch(named: branch,
                                    target: RefPrefixes.heads + currentBranch)
    if checkOut {
      try repository.checkOut(branch: branch)
    }
  }
}

struct Merge: RepoAction
{
  let sourceBranch: Branch?
  let branchName: String?

  init(branch: Branch)
  {
    self.sourceBranch = branch
    self.branchName = nil
  }

  init(branch: String)
  {
    self.sourceBranch = nil
    self.branchName = branch
  }

  func execute(in repository: Repository) throws
  {
    guard let branch = sourceBranch ??
                       branchName.flatMap({ repository.localBranch(named: $0) })
    else { throw RepoError.unexpected }

    try repository.merge(branch: branch)
  }
}

@_functionBuilder
struct RepoActionBuilder
{
  static func buildBlock(_ items: RepoAction...) -> [RepoAction]
  {
    return items
  }

  static func buildOptional(_ item: RepoAction?) -> RepoAction
  {
    item ?? EmptyAction()
  }

  static func buildEither(first: RepoAction) -> RepoAction { first }
  static func buildEither(second: RepoAction) -> RepoAction { second }

  static func buildArray(_ actions: [RepoAction]) -> RepoAction
  { ActionList(actions: actions) }
}

func execute(in repository: Repository, @RepoActionBuilder actions: () -> [RepoAction]) throws
{
  for action in actions() {
    try action.execute(in: repository)
  }
}
