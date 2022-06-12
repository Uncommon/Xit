import SwiftUI

enum ButtonType
{
  case cancel
  case accept(String)
  case other(String)

  static var ok = ButtonType.accept(UIString.ok.rawValue)

  static func accept(_ uiString: UIString) -> ButtonType
  { .accept(uiString.rawValue) }

  var title: String
  {
    switch self {
      case .cancel:
        return UIString.cancel.rawValue
      case .accept(let text), .other(let text):
        return text
    }
  }

  var keyboardShortcut: KeyboardShortcut?
  {
    switch self {
      case .cancel:
        return .cancelAction
      case .accept:
        return .defaultAction
      default:
        return nil
    }
  }
}

extension ButtonType: Hashable
{
  func hash(into hasher: inout Hasher)
  {
    hasher.combine(title)
  }
}

typealias ButtonAction = () -> Void
typealias ButtonList = [(ButtonType, ButtonAction)]

struct ButtonsKey: EnvironmentKey
{ static let defaultValue: ButtonList = [] }

extension EnvironmentValues
{
  /// The set of buttons that should appear at the bottom of a dialog.
  var buttons: ButtonList
  {
    get { self[ButtonsKey.self] }
    set { self[ButtonsKey.self] = newValue }
  }
}

/// A row of buttons, as specified in the `.buttons` environment value.
struct DialogButtonRow: View
{
  @Environment(\.buttons) var buttons: ButtonList

  var body: some View
  {
    HStack {
      Spacer()
      ForEach(buttons, id: \.0) {
        Button($0.0.title, action: $0.1)
          .keyboardShortcut($0.0.keyboardShortcut)
      }
    }.padding([.top])
  }
}

struct ButtonRow_Previews: PreviewProvider {
    static var previews: some View {
      DialogButtonRow()
        .environment(\.buttons, [
          (.cancel, {}),
          (.ok, {}),
        ])
      DialogButtonRow()
        .environment(\.buttons, [
          (.cancel, {}),
          (.accept(.add), {}),
        ])
    }
}
