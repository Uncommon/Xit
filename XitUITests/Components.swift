import Foundation
import XCTest

let XitApp = XCUIApplication(bundleIdentifier: "com.uncommonplace.Xit")

enum Window
{
  static let window = XitApp.windows["repoWindow"].firstMatch
  static let remoteOpSegControl = window.toolbars.groups["Remote Operations"]
  static let pullButton = remoteOpSegControl.buttons.element(boundBy: 0)
  static let pushButton = remoteOpSegControl.buttons.element(boundBy: 1)
  static let fetchButton = remoteOpSegControl.buttons.element(boundBy: 2)
  static let progressSpinner = window.progressIndicators["progress"]
  static let branchPopup = window.popUpButtons["branchPopup"].firstMatch
  static let tabStatus = window.buttons["tabStatus"]
  
  static let pullMenu = XitApp.menus[.PopupMenu.pull]
  static let pushMenu = XitApp.menus[.PopupMenu.push]
  static let fetchMenu = XitApp.menus[.PopupMenu.fetch]
}

enum Search
{
  static let popup = Window.window.popUpButtons[.Search.typePopup]
  static let field = Window.window.searchFields[.Search.field]
  static let clearButton = field.buttons["cancel"]
  // No idea where these IDs come from but that's what they are
  static let searchUp = Window.window.buttons["searchUp"]
  static let searchDown = Window.window.buttons["searchDown"]

  static func setSearchType(_ searchType: HistorySearchType)
  {
    popup.click()
    XitApp.menuItems[searchType.displayName.rawValue].click()
  }
}

enum Toolbar
{
  // Finding these items by ID rather than title doesn't work
  static let clean = Window.window.toolbars.buttons["Clean"]
  static let search = Window.window.toolbars.buttons["Search"]
  static let stash = Window.window.toolbars.buttons["Stash"]
}

enum PrefsWindow
{
  static let window = XitApp.windows[.Preferences.window]
  static let generalTab = window.toolbars.buttons[.Preferences.Toolbar.general]
  
  static let tabStatusCheck = window.checkBoxes[.Preferences.Controls.tabStatus]
  
  static func open(file: StaticString = #file, line: UInt = #line)
  {
    let menuBar = XitApp.menuBars
    
    menuBar.menuBarItems["Xit"].click()
    menuBar.menuItems["Settings…"].click()
    XCTAssertTrue(window.waitForExistence(timeout: 1.0),
                  "Preferences window did not open", file: file, line: line)
  }
  
  static func close()
  {
    if window.exists {
      window.buttons[XCUIIdentifierCloseWindow].click()
    }
  }
}

protocol SidebarList
{
  static var list: XCUIElement { get }
}

extension SidebarList
{
  static var cancelButton: XCUIElement { Window.window.buttons["cancelFilter"] }
  
  static func cell(named name: String) -> XCUIElement
  {
    return list.cells.containing(.staticText, identifier: name).firstMatch
  }
}

enum Sidebar
{
  enum Tab {
    static let local = Window.window.buttons["Local"]
    static let remotes = Window.window.buttons["Remotes"]
    static let tags = Window.window.buttons["Tags"]
    static let stashes = Window.window.buttons["Stashes"]
    static let submodules = Window.window.buttons["Submodules"]
  }
  
  enum Branches: SidebarList
  {
    static let list = Window.window.outlines[.Sidebar.branchList]
    static let stagingCell = list.cells.element(boundBy: 0)
    static let currentBranchCell =
        list.cells
            .containing(.any, identifier: .Sidebar.currentBranch)
            .firstMatch
    static let filterField = Window.window.textFields[.Sidebar.filter]
    
    static func branchCell(_ branch: String) -> XCUIElement
    {
      Sidebar.Branches.list.cells
        .containing(.staticText, identifier: branch)
        .firstMatch
    }
  }

  enum Tags: SidebarList
  {
    static let list = Window.window.outlines[.Sidebar.tagsList]
  }

  static let list = Window.window.outlines[.Sidebar.list]
  static let filter = Window.window.searchFields[.Sidebar.filter]
  static let addButton = Window.window.popUpButtons[.Sidebar.add]
  static let stagingCell = Branches.list.cells.element(boundBy: 0)

  static let branchPopup = XitApp.menus[.Menu.branch]
  static let remoteBranchPopup = XitApp.menus[.Menu.remoteBranch]
  static let tagPopup = XitApp.menus[.Menu.tag]

  static func assertStagingStatus(workspace: Int, staged: Int)
  {
    let expected = "\(workspace) ▸ \(staged)"
    let statusButton = stagingCell.staticTexts[.Sidebar.workspaceStatus]
    
    XCTAssertEqual(expected, statusButton.stringValue)
  }
  
  static func assertBranches(_ branches: [String])
  {
    for (index, branch) in branches.enumerated() {
      let cell = Branches.list.cells.element(boundBy: index + 2)
      let label = cell.staticTexts.firstMatch.value as? String ?? ""
      
      XCTAssertEqual(label, branch,
                     "item \(index) is '\(label)' instead of '\(branch)'")
    }
  }
  
  static func assertCurrentBranch(_ branch: String,
                                  file: StaticString = #file,
                                  line: UInt = #line)
  {
    let currentBranchID = AXID.Sidebar.currentBranch.rawValue
    guard let predicate = NSPredicate(fromMetadataQueryString: "identifier == \(currentBranchID) AND stringValue == \(branch)")
    else {
      XCTFail("could not construct predicate")
      return
    }
    let item = Sidebar.list.staticTexts.matching(predicate)
    
    XCTAssert(item.element.waitForExistence(timeout: 2),
              "current branch did not match",
              file: file, line: line)
  }
  
  static func workspaceStatusIndicator(branch: String) -> XCUIElement
  {
    let cell = Sidebar.Branches.branchCell(branch)
    
    return cell.staticTexts[.Sidebar.workspaceStatus]
  }
  
  static func trackingStatusIndicator(branch: String) -> XCUIElement
  {
    let cell = Sidebar.Branches.branchCell(branch)

    return cell.staticTexts[.Sidebar.trackingStatus]
  }
}

enum BranchList
{
  static var list: XCUIElement { Window.window.outlines[.Sidebar.branchList] }
  static var stagingCell: XCUIElement
  {
    list.cells.containing(.staticText,
                          identifier: .Sidebar.stagingCell).firstMatch
  }
  static var currentBranchCell: XCUIElement
  {
    list.cells.containing(.image, identifier: .Sidebar.currentBranchCheck)
      .firstMatch
  }
  
  static func cell(named name: String) -> XCUIElement
  {
    list.cells.containing(.staticText, identifier: name).firstMatch
  }
}

enum CommitHeader
{
  static let header = XitApp.scrollViews["commitInfo"].firstMatch
  static let dateField = header.staticTexts["date"].firstMatch
  static let shaField = header.links["sha"].firstMatch
  static let nameField = header.staticTexts["name"].firstMatch
  static let emailField = header.staticTexts["email"].firstMatch
  static let messageField = header.staticTexts["message"].firstMatch
  static var parentFields: [XCUIElement]
  {
    header.groups["parents"]
          .staticTexts.matching(identifier: "parent")
          .allElementsBoundByAccessibilityElement
  }
  
  static func parentField(_ index: Int) -> XCUIElement
  {
    header.groups["parents"]
          .staticTexts.matching(identifier: "parent")
          .element(boundBy: index)
  }
  
  static func assertDisplay(date: String, sha: String,
                            name: String, email: String,
                            parents: [String], message: String)
  {
    XCTAssertEqual(dateField.stringValue, date)
    XCTAssertEqual(shaField.label, sha)
    XCTAssertEqual(nameField.stringValue, name)
    XCTAssertEqual(emailField.stringValue, email)
    XCTAssertEqual(parentFields.map { $0.stringValue }, parents)
    XCTAssertEqual(messageField.stringValue, message)
  }
}

enum CommitEntry
{
  static let messageField = XitApp.textViews["messageField"].firstMatch
  static let commitButton = XitApp.buttons["commitButton"].firstMatch
  static let amendCheck = XitApp.checkBoxes["amendCheck"].firstMatch
  static let stripCheck = XitApp.checkBoxes["stripCheck"].firstMatch
}

protocol FileList
{
  static var group: XCUIElement { get }
  static var list: XCUIElement { get }
}

extension FileList
{
  static var outlineButton: XCUIElement
  { group.buttons["bulletest list indent"] }

  static func assertFiles(_ names: [String],
                          file: StaticString = #file,
                          line: UInt = #line)
  {
    let rows = list.outlineRows
    let rowCount = rows.count
    guard names.count == rowCount
    else {
      XCTFail("expected \(names.count) files, found \(rowCount)",
              file: file, line: line)
      return
    }

    for (index, name) in names.enumerated() {
      let label = rows.element(boundBy: index).staticTexts.firstMatch.stringValue
      
      XCTAssertEqual(label, name, "file \(index) does not match",
                     file: file, line: line)
    }
  }

  static func fileRow(named name: String) -> XCUIElement
  {
    list.outlineRows.containing(.staticText, identifier: name).firstMatch
  }
}

enum CommitFileList: FileList
{
  static let group = Window.window.groups[.FileList.Commit.group]
  static let list = XitApp.outlines[.FileList.Commit.list]
}

enum StagedFileList: FileList
{
  static let group = Window.window.groups[.FileList.Staged.group]
  static let list = XitApp.outlines[.FileList.Staged.list]

  static let refreshButton = Window.window.buttons["WorkspaceRefresh"]
  static let viewSelector = group.segmentedControls[.FileList.viewSelector]

  static func unstage(item: Int)
  {
    list.outlineRows.element(boundBy: item).buttons["action"].click()
  }
}

enum WorkspaceFileList: FileList
{
  static let group = XitApp.groups[.FileList.Workspace.group]
  static let list = XitApp.outlines[.FileList.Workspace.list]

  static let viewSelector = group.segmentedControls[.FileList.viewSelector]

  static func stage(item: Int)
  {
    list.outlineRows.element(boundBy: item).buttons["action"].click()
  }
}

enum HistoryList
{
  static let list = XitApp.tables["history"]

  static func row(_ index: Int) -> XCUIElement
  {
    list.tableRows.element(boundBy: index)
  }
  
  /// Returns the first row containing the given commit message
  static func row(_ message: String) -> XCUIElement
  {
    list.cells
        .containing(.init(format: "value == '\(message)'"))
        .firstMatch
  }
  
  enum ContextMenu
  {
    static let menu = XitApp.menus["HistoryMenu"]
    static let copySHAItem = menu.menuItems["Copy SHA"]
    static let resetItem = menu.menuItems["Reset to this commit..."]
  }
}

enum CleanSheet
{
  static let window = XitApp.sheets[.Clean.window]

  static let fileMode = window.popUpButtons[.Clean.Controls.fileMode]
  static let folderMode = window.popUpButtons[.Clean.Controls.folderMode]

  enum FileMode
  {
    static let untracked = window.menuItems["Untracked only"]
    static let ignored = window.menuItems["Ignored only"]
    static let all = window.menuItems["All"]
  }

  enum FolderMode
  {
    static let cleanFolder = window.menuItems["Clean entire folder"]
    static let recurse = window.menuItems["List contents"]
    static let ignore = window.menuItems["Ignore"]
  }

  static let filterPopup = window.popUpButtons[.Clean.Controls.filterType]
  static let selectedText = window.staticTexts[.Clean.Text.selected]

  static let totalText = window.staticTexts[.Clean.Text.total]
  static let refreshButton = window.buttons[.Clean.Button.refresh]

  static let cancelButton = window.buttons[.Clean.Button.cancel]
  static let cleanSelectedButton = window.buttons[.Clean.Button.cleanSelected]
  static let cleanAllButton = window.buttons[.Clean.Button.cleanAll]

  static func assertCleanFiles(_ names: [String],
                               file: StaticString = #filePath,
                               line: UInt = #line)
  {
    let cellTitles = window.cells.staticTexts.allElementsBoundByIndex
                           .map { $0.stringValue }

    XCTAssertEqual(cellTitles, names, file: file, line: line)
    XCTAssertEqual(totalText.stringValue,
                   "\(names.count) item(s) total",
                   file: file, line: line)
  }
}

enum ResetSheet
{
  static let window = XitApp.sheets["ResetSheet"]
  
  // Why these are exposed as radio buttons instead of a segmented control
  // is a mystery.
  static let softButton = window.radioButtons["Soft"]
  static let mixedButton = window.radioButtons["Mixed"]
  static let hardButton = window.radioButtons["Hard"]
  
  static let modeDescription = window.staticTexts["Description"]
  static let statusText = window.staticTexts["Status"]
  
  static let cancelButton = window.buttons["Cancel"]
  static let resetButton = window.buttons["Reset"]
}

enum PushNewSheet
{
  static let window = XitApp.sheets["PushNewSheet"]
  
  static let setTrackingCheck = window.checkBoxes["Set as tracking branch"]
  static let pushButton = window.buttons["Push"]
}

enum CreateTrackingSheet
{
  static let window = XitApp.sheets[.CreateTracking.window]
  
  static let prompt = window.staticTexts[.CreateTracking.prompt]
  static let branchName = window.textFields[.CreateTracking.branchName]
  static let checkOut = window.checkBoxes[.CreateTracking.checkOut]
  static let errorMessage = window.staticTexts[.CreateTracking.errorMessage]
  
  static let cancelButton = window.buttons[.Button.cancel]
  static let createButton = window.buttons[.Button.accept]
}
