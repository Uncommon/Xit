//
//  XTSideBarTableCellView.h
//  Xit
//
//  Created by David Catmull on 09/23/11.
//  Based on the SidebarDemo sample code from Apple
//

#import <Cocoa/Cocoa.h>

@interface XTSideBarTableCellView : NSTableCellView {
    @private
    NSButton *_button;
}

@property (strong) IBOutlet NSButton *button;

@end
