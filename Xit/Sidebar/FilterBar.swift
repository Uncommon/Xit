import Foundation
import SwiftUI

struct FilterBar<LeftContent: View, RightContent: View>: View
{
  @Binding var text: String
  let prompt: UIString
  let leftContent: () -> LeftContent
  let fieldRightContent: () -> RightContent

  var body: some View
  {
    HStack(spacing: 0) {
      leftContent()
      FilterField(text: $text, prompt: Text(prompt)) {
        FilterIndicator()
      } rightContent: {
        fieldRightContent()
      }.padding(2)
    }.padding(.horizontal, 4)
  }

  init(text: Binding<String>,
       prompt: UIString = .filter,
       @ViewBuilder leftContent: @escaping () -> LeftContent,
       @ViewBuilder fieldRightContent: @escaping () -> RightContent)
  {
    self._text = text
    self.prompt = prompt
    self.leftContent = leftContent
    self.fieldRightContent = fieldRightContent
  }
}

extension FilterBar where RightContent == EmptyView
{
  init(text: Binding<String>,
       prompt: UIString = .filter,
       @ViewBuilder leftContent: @escaping () -> LeftContent)
  {
    self._text = text
    self.prompt = prompt
    self.leftContent = leftContent
    self.fieldRightContent = EmptyView.init
  }
}

extension FilterBar where LeftContent == EmptyView, RightContent == EmptyView
{
  init(text: Binding<String>, prompt: UIString = .filter)
  {
    self._text = text
    self.prompt = prompt
    self.leftContent = EmptyView.init
    self.fieldRightContent = EmptyView.init
  }
}
