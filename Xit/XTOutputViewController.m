//
//  XTOutputViewController.m
//  Xit
//
//  Created by David Catmull on 10/26/11.
//

#import "XTOutputViewController.h"
#import "XTStatusView.h"

static float HeightForText(NSString *text, NSFont *font, float width);

@implementation XTOutputViewController

@synthesize popover;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Initialization code here.
    }

    return self;
}

- (NSSize)ownerSize {
    if (popover != nil)
        return popover.contentSize;
    else
        return [[[self.view window] contentView] frame].size;
}

- (void)setOwnerSize:(NSSize)size {
    if (popover != nil)
        popover.contentSize = size;
    else
        [[self.view window] setContentSize:size];
}

- (void)updateStatus:(NSNotification *)note {
    NSString *command = [[note userInfo] objectForKey:XTStatusCommandKey];
    NSString *output = [[note userInfo] objectForKey:XTStatusOutputKey];

    if (command != nil) {
        NSRect frame = [commandText frame];
        NSFont *font = [commandText font];
        const float newHeight = (font == nil) ? frame.size.height : HeightForText(command, font, frame.size.width);
        const float delta = newHeight - frame.size.height;

        [commandText setStringValue:command];
        if (delta != 0.0) {
            NSSize popoverSize = [self ownerSize];
            NSRect outputFrame = [outputScroll frame];

            frame.size.height = newHeight;
            frame.origin.y -= delta;
            [commandText setFrame:frame];
            outputFrame.size.height -= delta;
            [outputScroll setFrame:outputFrame];
            popoverSize.height += delta;
            [self setOwnerSize:popoverSize];
        }
    }
    if (output == nil)
        [outputText setString:@""];
    else {
        NSFont *fixedFont = [NSFont userFixedPitchFontOfSize:11];
        NSDictionary *attributes = [NSDictionary dictionaryWithObject:fixedFont forKey:NSFontAttributeName];

        if (![output hasSuffix:@"\n"])
            output = [output stringByAppendingString:@"\r"];
        [[outputText textStorage] appendAttributedString:[[[NSAttributedString alloc] initWithString:output attributes:attributes] autorelease]];
    }
}

@end

// Adapted from Text Layout Programming Guide sample code.
static float HeightForText(NSString *text, NSFont *font, float width) {
    NSTextStorage *storage = [[[NSTextStorage alloc] initWithString:text] autorelease];
    NSTextContainer *container = [[[NSTextContainer alloc] initWithContainerSize:NSMakeSize(width, FLT_MAX)] autorelease];
    NSLayoutManager *layout = [[[NSLayoutManager alloc] init] autorelease];

    [layout setTypesetterBehavior:NSTypesetterBehavior_10_2_WithCompatibility];
    [layout addTextContainer:container];
    [storage addLayoutManager:layout];
    [storage addAttribute:NSFontAttributeName value:font range:NSMakeRange(0, [storage length])];
    [container setLineFragmentPadding:0.0];
    [layout glyphRangeForTextContainer:container];

    const NSRect rect = [layout usedRectForTextContainer:container];

    return rect.size.height;
}
