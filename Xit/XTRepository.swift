import Foundation


public protocol RepositoryType: class
{
  associatedtype C: CommitType
  
  func commit(forSHA sha: String) -> C?
  func commit(forOID oid: C.ID) -> C?
}


/// Stores a repo reference for C callbacks
struct CallbackPayload { let repo: XTRepository }


extension XTRepository: RepositoryType
{
  public typealias ID = GitOID
  public typealias C = XTCommit

  public func commit(forSHA sha: String) -> XTCommit?
  {
    return XTCommit(sha: sha, repository: self)
  }
  
  public func commit(forOID oid: GitOID) -> XTCommit?
  {
    return XTCommit(oid: oid, repository: self)
  }
}

extension XTRepository
{
  enum Error: Swift.Error
  {
    case alreadyWriting
    case mergeInProgress
    case cherryPickInProgress
    case conflict  // List of conflicted files
    case localConflict
    case detachedHead
    case gitError(Int32)
    case patchMismatch
    case unexpected
    
    var message: String
    {
      switch self {
        case .alreadyWriting:
          return "A writing operation is already in progress."
        case .mergeInProgress:
          return "A merge operation is already in progress."
        case .cherryPickInProgress:
          return "A cherry-pick operation is already in progress."
        case .conflict:
          return "The operation could not be completed because there were " +
                 "conflicts."
        case .localConflict:
          return "There are conflicted files in the work tree or index. " +
                 "Try checking in or stashing your changes first."
        case .detachedHead:
          return "This operation cannot be performed in a detached HEAD state."
        case .gitError(let code):
          return "An internal git error (\(code)) occurred."
        case .patchMismatch:
          return "The patch could not be applied because it did not match " +
                 "the file content."
        case .unexpected:
          return "An unexpected repository error occurred."
      }
    }
    
    init(gitCode: git_error_code)
    {
      switch gitCode {
        case GIT_ECONFLICT, GIT_EMERGECONFLICT:
          self = .conflict
        case GIT_ELOCKED:
          self = .alreadyWriting
        default:
          self = .gitError(gitCode.rawValue)
      }
    }
    
    init(gitNSError: NSError)
    {
      if gitNSError.domain == GTGitErrorDomain {
        self = .gitError(Int32(gitNSError.code))
      }
      else {
        self = .unexpected
      }
    }
  }
  
  /// Returns a file URL for a given relative path.
  func fileURL(_ file: String) -> URL
  {
    return repoURL.appendingPathComponent(file)
  }
  
  /// Returns true if the path is ignored according to the repository's
  /// ignore rules.
  func isIgnored(path: String) -> Bool
  {
    let ignored = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
    let result = git_ignore_path_is_ignored(ignored,
                                            gtRepo.git_repository(),
                                            path)

    return (result == 0) && (ignored.pointee != 0)
  }
  
  func localBranches() -> Branches<XTLocalBranch>
  {
    return Branches(repo: self, type: GIT_BRANCH_LOCAL)
  }
  
  func remoteBranches() -> Branches<XTRemoteBranch>
  {
    return Branches(repo: self, type: GIT_BRANCH_REMOTE)
  }
  
  func remoteNames() -> [String]
  {
    let strArray = UnsafeMutablePointer<git_strarray>.allocate(capacity: 1)
    guard git_remote_list(strArray, gtRepo.git_repository()) == 0
    else { return [] }
    
    return [String](gitStrArray: strArray.pointee)
  }
  
  func stashes() -> Stashes
  {
    return Stashes(repo: self)
  }
  
  /// Like executeWritingBlock, but using Swift exceptions instead of
  /// returning bool.
  func performWriting(_ block: (() throws -> Void)) throws
  {
    objc_sync_enter(self)
    defer { objc_sync_exit(self) }
    
    if isWriting {
      throw Error.alreadyWriting
    }
    updateIsWriting(true)
    try block()
    updateIsWriting(false)
  }
  
  /// Reloads the cached map of OIDs to refs.
  func rebuildRefsIndex()
  {
    var payload = CallbackPayload(repo: self)
    let callback: git_reference_foreach_cb = {
      (reference, payload) -> Int32 in
      let repo = payload!.bindMemory(to: XTRepository.self,
                                     capacity: 1).pointee
      
      let rawName = git_reference_name(reference)
      guard rawName != nil,
            let name = String(validatingUTF8: rawName!)
      else { return 0 }
      
      var peeled: OpaquePointer? = nil
      guard git_reference_peel(&peeled, reference, GIT_OBJ_COMMIT) == 0
      else { return 0 }
      
      let peeledOID = git_object_id(peeled)
      guard let sha = GTOID(gitOid: peeledOID!).sha
      else { return 0 }
      var refs = repo.refsIndex[sha] ?? [String]()
      
      refs.append(name)
      repo.refsIndex[sha] = refs
      
      return 0
    }
    
    refsIndex.removeAll()
    git_reference_foreach(gtRepo.git_repository(), callback, &payload)
  }
  
  /// Returns a list of refs that point to the given commit.
  func refs(at sha: String) -> [String]
  {
    return refsIndex[sha] ?? []
  }
  
  /// Returns a list of all ref names.
  func allRefs() -> [String]
  {
    var stringArray = git_strarray()
    guard git_reference_list(&stringArray, gtRepo.git_repository()) == 0
    else { return [] }
    defer { git_strarray_free(&stringArray) }
    
    var result = [String]()
    
    for i in 0..<stringArray.count {
      guard let refString =
          String(validatingUTF8: UnsafePointer<CChar>(stringArray.strings[i]!))
      else { continue }
      result.append(refString)
    }
    return result
  }
  
  func submodules() -> [XTSubmodule]
  {
    var submodules = [XTSubmodule]()
    
    gtRepo.enumerateSubmodulesRecursively(false) {
      (submodule, _, _) in
      if let submodule = submodule {
        submodules.append(XTSubmodule(repository: self, submodule: submodule))
      }
    }
    return submodules
  }
  
  /// Returns the list of tags, or throws if libgit2 hit an error.
  func tags() throws -> [XTTag]
  {
    let tags = try gtRepo.allTags()
    
    return tags.map({ XTTag(repository: self, tag: $0) })
  }
  
  /// Applies the given patch hunk to the specified file in the index.
  /// - parameter path: Target file path
  /// - parameter hunk: Hunk to be applied
  /// - parameter stage: True if the change is being staged, falses if unstaged
  /// (the patch should be reversed)
  func patchIndexFile(path: String, hunk: GTDiffHunk, stage: Bool) throws
  {
    var encoding = String.Encoding.utf8
    let index = try gtRepo.index()
    
    if let entry = index.entry(withPath: path) {
      if (hunk.newStart == 1) || (hunk.oldStart == 1) {
        let status = try self.status(file: path)
        
        if stage {
          if status.0 == .deleted {
            try stageFile(path)
            return
          }
        }
        else {
          switch status.1 {
            case .added, .deleted:
              // If it's added/deleted in the index, and we're unstaging, then the
              // hunk must cover the whole file
              try unstageFile(path)
              return
            default:
              break
          }
        }
      }
      
      guard let blob = (try entry.gtObject()) as? GTBlob,
            let data = blob.data(),
            let text = String(data: data, usedEncoding: &encoding)
      else { throw Error.unexpected }
      
      guard let patchedText = hunk.applied(to: text, reversed: !stage)
      else { throw Error.patchMismatch }
      
      guard let patchedData = patchedText.data(using: encoding)
      else { throw Error.unexpected }
      
      try index.add(patchedData, withPath: path)
      try index.write()
      return
    }
    else {
      let status = try self.status(file: path)
      
      // Assuming the hunk covers the whole file
      if stage && status.0 == .untracked && hunk.newStart == 1 {
        try stageFile(path)
        return
      }
      else if !stage && (status.1 == .deleted) && (hunk.oldStart == 1) {
        try unstageFile(path)
        return
      }
    }
    throw Error.patchMismatch
  }
  
  /// Returns a diff maker for a file at the specified commit, compared to the
  /// parent commit.
  func diffMaker(forFile file: String, commitSHA: String, parentSHA: String?)
      -> XTDiffMaker?
  {
    guard let toCommit = commit(forSHA: commitSHA)?.gtCommit
    else { return nil }
    
    var fromSource = XTDiffMaker.SourceType.data(Data())
    var toSource = XTDiffMaker.SourceType.data(Data())
    
    if let toTree = toCommit.tree,
       let toEntry = try? toTree.entry(withPath: file),
       let toBlob = (try? GTObject(treeEntry: toEntry)) as? GTBlob {
      toSource = .blob(toBlob)
    }
    
    if let parentSHA = parentSHA,
       let parentCommit = commit(forSHA: parentSHA)?.gtCommit,
       let fromTree = parentCommit.tree,
       let fromEntry = try? fromTree.entry(withPath: file),
       let fromBlob = (try? GTObject(treeEntry: fromEntry)) as? GTBlob {
      fromSource = .blob(fromBlob)
    }
    
    return XTDiffMaker(from: fromSource, to: toSource, path: file)
  }
  
  func fileBlob(ref: String, path: String) -> GTBlob?
  {
    guard let headTree = XTCommit(ref: ref, repository: self)?.tree,
          let headEntry = try? headTree.entry(withPath: path),
          let headObject = try? GTObject(treeEntry: headEntry)
    else { return nil }

    return headObject as? GTBlob
  }
  
  func stagedBlob(file: String) -> GTBlob?
  {
    guard let index = try? gtRepo.index(),
          (try? index.refresh()) != nil,
          let indexEntry = index.entry(withPath: file),
          let indexObject = try? GTObject(indexEntry: indexEntry)
    else { return nil }
    
    return indexObject as? GTBlob
  }
  
  /// Returns a diff maker for a file in the index, compared to the workspace
  /// file.
  func stagedDiff(file: String) -> XTDiffMaker?
  {
    let indexBlob = stagedBlob(file: file)
    let headBlob = fileBlob(ref: headRef, path: file)
    
    return XTDiffMaker(from: XTDiffMaker.SourceType(headBlob),
                       to: XTDiffMaker.SourceType(indexBlob),
                       path: file)
  }
  
  /// Returns a diff maker for a file in the workspace, compared to the index.
  func unstagedDiff(file: String) -> XTDiffMaker?
  {
    let url = self.repoURL.appendingPathComponent(file)
    let exists = FileManager.default.fileExists(atPath: url.path)
    
    do {
      let data = exists ? try Data(contentsOf: url) : Data()
      
      if let index = try? gtRepo.index(),
         let indexEntry = index.entry(withPath: file),
         let indexBlob = try? GTObject(indexEntry: indexEntry) as? GTBlob {
        return XTDiffMaker(from: XTDiffMaker.SourceType(indexBlob),
                           to: .data(data), path: file)
      }
      else {
        return XTDiffMaker(from: .data(Data()), to: .data(data), path: file)
      }
    }
    catch {
      return nil
    }
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
  
  func commitForStash(at index: UInt) -> GTCommit?
  {
    guard let stashRef = try? gtRepo.lookUpReference(withName: "refs/stash"),
          let stashLog = GTReflog(reference: stashRef),
          index < stashLog.entryCount,
          let entry = stashLog.entry(at: index)
    else { return nil }
    
    return (try? entry.updatedOID.map { try gtRepo.lookUpObject(by: $0) })
           as? GTCommit
  }
  
  /// Returns the unstaged and staged status of the given file.
  func status(file: String) throws -> (XitChange, XitChange)
  {
    let statusFlags = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
    let result = git_status_file(statusFlags, gtRepo.git_repository(), file)
    
    if result != 0 {
      throw NSError.git_error(for: result)
    }
    
    let flags = git_status_t(statusFlags.pointee)
    var unstagedChange = XitChange.unmodified
    var stagedChange = XitChange.unmodified
    
    switch flags {
      case _ where flags.test(GIT_STATUS_WT_NEW):
        unstagedChange = .untracked
      case _ where flags.test(GIT_STATUS_WT_MODIFIED),
           _ where flags.test(GIT_STATUS_WT_TYPECHANGE):
        unstagedChange = .modified
      case _ where flags.test(GIT_STATUS_WT_DELETED):
        unstagedChange = .deleted
      case _ where flags.test(GIT_STATUS_WT_RENAMED):
        unstagedChange = .renamed
      case _ where flags.test(GIT_STATUS_IGNORED):
        unstagedChange = .ignored
      case _ where flags.test(GIT_STATUS_CONFLICTED):
        unstagedChange = .conflict
      // ignoring GIT_STATUS_WT_UNREADABLE
      default:
        break
    }
    
    switch flags {
      case _ where flags.test(GIT_STATUS_INDEX_NEW):
        stagedChange = .added
      case _ where flags.test(GIT_STATUS_INDEX_MODIFIED),
           _ where flags.test(GIT_STATUS_WT_TYPECHANGE):
        stagedChange = .modified
      case _ where flags.test(GIT_STATUS_INDEX_DELETED):
        stagedChange = .deleted
      case _ where flags.test(GIT_STATUS_INDEX_RENAMED):
        stagedChange = .renamed
      default:
        break
    }
    
    return (unstagedChange, stagedChange)
  }
  
  /// Reverts the given workspace file to the contents at HEAD.
  @objc(revertFile:error:)
  func revert(file: String) throws
  {
    let status = try self.status(file: file)
    
    if status.0 == .untracked {
      try FileManager.default.removeItem(at: repoURL.appendingPathComponent(file))
    }
    else {
      var options = git_checkout_options.defaultOptions()
      var error: Error? = nil
      
      git_checkout_init_options(&options, UInt32(GIT_CHECKOUT_OPTIONS_VERSION))
      [file].withGitStringArray {
        (stringarray) in
        options.checkout_strategy = GIT_CHECKOUT_FORCE.rawValue +
                                    GIT_CHECKOUT_RECREATE_MISSING.rawValue
        options.paths = stringarray
        
        let result = git_checkout_tree(self.gtRepo.git_repository(), nil, &options)
        
        if result < 0 {
          error = Error.gitError(result)
        }
      }
      
      try error.map { throw $0 }
    }
  }
  
  /// Renames the given local branch.
  @objc(renameBranch:to:error:)
  func rename(branch: String, to newName: String) throws
  {
    if isWriting {
      throw Error.alreadyWriting
    }
    
    let branchRef = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
    var result = git_branch_lookup(branchRef, gtRepo.git_repository(),
                                   branch, GIT_BRANCH_LOCAL)
  
    if result != 0 {
      throw NSError.git_error(for: result)
    }
    
    let newRef = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
    
    result = git_branch_move(newRef, branchRef.pointee, newName, 0)
    if result != 0 {
      throw NSError.git_error(for: result)
    }
  }
  
  func graphBetween(local: GitOID, upstream: GitOID) -> (ahead: Int,
                                                         behind: Int)?
  {
    let ahead = UnsafeMutablePointer<Int>.allocate(capacity: 1)
    let behind = UnsafeMutablePointer<Int>.allocate(capacity: 1)
    
    if git_graph_ahead_behind(ahead, behind, gtRepo.git_repository(),
                              local.unsafeOID(), upstream.unsafeOID()) == 0 {
      return (ahead.pointee, behind.pointee)
    }
    else {
      return nil
    }
  }
  
  func graphBetween(localBranch: XTLocalBranch,
                    upstreamBranch: XTRemoteBranch) ->(ahead: Int,
                                                       behind: Int)?
  {
    if let localOID = localBranch.oid,
       let upstreamOID = upstreamBranch.oid {
      return graphBetween(local: localOID, upstream: upstreamOID)
    }
    else {
      return nil
    }
  }
}

extension NSNotification.Name
{
  static let XTRepositoryRefLogChanged =
      NSNotification.Name("XTRepositoryRefLogChanged")
}
