#import "XTAppDelegate.h"

@implementation XTAppDelegate

- (id)init
{
  self = [super init];
  if (self) {
    // Initialization code here.
  }

  return self;
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
  [_openPanel setDelegate:self];
  
  // Add more descriptive title to open dialog box.
  [_openPanel setMessage:@"Open a directory that contains a Git repository"];
  
  [_openPanel beginWithCompletionHandler:^(NSInteger result) {
    if (result == NSFileHandlingPanelOKButton) {
      for (NSURL *url in [_openPanel URLs]) {
        [[NSDocumentController sharedDocumentController]
            openDocumentWithContentsOfURL:url
                                  display:YES
                        completionHandler:NULL];
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

  if ([[NSFileManager defaultManager] fileExistsAtPath:[repoURL path]])
    return YES;
  else {
    NSAlert *alert = [[NSAlert alloc] init];
    
    alert.messageText = @"That folder does not contain a Git repository.";
    
    [alert beginSheetModalForWindow:sender
                  completionHandler:NULL];
    return NO;
  }
}

@end
