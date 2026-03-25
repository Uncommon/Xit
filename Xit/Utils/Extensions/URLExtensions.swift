import Foundation

public extension URL
{
  /// Returns a copy of the URL with its path replaced.
  func withPath(_ path: String) -> URL
  {
    guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
    else { return self }

    components.path = path
    return components.url ?? self
  }

  /// Returns the default port based on the URL's scheme.
  var defaultPort: Int
  {
    switch scheme {
      case "https":
        return 443
      case "ssh":
        return 22
      case "git":
        return 9418
      default:
        return 80
    }
  }
}
