import Foundation

class XTDiffDelta: GTDiffDelta
{
}

extension GTDiffHunk
{
  func applied(to text: String, reversed: Bool) -> String?
  {
    var lines = text.components(separatedBy: .newlines)
    guard Int(oldStart + oldLines) < lines.count
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
