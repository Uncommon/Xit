#import "XTFileListView.h"
#import "XTConstants.h"
#import "Xit-Swift.h"

@implementation XTFileListView

+ (NSColor*)columnHighlightColor
{
  return [[NSColor shadowColor] colorWithAlphaComponent:0.05];
}

+ (void)highlightColumnInRect:(NSRect)rect
{
  rect.size.width += 2;
  [NSGraphicsContext saveGraphicsState];
  [[[self class] columnHighlightColor] setFill];
  [NSBezierPath fillRect:rect];
  [NSGraphicsContext restoreGraphicsState];
}

- (NSInteger)indexOfTableColumn:(NSTableColumn*)column
{
  return [self.tableColumns indexOfObject:column];
}

- (void)drawBackgroundInClipRect:(NSRect)clipRect
{
  [super drawBackgroundInClipRect:clipRect];
  
  XTWindowController *controller = self.window.windowController;
  
  if (!controller.inStagingView)
    return;
  
  const NSInteger highlightedIndex =
      [self indexOfTableColumn:self.highlightedTableColumn];
  NSRect highlightRect = [self frameOfCellAtColumn:highlightedIndex row:0];
  
  highlightRect.origin.y = clipRect.origin.y;
  highlightRect.size.height = clipRect.size.height;
  
  [[self class] highlightColumnInRect:highlightRect];
}

@end


@implementation XTFileRowView

- (void)drawBackgroundInRect:(NSRect)dirtyRect
{
  [super drawBackgroundInRect:dirtyRect];

  XTWindowController *controller = self.outlineView.window.windowController;

  if (controller.inStagingView &&
      (self.interiorBackgroundStyle != NSBackgroundStyleDark)) {
    NSTableColumn *column = self.outlineView.highlightedTableColumn;
    const NSInteger columnIndex = [self.outlineView.tableColumns indexOfObject:column];
    NSView *highlightedView = [self viewAtColumn:columnIndex];
    NSRect highlightFrame = highlightedView.frame;
    
    highlightFrame.origin.y = 0;
    highlightFrame.size.height = self.frame.size.height;
    [XTFileListView highlightColumnInRect:highlightFrame];
  }
}

@end
