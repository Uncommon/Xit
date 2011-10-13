//
//  XTTrakingTableView.m
//  Xit
//
//  Created by German Laullon Padilla on 12/10/11.
//
// http://www.cocoadev.com/index.pl?NSTableViewRollover
//
// TODO: rewirte to call a delegate method only when the mouseOverRow change... remove setNeedsDisplayInRect

#import "XTTrakingTableView.h"

@implementation XTTrakingTableView

- (void)awakeFromNib {
    [[self window] setAcceptsMouseMovedEvents:YES];
    trackingTag = [self addTrackingRect:[self frame] owner:self userData:nil assumeInside:NO];
    mouseOverView = NO;
    mouseOverRow = -1;
    lastOverRow = -1;
}

- (void)dealloc {
    [self removeTrackingRect:trackingTag];
    [super dealloc];
}

- (void)mouseEntered:(NSEvent *)theEvent {
    mouseOverView = YES;
}

- (void)mouseMoved:(NSEvent *)theEvent {
    id myDelegate = [self delegate];

    if (!myDelegate)
        return;         // No delegate, no need to track the mouse.
    if (![myDelegate respondsToSelector:@selector(tableView:willDisplayCell:forTableColumn:row:)])
        return;         // If the delegate doesn't modify the drawing, don't track.

    if (mouseOverView) {
        mouseOverRow = [self rowAtPoint:[self convertPoint:[theEvent locationInWindow] fromView:nil]];

        if (lastOverRow == mouseOverRow)
            return;
        else {
            [self setNeedsDisplayInRect:[self rectOfRow:lastOverRow]];
            lastOverRow = mouseOverRow;
        }

        [self setNeedsDisplayInRect:[self rectOfRow:mouseOverRow]];
    }
}

- (void)mouseExited:(NSEvent *)theEvent {
    mouseOverView = NO;
    [self setNeedsDisplayInRect:[self rectOfRow:mouseOverRow]];
    mouseOverRow = -1;
    lastOverRow = -1;
}

- (NSInteger)mouseOverRow {
    return mouseOverRow;
}

- (void)viewDidEndLiveResize {
    [super viewDidEndLiveResize];

    [self removeTrackingRect:trackingTag];
    trackingTag = [self addTrackingRect:[self frame] owner:self userData:nil assumeInside:NO];
}

@end
