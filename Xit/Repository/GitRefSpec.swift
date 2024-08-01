import Foundation
import FakedMacro

@Faked
public protocol RefSpec
{
  var source: String { get }
  var destination: String { get }
  var stringValue: String { get }
  var force: Bool { get }
  var direction: RemoteConnectionDirection { get }
  
  /// Check if a refspec's source descriptor matches a reference
  func sourceMatches(refName: String) -> Bool
  /// Check if a refspec's destination descriptor matches a reference
  func destinationMatches(refName: String) -> Bool
  /// Transform a reference to its target following the refspec's rules
  func transformToTarget(name: String) -> String?
  /// Transform a target reference to its source reference following the
  /// refspec's rules
  func transformToSource(name: String) -> String?
}

extension RemoteConnectionDirection: Fakable
{
  public static func fakeDefault() -> Self { .fetch }
}

public struct GitRefSpec: RefSpec
{
  let refSpec: OpaquePointer
  
  public var source: String { String(cString: git_refspec_src(refSpec)) }
  public var destination: String { String(cString: git_refspec_dst(refSpec)) }
  public var stringValue: String { String(cString: git_refspec_string(refSpec)) }
  public var force: Bool { git_refspec_force(refSpec) != 0 }

  public var direction: RemoteConnectionDirection
  { .init(gitDirection: git_refspec_direction(refSpec)) }

  init(refSpec: OpaquePointer)
  {
    self.refSpec = refSpec
  }
  
  init?(string: String, isFetch: Bool)
  {
    guard let refSpec = try? OpaquePointer.from({
      git_refspec_parse(&$0, string, isFetch ? 1 : 0)
    })
    else { return nil }
    
    self.refSpec = refSpec
  }

  public func sourceMatches(refName: String) -> Bool
  {
    return git_refspec_src_matches(refSpec, refName) == 1
  }
  
  public func destinationMatches(refName: String) -> Bool
  {
    return git_refspec_dst_matches(refSpec, refName) == 1
  }
  
  public func transformToTarget(name: String) -> String?
  {
    var buffer = git_buf()
    let result = git_refspec_transform(&buffer, refSpec, name)
    guard result == 0
    else { return "" }
    let target = String(gitBuffer: buffer)
    
    git_buf_free(&buffer)
    return target
  }
  
  public func transformToSource(name: String) -> String?
  {
    var buffer = git_buf()
    let result = git_refspec_rtransform(&buffer, refSpec, name)
    guard result == 0
    else { return nil }
    let source = String(gitBuffer: buffer)
    
    git_buf_free(&buffer)
    return source
  }
}
