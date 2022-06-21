import SwiftUI

struct PreviewsPrefsPane: View
{
  @AppStorage var fontName: String
  @AppStorage var fontSize: Int
  @AppStorage var whitespcae: WhitespaceSetting
  @AppStorage var wrapping: TextWrapping
  @AppStorage var tabWidth: Int
  @AppStorage var contextLines: Int

  @State var fontChanger: FontChanger?
  @State var font: NSFont

  let widths = [2, 4, 6, 8]
  let contexts = [0, 3, 6, 12, 25]

  class FontChanger: NSResponder, NSFontChanging
  {
    let font: Binding<NSFont>

    init(font: Binding<NSFont>)
    {
      self.font = font

      super.init()
    }

    required init?(coder: NSCoder)
    { fatalError("init(coder:) has not been implemented") }

    func changeFont(_ sender: NSFontManager?)
    {
      font.wrappedValue = NSFontManager.shared.convert(font.wrappedValue)
    }

    func validModesForFontPanel(_ fontPanel: NSFontPanel)
      -> NSFontPanel.ModeMask
    { [.collection, .face, .size] }
  }

  var body: some View
  {
    VStack(alignment: .leading) {
      LabeledField("Font:", HStack {
        Button("Change...") {
          let manager = NSFontManager.shared

          manager.setSelectedFont(font, isMultiple: false)
          manager.orderFrontFontPanel(nil)
          fontChanger = FontChanger(font: $font)
          manager.target = fontChanger
        }.controlSize(.small)
          .onChange(of: font) { newValue in
            fontName = newValue.displayName ?? newValue.fontName
            fontSize = Int(newValue.pointSize)
          }
        Text("\(fontName) \(fontSize)")
      })
      LabeledField("Diff view defaults:", VStack(alignment: .leading) {
        Picker(selection: $whitespcae) {
          ForEach(WhitespaceSetting.allCases, id: \.self) {
            Text($0.displayName)
          }
        } label: { EmptyView() }.fixedSize()
        HStack {
          Picker(selection: $tabWidth) {
            ForEach(widths, id: \.self) {
              Text("\($0)")
            }
          } label: { EmptyView() }.fixedSize()
          Text("spaces per tab")
        }
        HStack {
          Picker(selection: $contextLines) {
            ForEach(contexts, id: \.self) {
              Text("\($0)")
            }
          } label: { EmptyView() }.fixedSize()
          Text("lines of context")
        }
        Picker(selection: $wrapping) {
          ForEach(TextWrapping.allCases, id: \.self) {
            Text($0.displayName)
          }
        } label: { EmptyView() }.fixedSize()
      })
    }.labelWidthGroup().frame(minWidth: 350)
  }

  init(defaults: UserDefaults)
  {
    _fontName = .init(wrappedValue: defaults.fontName,
                      PreferenceKeys.fontName.key,
                      store: defaults)
    _fontSize = .init(wrappedValue: defaults.fontSize,
                      PreferenceKeys.fontSize.key,
                      store: defaults)
    _whitespcae = .init(wrappedValue: defaults.whitespace,
                        PreferenceKeys.diffWhitespace.key,
                        store: defaults)
    _wrapping = .init(wrappedValue: defaults.wrapping,
                      PreferenceKeys.wrapping.key,
                      store: defaults)
    _tabWidth = .init(wrappedValue: defaults.tabWidth,
                      PreferenceKeys.tabWidth.key,
                      store: defaults)
    _contextLines = .init(wrappedValue: defaults.contextLines,
                          PreferenceKeys.contextLines.key,
                          store: defaults)

    // Access wrappedValue and projectedValue explicitly because self isn't
    // completely initilaized yet.
    let cgSize = CGFloat(_fontSize.wrappedValue)

    _font = .init(initialValue:
        .init(name: _fontName.wrappedValue, size: cgSize) ??
        .monospacedSystemFont(ofSize: cgSize, weight: .regular))

    // Re-set the font namne in case we ended up with .monospacedSystemFont
    fontName = font.displayName ?? font.fontName
  }
}

struct PreviewsPrefsPane_Previews: PreviewProvider
{
  static var previews: some View
  {
    PreviewsPrefsPane(defaults: .testing)
      .padding().frame(width: 400.0)
  }
}
