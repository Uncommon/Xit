import Foundation

extension XTFileViewController
{
  @IBAction func revert(_: AnyObject)
  {
    guard let selectedRow = fileListOutline.selectedRowIndexes.first,
          let dataSource = fileListDataSource as? XTFileListDataSource,
          let change = dataSource.fileChange(atRow: selectedRow)
    else { return }
    
    let confirmAlert = NSAlert()
    
    confirmAlert.messageText = "Are you sure you want to revert changes to " +
                               "\((change.path as NSString).lastPathComponent)?"
    confirmAlert.addButton(withTitle: "Revert")
    confirmAlert.addButton(withTitle: "Cancel")
    confirmAlert.beginSheetModal(for: view.window!) {
      (response) in
      if response == NSAlertFirstButtonReturn {
        self.revertConfirmed(path: change.path)
      }
    }
  }
  
  func revertConfirmed(path: String)
  {
    do {
      try repo.revert(file: path)
    }
    catch let error as NSError {
      let alert = NSAlert(error: error)
      
      alert.beginSheetModal(for: view.window!, completionHandler: nil)
    }
  }
  
  override open func validateMenuItem(_ menuItem: NSMenuItem) -> Bool
  {
    guard let action = menuItem.action
    else { return false }
    
    switch action {
      case #selector(self.revert(_:)):
        guard let selectedRow = fileListOutline.selectedRowIndexes.first,
          let dataSource = fileListDataSource as? XTFileListDataSource,
          let change = dataSource.fileChange(atRow: selectedRow)
          else { return false }
        
          switch change.unstagedChange {
            case .unmodified: fallthrough  // No changes to revert
            case .untracked:               // Nothing to revert to
              return false
            default:
              return true
          }
      case #selector(self.showWhitespaceChanges(_:)),
           #selector(self.ignoreEOLWhitespace(_:)),
           #selector(self.ignoreAllWhitespace(_:)):
        // update the check mark
        return contentController.canSetWhitespace
      case #selector(self.tabWidth2(_:)),
           #selector(self.tabWidth4(_:)),
           #selector(self.tabWidth6(_:)),
           #selector(self.tabWidth8(_:)):
        // update the check mark
        return contentController.canSetTabWidth
      default:
        return true
    }
  }
  
  @IBAction func showWhitespaceChanges(_ sender: Any?)
  {
    setWhitespace(.showAll)
  }
  
  @IBAction func ignoreEOLWhitespace(_ sender: Any?)
  {
    setWhitespace(.ignoreEOL)
  }
  
  @IBAction func ignoreAllWhitespace(_ sender: Any?)
  {
    setWhitespace(.ignoreAll)
  }
  
  @IBAction func tabWidth2(_ sender: Any?)
  {
    setTabWidth(2)
  }
  
  @IBAction func tabWidth4(_ sender: Any?)
  {
    setTabWidth(4)
  }
  
  @IBAction func tabWidth6(_ sender: Any?)
  {
    setTabWidth(6)
  }
  
  @IBAction func tabWidth8(_ sender: Any?)
  {
    setTabWidth(8)
  }
  
  func setWhitespace(_ setting: PreviewsPrefsController.WhitespaceSetting)
  {
    // store the setting somewhere
    
    // re-do the diff
  }
  
  func setTabWidth(_ tabWidth: UInt)
  {
    // store the setting somewhere
    
    // change the CSS tab width style
  }
}

extension XTFileViewController: NSSplitViewDelegate
{
  public func splitView(_ splitView: NSSplitView,
                        shouldAdjustSizeOfSubview view: NSView) -> Bool
  {
    switch splitView {
      case headerSplitView:
        return view != headerController.view
      case fileSplitView:
        return view != leftPane
      default:
        return true
    }
  }
}
