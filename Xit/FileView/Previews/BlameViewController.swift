import Foundation
import Cocoa

class BlameViewController: WebViewController, RepositoryWindowViewController
{
  @IBOutlet var spinner: NSProgressIndicator!
  var isLoaded: Bool = false
  
  var currentSelection: FileSelection?
  
  class CommitColoring
  {
    var commitColors = [String: NSColor]()
    var lastHue = 120
    
    init(firstOID: OID)
    {
      _ = color(for: firstOID)
    }
    
    func color(for oid: OID) -> NSColor
    {
      if let color = commitColors[oid.sha] {
        return color
      }
      else {
        let blameStart = NSColor(named: "blameStart")!
        let result = blameStart.withHue(CGFloat(lastHue) / 360.0)
        
        lastHue = (lastHue + 55) % 360
        commitColors[oid.sha] = result
        return result
      }
    }
  }
  
  override func loadNotice(_ text: UIString)
  {
    spinner.isHidden = true
    spinner.stopAnimation(nil)
    super.loadNotice(text)
  }
  
  func notAvailable()
  {
    DispatchQueue.main.async {
      [weak self] in
      self?.loadNotice(.blameNotAvailable)
    }
  }
  
  enum HTML
  {
    static func jumpButton(_ sha: String) -> String
    {
      return """
          <div class='jumpbutton' \
          onclick='window.webkit.messageHandlers.controller\
          .postMessage({"action":"selectSHA","sha":"\(sha)"})'>\
          ‣</div>
          """
    }
    
    static func headerStart(color: NSColor,
                            button: String,
                            name: String?) -> String
    {
      return """
          <tr><td class='headcell'>
          <div class='blamehead' style='background-color: \(color.cssHSL)'>
          \(button)
          <div class='name'>\(name ?? "")</div>
          """
    }
    
    static func sha(_ hunk: BlameHunk, isCurrent: Bool) -> String
    {
      let `class` = isCurrent ? " class = 'currentsha'" : ""
      
      return "<div\(`class`)>\(hunk.finalLine.oid.sha.firstSix())</div>"
    }
    
    static func textLine(_ text: String) -> String
    {
      return "<div class='line'>\(text.xmlEscaped)</div>"
    }
    
    static func startTextCell(color: NSColor) -> [String]
    {
      return ["</div></td>",
              "<td style='background-color: \(color.cssHSL)'>"]
    }
    
    static let localChanges = "<div class='local'>local changes</div>"
  }
  
  func loadBlame(text: String, path: String,
                 selection: RepositorySelection, fileList: FileListModel)
  {
    defer {
      DispatchQueue.main.async {
        [weak self] in
        self?.spinner.isHidden = true
        self?.spinner.stopAnimation(nil)
      }
    }
    
    guard let blame = fileList.blame(for: path)
    else {
      notAvailable()
      return
    }
    
    var htmlLines = [String]()
    let lines = text.lineComponents()
    let selectOID: GitOID? = selection.shaToSelect.map { GitOID(sha: $0) }
                             ?? nil
    let currentOID = selectOID ?? GitOID.zero()
    let dateFormatter = DateFormatter()
    let coloring = CommitColoring(firstOID: currentOID)
    
    dateFormatter.timeStyle = .short
    dateFormatter.dateStyle = .short
    
    for hunk in blame.hunks {
      let finalOID = hunk.finalLine.oid as! GitOID
      var hunkColor = coloring.color(for: finalOID)
      let jumpButton = finalOID == currentOID ? "" : HTML.jumpButton(finalOID.sha)

      htmlLines.append(HTML.headerStart(color: hunkColor,
                                        button: jumpButton,
                                        name: hunk.finalLine.signature.name))
      
      if hunk.lineCount > 0 {
        if hunk.finalLine.oid.isZero {
          htmlLines.append(HTML.localChanges)
        }
        else {
          htmlLines.append(HTML.sha(hunk, isCurrent: finalOID == currentOID))
        }
        htmlLines.append("""
            <div class='date'>\
            \(dateFormatter.string(from: hunk.finalLine.signature.when))</div>
            """)
      }
      if finalOID != currentOID,
         let blend = hunkColor.blended(withFraction: 0.65,
                                       of: .textBackgroundColor) {
        hunkColor = blend
      }
      htmlLines.append(contentsOf: HTML.startTextCell(color: hunkColor))
      
      let start = hunk.finalLine.start - 1
      let end = min(start + hunk.lineCount, lines.count)
      let hunkLines = lines[start..<end]
      
      htmlLines.append(contentsOf: hunkLines.map(HTML.textLine))
      htmlLines.append("</td></tr>")
    }
    
    let htmlTemplate = WebViewController.htmlTemplate("blame")
    let html = String(format: htmlTemplate, htmlLines.joined(separator: "\n"))
    
    DispatchQueue.main.async {
      [weak self] in
      self?.load(html: html)
      self?.isLoaded = true
    }
  }
  
  override func webMessage(_ params: [String: Any])
  {
    guard params["action"] as? String == "selectSHA",
          let sha = params["sha"] as? String
    else { return }
    
    repoUIController?.select(sha: sha)
  }
}

extension BlameViewController: XTFileContentController
{
  func clear()
  {
    load(html: "")
    isLoaded = false
  }
  
  public func load(selection: [FileSelection])
  {
    switch selection.count {
      case 0:
        self.clear()
        return
      case 1:
        break
      default:
        loadNotice(.multipleItemsSelected)
        return
    }
    
    guard selection[0] != currentSelection
    else { return }
    
    currentSelection = selection[0]
    repoUIController?.queue.executeOffMainThread {
      [weak self] in
      guard let self = self
      else { return }
      let fileList = selection[0].fileList
      guard let data = fileList.dataForFile(selection[0].path),
            let text = String(data: data, encoding: .utf8) ??
                       String(data: data, encoding: .utf16)
      else {
        self.notAvailable()
        return
      }
      
      Thread.performOnMainThread {
        self.spinner.isHidden = false
        self.spinner.startAnimation(nil)
        self.clear()
      }
      self.loadBlame(text: text, path: selection[0].path,
                     selection: selection[0].repoSelection, fileList: fileList)
    }
  }
}
