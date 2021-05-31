import SwiftUI

struct ClonePanel: View
{
  @Binding var url: String
  @Binding var destination: String
  @Binding var name: String
  @Binding var branches: [String]
  
  typealias CloneField = LabeledField<Text, TextField<Text>, CloneLabelWidth>
  
  var body: some View
  {
    VStack {
      Form {
        CloneField("URL:", TextField("", text: $url))
        HStack {
          CloneField("Destination:", TextField("", text: $destination))
          Button {
            // select a folder
          } label: {
            Image(systemName: "folder")
          }.buttonStyle(BorderlessButtonStyle())
        }
        CloneField("Name:", TextField("", text: $name))
        LabeledField(label: Text("Check out branch:"),
                     content: Picker(selection: .constant(1), label: Text("")) {
                       ForEach(0..<branches.count) { index in
                         Text(branches[index])
                       }
                     }.labelsHidden(),
                     key: CloneLabelWidth.self)
      }
        .labelWidth(CloneLabelWidth.self)
      HStack {
        Spacer()
        Button("Cancel") {
          // close the sheet
        }
        Button("Clone") {
          // execute the action
        }
      }
    }.padding()
  }
}

struct CloneLabelWidth: MaxDimensionKey
{
  static var defaultValue: CGFloat = 0
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
