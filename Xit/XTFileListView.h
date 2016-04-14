#import <Cocoa/Cocoa.h>

/**
  Highlights the staged/unstaged columns for empty rows.
  XTFileRowView handles highlighting for populated rows.
 */
@interface XTFileListView : NSOutlineView

+ (nonnull NSColor*)columnHighlightColor;
+ (void)highlightColumnInRect:(NSRect)rect;

@end


/**
 Highlights the staged/unstaged columns for populated rows.
 XTFileListView handles highlighting for empty rows.
 */
@interface XTFileRowView : NSTableRowView

/// Stores the outline view so it can find the highlighted column.
@property (nullable, assign) NSOutlineView *outlineView;

@end
