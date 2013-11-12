#import "XTWebViewController.h"
#import <WebKit/WebKit.h>

// They left this one out.
const NSInteger WebMenuItemTagInspectElement = 2024;


@implementation XTWebViewController

+ (NSString*)htmlTemplate:(NSString*)name
{
  NSURL *htmlURL = [[NSBundle mainBundle]
      URLForResource:name withExtension:@"html" subdirectory:@"html"];
  NSStringEncoding encoding;
  NSError *error = nil;
  NSString *htmlTemplate = [NSString stringWithContentsOfURL:htmlURL
                                                usedEncoding:&encoding
                                                       error:&error];

  NSAssert(htmlTemplate != nil, @"Couldn't load text.html");
  return htmlTemplate;
}

+ (NSString*)escapeText:(NSString*)text
{
  return (NSString*)CFBridgingRelease(
      CFXMLCreateStringByEscapingEntities(
          kCFAllocatorDefault, (__bridge CFStringRef)text, NULL));
}

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
  NSScrollView *scrollView = [[[[_webView mainFrame] frameView]
      documentView] enclosingScrollView];

  [scrollView setHasHorizontalScroller:NO];
  [scrollView setHorizontalScrollElasticity:NSScrollElasticityNone];
  [scrollView setBackgroundColor:[NSColor colorWithDeviceWhite:0.8 alpha:1.0]];
  [[_webView windowScriptObject] setValue:self forKey:@"controller"];
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
