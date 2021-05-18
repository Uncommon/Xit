import Foundation

public struct Signature: Equatable
{
  let name: String?
  let email: String?
  let when: Date
}

extension Signature
{
  enum Default
  {
    static let noName = "nobody"
    
    static var userName: String
    {
      let fullName = NSFullUserName()
      guard !fullName.isEmpty
      else { return noName }
      
      return fullName
    }
    
    static var email: String
    {
      let name = NSUserName()
      
      return "\(name.isEmpty ? noName : name)@\(ProcessInfo.processInfo.hostName)"
    }
  }
  
  init(gitSignature: git_signature)
  {
    func makeString(_ ptr: UnsafeMutablePointer<Int8>!) -> String?
    { ptr.flatMap { String(utf8String: $0) } }
    
    name = makeString(gitSignature.name)
    email = makeString(gitSignature.email)
    when = Date(gitTime: gitSignature.when)
  }
  
  init(defaultFromRepo repository: OpaquePointer)
  {
    let config = GitConfig(repository: repository)
    
    self.name = config?["user.name"] ?? Default.userName
    self.email = config?["user.email"] ?? Default.email
    self.when = Date()
  }
  
  public func withGitSignature<T>(_ block: (git_signature) throws -> T)
    rethrows -> T
  {
    var utf8Name = (name ?? "").utf8CString
    var utf8Email = (email ?? "").utf8CString
    
    return try utf8Name.withUnsafeMutableBytes {
      (cName) in
      try utf8Email.withUnsafeMutableBytes {
        (cEmail) in
        let name = cName.baseAddress!.bindMemory(to: Int8.self,
                                                 capacity: cName.count+1)
        let email = cEmail.baseAddress!.bindMemory(to: Int8.self,
                                                   capacity: cName.count+1)
        let sig = git_signature(name: name, email: email, when: when.toGitTime())
        
        return try block(sig)
      }
    }
  }
}

extension Signature
{
  func contains(_ string: String) -> Bool
  {
    return (name?.lowercased().contains(string) ?? false) ||
           (email?.lowercased().contains(string) ?? false)
  }
}

extension Date
{
  init(gitTime: git_time)
  {
    // ignoring time zone offset
    self.init(timeIntervalSince1970: TimeInterval(gitTime.time))
  }
  
  func toGitTime() -> git_time
  {
    return git_time(time: git_time_t(timeIntervalSince1970), offset: 0,
                    sign: "+".utf8CString[0])
  }
}

class GitSignature
{
  // Use a pointer, instead of the struct directly, to let libgit2 handle
  // allocating and deallocating.
  var signature: UnsafeMutablePointer<git_signature>
  
  init?(defaultFromRepo repo: OpaquePointer)
  {
    guard let signature: UnsafeMutablePointer<git_signature> = try? .from({
      git_signature_default(&$0, repo)
    })
    else { return nil }
    
    self.signature = signature
  }
  
  deinit
  {
    git_signature_free(signature)
  }
}
