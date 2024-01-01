import Foundation
import SwiftUI

final class CheckOutRemoteOpController: OperationController
{
  let remoteName: String
  let remoteBranch: String
  
  init(windowController: XTWindowController, remote: String, branch: String)
  {
    self.remoteName = remote
    self.remoteBranch = branch
    
    super.init(windowController: windowController)
  }
  
  override func start() throws
  {
    guard let window = windowController?.window
    else { throw RepoError.unexpected }
    let bareBranchName = remoteBranch.droppingPrefix(remoteName + "/")
    let model = CheckOutRemotePanel.Model(branchName: bareBranchName)
    var sheet: NSWindow! = nil
    let panel = CheckOutRemotePanel(model: model,
                                    originBranch: remoteBranch,
                                    validateBranch: validateBranch(_:),
                                    cancelAction: {
                                      window.endSheet(sheet, returnCode: .cancel)
                                    },
                                    createAction: {
                                      window.endSheet(sheet, returnCode: .OK)
                                    }).padding()
    let controller = NSHostingController(rootView: panel)
    
    sheet = NSWindow(contentViewController: controller)
      .axid(.CreateTracking.window)
    Task {
      if await window.beginSheet(sheet) == .OK {
        ended()
        performOperation(model: model)
      }
      else {
        ended(result: .canceled)
      }
    }
  }
  
  func performOperation(model: CheckOutRemotePanel.Model)
  {
    guard let repository = windowController?.repository
    else { return }
    
    do {
      guard let branchName = RemoteBranchRefName(remote: remoteName,
                                                 branch: remoteBranch)
      else {
        assertionFailure("bad branch name")
        throw RepoError.unexpected
      }
      let operation = CheckOutRemoteOperation(repository: repository,
                                              remoteBranch: branchName)
      
      try operation.perform(using: model)
    }
    catch let error as RepoError {
      windowController?.showErrorMessage(error: error)
    }
    catch {
      windowController?.showErrorMessage(error: .unexpected)
    }
  }

  func validateBranch(_ branchName: String) -> CheckOutRemotePanel.BranchNameStatus
  {
    guard !branchName.isEmpty,
          let refName = LocalBranchRefName(branchName),
          refName.isValid
    else {
      return .invalid
    }
    
    if repository?.localBranch(named: refName) != nil {
      return .conflict
    }
    else {
      return .valid
    }
  }
}
