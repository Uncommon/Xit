#import <Cocoa/Cocoa.h>
#import "XTConstants.h"
#import "XTFileListDataSourceBase.h"

@protocol XTFileChangesModel;

/**
  Interface for a controller that displays file content in some form.
 */
@protocol XTFileContentController <NSObject>

/// Clears the display for when nothing is selected.
- (void)clear;
/// Displays the content from the given file model.
/// @param path The repository-relative file path.
/// @param model The model to read data from.
/// @param staged Whether to show staged content.
- (void)loadPath:(NSString*)path
           model:(id<XTFileChangesModel>)model
          staged:(BOOL)staged NS_SWIFT_NAME(load(path:model:staged:));

@end

@protocol WhitespaceVariable

@property XTWhitespace whitespace;

@end

@protocol TabWidthVariable

@property NSUInteger tabWidth;

@end
