//
//  PBGitRevisionCell.m
//  GitX
//
//  Created by Pieter de Bie on 17-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBGitRevisionCell.h"

@implementation PBGitRevisionCell


- (id)initWithCoder:(id)coder {
    self = [super initWithCoder:coder];
    textCell = [[NSTextFieldCell alloc] initWithCoder:coder];
    return self;
}

+ (NSArray *)laneColors {
    static NSArray *laneColors = nil;

    if (!laneColors)
        laneColors = [NSArray arrayWithObjects:
                      [NSColor colorWithCalibratedRed:0X4e / 256.0 green:0X9A / 256.0 blue:0X06 / 256.0 alpha:1.0],
                      [NSColor colorWithCalibratedRed:0X20 / 256.0 green:0X4A / 256.0 blue:0X87 / 256.0 alpha:1.0],
                      [NSColor colorWithCalibratedRed:0XC4 / 256.0 green:0XA0 / 256.0 blue:0 alpha:1.0],
                      [NSColor colorWithCalibratedRed:0X5C / 256.0 green:0X35 / 256.0 blue:0X66 / 256.0 alpha:1.0],
                      [NSColor colorWithCalibratedRed:0XA4 / 256.0 green:0X00 / 256.0 blue:0X00 / 256.0 alpha:1.0],
                      [NSColor colorWithCalibratedRed:0XCE / 256.0 green:0X5C / 256.0 blue:0 alpha:1.0],
                      nil];

    return laneColors;
}

- (void)drawLineFromColumn:(size_t)from toColumn:(size_t)to inRect:(NSRect)r offset:(CGFloat)offset color:(int)c {

    int columnWidth = 10;
    NSPoint origin = r.origin;

    NSPoint source = NSMakePoint(origin.x + columnWidth * from, origin.y + offset);
    NSPoint center = NSMakePoint(origin.x + columnWidth * to, origin.y + r.size.height * 0.5 + 0.5);

    NSArray *laneColors = [PBGitRevisionCell laneColors];
    NSColor *color = [laneColors objectAtIndex:c % [laneColors count]];

    [color set];

    NSBezierPath *path = [NSBezierPath bezierPath];
    [path setLineWidth:2];

    [path moveToPoint:source];
    [path lineToPoint:center];
    [path stroke];

}

- (BOOL)isCurrentCommit {
    return NO;
}

- (void)drawCircleInRect:(NSRect)r {

    size_t c = cellInfo.position;
    int columnWidth = 10;
    NSPoint origin = r.origin;
    NSPoint columnOrigin = { origin.x + columnWidth * c, origin.y };

    NSRect oval = { columnOrigin.x - 5, columnOrigin.y + r.size.height * 0.5 - 5, 10, 10 };


    NSBezierPath *path = [NSBezierPath bezierPathWithOvalInRect:oval];

    [[NSColor blackColor] set];
    [path fill];

    NSRect smallOval = { columnOrigin.x - 3, columnOrigin.y + r.size.height * 0.5 - 3, 6, 6 };

    if ( [self isCurrentCommit ] ) {
        [[NSColor colorWithCalibratedRed:0Xfc / 256.0 green:0Xa6 / 256.0 blue:0X4f / 256.0 alpha:1.0] set];
    } else {
        [[NSColor whiteColor] set];
    }

    path = [NSBezierPath bezierPathWithOvalInRect:smallOval];
    [path fill];
}

- (void)drawTriangleInRect:(NSRect)r sign:(char)sign {
    size_t c = cellInfo.position;
    int columnHeight = 10;
    int columnWidth = 8;

    NSPoint top;

    if (sign == '<')
        top.x = round(r.origin.x) + 10 * c + 4;
    else {
        top.x = round(r.origin.x) + 10 * c - 4;
        columnWidth *= -1;
    }
    top.y = r.origin.y + (r.size.height - columnHeight) / 2;

    NSBezierPath *path = [NSBezierPath bezierPath];
    // Start at top
    [path moveToPoint:NSMakePoint(top.x, top.y)];
    // Go down
    [path lineToPoint:NSMakePoint(top.x, top.y + columnHeight)];
    // Go left top
    [path lineToPoint:NSMakePoint(top.x - columnWidth, top.y + columnHeight / 2)];
    // Go to top again
    [path closePath];

    [[NSColor whiteColor] set];
    [path fill];
    [[NSColor blackColor] set];
    [path setLineWidth:2];
    [path stroke];
}

- (NSMutableDictionary *)attributesForRefLabelSelected:(BOOL)selected {
    NSMutableDictionary *attributes = [[[NSMutableDictionary alloc] initWithCapacity:2] autorelease];
    NSMutableParagraphStyle *style = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];

    [style setAlignment:NSCenterTextAlignment];
    [attributes setObject:style forKey:NSParagraphStyleAttributeName];
    [attributes setObject:[NSFont fontWithName:@"Helvetica" size:9] forKey:NSFontAttributeName];

    // if (selected)
    //	[attributes setObject:[NSColor alternateSelectedControlTextColor] forKey:NSForegroundColorAttributeName];

    return attributes;
}

- (void)drawWithFrame:(NSRect)rect inView:(NSView *)view {
    cellInfo = ((XTHistoryItem *)self.objectValue).lineInfo;

    if (cellInfo) {
        size_t pathWidth = 10 + 10 * cellInfo.numColumns;

        NSRect ownRect;
        NSDivideRect(rect, &ownRect, &rect, pathWidth, NSMinXEdge);

        int i;
        struct PBGitGraphLine *lines = cellInfo.lines;
        for (i = 0; i < cellInfo.nLines; i++) {
            if (lines[i].upper == 0)
                [self drawLineFromColumn:lines[i].from toColumn:lines[i].to inRect:ownRect offset:ownRect.size.height color:lines[i].colorIndex];
            else
                [self drawLineFromColumn:lines[i].from toColumn:lines[i].to inRect:ownRect offset:0 color:lines[i].colorIndex];
        }

        [self drawCircleInRect:ownRect];
    }

    // Still use this superclass because of hilighting differences
    // _contents = [self.objectValue subject];
    // [super drawWithFrame:rect inView:view];
    [textCell setObjectValue:[self.objectValue subject]];
    [textCell setHighlighted:[self isHighlighted]];
    [textCell drawWithFrame:rect inView:view];
}

// - (void) setObjectValue: (XTHistoryItem*)object {
//	[super setObjectValue:[NSValue valueWithNonretainedObject:object]];
// }
//
// - (XTHistoryItem *) objectValue {
//    return [[super objectValue] nonretainedObjectValue];
// }

- (NSRect)rectAtIndex:(int)index {
    cellInfo = [self.objectValue lineInfo];
    CGFloat pathWidth = 0;
    if (cellInfo)
        pathWidth = 10 + 10 * cellInfo.numColumns;
    NSRect refRect = NSMakeRect(pathWidth, 0, 1000, 10000);
    return refRect;
}

@end
