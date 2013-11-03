//
//  PBGitRevisionCell.m
//  GitX
//
//  Created by Pieter de Bie on 17-06-08.
//

#import "PBGitRevisionCell.h"
#import "XTRefToken.h"
#import "XTRepository.h"
#import "XTRemoteBranchItem.h"
#import "XTSideBarItem.h"

static const int kColumnWidth = 10;

@implementation NSString (Words)

- (NSString *)firstWord
{
  NSRange spaceRange = [self rangeOfString:@" "];

  if (spaceRange.location == NSNotFound)
    return self;
  return [self substringToIndex:spaceRange.location];
}

@end

@implementation PBGitRevisionCell

- (id)initWithCoder:(id)coder
{
  self = [super initWithCoder:coder];
  _textCell = [[NSTextFieldCell alloc] initWithCoder:coder];
  [_textCell setFont:[NSFont labelFontOfSize:12]];
  return self;
}

+ (NSArray *)laneColors
{
  static NSArray *laneColors = nil;

  if (!laneColors)
    laneColors = @[ [NSColor colorWithCalibratedRed:0X4e / 256.0
                                              green:0X9A / 256.0
                                               blue:0X06 / 256.0
                                              alpha:1.0],
                    [NSColor colorWithCalibratedRed:0X20 / 256.0
                                              green:0X4A / 256.0
                                               blue:0X87 / 256.0
                                              alpha:1.0],
                    [NSColor colorWithCalibratedRed:0XC4 / 256.0
                                              green:0XA0 / 256.0
                                               blue:0
                                              alpha:1.0],
                    [NSColor colorWithCalibratedRed:0X5C / 256.0
                                              green:0X35 / 256.0
                                               blue:0X66 / 256.0
                                              alpha:1.0],
                    [NSColor colorWithCalibratedRed:0XA4 / 256.0
                                              green:0X00 / 256.0
                                               blue:0X00 / 256.0
                                              alpha:1.0],
                    [NSColor colorWithCalibratedRed:0XCE / 256.0
                                              green:0X5C / 256.0
                                               blue:0
                                              alpha:1.0] ];

  return laneColors;
}

- (void)drawLineFromColumn:(size_t)from
                  toColumn:(size_t)to
                    inRect:(NSRect)r
                    offset:(CGFloat)offset
                     color:(int)c
{

  const NSPoint origin = r.origin;

  const NSPoint source =
      NSMakePoint(origin.x + kColumnWidth * from, origin.y + offset);
  const NSPoint center = NSMakePoint(origin.x + kColumnWidth * to,
                                     origin.y + r.size.height * 0.5 + 0.5);
  const float direction = center.y > source.y ? 1.0 : -1.0;

  NSArray *laneColors = [PBGitRevisionCell laneColors];
  NSColor *color = laneColors[c % [laneColors count]];

  [color set];

  NSBezierPath *path = [NSBezierPath bezierPath];
  [path setLineWidth:2];

  [path moveToPoint:source];
  [path relativeLineToPoint:NSMakePoint(0.0, direction * 1.0)];
  [path lineToPoint:center];
  if (from != to)
    // Particularly for HiDPI, make sure corners have good bevels
    [path lineToPoint:NSMakePoint(center.x, center.y + direction * 0.5)];
  [path stroke];
}

- (BOOL)isCurrentCommit
{
  return NO;
}

- (void)drawCircleInRect:(NSRect)r
{

  const size_t c = _cellInfo.position;
  const NSPoint origin = r.origin;
  const NSPoint columnOrigin = { origin.x + kColumnWidth * c, origin.y };

  NSRect oval = { columnOrigin.x - 5, columnOrigin.y + r.size.height * 0.5 - 5,
                  10, 10 };

  NSBezierPath *path = [NSBezierPath bezierPathWithOvalInRect:oval];

  [[NSColor blackColor] set];
  [path fill];

  const NSRect smallOval = { columnOrigin.x - 3,
                             columnOrigin.y + r.size.height * 0.5 - 3,
                             6, 6 };

  if ([self isCurrentCommit]) {
    [[NSColor colorWithCalibratedRed:0Xfc / 256.0
                               green:0Xa6 / 256.0
                                blue:0X4f / 256.0
                               alpha:1.0] set];
  } else {
    [[NSColor whiteColor] set];
  }

  path = [NSBezierPath bezierPathWithOvalInRect:smallOval];
  [path fill];
}

- (NSMutableDictionary *)attributesForRefLabelSelected:(BOOL)selected
{
  NSMutableDictionary *attributes =
      [[NSMutableDictionary alloc] initWithCapacity:2];
  NSMutableParagraphStyle *style =
      [[NSParagraphStyle defaultParagraphStyle] mutableCopy];

  [style setAlignment:NSCenterTextAlignment];
  attributes[NSParagraphStyleAttributeName] = style;
  attributes[NSFontAttributeName] = [NSFont fontWithName:@"Helvetica" size:9];

  // if (selected)
  //   [attributes setObject:[NSColor alternateSelectedControlTextColor]
  //                  forKey:NSForegroundColorAttributeName];

  return attributes;
}

#define kSpaceBetweenTokens 5

- (void)drawWithFrame:(NSRect)rect inView:(NSView *)view
{
  _cellInfo = ((XTHistoryItem *)self.objectValue).lineInfo;

  if (_cellInfo) {
    const size_t pathWidth = 10 + kColumnWidth * _cellInfo.numColumns;

    NSRect ownRect;
    NSDivideRect(rect, &ownRect, &rect, pathWidth, NSMinXEdge);

    int i;
    struct PBGitGraphLine *lines = _cellInfo.lines;
    for (i = 0; i < _cellInfo.nLines; i++) {
      if (lines[i].upper == 0)
        [self drawLineFromColumn:lines[i].from
                        toColumn:lines[i].to
                          inRect:ownRect
                          offset:ownRect.size.height
                           color:lines[i].colorIndex];
      else
        [self drawLineFromColumn:lines[i].from
                        toColumn:lines[i].to
                          inRect:ownRect
                          offset:0
                           color:lines[i].colorIndex];
    }

    [self drawCircleInRect:ownRect];
  }

  XTRepository *repo = [self.objectValue repo];
  NSArray *refs = [repo refsIndex][[self.objectValue sha]];

  if ([refs count] > 0) {
    rect.origin.x += 2;
    rect.size.width -= 2;
    for (NSString *ref in refs) {
      NSArray *refPrefixes =
          @[ @"refs/heads/", @"refs/remotes/", @"refs/tags/" ];
      NSString *text = ref;

      for (NSString *prefix in refPrefixes)
        if ([ref hasPrefix:prefix])
          text = [ref substringFromIndex:[prefix length]];

      NSRect tokenRect = { rect.origin, { [XTRefToken rectWidthForText : text],
                                          rect.size.height } };
      const CGFloat rectAdjust = tokenRect.size.width + kSpaceBetweenTokens;

      [XTRefToken
          drawTokenForRefType:[XTRefToken typeForRefName:ref inRepository:repo]
                         text:text
                         rect:tokenRect];
      rect.origin.x += rectAdjust;
      rect.size.width -= rectAdjust;
    }
  }

  [_textCell setObjectValue:[self.objectValue subject]];
  [_textCell setHighlighted:[self isHighlighted]];
  [_textCell drawWithFrame:rect inView:view];
}

- (NSRect)rectAtIndex:(int)index
{
  _cellInfo = [self.objectValue lineInfo];
  CGFloat pathWidth = 0;
  if (_cellInfo)
    pathWidth = 10 + kColumnWidth * _cellInfo.numColumns;
  NSRect refRect = NSMakeRect(pathWidth, 0, 1000, 10000);
  return refRect;
}

@end
