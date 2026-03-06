import Cocoa


enum AccountType: Int, CaseIterable, Sendable
{
  case gitHub = 0
  case gitLab = 1
  case teamCity = 2
  
  enum Names
  {
    static let gitHub = "github"
    static let gitLab = "gitlab"
    static let teamCity = "teamCity"
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
      case Names.teamCity:
        self = .teamCity
      default:
        return nil
    }
  }
  
  var name: String
  {
    switch self {
      case .gitHub: return Names.gitHub
      case .gitLab: return Names.gitLab
      case .teamCity: return Names.teamCity
    }
  }
  
  var displayName: UIString
  {
    switch self {
      case .gitHub: return ›"GitHub"
      case .gitLab: return ›"GitLab"
      case .teamCity: return ›"TeamCity"
    }
  }
  
  var defaultLocation: String
  {
    switch self {
      case .gitHub: return "" // "https://api.github.com"
      case .gitLab: return ""
      case .teamCity: return ""
    }
  }
  
  /// True if the service uses an API and therefore needs the location to be set
  var needsLocation: Bool
  {
    switch self {
      case .gitHub, .gitLab:
        return false
      case .teamCity:
        return true
    }
  }
  
  var imageName: NSImage.Name
  {
    switch self {
      case .gitHub: return .xtGitHub
      case .gitLab: return .xtGitLab
      case .teamCity: return .xtTeamCity
    }
  }
}
