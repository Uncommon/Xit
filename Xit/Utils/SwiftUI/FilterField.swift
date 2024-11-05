import Foundation
import SwiftUI

/// A text field that can have content (usually icons) to the left and right
/// of the text.
struct FilterField<LeftContent: View, RightContent: View>: View
{
  @Binding var text: String
  let prompt: Text?
  let leftContent: () -> LeftContent
  let rightContent: () -> RightContent

  @FocusState private var isFocused: Bool

  var body: some View
  {
    HStack(spacing: 4) {
      leftContent()
        .environment(\.filterActive, !text.isEmpty)
      TextField("", text: $text, prompt: prompt)
        .textFieldStyle(.plain)
        .focused($isFocused)
      rightContent()
        .environment(\.filterActive, !text.isEmpty)
    }
      .buttonStyle(.borderless)
      .padding(4)
      .background(RoundedRectangle(cornerRadius: 8)
        .fill(isFocused
              ? AnyShapeStyle(BackgroundStyle.background)
              : AnyShapeStyle(FillShapeStyle.fill))
        .stroke(.separator)
      )
  }

  init(text: Binding<String>, prompt: Text? = nil,
       @ViewBuilder leftContent: @escaping () -> LeftContent,
       @ViewBuilder rightContent: @escaping () -> RightContent)
  {
    self._text = text
    self.prompt = prompt
    self.leftContent = leftContent
    self.rightContent = rightContent
  }
}

extension FilterField where RightContent == EmptyView
{
  init(text: Binding<String>, prompt: Text? = nil,
       @ViewBuilder leftContent: @escaping () -> LeftContent)
  {
    self.init(text: text, prompt: prompt,
              leftContent: leftContent, rightContent: { EmptyView() })
  }
}

/// Indicator icon that highlights when the filter is active
struct FilterIndicator: View
{
  @Environment(\.filterActive) var isActive

  var body: some View
  {
    Image(systemName: "line.3.horizontal.decrease.circle")
      .symbolVariant(isActive ? .fill : .none)
      .foregroundColor(isActive ? .accentColor : .primary)
  }
}

struct FilterActiveKey: EnvironmentKey
{
  static let defaultValue: Bool = false
}

extension EnvironmentValues
{
  /// True when the `FilterField` filter is active - the filter text is not empty.
  var filterActive: Bool
  {
    get { self[FilterActiveKey.self] }
    set { self[FilterActiveKey.self] = newValue }
  }
}

struct FilterFieldPreview: View {
  @State var text: String
  var body: some View {
    FilterField(text: $text, prompt: Text("Filter")) {
      FilterIndicator()
    } rightContent: {
      Button {} label: { Image(systemName: "clock") }
    }
  }
}

#Preview {
  VStack {
    FilterFieldPreview(text: "")
    TextField("", text: .constant(""), prompt: Text("something else to focus"))
  }.padding()
}
