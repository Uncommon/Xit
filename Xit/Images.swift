import Foundation

extension NSImage.Name
{
  static let xtBitBucketTemplate = "bitbucketTemplate"
  static let xtBranchTemplate = "branchTemplate"
  static let xtBuildFailed = "buildFailed"
  static let xtBuildInProgress = "buildInProgress"
  static let xtBuildSucceeded = "buildSucceeded"
  static let xtNoBuilds = "noBuilds"
  static let xtGitHubTemplate = "githubTemplate"
  static let xtGitLabTemplate = "gitlabTemplate"
  static let xtStageAllTemplate = "stageAllTemplate"
  static let xtTeamCityTemplate = "teamcityTemplate"
  static let xtTrackingMissing = "trackingMissing"
  static let xtUnstageAllTemplate = "unstageAllTemplate"
}

extension NSImage
{
  convenience init?(systemSymbolName: String)
  {
    self.init(systemSymbolName: systemSymbolName, accessibilityDescription: nil)
  }
  
  static var xtBranchFolder: NSImage { .init(systemSymbolName: "folder.fill")! }
  static var xtCloud: NSImage { .init(systemSymbolName: "cloud")! }
  static var xtCurrentBranch: NSImage { .init(named: NSImage.menuOnStateTemplateName)! }
  static var xtCurrentRemoteBranch: NSImage { .init(systemSymbolName: "checkmark.circle")! }
  static var xtFile: NSImage { .init(systemSymbolName: "doc")! }
  static var xtFolder: NSImage { .init(systemSymbolName: "folder")! }
  static var xtRefresh: NSImage { .init(named: NSImage.refreshTemplateName)! }
  static var xtRemote: NSImage { .init(systemSymbolName: "cloud.fill")! }
  static var xtStageAll: NSImage { .init(named: .xtStageAllTemplate)! }
  static var xtStageButton: NSImage { .init(systemSymbolName: "circle")! }
  static var xtStageButtonHover: NSImage { .init(systemSymbolName: "chevron.up.circle")! }
  static var xtStageButtonPressed: NSImage { .init(systemSymbolName: "chevron.up.circle.fill")! }
  static var xtStaged: NSImage { .init(systemSymbolName: "arrow.up.circle")! }
  static var xtStaging: NSImage { .init(systemSymbolName: "arrow.up.and.down.circle.fill")! }
  static var xtStash: NSImage { .init(systemSymbolName: "shippingbox.fill")! }
  static var xtSubmodule: NSImage { .init(systemSymbolName: "square.split.bottomrightquarter.fill")! }
  static var xtTag: NSImage { .init(systemSymbolName: "tag.fill")! }
  static var xtUndo: NSImage { .init(systemSymbolName: "arrow.uturn.backward.circle")! }
  static var xtUnstageAll: NSImage { .init(named: .xtUnstageAllTemplate)! }
  static var xtUnstageButtonHover: NSImage { .init(systemSymbolName: "chevron.down.circle")! }
  static var xtUnstageButtonPressed: NSImage { .init(systemSymbolName: "chevron.down.circle.fill")! }
}
