import Foundation
import Xit

/// A repository action unit used in test setup.
protocol RepoAction
{
  /// Executes the action in the context of the given repository. It may be an
  /// actual git operation, or a file operation within the repository.
  func execute(in repository: Repository) throws
}

/// Executes the given list of actions in the given repository. This is the
/// primary consumer of RepoActions.
func execute(in repository: Repository,
             @RepoActionBuilder actions: () -> [RepoAction]) throws
{
  for action in actions() {
    try action.execute(in: repository)
  }
}

@resultBuilder
struct RepoActionBuilder
{
  static func buildExpression(_ expression: RepoAction) -> [RepoAction]
  { [expression] }
  
  static func buildBlock(_ items: [RepoAction]...) -> [RepoAction]
  { items.flatMap { $0 } }

  static func buildOptional(_ component: [RepoAction]?) -> [RepoAction]
  { component ?? [] }

  static func buildEither(first: [RepoAction]) -> [RepoAction]
  { first }
  static func buildEither(second: [RepoAction]) -> [RepoAction]
  { second }

  static func buildArray(_ actions: [[RepoAction]]) -> [RepoAction]
  { actions.flatMap { $0 } }
}

/// An action that affects a specific file which can then be staged.
protocol StageableAction : RepoAction
{
  var file: String { get }
}
