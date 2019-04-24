import Foundation


enum AccountType: Int, CaseIterable
{
  case gitHub = 0
  case bitbucketCloud = 1
  case bitbucketServer = 2
  case teamCity = 3
  
  enum Names
  {
    static let gitHub = "github"
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
      case .bitbucketCloud: return Names.bitbucketCloud
      case .bitbucketServer: return Names.bitbucketServer
      case .teamCity: return Names.teamCity
    }
  }
  
  var displayName: UIString
  {
    switch self {
      case .gitHub: return ›"GitHub"
      case .bitbucketCloud: return ›"Bitbucket Cloud"
      case .bitbucketServer: return ›"Bitbucket Server"
      case .teamCity: return ›"TeamCity"
    }
  }
  
  var defaultLocation: String
  {
    switch self {
      case .gitHub: return "https://api.github.com"
      case .bitbucketCloud: return "https://api.bitbucket.org"
      case .bitbucketServer: return ""
      case .teamCity: return ""
    }
  }
  
  var imageName: NSImage.Name
  {
    switch self {
      case .gitHub: return .xtGitHubTemplate
      case .bitbucketCloud, .bitbucketServer: return .xtBitBucketTemplate
      case .teamCity: return .xtTeamCityTemplate
    }
  }
}
