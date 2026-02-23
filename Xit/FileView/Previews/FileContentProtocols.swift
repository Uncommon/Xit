import Foundation
import AppKit
import XitGit

/// Interface for a controller that displays file content in some form.
@MainActor
protocol FileContentLoading: NSViewController
{
  /// Clears the display for when nothing is selected.
  func clear()
  /// Displays the content from the given selection.
  func load(selection: [FileSelection])
  /// True if the controller has content loaded.
  var isLoaded: Bool { get }
}

struct FileSelection: Equatable
{
  let repoSelection: any RepositorySelection
  let path: String
  let staging: StagingType
  
  var fileList: any FileListModel
  { repoSelection.list(staged: staging == .index) }

  static func == (lhs: FileSelection, rhs: FileSelection) -> Bool
  {
    return lhs.repoSelection == rhs.repoSelection &&
           lhs.path == rhs.path &&
           lhs.staging == rhs.staging
  }
}

@MainActor
protocol WhitespaceVariable: AnyObject
{
  var whitespace: WhitespaceSetting { get set }
}

@MainActor
protocol TabWidthVariable: AnyObject
{
  var tabWidth: UInt { get set }
}

@MainActor
protocol ContextVariable: AnyObject
{
  var contextLines: UInt { get set }
}

enum TextWrapping: RawRepresentable, CaseIterable
{
  static let allCases: [TextWrapping] = [
    .windowWidth,
    .columns(80),
    .none,
  ]

  case windowWidth
  case columns(Int)
  case none
  
  var rawValue: Int
  {
    switch self {
      case .windowWidth:
        return 0
      case .columns(let count):
        return count
      case .none:
        return -1
    }
  }
  
  init?(rawValue: Int)
  {
    switch rawValue {
      case 0:
        self = .windowWidth
      case -1:
        self = .none
      case 1...:
        self = .columns(rawValue)
      default:
        return nil
    }
  }

  var displayName: String
  {
    switch self {
      case .windowWidth: return "Wrap to window"
      case .columns(let count): return "Wrap to \(count) columns"
      case .none: return "No wrapping"
    }
  }
}

extension TextWrapping: Hashable
{
  func hash(into hasher: inout Hasher)
  {
    hasher.combine(rawValue)
  }
}

extension TextWrapping: Equatable
{
  public static func == (a: TextWrapping, b: TextWrapping) -> Bool
  {
    switch (a, b) {
      case (.windowWidth, .windowWidth),
           (.none, .none):
        return true
      case (.columns(let c1), .columns(let c2)):
        return c1 == c2
      default:
        return false
    }
  }
}

@MainActor
protocol WrappingVariable: AnyObject
{
  var wrapping: TextWrapping { get set }
}
