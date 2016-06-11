#import "XTPreviewItem.h"
#import "XTConstants.h"
#import "XTRepository+Parsing.h"

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
  return [_tempFolder
      stringByAppendingPathComponent:_path.lastPathComponent];
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

  if ((_path != nil) && (_commitSHA != nil)) {
    NSError *error = nil;
    NSData *contents = [_commitSHA isEqualToString:XTStagingSHA] ?
        [_repo contentsOfStagedFile:_path error:&error] :
        [_repo contentsOfFile:_path atCommit:_commitSHA error:&error];

    if (contents != nil) {
      NSString *tempFilePath = [self tempFilePath];

      [contents writeToFile:tempFilePath atomically:NO];
      self.previewItemURL = [NSURL fileURLWithPath:tempFilePath];
    }
  }
}

- (void)setPath:(NSString *)newPath
{
  if (![newPath isEqualToString:_path]) {
    _path = newPath;
    [self remakeTempFile];
  }
}

- (NSString *)path
{
  return _path;
}

- (void)setCommitSHA:(NSString *)newSHA
{
  if (![newSHA isEqualToString:_commitSHA]) {
    _commitSHA = newSHA;
    [self remakeTempFile];
  }
}

- (NSString *)commitSHA
{
  return _commitSHA;
}

@end
