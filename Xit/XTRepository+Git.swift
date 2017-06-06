import Foundation

public class XTRepository: NSObject
{
  private(set) var gtRepo: GTRepository
  let repoURL: URL
  let gitCMD: String
  let queue: TaskQueue
  var refsIndex = [String: [String]]()
  fileprivate(set) var isWriting = false
  fileprivate var executing = false
  
  fileprivate var cachedHeadRef, cachedHeadSHA, cachedBranch: String?
  
  let diffCache = NSCache<NSString, GTDiff>()
  fileprivate var repoWatcher: XTRepositoryWatcher! = nil
  fileprivate var workspaceWatcher: WorkspaceWatcher! = nil
  private(set) var config: XTConfig! = nil
  
  var gitDirectoryURL: URL
  {
    return gtRepo.gitDirectoryURL ?? URL(fileURLWithPath: "")
  }
  
  static func gitPath() -> String?
  {
    let paths = ["/usr/bin/git", "/usr/local/git/bin/git"]
    
    return paths.first(where: { FileManager.default.fileExists(atPath: $0) })
  }
  
  @objc(initWithURL:)
  init?(url: URL)
  {
    guard let gitCMD = XTRepository.gitPath(),
          let gtRepo = try? GTRepository(url: url)
    else { return nil }
    
    self.repoURL = url
    self.gitCMD = gitCMD
    self.gtRepo = gtRepo
    
    self.queue = TaskQueue(id: "com.uncommonplace.xit.\(url.path)")
    
    super.init()
    
    postInit()
  }
  
  @objc(initEmptyWithURL:)
  init?(emptyURL url: URL)
  {
    guard let gitCMD = XTRepository.gitPath(),
          let gtRepo = try? GTRepository.initializeEmpty(atFileURL: url,
                                                         options: nil)
    else { return nil }
    
    self.repoURL = url
    self.gitCMD = gitCMD
    self.gtRepo = gtRepo
    self.queue = TaskQueue(id: "com.uncommonplace.xit.\(url.path)")
    
    super.init()
    
    postInit()
  }
  
  private func postInit()
  {
    self.repoWatcher = XTRepositoryWatcher(repository: self)
    self.workspaceWatcher = WorkspaceWatcher(repository: self)
    self.config = XTConfig(repository: self)
  }
  
  deinit
  {
    repoWatcher.stop()
    workspaceWatcher.stop()
    NotificationCenter.default.removeObserver(self)
  }
  
  func updateIsWriting(_ writing: Bool)
  {
    guard writing != isWriting
    else { return }
    
    objc_sync_enter(self)
    defer {
      objc_sync_exit(self)
    }
    
    isWriting = writing
  }
  
  func writing(_ block: () -> Bool) -> Bool
  {
    objc_sync_enter(self)
    defer {
      objc_sync_exit(self)
    }
    
    guard !isWriting
    else { return false }
    
    isWriting = true
    defer {
      isWriting = false
    }
    return block()
  }

  func executeGit(args: [String],
                  stdIn: String? = nil,
                  writes: Bool) throws -> Data
  {
    guard FileManager.default.fileExists(atPath: repoURL.path)
    else {
      throw NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError,
                    userInfo: nil)
    }
    
    objc_sync_enter(self)
    defer {
      objc_sync_exit(self)
    }
    if writes && isWriting {
      throw Error.alreadyWriting
    }
    updateIsWriting(writes)
    defer {
      updateIsWriting(false)
    }
    executing = true
    defer { executing = false }
    NSLog("*** command = git \(args.joined(separator: " "))")
    
    let task = Process()
    
    task.currentDirectoryPath = repoURL.path
    task.launchPath = gitCMD
    task.arguments = args
    
    if let stdInData = stdIn?.data(using: .utf8) {
      let stdInPipe = Pipe()
      
      stdInPipe.fileHandleForWriting.write(stdInData)
      stdInPipe.fileHandleForWriting.closeFile()
      task.standardInput = stdInPipe
    }
    
    let pipe = Pipe()
    let errorPipe = Pipe()
    
    task.standardOutput = pipe
    task.standardError = errorPipe
    try task.throwingLaunch()
    
    let output = pipe.fileHandleForReading.readDataToEndOfFile()
    
    task.waitUntilExit()
    
    guard task.terminationStatus == 0
    else {
      let string = String(data: output, encoding: .utf8) ?? "-"
      let errorOutput = errorPipe.fileHandleForReading.readDataToEndOfFile()
      let errorString = String(data: errorOutput, encoding: .utf8) ?? "-"
      
      NSLog("**** output = \(string)")
      NSLog("**** error = \(errorString)")
      throw NSError(domain: XTErrorDomainGit, code: Int(task.terminationStatus),
                    userInfo: [XTErrorOutputKey: string,
                               XTErrorArgsKey: args.joined(separator: " ")])
    }
    
    return output
  }
}

// For testing
internal func setRepoWriting(_ repo: XTRepository, _ writing: Bool)
{
  repo.isWriting = writing
}

// MARK: Refs

extension XTRepository
{
  var headRef: String?
  {
    objc_sync_enter(self)
    defer {
      objc_sync_exit(self)
    }
    if let ref = cachedHeadRef {
      return ref
    }
    else {
      guard let head = parseSymbolicReference("HEAD")
      else { return nil }
      let ref = head.hasPrefix("refs/heads/") ? head : "HEAD"
      
      cachedHeadRef = ref
      cachedHeadSHA = sha(forRef: ref)
      return ref
    }
  }
  
  var headSHA: String?
  {
    return headRef.map { sha(forRef: $0) } ?? nil
  }

  func refsChanged()
  {
    guard let newBranch = calculateCurrentBranch(),
          newBranch != cachedBranch
    else { return }
    
    willChangeValue(forKey: "currentBranch")
    cachedBranch = newBranch
    didChangeValue(forKey: "currentBranch")
  }

  var currentBranch: String?
  {
    if cachedBranch == nil {
      cachedBranch = calculateCurrentBranch()
    }
    return cachedBranch
  }

  fileprivate func calculateCurrentBranch() -> String?
  {
    guard let branch = try? gtRepo.currentBranch(),
          let shortName = branch.shortName
    else { return nil }
    
    if let remoteName = branch.remoteName {
      return "\(remoteName)/\(shortName)"
    }
    else {
      return branch.shortName
    }
  }

  func hasHeadReference() -> Bool
  {
    if (try? gtRepo.headReference()) != nil {
      return true
    }
    else {
      return false
    }
  }
  
  func parseSymbolicReference(_ reference: String) -> String?
  {
    guard let gtRef = try? gtRepo.lookUpReference(withName: reference)
    else { return nil }
    
    if let unresolvedRef = gtRef.unresolvedTarget as? GTReference,
       let name = unresolvedRef.name {
      return name
    }
    return reference
  }
  
  func parentTree() -> String
  {
    return hasHeadReference() ? "HEAD" : kEmptyTreeHash
  }
  
  func sha(forRef ref: String) -> String?
  {
    guard let object = try? gtRepo.lookUpObject(byRevParse: ref)
    else { return nil }
    
    return (object as? GTObject)?.sha
  }
  
  func createBranch(_ name: String) -> Bool
  {
    cachedBranch = nil
    return (try? executeGit(args: ["checkout", "-b", name],
                            writes: true)) != nil
  }
  
  func deleteBranch(_ name: String) -> Bool
  {
    return writing {
      let fullBranch = GTBranch.localNamePrefix().appending(name)
      guard let ref = try? gtRepo.lookUpReference(withName: fullBranch),
            let branch = GTBranch(reference: ref, repository: gtRepo)
      else { return false }
      
      return (try? branch.delete()) != nil
    }
  }
}

// MARK: Files
extension XTRepository
{
  func contentsOfFile(path: String, at commit: XTCommit) -> Data?
  {
    guard let tree = commit.tree,
          let entry = try? tree.entry(withPath: path),
          let blob = (try? entry.gtObject()) as? GTBlob
    else { return nil }
    
    return blob.data()
  }
  
  func contentsOfStagedFile(path: String) -> Data?
  {
    guard let index = try? gtRepo.index(),
          (try? index.refresh()) != nil,
          let entry = index.entry(withPath: path),
          let blob = (try? entry.gtObject()) as? GTBlob
    else { return nil }
    
    return blob.data()
  }
  
  /// Returns the diff for the referenced commit, compared to its first parent
  /// or to a specific parent.
  func diff(forSHA sha: String, parent parentSHA: String?) -> GTDiff?
  {
    let parentSHA = parentSHA ?? ""
    let key = sha.appending(parentSHA) as NSString
    
    if let diff = diffCache.object(forKey: key) {
      return diff
    }
    else {
      guard let commit = (try? gtRepo.lookUpObject(bySHA: sha)) as? GTCommit
        else { return nil }
      
      let parents = commit.parents
      let parent: GTCommit? = (parentSHA == "")
        ? parents.first
        : parents.first(where: { $0.sha == parentSHA })
      
      guard let diff = try? GTDiff(oldTree: parent?.tree,
                                   withNewTree: commit.tree,
                                   in: gtRepo, options: nil)
        else { return nil }
      
      diffCache.setObject(diff, forKey: key)
      return diff
    }
  }
}
