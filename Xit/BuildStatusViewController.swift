import Cocoa

class BuildStatusViewController: NSViewController
{
  let branch: String
  let buildStatusCache: BuildStatusCache

  init(branch: String, cache: BuildStatusCache)
  {
    self.branch = branch
    self.buildStatusCache = cache
  
    super.init(nibName: "BuildStatusViewController", bundle: nil)!
    cache.add(client: self)
  }
  
  required init?(coder: NSCoder)
  {
    fatalError("init(coder:) has not been implemented")
  }
  
  deinit
  {
    buildStatusCache.remove(client: self)
  }

  func configure(remoteURL: String, branchName: String)
  {
    guard let (api, buildTypes) = TeamCityAPI.service(for: remoteURL)
    else {
      // clear the display
      return
    }
    
    
  }

  override func viewDidLoad()
  {
    super.viewDidLoad()
    // Do view setup here.
  }
}

extension BuildStatusViewController: BuildStatusClient
{
  func buildStatusUpdated(branch: String, buildType: String)
  {
    // refresh
  }
}
