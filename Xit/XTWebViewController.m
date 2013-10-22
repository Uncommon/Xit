#import "XTWebViewController.h"
#import <WebKit/WebKit.h>

// They left this one out.
const NSInteger WebMenuItemTagInspectElement = 2024;


@implementation XTWebViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)webView:(WebView*)sender didFinishLoadForFrame:(WebFrame*)frame
{
  [[self.webView windowScriptObject] setValue:self forKey:@"controller"];
}

- (NSUInteger)webView:(WebView*)sender
dragDestinationActionMaskForDraggingInfo:(id <NSDraggingInfo>)draggingInfo
{
  return WebDragDestinationActionNone;
}

- (NSArray*)webView:(WebView*)sender
contextMenuItemsForElement:(NSDictionary*)element
          defaultMenuItems:(NSArray*)defaultMenuItems
{
  // Exclude navigation, reload, download, etc.
  NSInteger allowedTags[] = {
      WebMenuItemTagCopy,
      WebMenuItemTagCut,
      WebMenuItemTagPaste,
      WebMenuItemTagOther,
      WebMenuItemTagSearchInSpotlight,
      WebMenuItemTagSearchWeb,
      WebMenuItemTagLookUpInDictionary,
      WebMenuItemTagOpenWithDefaultApplication,
      WebMenuItemTagInspectElement,
      };
  const unsigned int kAllowedCount = sizeof(allowedTags)/sizeof(NSInteger);
  NSMutableArray *allowedItems =
      [NSMutableArray arrayWithCapacity:[defaultMenuItems count]];

  for (NSMenuItem *item in defaultMenuItems) {
    for (int i = 0; i < kAllowedCount; ++i)
      if (allowedTags[i] == [item tag]) {
        [allowedItems addObject:item];
        break;
      }
  }
  return allowedItems;
}

@end
