import Foundation

extension XTRepository: FileContents
{
  public func contentsOfFile(path: String, at commit: XTCommit) -> Data?
  {
    guard let tree = commit.tree,
          let entry = try? tree.entry(withPath: path),
          let blob = (try? entry.gtObject()) as? GTBlob
    else { return nil }
    
    return blob.data()
  }
  
  public func contentsOfStagedFile(path: String) -> Data?
  {
    return stagedBlob(file: path)?.makeData()
  }
  
  public func stagedBlob(file: String) -> GitBlob?
  {
    guard let index = GitIndex(repository: self),
          let entry = index.entry(at: file),
          let blob = GitBlob(repository: self, oid: entry.oid as! GitOID)
    else { return nil }
    
    return blob
  }
  
  public func fileBlob(ref: String, path: String) -> GitBlob?
  {
    guard let headTree = XTCommit(ref: ref, repository: self)?.tree,
          let headEntry = try? headTree.entry(withPath: path),
          let oid = headEntry.oid.map({ GitOID(oid: $0.git_oid().pointee) })
    else { return nil }
    
    return GitBlob(repository: self, oid: oid)
  }
}

extension XTRepository: FileDiffing
{
  /// Returns a diff maker for a file at the specified commit, compared to the
  /// parent commit.
  public func diffMaker(forFile file: String,
                        commitOID: GitOID,
                        parentOID: GitOID?) -> XTDiffMaker?
  {
    guard let toCommit = commit(forOID: commitOID)?.gtCommit
    else { return nil }
    
    var fromSource = XTDiffMaker.SourceType.data(Data())
    var toSource = XTDiffMaker.SourceType.data(Data())
    
    if let toTree = toCommit.tree,
       let toEntry = try? toTree.entry(withPath: file),
       let oid = toEntry.oid.map({ GitOID(oid: $0.git_oid().pointee) }),
       let toBlob = GitBlob(repository: self, oid: oid) {
      toSource = .blob(toBlob)
    }
    
    if let parentOID = parentOID,
       let parentCommit = commit(forOID: parentOID)?.gtCommit,
       let fromTree = parentCommit.tree,
       let fromEntry = try? fromTree.entry(withPath: file),
       let oid = fromEntry.oid.map({ GitOID(oid: $0.git_oid().pointee) }),
       let fromBlob = GitBlob(repository: self, oid: oid) {
      fromSource = .blob(fromBlob)
    }
    
    return XTDiffMaker(from: fromSource, to: toSource, path: file)
  }
  
  // Returns a file diff for a given commit.
  public func diff(for path: String,
                   commitSHA sha: String,
                   parentOID: GitOID?) -> XTDiffDelta?
  {
    guard let diff = self.diff(forSHA: sha, parent: parentOID)
    else { return nil }
    
    return delta(from: diff, path: path)
  }
  
  /// Returns a diff maker for a file in the index, compared to the workspace
  /// file.
  public func stagedDiff(file: String) -> XTDiffMaker?
  {
    guard let headRef = self.headRef
    else { return nil }
    let indexBlob = stagedBlob(file: file)
    let headBlob = fileBlob(ref: headRef, path: file)
    
    return XTDiffMaker(from: XTDiffMaker.SourceType(headBlob),
                       to: XTDiffMaker.SourceType(indexBlob),
                       path: file)
  }
  
  /// Returns a diff maker for a file in the workspace, compared to the index.
  public func unstagedDiff(file: String) -> XTDiffMaker?
  {
    let url = self.repoURL.appendingPathComponent(file)
    let exists = FileManager.default.fileExists(atPath: url.path)
    
    do {
      let data = exists ? try Data(contentsOf: url) : Data()
      
      if let index = GitIndex(repository: self),
         let indexEntry = index.entry(at: file) as? GitIndex.Entry,
         let indexBlob = GitBlob(repository: self, oid: indexEntry.oid) {
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
}

extension XTRepository
{
  
  /// Returns the diff for the referenced commit, compared to its first parent
  /// or to a specific parent.
  func diff(forSHA sha: String, parent parentOID: GitOID?) -> GTDiff?
  {
    let parentSHA = parentOID?.sha ?? ""
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
  
  // Returns the changes for the given commit.
  func changes(for sha: String, parent parentOID: GitOID?) -> [FileChange]
  {
    guard sha != XTStagingSHA
    else { return stagingChanges() }
    
    guard let commit = self.commit(forSHA: sha),
          let sha = commit.sha
    else { return [] }
    
    let parentOID = parentOID ?? commit.parentOIDs.first
    let diff = self.diff(forSHA: sha, parent: parentOID)
    var result = [FileChange]()
    
    diff?.enumerateDeltas {
      (delta, _) in
      if delta.type != .unmodified {
        let change = FileChange(path: delta.newFile.path,
                                change: XitChange(delta: delta.type))
        
        result.append(change)
      }
    }
    return result
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
            try self.stage(file: path)
            return
          }
        }
        else {
          switch status.1 {
          case .added, .deleted:
            // If it's added/deleted in the index, and we're unstaging, then the
            // hunk must cover the whole file
            try unstage(file: path)
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
        try self.stage(file: path)
        return
      }
      else if !stage && (status.1 == .deleted) && (hunk.oldStart == 1) {
        try unstage(file: path)
        return
      }
    }
    throw Error.patchMismatch
  }
}
