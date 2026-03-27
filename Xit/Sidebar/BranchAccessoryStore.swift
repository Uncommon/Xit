import SwiftUI

/// Shared source of branch row accessories for the sidebar.
///
/// The store is a reference type so integrations can publish updates into it
/// and refresh both local and remote branch lists without rebuilding their
/// view models.
@MainActor
final class BranchAccessoryStore: ObservableObject
{
  /// Closure that renders an accessory view for a given reference.
  typealias Provider = (any ReferenceName) -> AnyView

  /// Bumped when callers want visible rows to refresh their accessory views.
  @Published private(set) var revision: Int = 0

  private var provider: Provider = { _ in AnyView(EmptyView()) }

  /// Returns the accessory view for the supplied reference.
  func accessory(for ref: any ReferenceName) -> AnyView
  {
    provider(ref)
  }

  /// Replaces the current provider and forces existing rows to re-render.
  func setProvider(_ provider: @escaping Provider)
  {
    self.provider = provider
    invalidate()
  }

  /// Marks some or all accessories as stale.
  ///
  /// `refs` is unused for now, but may allow invalidating a subset in the future.
  func invalidate(refs _: Set<String>? = nil)
  {
    revision += 1
  }
}
