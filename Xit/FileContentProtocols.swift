import Foundation

/// Interface for a controller that displays file content in some form.
protocol XTFileContentController
{
  /// Clears the display for when nothing is selected.
  func clear()
  /// Displays the content from the given selection.
  /// - parameter path: The repository-relative file path.
  /// - parameter fileList: The file list to read data from.
  func load(path: String!, fileList: FileListModel)
  /// True if the controller has content loaded.
  var isLoaded: Bool { get }
}

protocol WhitespaceVariable: class
{
  var whitespace: WhitespaceSetting { get set }
}

protocol TabWidthVariable: class
{
  var tabWidth: UInt { get set }
}

protocol ContextVariable: class
{
  var contextLines: UInt { get set }
}

enum TextWrapping
{
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

protocol WrappingVariable: class
{
  var wrapping: TextWrapping { get set }
}
