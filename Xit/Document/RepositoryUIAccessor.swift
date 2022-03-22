import Foundation

/// Convenience protocol for accessing things through a `RepositoryUIController`
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
  var repoUIController: (any RepositoryUIController)?
  {
    Thread.syncOnMain {
      window?.windowController as? RepositoryUIController
    }
  }
}


protocol RepositoryWindowViewController: NSViewController, RepositoryUIAccessor {}

extension RepositoryWindowViewController
{
  // Use ancestorWindow because window may be nil for hidden views
  var repoUIController: (any RepositoryUIController)?
  {
    Thread.syncOnMain {
      view.ancestorWindow?.windowController as? RepositoryUIController
    }
  }
}
