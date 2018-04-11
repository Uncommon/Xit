import Foundation

public struct Signature
{
  let name: String?
  let email: String?
  let when: Date
}

extension Signature
{
  struct Default
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
    name = Signature.makeString(gitSignature.name)
    email = Signature.makeString(gitSignature.email)
    when = Date(gitTime: gitSignature.when)
  }
  
  init(defaultFromRepo repository: OpaquePointer)
  {
    let config = GitConfig(repository: repository)
    
    self.name = config?["user.name"] ?? Default.userName
    self.email = config?["user.email"] ?? Default.email
    self.when = Date()
  }
  
  public func withGitSignature(_ block: (git_signature) throws -> Void) rethrows
  {
    var utf8Name = (name ?? "").utf8CString
    var utf8Email = (email ?? "").utf8CString
    
    try utf8Name.withUnsafeMutableBytes {
      (cName) in
      try utf8Email.withUnsafeMutableBytes {
        (cEmail) in
        let name = cName.baseAddress!.bindMemory(to: Int8.self,
                                                 capacity: cName.count+1)
        let email = cEmail.baseAddress!.bindMemory(to: Int8.self,
                                                   capacity: cName.count+1)
        let sig = git_signature(name: name, email: email, when: when.toGitTime())
        
        try block(sig)
      }
    }
  }
  
  private static func makeString(_ ptr: UnsafeMutablePointer<Int8>!) -> String?
  { return ptr == nil ? nil : String(utf8String: ptr) }
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
