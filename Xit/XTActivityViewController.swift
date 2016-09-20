import Cocoa

public class XTActivityViewController: NSTitlebarAccessoryViewController
{
  var activityCount: UInt = 0
  
  @IBOutlet var spinner: NSProgressIndicator!
  
  open override func awakeFromNib()
  {
    layoutAttribute = .right
    spinner.isHidden = true
  }
  
  func forceMainThread(_ block: ()->())
  {
    let mainQueue = DispatchQueue.main
    
    if Thread.isMainThread {
      block()
    }
    else {
      mainQueue.sync(execute: block)
    }
  }
  
  func activityStarted()
  {
    forceMainThread() {
      self.activityCount += 1
      self.spinner.isHidden = false
      self.spinner.startAnimation(self)
    }
  }
  
  func activityEnded()
  {
    forceMainThread() {
      guard self.activityCount > 0
      else { return }
      
      self.activityCount -= 1
      if self.activityCount == 0 {
        self.spinner.stopAnimation(self)
        self.spinner.isHidden = true
      }
    }
  }
}
