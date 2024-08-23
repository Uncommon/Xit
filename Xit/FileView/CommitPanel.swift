import SwiftUI

struct CommitPanel: View
{
  @Binding var message: String
  @Binding var amend: Bool
  @Binding var stripComments: Bool
  @Binding var commitAllowed: Bool
  let commit: () -> Void

  private var characterWidth: CGFloat
  {
    let size = "W".size(withAttributes: [.font: NSFont.code])
    return size.width
  }

  private enum Constants
  {
    static let textEditorInset: CGFloat = 5
  }

  var body: some View {
      HStack(spacing: 0) {
        ZStack(alignment: .topLeading) {
          TextEditor(text: $message).background(Color(NSColor.clear))
          Text("Commit message")
            .foregroundColor(Color(.placeholderTextColor))
            .padding(.leading, Constants.textEditorInset)
            .opacity(message.isEmpty ? 1 : 0)
            .allowsHitTesting(false)
          if UserDefaults.xit.showGuide {
            Rectangle()
              .fill(.gray.opacity(0.25))
              .frame(width: 1, height: .infinity)
              .offset(x: characterWidth
                      * CGFloat(UserDefaults.xit.guideWidth)
                      + Constants.textEditorInset)
          }
        }
        .font(.code)
        .clipped()
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
