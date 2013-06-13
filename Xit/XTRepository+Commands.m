#import "XTRepository+Commands.h"
#import <ObjectiveGit/ObjectiveGit.h>

@implementation XTRepository (Commands)

- (BOOL)initializeRepository
{
  NSError *error = nil;

  if (![GTRepository initializeEmptyRepositoryAtURL:repoURL error:&error])
    return NO;
  gtRepo = [GTRepository repositoryWithURL:repoURL error:&error];
  return error == nil;
}

- (BOOL)saveStash:(NSString *)name
{
  NSError *error = nil;
  BOOL result = NO;

  [self executeGitWithArgs:@[ @"stash", @"save", name ] error:&error];

  if (error == nil) {
    result = YES;
  }

  return result;
}

- (BOOL)createBranch:(NSString *)name
{
  NSError *error = nil;
  BOOL result = NO;

  [self executeGitWithArgs:@[ @"checkout", @"-b", name ] error:&error];

  if (error == nil) {
    result = YES;
  }

  return result;
}

- (BOOL)deleteBranch:(NSString *)name error:(NSError *__autoreleasing *)error
{
  if (error == NULL)
    return NO;
  *error = nil;

  NSString *fullBranch =
      [[GTBranch localNamePrefix] stringByAppendingString:name];
  GTBranch *branch =
      [GTBranch branchWithName:fullBranch repository:gtRepo error:error];

  if (*error != nil)
    return NO;
  [branch deleteWithError:error];
  return *error != nil;
}

- (NSString *)currentBranch
{
  if (cachedBranch == nil) {
    NSError *error = nil;
    GTBranch *branch = [gtRepo currentBranchWithError:&error];

    if (error != nil)
      return nil;

    NSString *remoteName = [branch remoteName];

    if (remoteName != nil)
      // shortName strips the remote name, so put it back
      cachedBranch =
          [NSString stringWithFormat:@"%@/%@", remoteName, [branch shortName]];
    else
      cachedBranch = [branch shortName];
  }
  return cachedBranch;
}

- (BOOL)merge:(NSString *)name error:(NSError **)error
{
  [self executeGitWithArgs:@[ @"merge", name ] error:error];
  return *error == nil;
}

- (BOOL)push:(NSString *)remote
{
  NSError *error = nil;
  BOOL result = NO;

  [self executeGitWithArgs:@[ @"push", @"--all", @"--force", remote ]
                     error:&error];

  if (error == nil) {
    result = YES;
  }

  return result;
}

- (BOOL)checkout:(NSString *)branch error:(NSError **)resultError
{
  NSError *error = nil;
  BOOL result = NO;

  cachedBranch = nil;
  [self executeGitWithArgs:@[ @"checkout", branch ] error:&error];

  if (error == nil) {
    result = YES;
  }
  if (resultError != NULL)
    *resultError = error;

  return result;
}

- (BOOL)createTag:(NSString *)name withMessage:(NSString *)msg
{
  NSError *error = nil;
  BOOL result = NO;

  [self executeGitWithArgs:@[ @"tag", @"-a", name, @"-m", msg ] error:&error];

  if (error == nil) {
    result = YES;
  }

  return result;
}

- (BOOL)deleteTag:(NSString *)name error:(NSError *__autoreleasing *)error
{
  return [self executeGitWithArgs:@[ @"tag", @"-d", name ] error:error] != nil;
}

- (BOOL)addRemote:(NSString *)name withUrl:(NSString *)url
{
  NSError *error = nil;
  BOOL result = NO;

  [self executeGitWithArgs:@[ @"remote", @"add", name, url ] error:&error];

  if (error == nil) {
    result = YES;
  }

  return result;
}

- (BOOL)deleteRemote:(NSString *)name error:(NSError *__autoreleasing *)error
{
  return [self executeGitWithArgs:@[ @"remote", @"rm", name ] error:error] !=
      nil;
}

- (BOOL)addFile:(NSString *)file
{
  NSError *error = nil;
  BOOL result = NO;

  [self executeGitWithArgs:@[ @"add", file ] error:&error];

  if (error == nil) {
    result = YES;
  }

  return result;
}

- (BOOL)commitWithMessage:(NSString *)message
{
  NSError *error = nil;
  BOOL result = NO;

  [self executeGitWithArgs:@[ @"commit", @"-F", @"-" ]
                 withStdIn:message
                     error:&error];

  if (error == nil) {
    result = YES;
  }

  return result;
}

- (NSString *)diffForStagedFile:(NSString *)file
{
  NSData *output = [self executeGitWithArgs:@[
      @"diff-index", @"--patch", @"--cached", [self parentTree], @"--", file ]
                                      error:nil];

  if (output == nil)
    return nil;
  return [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
}

- (NSString *)diffForUnstagedFile:(NSString *)file
{
  NSData *output =
      [self executeGitWithArgs:@[ @"diff-files", @"--patch", @"--", file ]
                         error:nil];

  if (output == nil)
    return nil;
  return [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
}

- (NSString *)diffForCommit:(NSString *)sha
{
  NSData *output = [self executeGitWithArgs:@[ @"diff-tree", @"--root", @"--cc",
                                               @"-C90%", @"-M90%", sha ]
                                      error:NULL];

  return [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
}

- (BOOL)stagePatch:(NSString *)patch
{
  NSError *error = nil;

  [self executeGitWithArgs:@[ @"apply", @"--cached" ]
                 withStdIn:patch
                     error:&error];
  return error == nil;
}

- (BOOL)unstagePatch:(NSString *)patch
{
  NSError *error = nil;

  [self executeGitWithArgs:@[ @"apply", @"--cached", @"--reverse" ]
                 withStdIn:patch
                     error:&error];
  return error == nil;
}

- (BOOL)discardPatch:(NSString *)patch
{
  NSError *error = nil;

  [self executeGitWithArgs:@[ @"apply", @"--reverse" ]
                 withStdIn:patch
                     error:&error];
  return error == nil;
}

- (BOOL)renameBranch:(NSString *)branch to:(NSString *)newName
{
  NSError *error = nil;

  [self executeGitWithArgs:@[ @"branch", @"-m", branch, newName ] error:&error];
  return error == nil;
}

- (BOOL)renameTag:(NSString *)branch to:(NSString *)newName
{
  // delete and re-make the tag
  // not doable for signed tags?
  return NO;
}

- (BOOL)renameRemote:(NSString *)branch to:(NSString *)newName
{
  NSError *error = nil;

  [self executeGitWithArgs:@[ @"remote", @"rename", branch, newName ]
                     error:&error];
  return error == nil;
}

- (BOOL)popStash:(NSString *)name error:(NSError **)error
{
  name = [name componentsSeparatedByString:@" "][0];
  [self executeGitWithArgs:@[ @"stash", @"pop", name ] error:error];
  return error == nil;
}

- (BOOL)applyStash:(NSString *)name error:(NSError **)error
{
  name = [name componentsSeparatedByString:@" "][0];
  [self executeGitWithArgs:@[ @"stash", @"apply", name ] error:error];
  return error == nil;
}

- (BOOL)dropStash:(NSString *)name error:(NSError **)error
{
  name = [name componentsSeparatedByString:@" "][0];
  [self executeGitWithArgs:@[ @"stash", @"drop", name ] error:error];
  return error == nil;
}

@end
