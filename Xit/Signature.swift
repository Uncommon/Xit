import Foundation

public struct Signature
{
  let name: String?
  let email: String?
  let when: Date
}

extension Signature
{
  init(gitSignature: git_signature)
  {
    name = Signature.makeString(gitSignature.name)
    email = Signature.makeString(gitSignature.email)
    when = Date(gitTime: gitSignature.when)
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
}
