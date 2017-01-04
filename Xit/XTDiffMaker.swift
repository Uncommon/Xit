import Cocoa

/// An object that can generate file diffs, and re-generate them with
/// different options.
class XTDiffMaker: NSObject
{
  enum SourceType
  {
    case blob(GTBlob)
    case data(Data)
    
    init(_ blob: GTBlob?)
    {
      self = blob.map { .blob($0) } ?? .data(Data())
    }
  }
  
  let fromSource: SourceType
  let toSource: SourceType
  let path: String
  
  var contextLines: UInt = 3
  var whitespace: XTWhitespace = .showAll
  var usePatience = false
  var minimal = false
  
  private var options: [String: Any]
  {
    var whitespaceFlags: UInt32 = 0
    
    switch (whitespace) {
      case .showAll:
        break
      case .ignoreEOL:
        whitespaceFlags = GIT_DIFF_IGNORE_WHITESPACE_EOL.rawValue
      case .ignoreAll:
        whitespaceFlags = GIT_DIFF_IGNORE_WHITESPACE.rawValue
    }
  
    return [
      GTDiffOptionsContextLinesKey: contextLines,
      GTDiffOptionsFlagsKey:
          (usePatience ? GIT_DIFF_PATIENCE.rawValue : 0) +
          (minimal ? GIT_DIFF_MINIMAL.rawValue : 0) +
          whitespaceFlags
    ]
  }

  init(from: SourceType, to: SourceType, path: String)
  {
    self.fromSource = from
    self.toSource = to
    self.path = path
  }

  func makeDiff() -> XTDiffDelta?
  {
    switch (fromSource, toSource) {
      case let (.blob(fromBlob), .blob(toBlob)):
        return try? XTDiffDelta(from: fromBlob, forPath: path,
                                to: toBlob, forPath: path,
                                options: options)
      case let (.data(fromData), .data(toData)):
        return try? XTDiffDelta(from: fromData, forPath: path,
                                to: toData, forPath: path,
                                options: options)
      case let (.blob(fromBlob), .data(toData)):
        return try? XTDiffDelta(from: fromBlob, forPath: path,
                                to: toData, forPath: path,
                                options: options)
      // Data to blob is not available
      default:
        return nil
    }
  }
}
