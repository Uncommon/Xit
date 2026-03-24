import Foundation
@testable import Xit

enum TestFileName: String
{
  case file1 = "file1.txt"
  case file2 = "file2.txt"
  case file3 = "file3.txt"
  case file4 = "file4.txt"
  case subFile1 = "folder/file1.txt"
  case subFile2 = "folder/file2.txt"
  case subSubFile2 = "folder/folder2/file2.txt"
  case added = "added.txt"
  case untracked = "untracked.txt"
  case deleted = "deleted"
  case tiff = "img.tiff"
  case binary = "binary"
  case blame = "elements.txt"

  static func == (lhs: String, rhs: TestFileName) -> Bool { lhs == rhs.rawValue }
  static func != (lhs: String, rhs: TestFileName) -> Bool { lhs != rhs.rawValue }
  static func == (lhs: String?, rhs: TestFileName) -> Bool { lhs.map { $0 == rhs.rawValue } ?? false }
  static func != (lhs: String?, rhs: TestFileName) -> Bool { lhs.map { $0 != rhs.rawValue } ?? false }
  static func == (lhs: TestFileName, rhs: String) -> Bool { lhs.rawValue == rhs }
  static func != (lhs: TestFileName, rhs: String) -> Bool { lhs.rawValue != rhs }
  static func == (lhs: TestFileName, rhs: String?) -> Bool { rhs.map { lhs.rawValue == $0 } ?? false }
  static func != (lhs: TestFileName, rhs: String?) -> Bool { rhs.map { lhs.rawValue != $0 } ?? false }
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

  func execute(in repository: any FullRepository) throws
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

  func execute(in repository: any FullRepository) throws
  {
    guard let sourceURL = sourceURL ?? source.map({ repository.fileURL($0) })
    else { throw RepoError.unexpected }
    let destURL = repository.fileURL(file)

    try FileManager.default.copyItem(at: sourceURL, to: destURL)
  }
}

struct RenameFile: StageableAction
{
  let file: String
  let newName: String

  init(_ file: String, to newName: String)
  {
    self.file = file
    self.newName = newName
  }

  init(_ file: TestFileName, to newName: String)
  {
    self.file = file.rawValue
    self.newName = newName
  }

  init(_ file: TestFileName, to newName: TestFileName)
  {
    self.file = file.rawValue
    self.newName = newName.rawValue
  }

  func execute(in repository: any FullRepository) throws
  {
    let fileURL = repository.fileURL(file)
    let newURL = repository.fileURL(newName)

    try FileManager.default.moveItem(at: fileURL, to: newURL)
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

  func execute(in repository: any FullRepository) throws
  {
    try data.write(to: repository.fileURL(file))
  }
}

struct MakeTiffFile: StageableAction
{
  let file: String

  init(_ file: String) { self.file = file }
  init(_ name: TestFileName) { self.file = name.rawValue }

  func execute(in repository: any FullRepository) throws
  {
    let tiffURL = repository.fileURL(file)
    let bytes: [UInt8] = [0x4D, 0x4D, 0x00, 0x2A, 0x00, 0xFF, 0x00, 0x80]
    try Data(bytes).write(to: tiffURL)
  }
}

struct Delete: StageableAction
{
  let file: String

  init(_ file: String) { self.file = file }
  init(_ name: TestFileName) { self.file = name.rawValue }

  func execute(in repository: any FullRepository) throws
  {
    try FileManager.default.removeItem(at: repository.fileURL(file))
  }
}

enum StageFileRef
{
  case path(String)
  case change(FileChange)
}

struct Stage: RepoAction
{
  let ref: StageFileRef

  init(_ file: String) { self.ref = .path(file) }
  init(_ name: TestFileName) { self.ref = .path(name.rawValue) }
  init(_ change: FileChange) { self.ref = .change(change) }

  func execute(in repository: any FullRepository) throws
  {
    switch ref {
    case .path(let path):
      try repository.stage(file: path)
    case .change(let change):
      try repository.stage(change: change)
    }
    try repository.index?.save()
  }
}

struct Unstage: RepoAction
{
  let ref: StageFileRef

  init(_ file: String) { self.ref = .path(file) }
  init(_ name: TestFileName) { self.ref = .path(name.rawValue) }
  init(_ change: FileChange) { self.ref = .change(change) }

  func execute(in repository: any FullRepository) throws
  {
    switch ref {
    case .path(let path):
      try repository.unstage(file: path)
    case .change(let change):
      try repository.unstage(change: change)
    }
  }
}

struct CommitFiles: RepoAction
{
  let message: String
  let amend: Bool
  let actions: [any RepoAction]

  init(_ message: String = "commit", amend: Bool = false)
  {
    self.message = message
    self.amend = amend
    self.actions = []
  }

  init(_ message: String = "commit", amend: Bool = false,
       @RepoActionBuilder actions: () -> [any RepoAction])
  {
    self.message = message
    self.amend = amend
    self.actions = actions()
  }

  func execute(in repository: any FullRepository) throws
  {
    for action in actions {
      try executeAndStage(action, in: repository)
      try repository.index?.save()
    }
    try repository.commit(message: message, amend: amend)
  }

  private func executeAndStage(_ action: any RepoAction,
                               in repository: any FullRepository) throws
  {
    try action.execute(in: repository)
    if let stageable = action as? any StageableAction {
      try repository.stage(file: stageable.file)
    }
  }
}

struct SaveStash: RepoAction
{
  let message: String

  init(_ message: String = "") { self.message = message }

  func execute(in repository: any FullRepository) throws
  {
    try repository.saveStash(name: message, keepIndex: false,
                             includeUntracked: true, includeIgnored: true)
  }
}

struct ApplyStash: RepoAction
{
  let index: UInt

  init(index: UInt = 0) { self.index = index }

  func execute(in repository: any FullRepository) throws
  {
    try repository.applyStash(index: index)
  }
}

struct PopStash: RepoAction
{
  let index: UInt

  init(index: UInt = 0) { self.index = index }

  func execute(in repository: any FullRepository) throws
  {
    try repository.popStash(index: index)
  }
}

struct DropStash: RepoAction
{
  let index: UInt

  init(index: UInt = 0) { self.index = index }

  func execute(in repository: any FullRepository) throws
  {
    try repository.dropStash(index: index)
  }
}

struct AddRemote: RepoAction
{
  let url: URL
  let name: String

  init(name: String = "origin", url: URL)
  {
    self.name = name
    self.url = url
  }

  func execute(in repository: any FullRepository) throws
  {
    try repository.addRemote(named: name, url: url)
  }
}

struct Fetch: RepoAction
{
  let remoteName: String

  init(remoteName: String = "origin")
  {
    self.remoteName = remoteName
  }

  func execute(in repository: any FullRepository) throws
  {
    guard let remote = repository.remote(named: remoteName) else {
      throw RepoError.notFound
    }
    try repository.fetch(remote: remote, options: .init())
  }
}

struct CreateBranch: RepoAction
{
  let name: LocalBranchRefName
  let target: any ReferenceName

  init(_ name: LocalBranchRefName, target: any ReferenceName = HeadRefName())
  {
    self.name = name
    self.target = target
  }

  func execute(in repository: any FullRepository) throws
  {
    _ = try repository.createBranch(named: name, target: target)
  }
}
