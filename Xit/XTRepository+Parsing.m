#import "XTRepository+Parsing.h"
#import "XTConstants.h"
#import "Xit-Swift.h"
#import <ObjectiveGit/ObjectiveGit.h>
#import <ObjectiveGit/GTRepository+Status.h>
#import "NSDate+Extensions.h"
#import "Xit-Swift.h"

@implementation XTRepository (Reading)

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
