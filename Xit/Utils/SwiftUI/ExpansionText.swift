import SwiftUI

struct ExpansionText: NSViewRepresentable
{
  typealias NSViewType = ExpansionTextField
  
  let text: String
  let font: NSFont
  let color: NSColor
  
  init(_ text: String,
       font: NSFont = .systemFontSized,
       color: NSColor = .labelColor) {
    self.text = text
    self.font = font
    self.color = color
  }
  
  func makeNSView(context: Context) -> NSViewType
  {
    let field = ExpansionTextField(labelWithString: text)
    
    // no way to convert Font -> NSFont
    field.stringValue = text
    field.lineBreakMode = .byTruncatingTail
    field.allowsExpansionToolTips = true
    field.controlSize = context.environment.controlSize.nsControlSize
    field.font = font
    field.textColor = color
    return field
  }
  
  func updateNSView(_ nsView: NSViewType, context: Context)
  {
    nsView.stringValue = text
    nsView.allowsExpansionToolTips = true
  }
  
  func sizeThatFits(_ proposal: ProposedViewSize,
                    nsView: ExpansionTextField,
                    context: Context) -> CGSize?
  {
    let intrinsic = nsView.intrinsicContentSize
    
    return .init(width: min(proposal.width ?? intrinsic.width, intrinsic.width),
                 height: intrinsic.height)
  }
}

extension ControlSize
{
  var nsControlSize: NSControl.ControlSize
  {
    switch self {
      case .mini:
        .mini
      case .small:
        .small
      case .regular:
        .regular
      case .large:
        .large
      case .extraLarge:
        .large
      @unknown default:
        .regular
    }
  }
}

#Preview
{
  ExpansionText("An example with text hopefully long enough to truncate")
    .frame(maxWidth: 50)
    .padding()
}
