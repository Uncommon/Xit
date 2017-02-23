import Foundation

/// Signature data used in commits, blame, tags
public protocol Signature
{
  var name: String? { get }
  var email: String? { get }
  var when: Date { get }
}

public struct GitSignature: Signature
{
  let signature: git_signature
  
  private func makeString(_ ptr: UnsafeMutablePointer<Int8>!) -> String?
  { return ptr == nil ? nil : String(utf8String: ptr) }
  
  public var name: String?
  { return makeString(signature.name) }
  
  public var email: String?
  { return makeString(signature.email) }
  
  public var when: Date
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
