import Foundation
import XitGit

/// A repository action unit used in test setup.
protocol RepoAction
{
  /// Executes the action in the context of the given repository. It may be an
  /// actual git operation, or a file operation within the repository.
  func execute(in repository: any FullRepository) throws
}

/// Executes the given list of actions in the given repository. This is the
/// primary consumer of RepoActions.
func execute(in repository: any FullRepository,
             @RepoActionBuilder actions: () -> [any RepoAction]) throws
{
  for action in actions() {
    try action.execute(in: repository)
  }
}

@resultBuilder
struct RepoActionBuilder
{
  static func buildExpression(_ expression: any RepoAction) -> [any RepoAction]
  { [expression] }
  
  static func buildBlock(_ items: [any RepoAction]...) -> [any RepoAction]
  { items.flatMap { $0 } }

  static func buildOptional(_ component: [any RepoAction]?) -> [any RepoAction]
  { component ?? [] }

  static func buildEither(first: [any RepoAction]) -> [any RepoAction]
  { first }
  static func buildEither(second: [any RepoAction]) -> [any RepoAction]
  { second }

  static func buildArray(_ actions: [[any RepoAction]]) -> [any RepoAction]
  { actions.flatMap { $0 } }
}

/// An action that affects a specific file which can then be staged.
protocol StageableAction : RepoAction
{
  var file: String { get }
}
