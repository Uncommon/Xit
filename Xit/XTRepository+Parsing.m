#import "XTRepository+Parsing.h"
#import "XTConstants.h"
#import "Xit-Swift.h"
#import <ObjectiveGit/ObjectiveGit.h>
#import <ObjectiveGit/GTRepository+Status.h>
#import "NSDate+Extensions.h"
#import "Xit-Swift.h"

@interface XTRepository (Private)

@property (readonly, copy) NSArray *stagingChanges;

@end


@implementation XTRepository (Reading)

- (NSDictionary<NSString*, XTWorkspaceFileStatus*>*)workspaceStatus
{
  NSMutableDictionary<NSString*, XTWorkspaceFileStatus*> *result =
      [NSMutableDictionary dictionary];
  NSDictionary *options =
      @{ GTRepositoryStatusOptionsFlagsKey:@(GIT_STATUS_OPT_INCLUDE_UNTRACKED) };

  [self.gtRepo enumerateFileStatusWithOptions:options error:NULL
      usingBlock:^(GTStatusDelta * _Nullable headToIndex,
                   GTStatusDelta * _Nullable indexToWorkingDirectory,
                   BOOL * _Nonnull stop) {
    NSString *path = headToIndex.oldFile.path;
    
    if (path == nil)
      path = indexToWorkingDirectory.oldFile.path;
    if (path != nil) {
      XTWorkspaceFileStatus *status = [[XTWorkspaceFileStatus alloc] init];
      
      status.unstagedChange = (XitChange)indexToWorkingDirectory.status;
      status.change = (XitChange)headToIndex.status;
      result[path] = status;
    }
  }];
  return result;
}

- (NSArray<XTFileChange*>*)changesForRef:(NSString*)ref
                                  parent:(NSString*)parentSHA
{
  if (ref == nil)
    return nil;

  if ([ref isEqualToString:XTStagingSHA])
    return [self stagingChanges];

  NSError *error = nil;
  GTCommit *commit = [_gtRepo lookUpObjectByRevParse:ref error:&error];
  
  if ((commit == nil) ||
      (git_object_type([commit git_object]) != GIT_OBJ_COMMIT))
    return nil;
  if (parentSHA == nil)
    parentSHA = commit.parents.firstObject.SHA;
  
  GTDiff *diff = [self diffForSHA:commit.SHA parent:parentSHA];
  NSMutableArray *result = [NSMutableArray array];

  [diff enumerateDeltasUsingBlock:^(GTDiffDelta *delta, BOOL *stop) {
    if (delta.type != GTDeltaTypeUnmodified) {
      XTFileChange *change = [[XTFileChange alloc] init];

      change.path = delta.newFile.path;
      change.change = (XitChange)delta.type;
      [result addObject:change];
    }
  }];
  return result;
}

- (NSArray*)stagingChanges
{
  NSMutableArray *result = [NSMutableArray array];
  NSDictionary *options = @{
      GTRepositoryStatusOptionsFlagsKey: @(GTRepositoryStatusFlagsIncludeUntracked) };
  NSError *error = nil;
  
  if (![_gtRepo enumerateFileStatusWithOptions:options
                                         error:nil
                                    usingBlock:
      ^(GTStatusDelta *headToIndex, GTStatusDelta *indexToWorking, BOOL *stop) {
    XTFileStaging *change = [[XTFileStaging alloc] init];
    
    if (headToIndex != nil) {
      change.path = headToIndex.oldFile.path;
      change.destinationPath = headToIndex.newFile.path;
    } else {
      change.path = indexToWorking.oldFile.path;
      change.destinationPath = indexToWorking.newFile.path;
    }
    change.change = (XitChange)headToIndex.status;
    change.unstagedChange = (XitChange)indexToWorking.status;
    [result addObject:change];
  }]) {
    NSLog(@"Can't enumerate file status: %@", error.description);
    return nil;
  }
  
  return result;
}

- (BOOL)isTextFile:(NSString*)path commit:(NSString*)commit
{
  NSString *name = path.lastPathComponent;

  if (name.length == 0)
    return NO;

  NSArray *extensionlessNames = @[
      @"AUTHORS", @"CONTRIBUTING", @"COPYING", @"LICENSE", @"Makefile",
      @"README", ];

  for (NSString *extensionless in extensionlessNames)
    if ([name isCaseInsensitiveLike:extensionless])
      return YES;

  NSString *extension = name.pathExtension;
  const CFStringRef utType = UTTypeCreatePreferredIdentifierForTag(
      kUTTagClassFilenameExtension, (__bridge CFStringRef)extension, NULL);
  const Boolean result = UTTypeConformsTo(utType, kUTTypeText);
  
  CFRelease(utType);
  return result;
}

- (XTDiffDelta*)deltaFromDiff:(GTDiff*)diff withPath:(NSString*)path
{
  __block GTDiffDelta *result = nil;
  
  [diff enumerateDeltasUsingBlock:^(GTDiffDelta *delta, BOOL *stop) {
    if ([delta.newFile.path isEqualToString:path]) {
      *stop = YES;
      result = delta;
    }
  }];
  return (XTDiffDelta*)result;
}

- (XTDiffDelta*)diffForFile:(NSString*)path
                  commitSHA:(NSString*)sha
                  parentSHA:(NSString*)parentSHA
{
  GTDiff *diff = [self diffForSHA:sha parent:parentSHA];
  
  return [self deltaFromDiff:diff withPath:path];
}

- (BOOL)stageFile:(NSString*)file error:(NSError**)error
{
  NSString *fullPath = [file hasPrefix:@"/"] ? file :
      [_repoURL.path stringByAppendingPathComponent:file];
  NSArray *args = [[NSFileManager defaultManager] fileExistsAtPath:fullPath]
      ? @[ @"add", file ]
      : @[ @"rm", file ];
  NSData *result = [self executeGitWithArgs:args
                                     writes:YES
                                      error:error];
  
  return result != nil;
}

- (BOOL)stageAllFilesWithError:(NSError**)error
{
  return [self executeGitWithArgs:@[ @"add", @"--all" ]
                           writes:YES
                            error:error] != nil;
}

- (BOOL)unstageFile:(NSString*)file error:(NSError**)error
{
  NSArray *args = self.hasHeadReference
      ? @[ @"reset", @"-q", @"HEAD", file ]
      : @[ @"rm", @"--cached", file ];
  
  return [self executeGitWithArgs:args writes:YES error:error] != nil;
}

- (BOOL)commitWithMessage:(NSString *)message
                    amend:(BOOL)amend
              outputBlock:(void (^)(NSString *output))outputBlock
                    error:(NSError **)error
{
  NSArray *args = @[ @"commit", @"-F", @"-" ];

  if (amend)
    args = [args arrayByAddingObject:@"--amend"];

  NSData *output = [self executeGitWithArgs:args
                                  withStdIn:message
                                     writes:YES
                                      error:error];

  if (output == nil)
    return NO;
  if (outputBlock != NULL)
    outputBlock([[NSString alloc] initWithData:output
                                      encoding:NSUTF8StringEncoding]);
  return YES;
}

@end


@implementation XTFileChange

- (instancetype)initWithPath:(NSString*)path
{
  return [self initWithPath:path
                     change:XitChangeUnmodified
             unstagedChange:XitChangeUnmodified];
}

- (instancetype)initWithPath:(NSString*)path
                      change:(XitChange)change
{
  return [self initWithPath:path
                     change:change
             unstagedChange:XitChangeUnmodified];
}

- (instancetype)initWithPath:(NSString*)path
                      change:(XitChange)change
              unstagedChange:(XitChange)unstagedChange
{
  if ((self = [super init]) == nil)
    return nil;
  
  self.path = path;
  self.change = change;
  self.unstagedChange = unstagedChange;
  return self;
}

-(NSString*)description
{
  return [NSString stringWithFormat:@"%@ %ld %ld", self.path.description,
          self.change, self.unstagedChange];
}

@end


@implementation XTWorkspaceFileStatus

@end


@implementation XTFileStaging

@end
