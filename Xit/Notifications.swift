import Foundation

extension NSNotification.Name
{
  /// The stash log has changed.
  static let XTRepositoryStashChanged = Self("XTRepositoryStashChanged")
  /// There is a new selection to be displayed.
  static let XTSelectedModelChanged = Self("XTSelectedModelChanged")
  /// The selection has been clicked again. Make sure it is visible.
  static let XTReselectModel = Self("XTReselectModel")
  /// TeamCity build status has been downloaded/refreshed.
  static let XTTeamCityStatusChanged = Self("XTTeamCityStatusChanged")
  
  static let XTRepositoryRefLogChanged = Self("XTRepositoryRefLogChanged")
}
