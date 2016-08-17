import Cocoa

public class XTActivityViewController: NSTitlebarAccessoryViewController {

  var activityCount: UInt = 0
  
  @IBOutlet var spinner: NSProgressIndicator!
  
  public override func awakeFromNib()
  {
    layoutAttribute = .Right
    spinner.hidden = true
  }
  
  func activityStarted()
  {
    activityCount += 1
    spinner.hidden = false
    spinner.startAnimation(self)
  }
  
  func activityEnded()
  {
    guard activityCount > 0
    else { return }
    
    activityCount -= 1
    if activityCount == 0 {
      spinner.stopAnimation(self)
      spinner.hidden = true
    }
  }
}
