import Foundation
import Cocoa

/// Table cell view that adjusts its date format according to its width.
final class DateCellView: NSTableCellView
{
  enum StyleThreshold
  {
    static let full: CGFloat = 280
    static let long: CGFloat = 210
    static let medium: CGFloat = 170
    static let short: CGFloat = 150
  }
  
  var date: Date?
  {
    get
    { textField?.objectValue as? Date }
    set
    {
      textField?.objectValue = newValue
      updateDateStyle()
    }
  }

  override var frame: NSRect
  {
    didSet
    {
      updateDateStyle()
    }
  }
  
  override func awakeFromNib()
  {
    if let cell = textField?.cell,
       cell.formatter == nil {
      cell.formatter = DateFormatter()
      updateDateStyle()
    }
  }
  
  func updateDateStyle()
  {
    guard let textField = self.textField,
          let formatter = textField.cell?.formatter as? DateFormatter,
          let date = self.date
    else { return }
    var dateStyle = DateFormatter.Style.short
    var timeStyle = DateFormatter.Style.short
    
    switch bounds.size.width {
      case 0..<StyleThreshold.short:
        timeStyle = .none
      case StyleThreshold.short..<StyleThreshold.medium:
        dateStyle = .short
      case StyleThreshold.medium..<StyleThreshold.long:
        dateStyle = .medium
      case StyleThreshold.long..<StyleThreshold.full:
        dateStyle = .long
      default:
        dateStyle = .full
    }
    formatter.dateStyle = dateStyle
    formatter.timeStyle = timeStyle
    textField.stringValue = ""
    textField.objectValue = date
  }
}
