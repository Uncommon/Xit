import Foundation

/// Signature data used in commits, blame, tags
protocol Signature
{
  var name: String? { get }
  var email: String? { get }
  var when: Date { get }
}

struct GitSignature: Signature
{
  let signature: git_signature
  
  private func makeString(_ ptr: UnsafeMutablePointer<Int8>!) -> String?
  { return ptr == nil ? nil : String(utf8String: ptr) }
  
  var name: String?
  { return makeString(signature.name) }
  
  var email: String?
  { return makeString(signature.email) }
  
  var when: Date
  { return Date(gitTime: signature.when) }
}

extension Date
{
  init(gitTime: git_time)
  {
    // ignoring time zone offset
    self.init(timeIntervalSince1970: TimeInterval(gitTime.time))
  }
}
