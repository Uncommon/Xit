import SwiftUI

struct StatusBadge: View
{
  let text: String
  let axid: AXID?

  var body: some View
  {
    Text(text)
      .padding(EdgeInsets(top: 1, leading: 5, bottom: 1, trailing: 5))
      .background(Color(nsColor: .controlColor))
      .clipShape(.capsule)
      .font(.system(size: 10))
      .axid(axid ?? .init(rawValue: ""))
  }
  
  init(_ text: String, axid: AXID? = nil)
  {
    self.text = text
    self.axid = axid
  }
}

struct WorkspaceStatusBadge: View
{
  let unstagedCount, stagedCount: Int

  var body: some View
  {
    StatusBadge("\(unstagedCount) ▸ \(stagedCount)",
                axid: .Sidebar.workspaceStatus)
  }
}
