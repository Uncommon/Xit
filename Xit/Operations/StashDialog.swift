import Foundation

struct StashDialog: SheetDialog
{
  typealias ContentView = StashPanel

  var acceptButtonTitle: UIString { .stash }

  func createModel() -> StashPanel.Model? {
    .init()
  }
}
