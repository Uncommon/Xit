import Foundation
import SwiftUI

/// Action pop-up button that goes next to the filter field at the bottom
/// of the sidebar
struct SidebarActionButton<Content: View>: View
{
  let content: () -> Content

  var body: some View
  {
    Menu(content: content, label: {
      Image(systemName: "ellipsis.circle")
    })
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .frame(width: 24)
  }

  init(@ViewBuilder content: @escaping () -> Content)
  {
    self.content = content
  }
}

struct SidebarBottomButton: View
{
  let systemImage: String
  let action: () -> Void

  var body: some View
  {
    Button(action: action, label: {
      Image(systemName: systemImage)
    }).buttonStyle(.plain).padding(.horizontal, 3)
  }
}
