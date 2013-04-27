#import <Foundation/Foundation.h>

@interface XTAppDelegate : NSObject<NSOpenSavePanelDelegate> {
    NSOpenPanel *openPanel;
}

- (IBAction)openDocument:(id)sender;

@end
