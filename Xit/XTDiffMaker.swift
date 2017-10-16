import Cocoa

/// An object that can generate file diffs, and re-generate them with
/// different options.
public class XTDiffMaker: NSObject
{
  public enum SourceType
  {
    case blob(Blob)
    case data(Data)
    
    init(_ blob: Blob?)
    {
      self = blob.map { .blob($0) } ?? .data(Data())
    }
  }
  
  public enum DiffResult
  {
    case noDifference
    case binary
    case diff(XTDiffMaker)
  }
  
  let fromSource: SourceType
  let toSource: SourceType
  let path: String
  
  static let defaultContextLines: UInt = 3
  var contextLines: UInt = XTDiffMaker.defaultContextLines
  var whitespace = PreviewsPrefsController.Default.whitespace()
  var usePatience = false
  var minimal = false
  
  private var options: DiffOptions
  {
    var flags: DiffOptionFlags = []
    
    switch whitespace {
      case .showAll:
        break
      case .ignoreEOL:
        flags = .ignoreWhitespaceEOL
      case .ignoreAll:
        flags = .ignoreWhitespace
    }
    if usePatience {
      flags.insert(.patience)
    }
    if minimal {
      flags.insert(.minimal)
    }
    
    var result = DiffOptions(flags: flags)
    
    result.contextLines = UInt32(contextLines)
    return result
  }

  init(from: SourceType, to: SourceType, path: String)
  {
    self.fromSource = from
    self.toSource = to
    self.path = path
  }

  func makePatch() -> Patch?
  {
    switch (fromSource, toSource) {
      case let (.blob(fromBlob), .blob(toBlob)):
        return GitPatch(oldBlob: fromBlob, newBlob: toBlob, options: options)
      case let (.data(fromData), .data(toData)):
        return GitPatch(oldData: fromData, newData: toData, options: options)
      case let (.blob(fromBlob), .data(toData)):
        return GitPatch(oldBlob: fromBlob, newData: toData, options: options)
      case let (.data(fromData), .blob(toBlob)):
        if let result = try? toBlob.withData({
          GitPatch(oldData: fromData, newData: $0, options: options)
        }) {
          return result
        }
        else {
          return nil
        }
    }
  }
}
