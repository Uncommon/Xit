#import "XTRefToken.h"
#import "XTRepository+Commands.h"

@implementation XTRefToken

+ (NSGradient *)gradientWithHue:(CGFloat)hue
                     saturation:(CGFloat)saturation
                         active:(BOOL)active
{
  const CGFloat startBrightness = active ? 0.75 : 1.0;
  const CGFloat endBrightness = active ? 0.6 : 0.8;
  NSColor *startColor = [NSColor colorWithDeviceHue:hue / 360.0
                                         saturation:saturation / 100.0
                                         brightness:startBrightness
                                              alpha:1.0];
  NSColor *endColor = [NSColor colorWithDeviceHue:hue / 360.0
                                       saturation:saturation / 100.0
                                       brightness:endBrightness
                                            alpha:1.0];

  return [[NSGradient alloc] initWithStartingColor:startColor
                                       endingColor:endColor];
}

+ (NSGradient *)gradientForType:(XTRefType)refType
{
  switch (refType) {
    case XTRefTypeBranch:
      return [self gradientWithHue:100 saturation:60 active:NO];

    case XTRefTypeActiveBranch:
      return [self gradientWithHue:100 saturation:85 active:YES];

    case XTRefTypeRemoteBranch:
      return [self gradientWithHue:150 saturation:15 active:NO];

    case XTRefTypeTag:
      return [self gradientWithHue:42 saturation:30 active:NO];

    default:
      return [self gradientWithHue:0 saturation:0 active:NO];
  }
  return nil;
}

+ (NSBezierPath *)pathForType:(XTRefType)refType rect:(NSRect)rect
{
  // Inset because the stroke will be centered on the path border
  rect = NSInsetRect(rect, 0.5, 1.5);
  ++rect.origin.y;
  --rect.size.height;

  switch (refType) {
    case XTRefTypeBranch:
    case XTRefTypeActiveBranch: {
      const CGFloat radius = rect.size.height / 2;

      return [NSBezierPath bezierPathWithRoundedRect:rect
                                             xRadius:radius
                                             yRadius:radius];
    }

    case XTRefTypeTag: {
      NSBezierPath *path = [NSBezierPath bezierPath];
      const int kCornerInset = 5;
      const CGFloat top = rect.origin.y;
      const CGFloat left = rect.origin.x;
      const CGFloat bottom = top + rect.size.height;
      const CGFloat right = left + rect.size.width;
      const CGFloat leftInset = left + kCornerInset;
      const CGFloat rightInset = right - kCornerInset;
      const CGFloat middle = top + rect.size.height / 2;

      [path moveToPoint:NSMakePoint(leftInset, top)];
      [path lineToPoint:NSMakePoint(rightInset, top)];
      [path lineToPoint:NSMakePoint(right, middle)];
      [path lineToPoint:NSMakePoint(rightInset, bottom)];
      [path lineToPoint:NSMakePoint(leftInset, bottom)];
      [path lineToPoint:NSMakePoint(left, middle)];
      [path closePath];
      return path;
    }

    default:
      return [NSBezierPath bezierPathWithRect:rect];
  }
  return nil;
}

+ (NSColor *)strokeColorForType:(XTRefType)type
{
  CGFloat hue = 0.0;
  CGFloat saturation = 74.0;

  switch (type) {
    case XTRefTypeBranch:
    case XTRefTypeActiveBranch:
      hue = 100.0;
      break;

    case XTRefTypeRemoteBranch:
      hue = 150.0;
      break;

    case XTRefTypeTag:
      hue = 40.0;
      break;

    default:
      saturation = 0.0;
      break;
  }
  return [NSColor colorWithDeviceHue:hue /
          360.0 saturation:saturation / 100.0 brightness:0.55 alpha:1];
}

+ (NSFont *)labelFont
{
  return [NSFont fontWithName:@"Helvetica" size:11];
}

+ (void)drawTokenForRefType:(XTRefType)type
                       text:(NSString *)text
                       rect:(NSRect)rect
{
  NSBezierPath *path = [self pathForType:type rect:rect];
  NSGradient *gradient = [self gradientForType:type];
  NSAffineTransform *transform = [NSAffineTransform transform];

  [gradient drawInBezierPath:path angle:270];
  [NSGraphicsContext saveGraphicsState];
  [path addClip];
  [transform translateXBy:0.0 yBy:-1.0];
  [transform concat];
  [[NSColor colorWithDeviceWhite:1.0 alpha:0.4] set];
  [path stroke];
  [NSGraphicsContext restoreGraphicsState];

  NSColor *fgColor = (type == XTRefTypeActiveBranch) ? [NSColor whiteColor]
                                                     : [NSColor blackColor];
  NSShadow *shadow = [[NSShadow alloc] init];
  NSMutableParagraphStyle *paragraphStyle =
      [[NSParagraphStyle defaultParagraphStyle] mutableCopy];

  shadow.shadowBlurRadius = 1.0;
  shadow.shadowOffset = NSMakeSize(0, -1);
  shadow.shadowColor = (type == XTRefTypeActiveBranch)
      ? [NSColor blackColor]
      : [NSColor whiteColor];
  paragraphStyle.alignment = NSTextAlignmentCenter;

  NSDictionary *attributes = @{ NSFontAttributeName:[self labelFont],
                                NSParagraphStyleAttributeName:paragraphStyle,
                                NSForegroundColorAttributeName:fgColor,
                                NSShadowAttributeName:shadow };
  NSMutableAttributedString *attrText =
  [[NSMutableAttributedString alloc] initWithString:text
                                         attributes:attributes];
  const NSRange slashRange = [text rangeOfString:@"/"
                                         options:NSBackwardsSearch];

  if (slashRange.location != NSNotFound)
    [attrText addAttribute:NSForegroundColorAttributeName
                     value:[NSColor colorWithDeviceWhite:0.0 alpha:0.6]
                     range:NSMakeRange(0, slashRange.location + 1)];
  [attrText drawInRect:rect];

  [[self strokeColorForType:type] set];
  [path stroke];
}

+ (CGFloat)rectWidthForText:(NSString *)text
{
  NSDictionary *attributes = @{NSFontAttributeName : [self labelFont]};
  const NSSize size = [text sizeWithAttributes:attributes];

  return size.width + 12;
}

@end
