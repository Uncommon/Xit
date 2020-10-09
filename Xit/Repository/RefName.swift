import Foundation

enum RefName: RawRepresentable
{
  case tag(String)
  case branch(String)
  case remoteBranch(remote: String, branch: String)
  case unknown

  var rawValue: String
  {
    switch self {
      case .tag(let name): return RefPrefixes.tags + name
      case .branch(let name): return RefPrefixes.heads + name
      case .remoteBranch(let remote, let name):
        return RefPrefixes.remotes + remote +/ name
      case .unknown: return ""
    }
  }
  
  init?(rawValue: String)
  {
    let components = rawValue.components(separatedBy: "/")
    guard components.first == "refs",
          components.count >= 3
    else {
      self = .unknown
      return
    }
    
    switch components[1] {
      case "tags":
        self = .tag(components.dropFirst(2).joined(separator: "/"))
      case "heads":
        self = .branch(components.dropFirst(2).joined(separator: "/"))
      case "remotes":
        guard components.count > 3
        else {
          self = .unknown
          break
        }
        self = .remoteBranch(remote: components[2],
                             branch: components.dropFirst(3)
                                               .joined(separator: "/"))
      default:
        self = .unknown
    }
  }
}
