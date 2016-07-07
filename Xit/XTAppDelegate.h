#import <Foundation/Foundation.h>

@interface XTAppDelegate : NSObject<NSOpenSavePanelDelegate> {
  NSOpenPanel *_openPanel;
}

@property (weak) IBOutlet NSMenu *remoteSettingsSubmenu;

- (IBAction)openDocument:(id)sender;

@end
