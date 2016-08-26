#import "XTAppDelegate.h"
#import "Xit-Swift.h"

@implementation XTAppDelegate

- (instancetype)init
{
  self = [super init];
  if (self) {
#if DEBUG
    [[NSUserDefaults standardUserDefaults] registerDefaults:
        @{ @"WebKitDeveloperExtras": @( YES ) }];
#endif
  }

  return self;
}

- (void)applicationDidFinishLaunching:(NSNotification*)note
{
  if ([NSBundle bundleWithIdentifier:@"com.uncommonplace.XitTests"] == nil)
    [XTServices.services initializeServices];
}

- (void)openDocument:(id)sender
{
  if (_openPanel != nil) {
    [_openPanel makeKeyAndOrderFront:self];
    return;
  }

  _openPanel = [NSOpenPanel openPanel];

  [_openPanel setCanChooseFiles:NO];
  [_openPanel setCanChooseDirectories:YES];
  _openPanel.delegate = self;
  
  // Add more descriptive title to open dialog box.
  _openPanel.message = @"Open a directory that contains a Git repository";
  
  [_openPanel beginWithCompletionHandler:^(NSInteger result) {
    if (result == NSFileHandlingPanelOKButton) {
      for (NSURL *url in _openPanel.URLs) {
        [[NSDocumentController sharedDocumentController]
            openDocumentWithContentsOfURL:url
                                  display:YES
                        completionHandler:^(NSDocument *doc,BOOL open, NSError *error) {}];
      }
    }
    _openPanel = nil;
  }];
}

- (BOOL)applicationOpenUntitledFile:(NSApplication *)app
{
  [self openDocument:nil];
  // Returning YES prevents the app from opening an untitled document on its
  // own.
  return YES;
}

- (BOOL)panel:(id)sender validateURL:(NSURL*)url error:(NSError**)outError
{
  NSURL *repoURL = [url URLByAppendingPathComponent:@".git" isDirectory:YES];

  if ([[NSFileManager defaultManager] fileExistsAtPath:repoURL.path])
    return YES;
  else {
    NSAlert *alert = [[NSAlert alloc] init];
    
    alert.messageText = @"That folder does not contain a Git repository.";
    
    [alert beginSheetModalForWindow:sender
                  completionHandler:NULL];
    return NO;
  }
}

- (IBAction)showPreferences:(id)sender
{
  [XTPrefsWindowController.sharedPrefsController.window makeKeyAndOrderFront:nil];
}

- (XTWindowController*)activeWindowController
{
  NSWindowController *controller = NSApp.mainWindow.windowController;
  
  if ([controller isKindOfClass:[XTWindowController class]])
    return (XTWindowController*)controller;
  return nil;
}

- (void)menuNeedsUpdate:(NSMenu*)menu
{
  if (menu == self.remoteSettingsSubmenu)
    [[self activeWindowController] updateRemotesMenu:menu];
}

@end
