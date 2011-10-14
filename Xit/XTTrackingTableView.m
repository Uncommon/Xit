//
//  XTTrakingTableView.m
//  Xit
//
//  Created by German Laullon Padilla on 12/10/11.
//
// http://www.cocoadev.com/index.pl?NSTableViewRollover
//
// TODO: rewirte to call a delegate method only when the mouseOverRow change... remove setNeedsDisplayInRect

#import "XTTrackingTableView.h"
#import "XTTrackingTableDelegate.h"

@interface XTTrackingTableView (hidden)

- (void)updateMouseOverRow;

@end

@implementation XTTrackingTableView

@synthesize mouseOverRow;

- (void)awakeFromNib {
    mouseOverRow = -1;
    lastOverRow = -1;
}

- (void)dealloc {
    [self removeTrackingRect:trackingTag];
    [super dealloc];
}

- (void)mouseEntered:(NSEvent *)theEvent {
    [[self window] setAcceptsMouseMovedEvents:YES];
    [[self window] makeFirstResponder:self];
}

- (void)mouseMoved:(NSEvent *)theEvent {
    mouseLocation = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    [self updateMouseOverRow];
}

- (void)mouseExited:(NSEvent *)theEvent {
    [[self window] setAcceptsMouseMovedEvents:NO];
    [self setNeedsDisplayInRect:[self rectOfRow:mouseOverRow]];
    mouseOverRow = -1;
    lastOverRow = -1;
    id myDelegate = [self delegate];
    if ([myDelegate conformsToProtocol:@protocol(XTTrackingTableDelegate)]) {
        [myDelegate tableView:self mouseOverRow:mouseOverRow];
        [[self window] makeFirstResponder:self];
    }
}

- (NSRect)adjustScroll:(NSRect)proposedVisibleRect {
    [self removeTrackingRect:trackingTag];
    trackingTag = [self addTrackingRect:proposedVisibleRect owner:self userData:nil assumeInside:NO];
    mouseLocation = [self convertPoint:[self.window mouseLocationOutsideOfEventStream] fromView:nil];
    [self updateMouseOverRow];
    return proposedVisibleRect;
}

- (void)viewDidEndLiveResize {
    [super viewDidEndLiveResize];

    trackingTag = [self addTrackingRect:[self frame] owner:self userData:nil assumeInside:NO];
}

- (void)updateMouseOverRow {
    mouseOverRow = [self rowAtPoint:mouseLocation];
    if (lastOverRow != mouseOverRow) {
        [self setNeedsDisplayInRect:[self rectOfRow:lastOverRow]];
        lastOverRow = mouseOverRow;
        id myDelegate = [self delegate];
        if ([myDelegate conformsToProtocol:@protocol(XTTrackingTableDelegate)]) {
            [myDelegate tableView:self mouseOverRow:mouseOverRow];
            [[self window] makeFirstResponder:self];
        }
        [self setNeedsDisplayInRect:[self rectOfRow:mouseOverRow]];
    }
}


@end
