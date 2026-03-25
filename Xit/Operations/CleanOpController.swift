import Foundation

class CleanOpController: OperationController
{
  var panelController: CleanPanelController?

  override func start() throws {
    guard let repository = repository
    else { throw RepoError.unexpected }

    panelController = CleanPanelController(repository: repository)

    windowController?.window?.beginSheet(panelController!.window!) {
      _ in
      self.ended()
    }
  }
}
