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

// Branches and BranchIterator were supposed to be nested inside XTRepository
// but nested generics are not allowed.

/// Branches is a sequence, not a collection, because the API does not provide
/// a count or indexed access.
struct Branches<BranchType: XTBranch>: Sequence
{
  typealias Element = BranchType
  let repo: XTRepository
  let type: git_branch_t
  
  func makeIterator() -> BranchIterator<BranchType>
  {
    return BranchIterator<BranchType>(repo: repo, flags: type)
  }
}

class BranchIterator<BranchType: XTBranch>: IteratorProtocol
{
  let repo: XTRepository
  let iterator: OpaquePointer?
  
  init(repo: XTRepository, flags: git_branch_t)
  {
    var result: OpaquePointer?
    
    if git_branch_iterator_new(&result,
                               repo.gtRepo.git_repository(), flags) == 0 {
      self.iterator = result
    }
    else {
      self.iterator = nil
    }
    self.repo = repo
  }
  
  func next() -> BranchType?
  {
    guard let iterator = self.iterator
      else { return nil }
    
    var type = git_branch_t(0)
    var ref: OpaquePointer?
    guard git_branch_next(&ref, &type, iterator) == 0,
      ref != nil,
      let gtRef = GTReference(gitReference: ref!,
                              repository: repo.gtRepo),
      let gtBranch = GTBranch(reference: gtRef,
                              repository: repo.gtRepo)
      else { return nil }
    
    return BranchType(gtBranch: gtBranch)
  }
  
  deinit
  {
    git_branch_iterator_free(iterator)
  }
}

extension XTRepository
{
  enum Error: Swift.Error
  {
    case alreadyWriting
  }
  
  /// The indexable collection of stashes in the repository.
  class Stashes: Collection
  {
    typealias Iterator = StashIterator
    
    let repo: XTRepository
    let refLog: OpaquePointer?
    let count: Int
    
    static let stashRefName = "refs/stash"
    
    init(repo: XTRepository)
    {
      self.repo = repo
      
      let refLogPtr = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
      guard git_reflog_read(refLogPtr, repo.gtRepo.git_repository(),
                            Stashes.stashRefName) == 0
      else {
        self.refLog = nil
        self.count = 0
        return
      }
      
      self.refLog = refLogPtr.pointee
      self.count = git_reflog_entrycount(refLog)
    }
    
    deinit
    {
      git_reflog_free(refLog)
    }
    
    func makeIterator() -> StashIterator
    {
      return StashIterator(stashes: self)
    }
    
    subscript(position: Int) -> XTStash
    {
      let entry = git_reflog_entry_byindex(refLog, position)
      let message = String(cString: git_reflog_entry_message(entry))
      
      return XTStash(repo: repo, index: UInt(position), message: message)
    }
    
    var startIndex: Int { return 0 }
    var endIndex: Int { return count }
    
    func index(after i: Int) -> Int
    {
      return i + 1
    }
  }
  
  class StashIterator: IteratorProtocol
  {
    typealias Element = XTStash
    let stashes: Stashes
    var index: Int
    
    init(stashes: Stashes)
    {
      self.stashes = stashes
      self.index = 0
    }
    
    func next() -> XTStash?
    {
      let result = stashes[index]
      
      index += 1
      return result
    }
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
    
    return toStringArray(strArray.pointee)
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
  
  func rebuildRefsIndex()
  {
    var payload = CallbackPayload(repo: self)
    let callback: git_reference_foreach_cb = { (reference, payload) -> Int32 in
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
      (submodule, error, stop) in
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
  
  func stagedDiff(file: String) -> XTDiffMaker?
  {
    guard let index = try? gtRepo.index(),
          (try? index.refresh()) != nil
    else { return nil }
    
    var indexBlob: GTBlob? = nil
    var headBlob: GTBlob? = nil
    
    if let indexEntry = index.entry(withPath: file),
       let indexObject = try? GTObject(indexEntry: indexEntry) {
      indexBlob = indexObject as? GTBlob
    }
      
    if let headTree = XTCommit(ref: headRef, repository: self)?.tree,
       let headEntry = try? headTree.entry(withPath: file),
       let headObject = try? GTObject(treeEntry: headEntry) {
      headBlob = headObject as? GTBlob
    }
    
    return XTDiffMaker(from: XTDiffMaker.SourceType(headBlob),
                       to: XTDiffMaker.SourceType(indexBlob),
                       path: file)
  }
  
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
      return nil;
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
    var options = git_checkout_options.defaultOptions()
    var error: NSError? = nil
    
    git_checkout_init_options(&options, UInt32(GIT_CHECKOUT_OPTIONS_VERSION))
    withGitStringArray(from: [file]) {
      (stringarray) in
      options.checkout_strategy = GIT_CHECKOUT_FORCE.rawValue +
                                          GIT_CHECKOUT_RECREATE_MISSING.rawValue
      options.paths = stringarray
      
      let result = git_checkout_tree(self.gtRepo.git_repository(), nil, &options)
      
      if result < 0 {
        error = NSError.git_error(for: result) as NSError?
      }
    }
    
    try error.map { throw $0 }
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

/// Converts the given array to a `git_strarray` and calls the given block.
/// This is patterned after `withArrayOfCStrings` except that function does not
/// produce the necessary type.
/// - Note: Ideally this would be an extension on Array where `Element == String`
/// but that's not allowed.
/// - parameter array: The array to convert
/// - parameter block: The block called with the resulting `git_strarray`. To
/// use this array outside the block, use `git_strarray_copy()`.
func withGitStringArray(from array: [String],
                        block: @escaping (git_strarray) -> Void)
{
  let lengths = array.map { $0.utf8.count + 1 }
  let offsets = [0] + scan(lengths, 0, +)
  var buffer = [Int8]()
  
  buffer.reserveCapacity(offsets.last!)
  for string in array {
    buffer.append(contentsOf: string.utf8.map({ Int8($0) }))
    buffer.append(0)
  }
  
  buffer.withUnsafeMutableBufferPointer {
    (pointer) in
    let boundPointer = UnsafeMutableRawPointer(pointer.baseAddress!)
                       .bindMemory(to: Int8.self, capacity: buffer.count)
    var cStrings: [UnsafeMutablePointer<Int8>?] =
                  offsets.map { boundPointer + $0 }
    
    cStrings[cStrings.count-1] = nil
    cStrings.withUnsafeMutableBufferPointer({
      (arrayBuffer) in
      let strarray = git_strarray(strings: arrayBuffer.baseAddress,
                                  count: array.count)
      
      block(strarray)
    })
  }
}

// Waiting for Swift 3.1 where we can do:
// extension Array where Element == String
func toStringArray(_ gitStrArray: git_strarray) -> [String]
{
  var result = [String]()
  var stringPtr = gitStrArray.strings
  
  while let string = stringPtr?.pointee {
    result.append(String(cString: string))
    stringPtr = stringPtr?.advanced(by: 1)
  }
  return result
}

// MARK: Push/pull
extension XTRepository
{
  
  func credentialProvider(_ passwordBlock: @escaping () -> (String, String)?)
      -> GTCredentialProvider
  {
    return GTCredentialProvider() {
      (type, url, user) -> GTCredential in
      if checkCredentialType(type, flag: .sshKey) {
        return sshCredential(user) ?? GTCredential()
      }
      
      guard checkCredentialType(type, flag: .userPassPlaintext)
      else { return GTCredential() }
      
      if let password = keychainPassword(urlString: url, user: user) {
        do {
          return try GTCredential(userName: user, password: password)
        }
        catch let error as NSError {
          NSLog(error.description)
        }
      }
      
      if let (userName, password) = passwordBlock(),
         let result = try? GTCredential(userName: userName,
                                        password: password) {
        return result
      }
      return GTCredential()
    }
  }
  
  public func fetchOptions(downloadTags: Bool,
                           pruneBranches: Bool,
                           passwordBlock: @escaping () -> (String, String)?)
      -> [String: AnyObject]
  {
    let tagOption = downloadTags ? GTRemoteDownloadTagsAuto
                                 : GTRemoteDownloadTagsNone
    let pruneOption: GTFetchPruneOption = pruneBranches ? .yes : .no
    let pruneValue = NSNumber(value: pruneOption.rawValue as Int)
    let tagValue = NSNumber(value: tagOption.rawValue as UInt32)
    let provider = self.credentialProvider(passwordBlock)
    
    return [
        GTRepositoryRemoteOptionsDownloadTags: tagValue,
        GTRepositoryRemoteOptionsFetchPrune: pruneValue,
        GTRepositoryRemoteOptionsCredentialProvider: provider]
  }
  
  /// Initiates a fetch operation.
  /// - parameter remote: The remote to pull from.
  /// - parameter downloadTags: True to also download tags
  /// - parameter pruneBranches: True to delete obsolete branch refs
  /// - parameter passwordBlock: Callback for getting the user and password
  /// - parameter progressBlock: Return true to stop the operation
  public func fetch(remote: XTRemote,
                    downloadTags: Bool,
                    pruneBranches: Bool,
                    passwordBlock: @escaping () -> (String, String)?,
                    progressBlock: @escaping (git_transfer_progress) -> Bool) throws
  {
    try performWriting() {
      let options = self.fetchOptions(downloadTags: downloadTags,
                                      pruneBranches: pruneBranches,
                                      passwordBlock: passwordBlock)
    
      try self.gtRepo.fetch(remote, withOptions: options) {
        (progress, stop) in
        stop.pointee = ObjCBool(progressBlock(progress.pointee))
      }
    }
  }
  
  /// Initiates pulling the given branch.
  /// - parameter branch: Either the local branch or the remote tracking branch.
  /// - parameter remote: The remote to pull from.
  /// - parameter downloadTags: True to also download tags
  /// - parameter pruneBranches: True to delete obsolete branch refs
  /// - parameter passwordBlock: Callback for getting the user and password
  /// - parameter progressBlock: Return true to stop the operation
  // TODO: Use something other than git_transfer_progress
  public func pull(branch: XTBranch,
                   remote: XTRemote,
                   downloadTags: Bool,
                   pruneBranches: Bool,
                   passwordBlock: @escaping () -> (String, String)?,
                   progressBlock: @escaping (git_transfer_progress) -> Bool) throws
  {
    try performWriting() {
      let options = self.fetchOptions(downloadTags: downloadTags,
                                      pruneBranches: pruneBranches,
                                      passwordBlock: passwordBlock)

      try self.gtRepo.pull(branch.gtBranch,
                           from: remote,
                           withOptions: options) {
        (progress, stop) in
        stop.pointee = ObjCBool(progressBlock(progress.pointee))
      }
    }
  }
  
  /// Initiates pushing the given branch.
  /// - parameter branch: Either the local branch or the remote tracking branch.
  /// - parameter remote: The remote to pull from.
  /// - parameter passwordBlock: Callback for getting the user and password
  /// - parameter progressBlock: Return true to stop the operation
  public func push(branch: XTBranch,
                   remote: XTRemote,
                   passwordBlock: @escaping () -> (String, String)?,
                   progressBlock: @escaping (UInt32, UInt32, size_t) -> Bool) throws
  {
    try performWriting() {
      let provider = self.credentialProvider(passwordBlock)
      let options = [ GTRepositoryRemoteOptionsCredentialProvider: provider ]
      
      try self.gtRepo.push(branch.gtBranch, to: remote, withOptions: options) {
        (current, total, bytes, stop) in
        stop.pointee = ObjCBool(progressBlock(current, total, bytes))
      }
    }
  }
}

// MARK: Credential helpers

func checkCredentialType(_ type: GTCredentialType,
                         flag: GTCredentialType) -> Bool
{
  return (type.rawValue & flag.rawValue) != 0
}

func keychainPassword(urlString: String, user: String) -> String?
{
  guard let url = URL(string: urlString),
        let server = url.host as NSString?
  else { return nil }
  
  let user = user as NSString
  var passwordLength: UInt32 = 0
  var passwordData: UnsafeMutableRawPointer? = nil
  
  let err = SecKeychainFindInternetPassword(
      nil,
      UInt32(server.length), server.utf8String,
      0, nil,
      UInt32(user.length), user.utf8String,
      0, nil, 0,
      .any, .default,
      &passwordLength, &passwordData, nil)
  
  if err != noErr {
    return nil
  }
  return NSString(bytes: passwordData!,
                  length: Int(passwordLength),
                  encoding: String.Encoding.utf8.rawValue) as String?
}

func sshCredential(_ user: String) -> GTCredential?
{
  let publicPath =
      ("~/.ssh/id_rsa.pub" as NSString).expandingTildeInPath
  let privatePath =
      ("~/.ssh/id_rsa" as NSString).expandingTildeInPath
  
  return try? GTCredential(
      userName: user,
      publicKeyURL: URL(fileURLWithPath: publicPath),
      privateKeyURL: URL(fileURLWithPath: privatePath),
      passphrase: "")
}

extension NSNotification.Name
{
  static let XTRepositoryRefLogChanged =
      NSNotification.Name("XTRepositoryRefLogChanged")
}
