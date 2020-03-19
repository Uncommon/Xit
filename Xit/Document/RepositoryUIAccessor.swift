import Foundation

/// Convenience protocol for accessing things through a `RepositoryUIController`
protocol RepositoryUIAccessor
{
  var repoUIController: RepositoryUIController? { get }
}

extension RepositoryUIAccessor
{
  var repoController: RepositoryController?
  { repoUIController?.repoController }
  var repoSelection: RepositorySelection?
  { repoUIController?.selection }
}


protocol RepositoryWindowView: NSView, RepositoryUIAccessor {}

extension RepositoryWindowView
{
  var repoUIController: RepositoryUIController?
  {
    Thread.syncOnMainThread {
      window?.windowController as? RepositoryUIController
    }
  }
}


protocol RepositoryWindowViewController: NSViewController, RepositoryUIAccessor {}

extension RepositoryWindowViewController
{
  // Use ancestorWindow because window may be nil for hidden views
  var repoUIController: RepositoryUIController?
  {
    Thread.syncOnMainThread {
      view.ancestorWindow?.windowController as? RepositoryUIController
    }
  }
}
