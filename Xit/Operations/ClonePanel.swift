import SwiftUI

struct ClonePanel: View
{
  @ObservedObject var data: CloneData
  
  @State var inProgress: Bool = false
  @State var urlValid: Bool = false
  
  var body: some View
  {
    VStack {
      Form {
        LabeledField("URL:", TextField("", text: $data.url)
          { _ in }
          onCommit: {
            inProgress = true
            defer { inProgress = false }
            urlValid = false
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
            urlValid = true
          })
        LabeledField("Destination:", PathField(path: $data.destination))
        LabeledField("Name:", TextField("", text: $data.name))
        LabeledField(label: Text("Check out branch:"),
                     content: Picker(selection: .constant(1), label: Text("")) {
                      ForEach(0..<data.branches.count) { index in
                        Text(data.branches[index])
                       }
                     }.labelsHidden())
        LabeledField("", Toggle("Recurse submodules", isOn: $data.recurse))
      }.labelWidthGroup()
      HStack {
        if inProgress {
          ProgressView()
        }
        Spacer()
        Button("Cancel") {
          // close the sheet
        }.keyboardShortcut(.cancelAction)
        Button("Clone") {
          // execute the action
        }.keyboardShortcut(.defaultAction)
          .disabled(!urlValid)
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
    @StateObject var data: CloneData = .init()
    
    var body: some View
    {
      ClonePanel(data: data)
    }
  }
  static var previews: some View
  {
    Preview()
  }
}
