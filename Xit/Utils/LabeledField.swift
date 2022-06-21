import SwiftUI

/// A field with a label and content. Inside a parent view that uses the
/// `labelWidthGroup()` modifier, all field labels have the same width.
struct LabeledField<Label, Content>: View
  where Label: View, Content: View
{
  let label: Label
  let content: Content
  
  @Environment(\.labelWidth) var labelWidth: CGFloat
  
  var body: some View
  {
    HStack(alignment: .firstTextBaseline) {
      label
        .layoutPriority(1)
        .fixedSize()
        .overlay(GeometryReader(content: { geometry in
          Spacer().preference(key: LabelWidthPreferenceKey.self,
                              value: geometry.size.width)
        }))
        .frame(width: labelWidth, alignment: .trailing)
      content
    }
  }
  
  init(label: Label, content: Content)
  {
    self.label = label
    self.content = content
  }
}

extension LabeledField where Label == Text
{
  /// Convenience initializer for a field with a simple text label.
  init(_ labelText: String, _ content: Content)
  {
    self.init(label: Text(labelText), content: content)
  }
  
  init(_ labelString: UIString, _ content: Content)
  {
    self.init(label: Text(labelString.rawValue), content: content)
  }
}

private struct LabelWidthPreferenceKey: MaxDimensionKey
{
  static var defaultValue: CGFloat = 0
}

// MARK: -

/// A preference that collects the maximum value from the subviews.
protocol MaxDimensionKey: SwiftUI.PreferenceKey where Value == CGFloat {}

extension MaxDimensionKey
{
  static func reduce(value: inout Value, nextValue: () -> Value)
  {
    value = max(value, nextValue())
  }
}

// MARK: -

struct LabelWidthKey: EnvironmentKey
{
  static let defaultValue: CGFloat = 0
}

extension EnvironmentValues
{
  /// Communicates the largest label width to subviews.
  var labelWidth: CGFloat
  {
    get { self[LabelWidthKey.self] }
    set { self[LabelWidthKey.self] = newValue }
  }
}

// MARK: -

struct LabelWidthModifier: ViewModifier
{
  @State var labelWidth: CGFloat = 0
  
  func body(content: Content) -> some View
  {
    content
      .onPreferenceChange(LabelWidthPreferenceKey.self) { labelWidth = $0 }
      .environment(\.labelWidth, labelWidth)
  }
}

extension View
{
  /// Identifies a group within which all field labels have the same width.
  func labelWidthGroup() -> some View
  {
    modifier(LabelWidthModifier())
  }
}
