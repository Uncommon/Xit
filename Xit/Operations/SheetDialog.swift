import Foundation
import SwiftUI

/// A view with a specific data model type.
protocol DataModelView: View
{
  associatedtype Model: ObservableObject, Validating

  init(model: Model)
}

/// Presents a `DataModelView` in a sheet.
protocol SheetDialog
{
  associatedtype ContentView: DataModelView

  var acceptButtonTitle: UIString { get }

  func createModel() -> ContentView.Model?
}

struct SheetDialogView<ContentView>: View where ContentView: DataModelView
{
  @ObservedObject var model: ContentView.Model
  let acceptButtonTitle: UIString
  let cancel: ButtonAction
  let accept: ButtonAction

  var body: some View
  {
    VStack {
      ContentView(model: model)
      DialogButtonRow(validator: model, buttons: [
        (.cancel, cancel),
        (.accept(acceptButtonTitle), accept),
      ])
    }.padding(20)
  }
}

extension SheetDialog
{
  @MainActor
  private func resolvedContentSize(for viewController: NSHostingController<
      SheetDialogView<ContentView>>) -> CGSize
  {
    viewController.view.layoutSubtreeIfNeeded()

    let fittingSize = viewController.view.fittingSize
    let intrinsicSize = viewController.view.intrinsicContentSize
    let width = resolvedDimension(fittingSize.width,
                                  fallback: intrinsicSize.width)
    let height = resolvedDimension(fittingSize.height,
                                   fallback: intrinsicSize.height)

    return .init(width: width, height: height)
  }

  private func resolvedDimension(_ value: CGFloat, fallback: CGFloat) -> CGFloat
  {
    if value.isFinite && value > 0 {
      value
    }
    else if fallback.isFinite && fallback > 0 {
      fallback
    } else {
      1
    }
  }

  /// Presents the sheet, and returns the user-approved settings, or `nil`
  /// if the user chooses to cancel.
  @MainActor
  func getOptions(parent: NSWindow) async -> ContentView.Model?
  {
    guard let model = createModel()
    else { return nil }
    let sheet = NSWindow()
    let rootView = SheetDialogView<ContentView>(
        model: model,
        acceptButtonTitle: acceptButtonTitle,
        cancel: { parent.endSheet(sheet, returnCode: .cancel) },
        accept: { parent.endSheet(sheet, returnCode: .OK) })
    let viewController = NSHostingController(rootView: rootView)

    sheet.contentViewController = viewController
    let contentSize = resolvedContentSize(for: viewController)
    sheet.contentMinSize = contentSize
    sheet.setContentSize(contentSize)

    guard await parent.beginSheet(sheet) == .OK
    else { return nil }

    return model
  }
}

struct SheetDialogView_Previews: PreviewProvider
{
  static var fetchModel: FetchPanel.Options = .init(
      remotes: ["origin", "constantinople"],
      remote: "origin",
      downloadTags: false,
      pruneBranches: true)

  static var stashModel = StashPanel.Model()

  static var tagModel: TagPanel.Model = .init(
      commitMessage: "Commit message",
      signature: .init(name: "Name", email: "email", when: .now))

  static var previews: some View
  {
    Group {
      SheetDialogView<FetchPanel>(
          model: fetchModel,
          acceptButtonTitle: .fetch,
          cancel: {},
          accept: {}).previewDisplayName("Fetch")
      SheetDialogView<StashPanel>(
          model: stashModel,
          acceptButtonTitle: .stash,
          cancel: {},
          accept: {}).previewDisplayName("Stash")
      SheetDialogView<TagPanel>(
          model: tagModel,
          acceptButtonTitle: .create,
          cancel: {},
          accept: {}).previewDisplayName("Tag")
    }
  }
}
