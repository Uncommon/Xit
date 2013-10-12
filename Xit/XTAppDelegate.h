#import <Foundation/Foundation.h>

#import <Cocoa/Cocoa.h>
@interface XTAppDelegate : NSObject<NSOpenSavePanelDelegate> {
  NSOpenPanel *openPanel;
}

- (IBAction)openDocument:(id)sender;

@end
