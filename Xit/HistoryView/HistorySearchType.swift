import Foundation

enum HistorySearchType: CaseIterable
{
  case summary, author, committer, sha

  var displayName: UIString
  {
    switch self {
      case .summary: return .init(rawValue: "Summary")
      case .author: return .init(rawValue: "Author")
      case .committer: return .init(rawValue: "Committer")
      case .sha: return .init(rawValue: "SHA")
    }
  }
}
