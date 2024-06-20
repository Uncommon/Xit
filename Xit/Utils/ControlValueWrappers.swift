import Cocoa

@propertyWrapper @MainActor
struct ControlStringValue
{
  var control: NSControl!
  
  var wrappedValue: String
  {
    get { control.stringValue }
    set { control.stringValue = newValue }
  }
  
  var projectedValue: NSControl?
  {
    get { control }
    set { control = newValue }
  }
}

@propertyWrapper @MainActor
struct ControlURLValue
{
  var control: NSControl!
  
  var wrappedValue: URL?
  {
    get { URL(string: control.stringValue) }
    set { control.stringValue = newValue?.absoluteString ?? "" }
  }
  
  var projectedValue: NSControl?
  {
    get { control }
    set { control = newValue }
  }
}

@propertyWrapper @MainActor
struct ControlBoolValue
{
  var control: NSControl!

  var wrappedValue: Bool
  {
    get { control.boolValue }
    set { control.boolValue = newValue }
  }
  
  var projectedValue: NSControl?
  {
    get { control }
    set { control = newValue }
  }
}

@propertyWrapper @MainActor
struct TextViewString
{
  var textView: NSTextView!
  
  var wrappedValue: String
  {
    get { textView.string }
    set { textView.string = newValue }
  }
  
  var projectedValue: NSTextView?
  {
    get { textView }
    set { textView = newValue }
  }
}
