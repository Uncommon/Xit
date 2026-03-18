import Cocoa


enum AccountType: Int, CaseIterable, Sendable
{
  case gitHub = 0
  case gitLab = 1
  
  enum Names
  {
    static let gitHub = "github"
    static let gitLab = "gitlab"
  }
  
  init?(name: String?)
  {
    guard let name = name
    else { return nil }
    
    switch name {
      case Names.gitHub:
        self = .gitHub
      case Names.gitLab:
        self = .gitLab
      default:
        return nil
    }
  }
  
  var name: String
  {
    switch self {
      case .gitHub: return Names.gitHub
      case .gitLab: return Names.gitLab
    }
  }

  var displayName: UIString
  {
    switch self {
      case .gitHub: return ›"GitHub"
      case .gitLab: return ›"GitLab"
    }
  }
  
  var defaultLocation: String
  {
    switch self {
      case .gitHub: return "" // "https://api.github.com"
      case .gitLab: return ""
    }
  }

  /// True if the service uses an API and therefore needs the location to be set
  var needsLocation: Bool
  {
    switch self {
      case .gitHub, .gitLab:
        return false
    }
  }
  
  var imageName: NSImage.Name
  {
    switch self {
      case .gitHub: return .xtGitHub
      case .gitLab: return .xtGitLab
    }
  }
}
