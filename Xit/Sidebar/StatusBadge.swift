import SwiftUI

struct StatusBadge: View
{
  let text: String

  var body: some View
  {
    Text(text)
      .padding(EdgeInsets(top: 1, leading: 5, bottom: 1, trailing: 5))
      .background(Color(nsColor: .controlColor))
      .clipShape(.capsule)
      .font(.system(size: 10))
  }
  
  init(_ text: String)
  {
    self.text = text
  }
}

struct WorkspaceStatusBadge: View
{
  let unstagedCount, stagedCount: Int

  var body: some View
  {
    StatusBadge("\(unstagedCount) ▸ \(stagedCount)")
  }
}
