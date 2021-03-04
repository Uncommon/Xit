import SwiftUI

@available(OSX 10.15, *)
extension Font
{
  static let commitBody = Font.system(.body, design: .monospaced)
}

@available(OSX 10.15.0, *)
struct CommitHeader: View
{
  let name, email: String
  let parentDescriptions: [String]
  let date: Date
  let sha: String
  let message: String
  
  var body: some View {
    VStack(spacing: 8) {
      VStack {
        HStack {
          Text("\(name) <\(email)>").bold()
          Spacer()
          CommitHeaderLabel(text: "Date:")
          Text("\(date)")
        }
        HStack(alignment: .firstTextBaseline) {
          VStack(alignment: .leading) {
            ForEach(0..<parentDescriptions.count) { index in
              HStack {
                CommitHeaderLabel(text: "Parent:")
                Text(parentDescriptions[index])
                  .foregroundColor(.blue)
                  .onHover { isInside in
                    if isInside {
                      NSCursor.pointingHand.push()
                    }
                    else {
                      NSCursor.pop()
                    }
                  }
                  .onTapGesture {
                    print("tap")
                  }
              }
            }
          }
          Spacer()
          CommitHeaderLabel(text: "SHA:")
          Text(sha)
        }
      }
      Text(message)
        .lineLimit(nil)
        .font(.commitBody)
    }
  }
}

@available(OSX 10.15.0, *)
struct CommitHeaderLabel: View
{
  let text: String
  
  var body: some View {
    Text(text).font(.body).bold().foregroundColor(.gray)
  }
}

@available(OSX 10.15.0, *)
struct CommitHeader_Previews: PreviewProvider {
    static var previews: some View {
      CommitHeader(name: "Myself",
                   email: "me@myself.com",
                   parentDescriptions: ["The before", "Previous"],
                   date: Date(),
                   sha: "457608978",
                   message: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.")
        
    }
}
