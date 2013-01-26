//
//  XTSideBarTableCellView.h
//  Xit
//
//  Created by David Catmull on 09/23/11.
//  Based on the SidebarDemo sample code from Apple
//

#import <Cocoa/Cocoa.h>

@class XTSideBarItem;

@interface XTSideBarTableCellView : NSTableCellView {
    @private
    NSButton *_button;
    XTSideBarItem * __weak item;
}

@property (strong) IBOutlet NSButton *button;
@property (weak) XTSideBarItem *item;

@end
