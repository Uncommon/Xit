#import "XTRepository+Commands.h"
#import "XTConstants.h"
#import "Xit-Swift.h"
#import <ObjectiveGit/ObjectiveGit.h>

@interface XTRepository()

@property (readwrite) XTRepositoryWatcher *repoWatcher;
@property (readwrite) XTWorkspaceWatcher *workspaceWatcher;
@property (readwrite) XTConfig *config;

@end


@implementation XTRepository (Commands)

- (BOOL)initializeRepository
{
  NSError *error = nil;
  GTRepository *newRepo = [GTRepository
      initializeEmptyRepositoryAtFileURL:_repoURL
                                 options:nil
                                   error:&error];
  
  if ((newRepo == nil) || (error != nil))
    return NO;
  _gtRepo = newRepo;
  self.repoWatcher = [[XTRepositoryWatcher alloc] initWithRepository:self];
  self.workspaceWatcher =
      [[XTWorkspaceWatcher alloc] initWithRepository:self];
  self.config = [[XTConfig alloc] initWithRepository:self];
  return YES;
}

- (BOOL)saveStash:(NSString*)name includeUntracked:(BOOL)untracked
{
  NSError *error = nil;
  BOOL result = NO;
  NSMutableArray<NSString*> *args =
      [NSMutableArray arrayWithObjects:@"stash", @"save", nil];

  if (untracked)
    [args addObject:@"--include-untracked"];
  if (name.length > 0)
    [args addObject:name];
  [self executeGitWithArgs:args writes:YES error:&error];

  if (error == nil) {
    result = YES;
  }

  return result;
}

- (BOOL)push:(NSString *)remote
{
  NSError *error = nil;
  BOOL result = NO;

  [self executeGitWithArgs:@[ @"push", @"--all", @"--force", remote ]
                    writes:NO
                     error:&error];

  if (error == nil) {
    result = YES;
  }

  return result;
}

- (BOOL)checkout:(NSString *)branch error:(NSError **)resultError
{
  return [self executeWritingBlock:^BOOL{
    _cachedBranch = nil;
    _cachedHeadRef = nil;
    _cachedHeadSHA = nil;

    GTCheckoutOptions *options = [GTCheckoutOptions checkoutOptionsWithStrategy:GTCheckoutStrategySafe];
    NSString *branchRef = [[GTBranch localNamePrefix]
        stringByAppendingPathComponent:branch];
    GTReference *ref = [_gtRepo lookUpReferenceWithName:branchRef error:resultError];

    if (ref != nil)
      return [_gtRepo checkoutReference:ref
                               options:options
                                 error:resultError];

    // TODO: Make a separate checkoutSHA method to avoid ambiguity
    if (branch.length == 40) {
      if (resultError != NULL)
        *resultError = nil;

      GTCommit *commit = [_gtRepo
          lookUpObjectBySHA:branch
          objectType:GTObjectTypeCommit
          error:resultError];

      if (commit != nil)
        return [_gtRepo checkoutCommit:commit
                               options:options
                                 error:resultError];
    }
    return NO;
  }];
}

- (BOOL)createTag:(NSString*)name
        targetSHA:(NSString*)sha
          message:(NSString*)message
{
  return [self executeWritingBlock:^BOOL{
    NSError *error = nil;
    GTCommit *targetCommit = [_gtRepo lookUpObjectBySHA:sha
                                             objectType:GTObjectTypeCommit
                                                  error:&error];
    GTSignature *signature = [_gtRepo userSignatureForNow];

    if ((targetCommit == nil) || (signature == nil))
      return NO;

    [_gtRepo createTagNamed:name
                     target:targetCommit
                     tagger:[_gtRepo userSignatureForNow]
                    message:message
                      error:&error];
    return error == nil;
  }];
}

- (BOOL)createLightweightTag:(NSString*)name targetSHA:(NSString*)sha
{
  return [self executeWritingBlock:^BOOL{
    NSError *error = nil;
    GTCommit *targetCommit = [_gtRepo lookUpObjectBySHA:sha
                                             objectType:GTObjectTypeCommit
                                                  error:&error];
    
    if (targetCommit == nil)
      return NO;
    [_gtRepo createLightweightTagNamed:name
                                target:targetCommit
                                 error:&error];
    return error != nil;
  }];
}

- (BOOL)deleteTag:(NSString *)name error:(NSError *__autoreleasing *)error
{
  return [self executeWritingBlock:^BOOL{
    int result = git_tag_delete([_gtRepo git_repository], name.UTF8String);

    if (result == 0)
      return YES;
    else {
      if (error != NULL)
        *error = [NSError git_errorFor:result];
      return NO;
    }
  }];
}

- (BOOL)addRemote:(NSString *)name withUrl:(NSString *)url
{
  NSError *error = nil;
  BOOL result = NO;

  [self executeGitWithArgs:@[ @"remote", @"add", name, url ]
                    writes:YES
                     error:&error];

  if (error == nil) {
    result = YES;
  }

  return result;
}

- (BOOL)deleteRemote:(NSString *)name error:(NSError *__autoreleasing *)error
{
  return [self executeGitWithArgs:@[ @"remote", @"rm", name ]
                           writes:YES
                            error:error] != nil;
}

- (NSString *)urlStringForRemote:(NSString *)remoteName
{
  NSString *remoteURL =
      [[_gtRepo configurationWithError:nil] stringForKey:remoteName];
  
  return remoteURL;
}

- (BOOL)stagePatch:(NSString *)patch
{
  NSError *error = nil;

  [self executeGitWithArgs:@[ @"apply", @"--cached" ]
                 withStdIn:patch
                    writes:YES
                     error:&error];
  return error == nil;
}

- (BOOL)unstagePatch:(NSString *)patch
{
  NSError *error = nil;

  [self executeGitWithArgs:@[ @"apply", @"--cached", @"--reverse" ]
                 withStdIn:patch
                    writes:YES
                     error:&error];
  return error == nil;
}

- (BOOL)discardPatch:(NSString *)patch
{
  NSError *error = nil;

  [self executeGitWithArgs:@[ @"apply", @"--reverse" ]
                 withStdIn:patch
                    writes:YES
                     error:&error];
  return error == nil;
}

- (BOOL)unstageAllFiles
{
  // "Unstaging" just means making things match what's in the head commit,
  // so if we're unstaging everything we can just copy the tree over.
  NSError *error = nil;
  GTReference *headRef = [_gtRepo headReferenceWithError:&error];
  GTCommit *headCommit = (GTCommit*)headRef.resolvedTarget;
  
  if ((headCommit == nil) || ![headCommit isKindOfClass:[GTCommit class]])
    return NO;
  
  GTIndex *index = [_gtRepo indexWithError:&error];
  
  if (index == nil)
    return NO;
  
  if (![index addContentsOfTree:headCommit.tree error:&error]) {
    NSLog(@"couldn't unstage all: %@", error);
    return NO;
  }
  if (![index write:&error]) {
    NSLog(@"couldn't write index: %@", error);
    return NO;
  }
  return YES;
}

- (BOOL)renameRemote:(NSString *)branch to:(NSString *)newName
{
  NSError *error = nil;

  [self executeGitWithArgs:@[ @"remote", @"rename", branch, newName ]
                    writes:YES
                     error:&error];
  return error == nil;
}

- (GTCheckoutOptions*)stashCheckoutOptions
{
  return [GTCheckoutOptions checkoutOptionsWithStrategy:GTCheckoutStrategySafe];
}

- (BOOL)popStashIndex:(NSUInteger)index error:(NSError**)error
{
  return [self executeWritingBlock:^BOOL{
    return [self.gtRepo popStashAtIndex:index
                                  flags:GTRepositoryStashApplyFlagReinstateIndex
                        checkoutOptions:[self stashCheckoutOptions]
                                  error:error
                          progressBlock:nil];
  }];
}

- (BOOL)applyStashIndex:(NSUInteger)index error:(NSError**)error
{
  return [self executeWritingBlock:^BOOL{
    return [self.gtRepo applyStashAtIndex:index
                                    flags:GTRepositoryStashApplyFlagReinstateIndex
                          checkoutOptions:[self stashCheckoutOptions]
                                    error:error
                            progressBlock:nil];
  }];
}

- (BOOL)dropStashIndex:(NSUInteger)index error:(NSError**)error
{
  return [self executeWritingBlock:^BOOL{
    return [self.gtRepo dropStashAtIndex:index error:(NSError**)error];
  }];
}

- (BOOL)addSubmoduleAtPath:(NSString *)path
                 urlOrPath:(NSString *)urlOrPath
                     error:(NSError **)error
{
  return [self executeGitWithArgs:@[ @"submodule", @"add", @"-f",
                                     urlOrPath, path ]
                           writes:YES
                            error:error] != nil;
/* The clone step must be implemented for this to be good.
  return [self executeWritingBlock:^BOOL{
    git_submodule *gitSub = NULL;
    int result = git_submodule_add_setup(
        &gitSub, [gtRepo git_repository],
        [urlOrPath UTF8String], [path UTF8String], false);

    if ((result != 0) && (error != NULL)) {
      *error = [NSError git_errorFor:result];
      return NO;
    }
    // clone the sub-repo
    git_submodule_add_finalize(gitSub);
    return YES;
  }];
*/
}

@end
