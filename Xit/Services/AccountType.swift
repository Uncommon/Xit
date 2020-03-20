import Foundation


enum AccountType: Int, CaseIterable
{
  case gitHub = 0
  case gitLab = 1
  case bitbucketCloud = 2
  case bitbucketServer = 3
  case teamCity = 4
  
  enum Names
  {
    static let gitHub = "github"
    static let gitLab = "gitlab"
    static let bitbucketCloud = "bitbucketCloud"
    static let bitbucketServer = "bitbucketServer"
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
      case Names.bitbucketCloud:
        self = .bitbucketCloud
      case Names.bitbucketServer:
        self = .bitbucketServer
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
      case .bitbucketCloud: return Names.bitbucketCloud
      case .bitbucketServer: return Names.bitbucketServer
      case .teamCity: return Names.teamCity
    }
  }
  
  var displayName: UIString
  {
    switch self {
      case .gitHub: return ›"GitHub"
      case .gitLab: return ›"GitLab"
      case .bitbucketCloud: return ›"Bitbucket Cloud"
      case .bitbucketServer: return ›"Bitbucket Server"
      case .teamCity: return ›"TeamCity"
    }
  }
  
  var defaultLocation: String
  {
    switch self {
      case .gitHub: return "" // "https://api.github.com"
      case .gitLab: return ""
      case .bitbucketCloud: return "" // "https://api.bitbucket.org"
      case .bitbucketServer: return ""
      case .teamCity: return ""
    }
  }

  /// True if the service uses an API and therefore needs the location to be set
  var needsLocation: Bool
  {
    switch self {
      case .gitHub, .gitLab, .bitbucketCloud:
        return false
      case .bitbucketServer, .teamCity:
        return true
    }
  }
  
  var imageName: NSImage.Name
  {
    switch self {
      case .gitHub: return .xtGitHubTemplate
      case .gitLab: return .xtGitLabTemplate
      case .bitbucketCloud, .bitbucketServer: return .xtBitBucketTemplate
      case .teamCity: return .xtTeamCityTemplate
    }
  }
}
