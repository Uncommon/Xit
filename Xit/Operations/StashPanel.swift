import SwiftUI

struct StashPanel: DataModelView
{
  final class Model: ObservableObject, AlwaysValid
  {
    @Published var message: String = ""
    @Published var keepStaged: Bool = false
    @Published var includeUntracked: Bool = true
    @Published var includeIgnored: Bool = false
  }

  @ObservedObject var model: Model

  var body: some View
  {
    VStack(alignment: .leading) {
      Text("Stash message (optional):")
      TextField(text: $model.message, label: { EmptyView() })
        .frame(minWidth: 285)
      Toggle("Keep staged changes", isOn: $model.keepStaged)
      Toggle("Include untracked files", isOn: $model.includeUntracked)
      Toggle("Include ignored files", isOn: $model.includeIgnored)
    }
  }
}

struct StashPanel_Previews: PreviewProvider
{
  static var previews: some View
  {
    VStack {
      StashPanel(model: .init())
      DialogButtonRow(validator: StashPanel.Model(), buttons: [
        (.cancel, {}),
        (.accept("Stash"), {}),
      ])
    }.padding()
  }
}
