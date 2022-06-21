import Cocoa

/// An object that can generate file patches, and re-generate them with
/// different options.
public final class PatchMaker
{
  public enum SourceType
  {
    case blob(any Blob)
    case data(Data)
    
    init(_ blob: (any Blob)?)
    {
      self = blob.map { .blob($0) } ?? .data(Data())
    }
  }
  
  public enum PatchResult
  {
    case noDifference
    case binary
    case diff(PatchMaker)
  }
  
  let fromSource: SourceType
  let toSource: SourceType
  let path: String
  
  static let defaultContextLines: UInt = 3
  var contextLines: UInt = PatchMaker.defaultContextLines
  var whitespace = UserDefaults.standard.whitespace
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

  func makePatch() -> (any Patch)?
  {
    switch (fromSource, toSource) {
      case let (.blob(fromBlob), .blob(toBlob)):
        return GitPatch(oldBlob: fromBlob, newBlob: toBlob, options: options)
      case let (.data(fromData), .data(toData)):
        return GitPatch(oldData: fromData, newData: toData, options: options)
      case let (.blob(fromBlob), .data(toData)):
        return GitPatch(oldBlob: fromBlob, newData: toData, options: options)
      case let (.data(fromData), .blob(toBlob)):
        return GitPatch(oldData: fromData,
                        newData: toBlob.makeData() ?? Data(),
                        options: options)
    }
  }
}
