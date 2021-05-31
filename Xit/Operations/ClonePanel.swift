import SwiftUI

struct ClonePanel: View
{
  @Binding var url: String
  @Binding var destination: String
  @Binding var name: String
  
  typealias CloneField = LabeledField<Text, TextField<Text>, CloneLabelWidth>
  
  var body: some View
  {
    VStack {
      Form {
        CloneField("URL:", TextField("", text: $url))
        CloneField("Destination:", TextField("", text: $destination))
        CloneField("Name:", TextField("", text: $name))
      }
        .labelWidth(CloneLabelWidth.self)
      HStack {
        Spacer()
        Button("Cancel") {}
        Button("Clone") {}
      }
    }.padding()
  }
}

struct CloneLabelWidth: MaxDimensionKey
{
  static var defaultValue: CGFloat = 0
}

// MARK: -

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
}

extension LabeledField where Label == Text
{
  init(_ labelText: String, _ content: Content)
  {
    self.init(label: Text(labelText), content: content)
  }
}

// MARK: -

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
  func labelWidth<K>(_ key: K.Type) -> some View where K: MaxDimensionKey
  {
    modifier(LabelWidthModifier<K>())
  }
}

// MARK: -

struct ClonePanel_Previews: PreviewProvider
{
  struct Preview: View
  {
    @State var url: String = ""
    @State var destination: String = ""
    @State var name: String = ""
    
    var body: some View
    {
      ClonePanel(url: $url, destination: $destination, name: $name)
    }
  }
  static var previews: some View
  {
    Preview()
  }
}
