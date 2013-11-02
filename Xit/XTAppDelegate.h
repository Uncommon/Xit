#import <Foundation/Foundation.h>

@interface XTAppDelegate : NSObject<NSOpenSavePanelDelegate> {
  NSOpenPanel *_openPanel;
}

- (IBAction)openDocument:(id)sender;

@end
