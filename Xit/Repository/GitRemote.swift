import Cocoa

public protocol Remote: AnyObject
{
  var name: String? { get }
  var urlString: String? { get }
  var pushURLString: String? { get }
  
  func rename(_ name: String) throws
  func updateURLString(_ URLString: String) throws
  func updatePushURLString(_ URLString: String) throws
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
    else { throw XTRepository.Error.unexpected }
    
    let problems = UnsafeMutablePointer<git_strarray>.allocate(capacity: 1)
    let result = git_remote_rename(problems, owner, oldName, name)
    
    try XTRepository.Error.throwIfGitError(result)
    git_strarray_free(problems)
  }
  
  func updateURLString(_ URLString: String) throws
  {
    guard let name = git_remote_name(remote),
          let owner = git_remote_owner(remote)
    else { throw XTRepository.Error.unexpected }
    let result = git_remote_set_url(owner, name, URLString)
    
    try XTRepository.Error.throwIfGitError(result)
  }
  
  func updatePushURLString(_ URLString: String) throws
  {
    guard let name = git_remote_name(remote),
          let owner = git_remote_owner(remote)
    else { throw XTRepository.Error.unexpected }
    let result = git_remote_set_pushurl(owner, name, URLString)
    
    try XTRepository.Error.throwIfGitError(result)
  }
}
