//
//  XTStatusView.m
//  Xit
//
//  Created by David Catmull on 10/18/11.
//

#import "XTStatusView.h"
#import "XTOutputViewController.h"

NSString *const XTStatusNotification = @"XTStatus";
NSString *const XTStatusTextKey = @"text";
NSString *const XTStatusCommandKey = @"command";
NSString *const XTStatusOutputKey = @"output";

#define kCornerRadius 4

@implementation XTStatusView

+ (void)updateStatus:(NSString *)status command:(NSString *)command output:(NSString *)output forRepository:(XTRepository *)repo {
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];

    assert(repo != nil);
    if (status != nil)
        [userInfo setObject:status forKey:XTStatusTextKey];
    if (command != nil)
        [userInfo setObject:command forKey:XTStatusCommandKey];
    if (output != nil)
        [userInfo setObject:output forKey:XTStatusOutputKey];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:XTStatusNotification object:repo userInfo:userInfo];
    });
}

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        NSColor *backgroundColor = [NSColor colorWithDeviceHue:212 / 360.0 saturation:0.06 brightness:0.8 alpha:1.0];
        NSColor *white = [NSColor whiteColor];

        fillGradient = [[NSGradient alloc] initWithColorsAndLocations:
                        backgroundColor, 0.0,
                        backgroundColor, 0.5,
                        [backgroundColor blendedColorWithFraction:0.2 ofColor:white], 0.5,
                        [backgroundColor blendedColorWithFraction:0.4 ofColor:white], 0.75,
                        [backgroundColor blendedColorWithFraction:0.3 ofColor:white], 1.0,
                        nil];
        strokeGradient = [[NSGradient alloc] initWithColorsAndLocations:
                          [NSColor colorWithDeviceWhite:0.0 alpha:0.43], 0.0,
                          [NSColor colorWithDeviceWhite:0.0 alpha:0.62], 1.0,
                          nil];
    }

    return self;
}

- (void)awakeFromNib {
    detachedWindow.title = [NSString stringWithFormat:detachedWindow.title, self.window.title];
    [detachedWindow setContentSize:[detachedController.view bounds].size];
    detachedWindow.contentView = detachedController.view;
    [outputController view];  // make sure the view is loaded
}

- (void)setRepo:(XTRepository *)newRepo {
    if (repo != nil)
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    repo = newRepo;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateStatus:) name:XTStatusNotification object:repo];
    [[NSNotificationCenter defaultCenter] addObserver:detachedController selector:@selector(updateStatus:) name:XTStatusNotification object:repo];
    [[NSNotificationCenter defaultCenter] addObserver:outputController selector:@selector(updateStatus:) name:XTStatusNotification object:repo];
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

    NSRect pathFrameBounds = NSOffsetRect(pathBounds, 0, 1);

    --pathFrameBounds.size.height;

    NSBezierPath *framePath = [NSBezierPath bezierPathWithRoundedRect:pathFrameBounds xRadius:kCornerRadius yRadius:kCornerRadius];

    [framePath appendBezierPathWithRoundedRect:NSInsetRect(pathFrameBounds, 1, 1) xRadius:kCornerRadius - 1 yRadius:kCornerRadius - 1];
    [framePath setWindingRule:NSEvenOddWindingRule];
    [strokeGradient drawInBezierPath:framePath angle:90.0];

    // TODO: inner shadow effect
}

- (void)updateStatus:(NSNotification *)note {
    NSString *status = [[note userInfo] objectForKey:XTStatusTextKey];

    if (status != nil)
        [label setStringValue:status];
}

- (IBAction)showOutput:(id)sender {
    [popover showRelativeToRect:NSZeroRect ofView:sender preferredEdge:NSMaxYEdge];
}

@end

@implementation XTStatusView (NSPopoverDelegate)

- (NSWindow *)detachableWindowForPopover:(NSPopover *)pop {
    [detachedWindow setContentSize:[pop contentSize]];
    return detachedWindow;
}

@end
