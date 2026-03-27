import Foundation

/// Minimal path-tree identity used by branch, tag, and ref models inside the
/// package without depending on the app target's UI utilities.
public protocol PathTreeData
{
  var treeNodePath: String { get }
}
