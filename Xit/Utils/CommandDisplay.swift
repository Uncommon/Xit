import SwiftUI

enum ImageName
{
  case system(String)
  case custom(String)
}

/// The same command name and associated icon can appear in various places
/// in the app, so this consolidates those pairings.
struct CommandDisplay
{
  let title: UIString
  let name: ImageName
  
  static let checkOut: Self = .init(title: .checkOut, name: .system("arrow.down.to.line"))
  static let delete: Self = .init(title: .delete, name: .system("trash"))
  static let merge: Self = .init(title: .merge, name: .system("arrow.trianglehead.merge"))
  static let rename: Self = .init(title: .rename, name: .system("pencil"))
}

extension Button where Label == SwiftUI.Label<Text, Image>
{
  init(command: CommandDisplay, role: ButtonRole? = nil, action: @escaping () -> Void)
  {
    let label = switch command.name {
      case .system(let systemImage): Label(command.title.rawValue, systemImage: systemImage)
      case .custom(let imageName): Label(command.title.rawValue, image: imageName)
    }
    self.init(role: role, action: action, label: { label })
  }
}
