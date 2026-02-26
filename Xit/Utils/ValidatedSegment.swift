import Cocoa

/// Represents a segment of a segmented control that can be validated.
class ValidatedSegment
{
  let segmentedControl: NSSegmentedControl
  let index: Int
  let action: Selector?
  
  init(control: NSSegmentedControl, index: Int, action: Selector)
  {
    self.segmentedControl = control
    self.index = index
    self.action = action
  }
}

extension ValidatedSegment: NSValidatedUserInterfaceItem
{
  var tag: Int
  { (segmentedControl.cell as? NSSegmentedCell)?.tag(forSegment: index) ?? 0 }
}
