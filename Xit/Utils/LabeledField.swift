import SwiftUI

/// A field with a text label and content. Fields using the same `Key` will
/// have their labels set to the same width as long as a parent view uses the
/// `.labelWidth()` modifier.
struct LabeledField<Label, Content, Key>: View
  where Label: View, Content: View, Key: MaxDimensionKey
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
          Spacer().preference(key: Key.self, value: geometry.size.width)
        }))
        .frame(width: labelWidth, alignment: .trailing)
      content
    }
  }
  
  init(label: Label, content: Content, key: Key.Type = Key.self)
  {
    self.label = label
    self.content = content
  }
}

extension LabeledField where Label == Text
{
  init(_ labelText: String, _ content: Content)
  {
    self.init(label: Text(labelText), content: content)
  }
}

// MARK: -

/// A preference that collects the maximum value from the subviews.
protocol MaxDimensionKey: PreferenceKey where Value == CGFloat {}

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
  /// Communicates the largest label width to subviews. The value is not
  /// differentiated by preference key, so only one label width can be used
  /// inside a given parent view.
  var labelWidth: CGFloat
  {
    get { self[LabelWidthKey.self] }
    set { self[LabelWidthKey.self] = newValue }
  }
}

// MARK: -

struct LabelWidthModifier<Key>: ViewModifier where Key: MaxDimensionKey
{
  @State var labelWidth: CGFloat = 0
  
  func body(content: Content) -> some View
  {
    content
      .onPreferenceChange(Key.self) { labelWidth = $0 }
      .environment(\.labelWidth, labelWidth)
  }
}

extension View
{
  /// Sets the preference key used for label width among subviews.
  func labelWidth<K>(_ key: K.Type) -> some View where K: MaxDimensionKey
  {
    modifier(LabelWidthModifier<K>())
  }
}
