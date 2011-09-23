//
//  SidebarTableCellView.h
//  Xit
//
//  Created by David Catmull on 09/23/11.
//  Based on the SidebarDemo sample code from Apple
//

#import <Cocoa/Cocoa.h>

@interface SidebarTableCellView : NSTableCellView {
    @private
    NSButton *_button;
}

@property (retain) IBOutlet NSButton *button;

@end
