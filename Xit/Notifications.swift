import Foundation

extension NSNotification.Name
{
  /// Some change has been detected in the repository.
  static let XTRepositoryChanged = ‡"XTRepositoryChanged"
  /// The repository's config file has changed.
  static let XTRepositoryConfigChanged = ‡"XTRepositoryConfigChanged"
  /// The head reference (current branch) has changed.
  static let XTRepositoryHeadChanged = ‡"XTRepositoryHeadChanged"
  /// The repository's index has changed.
  static let XTRepositoryIndexChanged = ‡"XTRepositoryIndexChanged"
  /// The repository's refs have changed.
  static let XTRepositoryRefsChanged = ‡"XTRepositoryRefsChanged"
  /// A file in the workspace has changed.
  static let XTRepositoryWorkspaceChanged = ‡"XTRepositoryWorkspaceChanged"
  /// The stash log has changed.
  static let XTRepositoryStashChanged = ‡"XTRepositoryStashChanged"
  /// There is a new selection to be displayed.
  static let XTSelectedModelChanged = ‡"XTSelectedModelChanged"
  /// The selection has been clicked again. Make sure it is visible.
  static let XTReselectModel = ‡"XTReselectModel"
  /// TeamCity build status has been downloaded/refreshed.
  static let XTTeamCityStatusChanged = ‡"XTTeamCityStatusChanged"
  
  static let XTRepositoryRefLogChanged = ‡"XTRepositoryRefLogChanged"
}
