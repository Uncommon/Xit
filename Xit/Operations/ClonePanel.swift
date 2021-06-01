import SwiftUI

struct ClonePanel: View
{
  @Binding var url: String
  @Binding var destination: String
  @Binding var name: String
  @Binding var branches: [String]
  @Binding var recurse: Bool
  
  @State var inProgress: Bool = false
  @State var urlValid: Bool = false
  
  var body: some View
  {
    VStack {
      Form {
        LabeledField("URL:", TextField("", text: $url)
          { _ in }
          onCommit: {
            inProgress = true
            defer { inProgress = false }
            urlValid = false
            branches = []
            
            guard let url = URL(string: self.url),
                  let remote = GitRemote(url: url)
            else { return }

            // May need a password callback depending on the host
            guard let heads = try? remote.withConnection(direction: .fetch,
                                                         callbacks: .init(),
                                                         action: {
              try $0.referenceAdvertisements()
            })
            else { return }

            branches = heads.compactMap { head in
              head.symrefTarget.hasPrefix(RefPrefixes.heads)
                ? head.symrefTarget.droppingPrefix(RefPrefixes.heads)
                : nil
            }
            urlValid = true
          })
        LabeledField("Destination:", PathField(path: $destination))
        LabeledField("Name:", TextField("", text: $name))
        LabeledField(label: Text("Check out branch:"),
                     content: Picker(selection: .constant(1), label: Text("")) {
                       ForEach(0..<branches.count) { index in
                         Text(branches[index])
                       }
                     }.labelsHidden())
        LabeledField("", Toggle("Recurse submodules", isOn: $recurse))
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
    }.padding()
  }
}

struct ClonePanel_Previews: PreviewProvider
{
  struct Preview: View
  {
    @State var url: String = ""
    @State var destination: String = ""
    @State var name: String = ""
    @State var branches: [String] = ["default", "main"]
    @State var recurse: Bool = false
    
    var body: some View
    {
      ClonePanel(url: $url, destination: $destination,
                 name: $name, branches: $branches, recurse: $recurse)
    }
  }
  static var previews: some View
  {
    Preview()
  }
}
