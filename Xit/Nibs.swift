import Foundation
import AppKit

extension NSNib.Name
{
  // Use a "nib" suffix because NSNib.Name is a typealias for String
  static let fileViewControllerNib =
      String(describing: FileViewController.self)
}
