#import "XTPreviewItem.h"
#import "XTConstants.h"
#import "XTRepository+Parsing.h"
#import "Xit-Swift.h"

@interface XTPreviewItem ()

@property(readwrite) NSURL *previewItemURL;

@end


@implementation XTPreviewItem

- (instancetype)init
{
  if ((self = [super init]) != nil) {
    NSString *tempDir = NSTemporaryDirectory();
    NSString *tempTemplate =
        [tempDir stringByAppendingPathComponent:@"xtpreviewXXXXXX"];
    const char *templateStr =
        [tempTemplate cStringUsingEncoding:NSUTF8StringEncoding];
    char *template = malloc(strlen(templateStr) + 1);

    strcpy(template, templateStr);

    const char *tempPath = mkdtemp(template);

    if (tempPath != NULL)
      _tempFolder = @(tempPath);
    free(template);
  }
  return self;
}

- (NSString *)tempFilePath
{
  return [self.tempFolder
      stringByAppendingPathComponent:self.path.lastPathComponent];
}

- (void)deleteTempFile
{
  const char *tempPath =
      [[self tempFilePath] cStringUsingEncoding:NSUTF8StringEncoding];

  if (tempPath != NULL)
    unlink(tempPath);
}

- (void)dealloc
{
  [self deleteTempFile];
  rmdir([_tempFolder cStringUsingEncoding:NSUTF8StringEncoding]);
}

- (void)remakeTempFile
{
  [self deleteTempFile];
  self.previewItemURL = nil;

  if ((self.path != nil) && (self.model != nil)) {
    NSData *contents = [self.model dataForFile:self.path staged:YES];

    if (contents != nil) {
      NSString *tempFilePath = [self tempFilePath];

      [contents writeToFile:tempFilePath atomically:NO];
      self.previewItemURL = [NSURL fileURLWithPath:tempFilePath];
    }
  }
}

- (void)setModel:(id<XTFileChangesModel>)newModel
{
  _model = newModel;
  [self remakeTempFile];
}

- (void)setPath:(NSString*)path
{
  _path = path;
  [self remakeTempFile];
}

@end
