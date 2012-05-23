//
//  XTAppDelegate.h
//  Xit
//
//  Created by David Catmull on 10/13/11.
//

#import <Foundation/Foundation.h>

@interface XTAppDelegate : NSObject<NSOpenSavePanelDelegate> {
    NSOpenPanel *openPanel;
}

- (IBAction)openDocument:(id)sender;

@end
