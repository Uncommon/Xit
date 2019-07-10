import Cocoa

public enum RemoteConnectionDirection
{
  case push
  case fetch
}

extension RemoteConnectionDirection
{
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
  
  func rename(_ name: String) throws
  func updateURLString(_ URLString: String?) throws
  func updatePushURLString(_ URLString: String?) throws
  
  /// Calls the callback between opening and closing a cennection to the remote.
  func withConnection(direction: RemoteConnectionDirection,
                      progress: PushProgressCallback?,
                      callback: () throws -> Void) throws
}

extension Remote
{
  var url: URL? { return urlString.flatMap { URL(string: $0) } }
  var pushURL: URL? { return pushURLString.flatMap { URL(string: $0) } }
  
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
  
  init?(name: String, repository: OpaquePointer)
  {
    let remote = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
    let result = git_remote_lookup(remote, repository, name)
    guard result == 0,
          let finalRemote = remote.pointee
    else { return nil }
    
    self.remote = finalRemote
  }

  func rename(_ name: String) throws
  {
    guard let oldName = git_remote_name(remote),
          let owner = git_remote_owner(remote)
    else { throw RepoError.unexpected }
    
    let problems = UnsafeMutablePointer<git_strarray>.allocate(capacity: 1)
    
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
                      progress: PushProgressCallback?,
                      callback: () throws -> Void) throws
  {
    var result: Int32
    var callbacks = git_remote_callbacks.defaultOptions()
    
    if let progress = progress {
      // The progress callback is used as a payload, so it must be "escaping",
      // but since git_remote_connect runs synchronously it doesn't actually
      // escape.
      result = withoutActuallyEscaping(progress) {
        (escapingProgress) in
        var payload = escapingProgress // must also be modifiable
        
        callbacks.payload = UnsafeMutableRawPointer(&payload)
        callbacks.push_transfer_progress = {
          (current, total, bytes, payload) -> Int32 in
          guard let callback = payload?.bindMemory(to: PushProgressCallback.self,
                                                   capacity: 1)
          else { return 1 }
          let progress = PushTransferProgress(current: current, total: total,
                                              bytes: bytes)
          
          return callback.pointee(progress) ? 0 : -1
        }
        return git_remote_connect(remote, direction.gitDirection, &callbacks,
                                  nil, nil)
      }
    }
    else {
      result = git_remote_connect(remote, direction.gitDirection, &callbacks,
                                  nil, nil)
    }

    try RepoError.throwIfGitError(result)
    defer {
      git_remote_disconnect(remote)
    }
    try callback()
  }
}
