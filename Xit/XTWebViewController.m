#import "XTWebViewController.h"
#import "Xit-Swift.h"
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

+ (NSURL*)baseURL
{
  return [[NSBundle mainBundle] URLForResource:@"html" withExtension:nil];
}

+ (NSString*)escapeText:(NSString*)text
{
  return (NSString*)CFBridgingRelease(
      CFXMLCreateStringByEscapingEntities(
          kCFAllocatorDefault, (__bridge CFStringRef)text, NULL));
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)awakeFromNib
{
  // Notification name is in Swift Notification.Name
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(fontChanged:)
                                               name:@"XTFontChanged"
                                             object:nil];
}

- (void)fontChanged:(NSNotification*)note
{
  [self updateFont];
}

- (NSUInteger)tabWidth
{
  DOMCSSStyleDeclaration *style = self.webView.mainFrameDocument.body.style;
  NSString *tabSizeString = [style getPropertyValue:@"tab-size"];
  
  return (tabSizeString.length == 0) ? 4 : [tabSizeString integerValue];
}

- (void)setTabWidth:(NSUInteger)tabWidth
{
  DOMCSSStyleDeclaration *style = self.webView.mainFrameDocument.body.style;

  [style setProperty:@"tab-size"
               value:[NSString stringWithFormat:@"%lu", tabWidth]
            priority:@"important"];
  self.savedTabWidth = tabWidth;
}

- (void)setDefaultTabWidth
{
  NSUInteger defaultWidth = [[NSUserDefaults standardUserDefaults]
                             integerForKey:@"tabWidth"];
  
  if (defaultWidth == 0)
    defaultWidth = 4;
  self.tabWidth = defaultWidth;
}

- (void)loadNotice:(NSString*)text
{
  NSString *template = [[self class] htmlTemplate:@"notice"];
  NSString *escapedText = [[self class] escapeText:text];
  NSString *html = [NSString stringWithFormat:template, escapedText];
  
  [_webView.mainFrame loadHTMLString:html baseURL:[[self class] baseURL]];
}

- (id)webActionDelegate
{
  return nil;
}

- (void)webView:(WebView*)sender didFinishLoadForFrame:(WebFrame*)frame
{
  NSScrollView *scrollView =
      _webView.mainFrame.frameView.documentView.enclosingScrollView;

  [scrollView setHasHorizontalScroller:NO];
  scrollView.horizontalScrollElasticity = NSScrollElasticityNone;
  scrollView.backgroundColor = [NSColor colorWithDeviceWhite:0.8 alpha:1.0];
  
  id webActionDelegate = [self webActionDelegate];
  
  if (webActionDelegate != nil)
    [_webView.windowScriptObject setValue:webActionDelegate
                                   forKey:@"webActionDelegate"];
  
  if (self.savedTabWidth != 0)
    self.tabWidth = self.savedTabWidth;
  else
    [self setDefaultTabWidth];
  
  [self updateFont];
}

- (void)updateFont
{
  NSFont *font = [PreviewsPrefsController defaultFont];
  
  self.webView.preferences.standardFontFamily = font.familyName;
  self.webView.preferences.defaultFontSize = font.pointSize;
  self.webView.preferences.defaultFixedFontSize = font.pointSize;
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
      [NSMutableArray arrayWithCapacity:defaultMenuItems.count];

  for (NSMenuItem *item in defaultMenuItems) {
    for (int i = 0; i < kAllowedCount; ++i)
      if (allowedTags[i] == item.tag) {
        [allowedItems addObject:item];
        break;
      }
  }
  return allowedItems;
}

@end
