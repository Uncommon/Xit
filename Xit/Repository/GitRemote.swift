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
  func withConnection(direction: RemoteConnectionDirection,
                      callbacks: RemoteCallbacks,
                      action: () throws -> Void) throws
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
    var remote: OpaquePointer? = nil
    let result = git_remote_lookup(&remote, repository, name)
    guard result == 0,
          let finalRemote = remote
    else { return nil }
    
    self.remote = finalRemote
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
  
  func withConnection(direction: RemoteConnectionDirection,
                      callbacks: RemoteCallbacks,
                      action: () throws -> Void) throws
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
    try action()
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
  
  struct RefSpecIterator: IteratorProtocol
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
