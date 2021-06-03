import SwiftUI

struct ClonePanel: View
{
  @ObservedObject var data: CloneData
  let close: () -> Void
  let clone: () -> Void
  
  var popupSelection: Binding<String>
  {
    data.branches.isEmpty ? .constant("Unavailable") : $data.selectedBranch
  }
  
  var popupBranches: [String]
  {
    data.branches.isEmpty ? ["Unavailable"] : data.branches
  }
  
  var body: some View
  {
    VStack {
      Form {
        LabeledField("URL:", TextField("", text: $data.url))
        LabeledField("Destination:", PathField(path: $data.destination))
        LabeledField("Name:", TextField("", text: $data.name))
        LabeledField(label: Text("Check out branch:"),
                     content: Picker(selection: popupSelection, label: Text("")) {
                       ForEach(popupBranches, id: \.self) {
                         Text($0)
                       }
                     }.labelsHidden()
                      .disabled(data.branches.isEmpty)
                      .fixedSize(horizontal: true, vertical: true))
        LabeledField("", Toggle("Recurse submodules", isOn: $data.recurse))
      }.labelWidthGroup()
      Spacer(minLength: 12)
      HStack {
        if data.inProgress {
          ProgressView().controlSize(.small).padding(.trailing, 8)
        }
        if let error = data.error {
          Image(systemName: "exclamationmark.triangle.fill")
            .renderingMode(.original)
          Text(error)
        }
        Spacer()
        Button("Cancel") {
          close()
        }.keyboardShortcut(.cancelAction)
        Button("Clone") {
          clone()
        }.keyboardShortcut(.defaultAction)
         .disabled(!data.urlValid)
      }
    }.padding()
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
      ClonePanel(data: data, close: {}, clone: {})
    }
  }
  static var previews: some View
  {
    Group {
      Preview(data: .init())
      Preview(data: .init()
                .error("Oops!")
                .branches(["main", "master"], "main")
                .inProgress())
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
  
  func branches(_ b: [String], _ s: String) -> CloneData
  {
    branches = b
    selectedBranch = s
    return self
  }
  
  func inProgress(_ p: Bool = true) -> CloneData
  {
    inProgress = p
    return self
  }
}
