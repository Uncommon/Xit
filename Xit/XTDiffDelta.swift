import Foundation

public typealias XTDiffDelta = GTDiffDelta

extension GTDiffDelta
{
  public convenience init(from oldBlob: Blob?, forPath oldBlobPath: String?,
                          to newBlob: Blob?, forPath newBlobPath: String?,
                          options: [AnyHashable: Any]? = nil) throws
  {
    guard let blob1 = (oldBlob as? GTBlob) ??
                      (oldBlob as? GitBlob)?.makeGTBlob(),
          let blob2 = (newBlob as? GTBlob) ??
                      (newBlob as? GitBlob)?.makeGTBlob()
    else { throw XTRepository.Error.unexpected }
    
    try self.init(from: blob1, forPath: oldBlobPath,
                  to: blob2, forPath: newBlobPath, options: options)
  }

  public convenience init(from oldBlob: Blob?, forPath oldBlobPath: String?,
                          to newData: Data?, forPath newBlobPath: String?,
                          options: [AnyHashable: Any]? = nil) throws
  {
    guard let blob1 = (oldBlob as? GTBlob) ??
                      (oldBlob as? GitBlob)?.makeGTBlob()
    else { throw XTRepository.Error.unexpected }
    
    try self.init(from: blob1, forPath: oldBlobPath,
                  to: newData, forPath: newBlobPath, options: options)
  }
}

extension GTDiffHunk
{
  /// Applies just this hunk to the target text.
  /// - parameter text: The target text.
  /// - parameter reversed: True if the target text is the "new" text and the
  /// patch should be reverse-applied.
  /// - returns: The modified hunk of text, or nil if the patch does not match
  /// or if an error occurs.
  func applied(to text: String, reversed: Bool) -> String?
  {
    var lines = text.components(separatedBy: .newlines)
    guard Int(oldStart - 1 + oldLines) <= lines.count
    else { return nil }
    
    do {
      var oldLines = [String]()
      var newLines = [String]()
      
      try enumerateLinesInHunk {
        (line, _) in
        let content = line.content
        
        switch line.origin {
          case .context:
            oldLines.append(content)
            newLines.append(content)
          case .addition:
            newLines.append(content)
          case .deletion:
            oldLines.append(content)
          default:
            break
        }
      }
      
      let targetLines = reversed ? newLines : oldLines
      let replacementLines = reversed ? oldLines : newLines
      
      let targetLineStart = Int(reversed ? newStart : oldStart) - 1
      let targetLineCount = Int(reversed ? self.newLines : self.oldLines)
      let replaceRange = targetLineStart..<(targetLineStart+targetLineCount)
      
      if targetLines != Array(lines[replaceRange]) {
        // Patch doesn't match
        return nil
      }
      lines.replaceSubrange(replaceRange, with: replacementLines)
      
      return lines.joined(separator: text.lineEndingStyle.string)
    }
    catch {
      return nil
    }
  }
  
  /// Returns true if the hunk can be applied to the given text.
  /// - parameter lines: The target text. This is an array of strings rather
  /// than the raw text to more efficiently query multiple hunks on one file.
  func canApply(to lines: [String]) -> Bool
  {
    guard (oldLines == 0) || (Int(oldStart - 1 + oldLines) <= lines.count)
    else { return false }
    
    do {
      var oldLines = [String]()
      
      try enumerateLinesInHunk {
        (line, _) in
        switch line.origin {
          case .context, .deletion:
            oldLines.append(line.content)
          default:
            break
        }
      }
      
      // oldStart and oldLines are 0 if the old file is empty
      let targetLineStart = max(Int(oldStart) - 1, 0)
      let targetLineCount = Int(self.oldLines)
      let replaceRange = targetLineStart..<(targetLineStart+targetLineCount)
      
      return oldLines == Array(lines[replaceRange])
    }
    catch {
      return false
    }
  }
}

extension String
{
  enum LineEndingStyle: String
  {
    case crlf
    case lf
    case unknown
    
    var string: String
    {
      switch self
      {
        case .crlf: return "\r\n"
        case .lf:   return "\n"
        case .unknown: return "\n"
      }
    }
  }
  
  var lineEndingStyle: LineEndingStyle
  {
    if range(of: "\r\n") != nil {
      return .crlf
    }
    if range(of: "\n") != nil {
      return .lf
    }
    return .unknown
  }
}
