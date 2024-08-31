import SwiftUI

struct FetchPanel: DataModelView
{
  typealias Model = Options

  final class Options: ObservableObject, AlwaysValid
  {
    let remotes: [String]
    @Published var remote: String
    @Published var downloadTags: Bool
    @Published var pruneBranches: Bool

    init(remotes: [String], remote: String,
         downloadTags: Bool, pruneBranches: Bool)
    {
      self.remotes = remotes
      self.remote = remote
      self.downloadTags = downloadTags
      self.pruneBranches = pruneBranches
    }
  }

  @ObservedObject var model: Options

  var body: some View
  {
    Form {
      Picker(.remote.colon, selection: $model.remote) {
        ForEach(model.remotes, id: \.self) {
          Text($0)
        }
      }.accessibilityIdentifier(.FetchSheet.remotePopup)
      LabeledContent(.options.colon) {
        VStack(alignment: .leading) {
          Toggle(.downloadTags, isOn: $model.downloadTags)
            .accessibilityIdentifier(.FetchSheet.tagsCheck)
          Toggle(.pruneObsolete, isOn: $model.pruneBranches)
            .accessibilityIdentifier(.FetchSheet.pruneCheck)
        }
      }
    }
  }
}

struct FetchPanel_Previews: PreviewProvider
{
  static var options: FetchPanel.Options = .init(
      remotes: ["origin", "constantinople"],
      remote: "origin",
      downloadTags: false,
      pruneBranches: true)

  static var previews: some View {
    FetchPanel(model: options)
    VStack {
      FetchPanel(model: options)
      DialogButtonRow(validator: options, buttons: [
        (.cancel, {}),
        (.accept(.fetch), {}),
      ])
    }
  }
}
