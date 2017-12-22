import Cocoa

public protocol Submodule
{
  var name: String { get }
  var path: String { get }
  var url: URL? { get }
}

public class GitSubmodule: Submodule
{
  var submodule: OpaquePointer
  
  init(submodule: OpaquePointer)
  {
    self.submodule = submodule
  }
  
  public var name: String { return String(cString: git_submodule_name(submodule)) }
  public var path: String { return String(cString: git_submodule_path(submodule)) }
  public var url: URL?
  {
    return URL(string: String(cString: git_submodule_url(submodule)))
  }
}
