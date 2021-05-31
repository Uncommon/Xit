import SwiftUI

struct ClonePanel: View
{
  @Binding var url: String
  @Binding var destination: String
  @Binding var name: String
  @Binding var branches: [String]
  
  var body: some View
  {
    VStack {
      Form {
        LabeledField("URL:", TextField("", text: $url))
        HStack {
          LabeledField("Destination:", TextField("", text: $destination))
          Button {
            // select a folder
          } label: {
            Image(systemName: "folder")
          }.buttonStyle(BorderlessButtonStyle())
        }
        LabeledField("Name:", TextField("", text: $name))
        LabeledField(label: Text("Check out branch:"),
                     content: Picker(selection: .constant(1), label: Text("")) {
                       ForEach(0..<branches.count) { index in
                         Text(branches[index])
                       }
                     }.labelsHidden())
      }.labelWidthGroup()
      HStack {
        Spacer()
        Button("Cancel") {
          // close the sheet
        }.keyboardShortcut(.cancelAction)
        Button("Clone") {
          // execute the action
        }.keyboardShortcut(.defaultAction)
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
    
    var body: some View
    {
      ClonePanel(url: $url, destination: $destination,
                 name: $name, branches: $branches)
    }
  }
  static var previews: some View
  {
    Preview()
  }
}
