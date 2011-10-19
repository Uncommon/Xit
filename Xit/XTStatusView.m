//
//  XTStatusView.m
//  Xit
//
//  Created by David Catmull on 10/18/11.
//

#import "XTStatusView.h"

NSString *const XTStatusNotification = @"XTStatus";
NSString *const XTStatusTextKey = @"text";

#define kCornerRadius 4

@interface XTStatusView () {
    NSGradient *fillGradient, *strokeGradient;
}
@end

@implementation XTStatusView

+ (void)notifyStatus:(NSString *)status forRepository:(XTRepository *)repo {
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:status forKey:XTStatusTextKey];

    [[NSNotificationCenter defaultCenter] postNotificationName:XTStatusNotification object:repo userInfo:userInfo];
}

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        NSColor *backgroundColor = [NSColor colorWithDeviceHue:212 / 360.0 saturation:0.06 brightness:0.8 alpha:1.0];
        NSColor *white = [NSColor whiteColor];

        fillGradient = [[NSGradient alloc] initWithColorsAndLocations:
                        backgroundColor, 0.0,
                        backgroundColor, 0.5,
                        [backgroundColor blendedColorWithFraction:0.2 ofColor:white], 0.5,
                        [backgroundColor blendedColorWithFraction:0.4 ofColor:white], 0.75,
                        [backgroundColor blendedColorWithFraction:0.3 ofColor:white], 1.0,
                        nil];
    }

    return self;
}

- (void)setRepo:(XTRepository *)newRepo {
    if (repo != nil)
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    repo = newRepo;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateStatus:) name:XTStatusNotification object:repo];
}

- (void)drawRect:(NSRect)dirtyRect {
    const NSRect bounds = [self bounds];
    const NSRect pathBounds = { bounds.origin, { bounds.size.width, bounds.size.height - 1 } };
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:pathBounds xRadius:kCornerRadius yRadius:kCornerRadius];
    NSAffineTransform *offset = [NSAffineTransform transform];

    [[NSColor colorWithDeviceWhite:1.0 alpha:0.5] set];
    [path fill];
    [offset translateXBy:0 yBy:1];
    [path transformUsingAffineTransform:offset];

    [fillGradient drawInBezierPath:path angle:90.0];

    NSRect pathFrameBounds = NSOffsetRect(pathBounds, 0.5, 1.5);

    --pathFrameBounds.size.width;
    --pathFrameBounds.size.height;

    NSBezierPath *framePath = [NSBezierPath bezierPathWithRoundedRect:pathFrameBounds xRadius:kCornerRadius yRadius:kCornerRadius];

    [[NSColor colorWithDeviceWhite:0.0 alpha:0.5] set];
    [framePath stroke];

    // TODO: inner shadow effect
}

- (void)updateStatus:(NSNotification *)note {
    [label setStringValue:[[note userInfo] objectForKey:XTStatusTextKey]];
}

@end
