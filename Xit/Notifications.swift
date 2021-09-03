import Foundation

extension NSNotification.Name
{
  /// The selection has been clicked again. Make sure it is visible.
  static let XTReselectModel = Self("XTReselectModel")
  /// TeamCity build status has been downloaded/refreshed.
  static let XTTeamCityStatusChanged = Self("XTTeamCityStatusChanged")
}
