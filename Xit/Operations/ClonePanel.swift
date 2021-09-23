import SwiftUI

struct ClonePanel: View
{
  @ObservedObject var data: CloneData
  let close: () -> Void
  let clone: () -> Void
  
  var popupSelection: Binding<String>
  {
    data.branches.isEmpty ? .constant(UIString.unavailable.rawValue)
                          : $data.selectedBranch
  }
  
  var popupBranches: [String]
  {
    data.branches.isEmpty ? [UIString.unavailable.rawValue] : data.branches
  }
  
  var body: some View
  {
    VStack {
      Form {
        LabeledField(.sourceURL.colon, TextField("", text: $data.url))
        LabeledField(.cloneTo.colon, PathField(path: $data.destination))
        LabeledField(.name.colon, TextField("", text: $data.name))
        LabeledField(.fullPath.colon, Text(data.destination +/ data.name))
        Divider()
        LabeledField(label: Text(.checkOutBranch.colon),
                     content: Picker(selection: popupSelection,
                                     label: EmptyView()) {
                       ForEach(popupBranches, id: \.self) {
                         Text($0)
                       }
                     }.labelsHidden()
                      .disabled(data.branches.isEmpty)
                      .fixedSize(horizontal: true, vertical: true))
        //LabeledField("", Toggle("Recurse submodules", isOn: $data.recurse))
      }.labelWidthGroup()
      Spacer(minLength: 12)
      HStack {
        if data.inProgress {
          ProgressView().controlSize(.small).padding(.trailing, 8)
        }
        if let error = data.errorString {
          Image(systemName: "exclamationmark.triangle.fill")
            .renderingMode(.original)
          Text(error)
        }
        Spacer()
        Button(.cancel) {
          close()
        }.keyboardShortcut(.cancelAction)
        Button(.clone) {
          clone()
        }.keyboardShortcut(.defaultAction)
         .disabled(!data.results.allSucceeded)
      }
    }.padding(20)
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
      Preview(data: .init(readURL: {
        _ in .success(("Repo", ["main", "master"], "main"))
      }))
      Preview(data: .init(readURL: { _ in .failure(.unexpected) })
                .path("/Users/Uncommon/Developer")
                .name("Repo")
                .urlResult(.failure(.invalid))
                .branches(["main", "master"], "main")
                .inProgress())
    }
  }
}

extension CloneData
{
  func urlResult(_ r: Result<Void, URLValidationError>) -> CloneData
  { results.url = r; return self }
  
  func branches(_ b: [String], _ s: String) -> CloneData
  { branches = b; selectedBranch = s; return self }
  
  func path(_ p: String) -> CloneData
  { destination = p; return self }
  
  func name(_ n: String) -> CloneData
  { name = n; return self }
  
  func inProgress(_ p: Bool = true) -> CloneData
  { inProgress = p; return self }
}
