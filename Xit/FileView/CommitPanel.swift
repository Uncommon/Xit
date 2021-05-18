import SwiftUI

struct CommitPanel: View
{
  @Binding var message: String
  @Binding var amend: Bool
  @Binding var stripComments: Bool
  @Binding var commitAllowed: Bool
  let commit: () -> Void

  var body: some View {
      HStack(spacing: 0) {
        ZStack(alignment: .topLeading) {
          TextEditor(text: $message).background(Color(NSColor.clear))
          Text("Commit message")
            .foregroundColor(Color(.placeholderTextColor))
            .padding(.leading, 5)
            .opacity(message.isEmpty ? 1 : 0)
            .allowsHitTesting(false)
        }.font(.commitBody)
        Divider()
        VStack(alignment: .leading) {
          Toggle(isOn: $amend, label: {
            Text("Amend")
          })
          Toggle(isOn: $stripComments, label: {
            Text("Strip comments")
          })
          TextField("Text", text: .constant("none"))
          Spacer()
          HStack {
            Spacer()
            Button("Commit") {
              commit()
            }.disabled(message.isEmpty || !commitAllowed)
            Spacer()
          }
        }.fixedSize(horizontal: true, vertical: false).padding()
      }
  }
}

struct CommitEntry_Previews: PreviewProvider
{
  struct Preview: View
  {
    @State var message: String = ""
    @State var amend: Bool = false
    @State var stripComments: Bool = true

    var body: some View {
      CommitPanel(message: $message, amend: $amend, stripComments: $stripComments,
                  commitAllowed: .constant(true),
                  commit: {})
    }
  }

  static var previews: some View {
    Preview()
  }
}
