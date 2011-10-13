//
//  XTTrakingTableView.h
//  Xit
//
//  Created by German Laullon Padilla on 12/10/11.
//

#import <AppKit/AppKit.h>

@interface XTTrackingTableView : NSTableView
{
    NSTrackingRectTag trackingTag;
    BOOL mouseOverView;
    NSInteger mouseOverRow;
    NSInteger lastOverRow;
}
@end
