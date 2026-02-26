import Foundation
import Cocoa
import XitGit

/// Convenience protocol for accessing things through a `RepositoryUIController`
@MainActor
protocol RepositoryUIAccessor
{
  var repoUIController: (any RepositoryUIController)? { get }
}

extension RepositoryUIAccessor
{
  var repoController: (any RepositoryController)?
  { repoUIController?.repoController }
  var repoSelection: (any RepositorySelection)?
  { repoUIController?.selection }
}


protocol RepositoryWindowView: NSView, RepositoryUIAccessor {}

extension RepositoryWindowView
{
  @MainActor
  var repoUIController: (any RepositoryUIController)?
  {
    window?.windowController as? RepositoryUIController
  }
}


protocol RepositoryWindowViewController: NSViewController, RepositoryUIAccessor {}

extension RepositoryWindowViewController
{
  @MainActor
  var repoUIController: (any RepositoryUIController)?
  {
    // Use ancestorWindow because window may be nil for hidden views
    view.ancestorWindow?.windowController as? RepositoryUIController
  }
}
