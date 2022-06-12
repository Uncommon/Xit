import Foundation
import SwiftUI

/// A view with a specific data model type.
protocol DataModelView: View
{
  associatedtype Model: ObservableObject

  init(model: Model)
}

/// Presents a `DataModelView` in a sheet.
protocol SheetDialog
{
  associatedtype ContentView: DataModelView

  var acceptButtonTitle: UIString { get }

  func createModel() -> ContentView.Model?
}

extension SheetDialog
{
  /// Presents the sheet, and returns the user-approved settings, or `nil`
  /// if the user chooses to cancel.
  @MainActor
  func getOptions(parent: NSWindow) async -> ContentView.Model?
  {
    guard let model = createModel()
    else { return nil }
    let sheet = NSWindow()
    let viewController = NSHostingController {
      VStack {
        ContentView(model: model)
        DialogButtonRow()
          .environment(\.buttons, [
            (.cancel,
             { parent.endSheet(sheet, returnCode: .cancel) }),
            (.accept(acceptButtonTitle),
             { parent.endSheet(sheet, returnCode: .OK) }),
          ])
      }.padding()
    }

    sheet.contentViewController = viewController
    sheet.contentMinSize = viewController.view.intrinsicContentSize

    guard await parent.beginSheet(sheet) == .OK
    else { return nil }

    return model
  }
}
