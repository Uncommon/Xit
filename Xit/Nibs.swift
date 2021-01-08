import Foundation

extension NSNib.Name
{
  // Use a "nib" suffix because NSNib.Name is a typealias for String
  static let buildStatusNib = String(describing: BuildStatusViewController.self)
  static let fileViewControllerNib =
      String(describing: FileViewController.self)
}
