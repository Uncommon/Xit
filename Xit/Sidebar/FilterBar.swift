import Foundation
import SwiftUI

struct FilterBar<LeftContent: View, RightContent: View>: View
{
  let text: Binding<String>
  let leftContent: () -> LeftContent
  let fieldRightContent: () -> RightContent

  var body: some View
  {
    HStack(spacing: 0) {
      leftContent()
      FilterField(text: text, prompt: Text(.filter)) {
        FilterIndicator()
      } rightContent: {
        fieldRightContent()
      }.padding(2)
    }.padding(.horizontal, 4)
  }

  init(text: Binding<String>,
       @ViewBuilder leftContent: @escaping () -> LeftContent,
       @ViewBuilder fieldRightContent: @escaping () -> RightContent)
  {
    self.text = text
    self.leftContent = leftContent
    self.fieldRightContent = fieldRightContent
  }
}

extension FilterBar where RightContent == EmptyView
{
  init(text: Binding<String>,
       @ViewBuilder leftContent: @escaping () -> LeftContent)
  {
    self.text = text
    self.leftContent = leftContent
    self.fieldRightContent = EmptyView.init
  }
}

extension FilterBar where LeftContent == EmptyView, RightContent == EmptyView
{
  init(text: Binding<String>)
  {
    self.text = text
    self.leftContent = EmptyView.init
    self.fieldRightContent = EmptyView.init
  }
}
