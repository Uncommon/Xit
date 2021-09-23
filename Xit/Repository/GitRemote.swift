import Cocoa

public enum RemoteConnectionDirection
{
  case push
  case fetch
}

extension RemoteConnectionDirection
{
  init(gitDirection: git_direction)
  {
    switch gitDirection {
      case GIT_DIRECTION_FETCH:
        self = .fetch
      default:
        self = .push
    }
  }
  
  var gitDirection: git_direction
  {
    switch self {
      case .push:
        return GIT_DIRECTION_PUSH
      case .fetch:
        return GIT_DIRECTION_FETCH
    }
  }
}

public protocol Remote: AnyObject
{
  typealias PushProgressCallback = (PushTransferProgress) -> Bool
  
  var name: String? { get }
  var urlString: String? { get }
  var pushURLString: String? { get }
  
  var refSpecs: AnyCollection<RefSpec> { get }
  
  func rename(_ name: String) throws
  func updateURLString(_ URLString: String?) throws
  func updatePushURLString(_ URLString: String?) throws
  
  /// Calls the callback between opening and closing a connection to the remote.
  func withConnection<T>(direction: RemoteConnectionDirection,
                         callbacks: RemoteCallbacks,
                         action: (ConnectedRemote) throws -> T) throws -> T
}

extension Remote
{
  var url: URL? { urlString.flatMap { URL(string: $0) } }
  var pushURL: URL? { pushURLString.flatMap { URL(string: $0) } }
  
  func updateURL(_ url: URL) throws
  {
    try updateURLString(url.absoluteString)
  }
  
  func updatePushURL(_ url: URL) throws
  {
    try updatePushURLString(url.absoluteString)
  }
}

public protocol ConnectedRemote: AnyObject
{
  var defaultBranch: String? { get }
  
  func referenceAdvertisements() throws -> [RemoteHead]
}

class GitRemote: Remote
{
  let remote: OpaquePointer
  
  var name: String?
  {
    guard let name = git_remote_name(remote)
    else { return nil }
    
    return String(cString: name)
  }

  var urlString: String?
  {
    guard let url = git_remote_url(remote)
    else { return nil }
    
    return String(cString: url)
  }
  
  var pushURLString: String?
  {
    guard let url = git_remote_pushurl(remote)
    else { return nil }
    
    return String(cString: url)
  }
  
  var refSpecs: AnyCollection<RefSpec>
  { AnyCollection(RefSpecCollection(remote: self)) }
  
  init?(name: String, repository: OpaquePointer)
  {
    guard let remote = try? OpaquePointer.from({
        git_remote_lookup(&$0, repository, name) })
    else { return nil }
    
    self.remote = remote
  }
  
  init?(url: URL)
  {
    guard let remote = try? OpaquePointer.from({
      git_remote_create_detached(&$0, url.absoluteString)
    })
    else { return nil }
    
    self.remote = remote
  }

  func rename(_ name: String) throws
  {
    guard let oldName = git_remote_name(remote),
          let owner = git_remote_owner(remote)
    else { throw RepoError.unexpected }
    
    let problems = UnsafeMutablePointer<git_strarray>.allocate(capacity: 1)
    defer {
      problems.deallocate()
    }
    
    problems.pointee = git_strarray()
    
    let result = git_remote_rename(problems, owner, oldName, name)
    let resultCode = git_error_code(rawValue: result)
    
    defer {
      git_strarray_free(problems)
    }
    switch resultCode {
      case GIT_EINVALIDSPEC:
        throw RepoError.invalidName(name)
      case GIT_EEXISTS:
        throw RepoError.duplicateName
      case GIT_OK:
        break
      default:
        throw RepoError(gitCode: resultCode)
    }
  }
  
  func updateURLString(_ URLString: String?) throws
  {
    guard let name = git_remote_name(remote),
          let owner = git_remote_owner(remote)
    else { throw RepoError.unexpected }
    let result = git_remote_set_url(owner, name, URLString)
    
    if result == GIT_EINVALIDSPEC.rawValue {
      throw RepoError.invalidName(URLString ?? "")
    }
    else {
      try RepoError.throwIfGitError(result)
    }
  }
  
  func updatePushURLString(_ URLString: String?) throws
  {
    guard let name = git_remote_name(remote),
          let owner = git_remote_owner(remote)
    else { throw RepoError.unexpected }
    let result = git_remote_set_pushurl(owner, name, URLString)
    
    if result == GIT_EINVALIDSPEC.rawValue {
      throw RepoError.invalidName(URLString ?? "")
    }
    else {
      try RepoError.throwIfGitError(result)
    }
  }
  
  func withConnection<T>(direction: RemoteConnectionDirection,
                         callbacks: RemoteCallbacks,
                         action: (ConnectedRemote) throws -> T) throws -> T
  {
    var result: Int32
    
    result = git_remote_callbacks.withCallbacks(callbacks) {
      (gitCallbacks) in
      withUnsafePointer(to: gitCallbacks) {
        (callbacksPtr) in
        git_remote_connect(remote, direction.gitDirection, callbacksPtr, nil, nil)
      }
    }
    
    try RepoError.throwIfGitError(result)
    defer {
      git_remote_disconnect(remote)
    }
    return try action(GitConnectedRemote(remote))
  }
}

extension GitRemote
{
  struct RefSpecCollection: Collection
  {
    let remote: GitRemote

    var count: Int { git_remote_refspec_count(remote.remote) }
    
    func makeIterator() -> RefSpecIterator
    {
      return RefSpecIterator(remote: remote)
    }
    
    subscript(position: Int) -> RefSpec
    {
      return GitRefSpec(refSpec: git_remote_get_refspec(remote.remote, position))
    }
    
    public var startIndex: Int { 0 }
    public var endIndex: Int { count }
    
    public func index(after i: Int) -> Int
    {
      return i + 1
    }
  }
  
  public struct RefSpecIterator: IteratorProtocol
  {
    var index: Int
    let remote: GitRemote
    
    init(remote: GitRemote)
    {
      self.index = 0
      self.remote = remote
    }
    
    mutating func next() -> RefSpec?
    {
      guard index < git_remote_refspec_count(remote.remote)
      else { return nil }
      
      defer {
        index += 1
      }
      return GitRefSpec(refSpec: git_remote_get_refspec(remote.remote, index))
    }
  }
}

public struct RemoteHead
{
  let local: Bool
  let oid: OID
  let localOID: OID
  let name: String
  let symrefTarget: String
  
  init(_ head: git_remote_head)
  {
    self.local = head.local == 0 ? false : true
    self.oid = GitOID(oid: head.oid)
    self.localOID = GitOID(oid: head.loid)
    self.name = String(cString: head.name)
    self.symrefTarget = head.symref_target.map { String(cString: $0) } ?? ""
  }
}

class GitConnectedRemote: ConnectedRemote
{
  let remote: OpaquePointer

  var defaultBranch: String?
  {
    var buf = git_buf()
    let result = git_remote_default_branch(&buf, remote)
    guard result == GIT_OK.rawValue
    else { return nil }
    defer {
      git_buf_free(&buf)
    }
    
    return String(gitBuffer: buf)
  }
  
  init(_ remote: OpaquePointer)
  {
    self.remote = remote
  }
  
  func referenceAdvertisements() throws -> [RemoteHead]
  {
    var size: size_t = 0
    let heads = try UnsafeMutablePointer.from {
      git_remote_ls(&$0, &size, remote)
    }
    
    return (0..<size).compactMap {
      heads.advanced(by: $0).pointee.flatMap({ RemoteHead($0.pointee) })
    }
  }
}
