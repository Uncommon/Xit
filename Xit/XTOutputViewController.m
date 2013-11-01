#import "XTOutputViewController.h"
#import "XTStatusView.h"

static float HeightForText(NSString *text, NSFont *font, float width);

@implementation XTOutputViewController


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if (self) {
    // Initialization code here.
  }

  return self;
}

- (NSSize)ownerSize
{
  if (_popover != nil)
    return _popover.contentSize;
  else
    return [[[self.view window] contentView] frame].size;
}

- (void)setOwnerSize:(NSSize)size
{
  if (_popover != nil)
    _popover.contentSize = size;
  else
    [[self.view window] setContentSize:size];
}

- (void)updateStatus:(NSNotification *)note
{
  NSString *command = [note userInfo][XTStatusCommandKey];
  NSString *output = [note userInfo][XTStatusOutputKey];

  if (command != nil) {
    NSRect frame = [_commandText frame];
    NSFont *font = [_commandText font];
    const float newHeight =
        (font == nil) ? frame.size.height
                      : HeightForText(command, font, frame.size.width);
    const float delta = newHeight - frame.size.height;

    [_commandText setStringValue:command];
    if (delta != 0.0) {
      NSSize popoverSize = [self ownerSize];
      NSRect outputFrame = [_outputScroll frame];

      frame.size.height = newHeight;
      frame.origin.y -= delta;
      [_commandText setFrame:frame];
      outputFrame.size.height -= delta;
      [_outputScroll setFrame:outputFrame];
      popoverSize.height += delta;
      [self setOwnerSize:popoverSize];
    }
  }
  if (output == nil)
    [_outputText setString:@""];
  else {
    NSFont *fixedFont = [NSFont userFixedPitchFontOfSize:11];
    NSDictionary *attributes = @{ NSFontAttributeName : fixedFont };

    if (![output hasSuffix:@"\n"])
      output = [output stringByAppendingString:@"\r"];
    [[_outputText textStorage] appendAttributedString:
        [[NSAttributedString alloc] initWithString:output
                                        attributes:attributes]];
  }
}

@end

// Adapted from Text Layout Programming Guide sample code.
static float HeightForText(NSString *text, NSFont *font, float width)
{
  NSTextStorage *storage = [[NSTextStorage alloc] initWithString:text];
  NSTextContainer *container = [[NSTextContainer alloc]
      initWithContainerSize:NSMakeSize(width, FLT_MAX)];
  NSLayoutManager *layout = [[NSLayoutManager alloc] init];

  [layout setTypesetterBehavior:NSTypesetterBehavior_10_2_WithCompatibility];
  [layout addTextContainer:container];
  [storage addLayoutManager:layout];
  [storage addAttribute:NSFontAttributeName
                  value:font
                  range:NSMakeRange(0, [storage length])];
  [container setLineFragmentPadding:0.0];
  [layout glyphRangeForTextContainer:container];

  const NSRect rect = [layout usedRectForTextContainer:container];

  return rect.size.height;
}
