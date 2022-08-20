import Foundation
import SwiftUI

// Convenience extensions for using UIString in place of String in various
// appropriate places.

extension NSAlert
{
  var messageString: UIString
  {
    get { UIString(rawValue: messageText) }
    set { messageText = newValue.rawValue }
  }
  var informativeString: UIString
  {
    get { UIString(rawValue: informativeText) }
    set { informativeText = newValue.rawValue }
  }
  
  func addButton(withString title: UIString)
  {
    addButton(withTitle: title.rawValue)
  }
}

extension NSButton
{
  var titleString: UIString
  {
    get { UIString(rawValue: title) }
    set { title = newValue.rawValue }
  }
  
  convenience init(titleString: UIString, target: AnyObject, action: Selector)
  {
    self.init(title: titleString.rawValue, target: target, action: action)
  }
}

extension NSControl
{
  var uiStringValue: UIString
  {
    get { UIString(rawValue: stringValue) }
    set { stringValue = newValue.rawValue }
  }
}

extension NSMenu
{
  @discardableResult
  func addItem(withTitleString title: UIString,
               action: Selector?, keyEquivalent: String) -> NSMenuItem
  {
    return addItem(withTitle: title.rawValue,
                   action: action, keyEquivalent: keyEquivalent)
  }
}

extension NSMenuItem
{
  var titleString: UIString
  {
    get { UIString(rawValue: title) }
    set { title = newValue.rawValue }
  }

  convenience init(titleString: UIString,
                   action: Selector?,
                   keyEquivalent: String)
  {
    self.init(title: titleString.rawValue,
              action: action,
              keyEquivalent: keyEquivalent)
  }
}

extension NSPathControlItem
{
  var titleString: UIString
  {
    get { UIString(rawValue: title) }
    set { title = newValue.rawValue }
  }
}

extension NSSavePanel
{
  var messageString: UIString
  {
    get { UIString(rawValue: message) }
    set { message = newValue.rawValue }
  }
  var promptString: UIString
  {
    get { UIString(rawValue: prompt) }
    set { prompt = newValue.rawValue }
  }
}

extension NSTextField
{
  convenience init(labelWithUIString uiString: UIString)
  {
    self.init(labelWithString: uiString.rawValue)
  }
}

extension NSSegmentedControl
{
  convenience init(labelStrings: [UIString],
                   trackingMode: NSSegmentedControl.SwitchTracking,
                   target: AnyObject, action: Selector)
  {
    self.init(labels: labelStrings.map { $0.rawValue },
              trackingMode: trackingMode,
              target: target, action: action)
  }
}

extension NSWindow
{
  var titleString: UIString
  {
    get { UIString(rawValue: title) }
    set { title = newValue.rawValue }
  }
}

extension Button where Label == Text
{
  init(_ string: UIString, role: ButtonRole? = nil, action: @escaping () -> Void)
  {
    self.init(string.rawValue, role: role, action: action)
  }
}

extension Text
{
  init(_ string: UIString)
  {
    self.init(verbatim: string.rawValue)
  }
}

extension TextField where Label == Text
{
  init(_ title: UIString,
       text: Binding<String>,
       onEditingChanged: @escaping (Bool) -> Void = { _ in },
       onCommit: @escaping () -> Void = {})
  {
    self.init(title.rawValue, text: text,
              onEditingChanged: onEditingChanged, onCommit: onCommit)
  }
}

extension View
{
  public func confirmationDialog<A>(_ title: UIString,
                                    isPresented: Binding<Bool>,
                                    titleVisibility: Visibility = .automatic,
                                    @ViewBuilder actions: () -> A)
    -> some View where A: View
  {
    confirmationDialog(title.rawValue,
                       isPresented: isPresented,
                       titleVisibility: titleVisibility,
                       actions: actions)
  }
}
