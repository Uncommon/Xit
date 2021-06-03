import SwiftUI

struct ClonePanel: View
{
  @ObservedObject var data: CloneData
  
  var body: some View
  {
    VStack {
      Form {
        LabeledField("URL:", TextField("", text: $data.url)
          { _ in }
          onCommit: {
            data.inProgress = true
            defer { data.inProgress = false }
            data.urlValid = false
            data.branches = []
            
            guard let url = URL(string: self.data.url),
                  let remote = GitRemote(url: url)
            else { return }

            // May need a password callback depending on the host
            guard let heads = try? remote.withConnection(direction: .fetch,
                                                         callbacks: .init(),
                                                         action: {
              try $0.referenceAdvertisements()
            })
            else { return }

            data.branches = heads.compactMap { head in
              head.symrefTarget.hasPrefix(RefPrefixes.heads)
                ? head.symrefTarget.droppingPrefix(RefPrefixes.heads)
                : nil
            }
            data.urlValid = true
          })
        LabeledField("Destination:", PathField(path: $data.destination))
        LabeledField("Name:", TextField("", text: $data.name))
        LabeledField(label: Text("Check out branch:"),
                     content: Picker(selection: $data.selectedBranch,
                                     label: Text("")) {
                      ForEach(data.branches, id: \.self) { branch in
                        Text(branch)
                       }
                     }.labelsHidden().disabled(data.branches.isEmpty))
        LabeledField("", Toggle("Recurse submodules", isOn: $data.recurse))
      }.labelWidthGroup()
      Spacer(minLength: 12)
      HStack {
        if data.inProgress {
          ProgressView()
        }
        if let error = data.error {
          Image(systemName: "exclamationmark.triangle.fill")
            .renderingMode(.original)
          Text(error)
        }
        Spacer()
        Button("Cancel") {
          // close the sheet
        }.keyboardShortcut(.cancelAction)
        Button("Clone") {
          // execute the action
        }.keyboardShortcut(.defaultAction)
          .disabled(!data.urlValid)
      }
    }
      .padding()
      .fixedSize(horizontal: false, vertical: true)
      .frame(minWidth: 500)
  }
}

struct ClonePanel_Previews: PreviewProvider
{
  struct Preview: View
  {
    @StateObject var data: CloneData
    
    var body: some View
    {
      ClonePanel(data: data)
    }
  }
  static var previews: some View
  {
    Group {
      Preview(data: .init())
      Preview(data: .init().error("Oops!").branches(["main", "master"]))
    }
  }
}

extension CloneData
{
  func error(_ e: String) -> CloneData
  {
    error = e
    return self
  }
  
  func branches(_ b: [String]) -> CloneData
  {
    branches = b
    return self
  }
}
