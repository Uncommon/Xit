#import "XTTest.h"
#import <Cocoa/Cocoa.h>
#import "OCMock/OCMock.h"
#import "XTRepository+Commands.h"
#import "XTRepository+Parsing.h"

@interface XTRepositoryTests : XTTest

@end

@interface XTRepository (Test)

@property(readwrite) BOOL isWriting;

@end

extern NSString *kHeaderFormat;  // From XTRepository+Parsing.m

@implementation XTRepositoryTests

- (void)addInitialRepoContent
{
}

- (void)testEmptyRepositoryHead
{
  STAssertFalse([repository hasHeadReference], @"");
  STAssertEqualObjects([repository parentTree], kEmptyTreeHash, @"");
}

- (void)testHeadRef
{
  [super addInitialRepoContent];
  STAssertEqualObjects([repository headRef], @"refs/heads/master", @"");

  // The SHA will vary with the date, so just make sure it's valid.
  NSString *headSHA = [repository headSHA];
  NSCharacterSet *hexChars = [NSCharacterSet
      characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];

  STAssertEquals([headSHA length], (NSUInteger) 40, nil);
  STAssertEqualObjects([headSHA stringByTrimmingCharactersInSet:hexChars], @"",
                       @"SHA should be only hex chars");
}

- (void)testDetachedCheckout
{
  [super addInitialRepoContent];

  NSString *firstSHA = [repository headSHA];
  NSError *error = nil;

  [@"mash" writeToFile:file1Path
            atomically:YES
              encoding:NSUTF8StringEncoding
                 error:&error];
  STAssertNil(error, nil);
  [repository stageFile:file1Path];
  [repository commitWithMessage:@"commit 2"
                          amend:NO
                    outputBlock:NULL
                          error:&error];
  STAssertNil(error, nil);

  [repository checkout:firstSHA error:&error];
  STAssertNil(error, nil);

  NSString *detachedSHA = [repository headSHA];

  STAssertEqualObjects(firstSHA, detachedSHA, nil);
}

- (void)testParseCommit
{
  NSString *output =
      @"e8cab5650bd1ab770d6ef48c47b1fd6bb3094a92\n"
       "bc6eeceec6b97132b5e1755f022f69d5c245b15f\n"
       "ab60534fdef2a1e8d191e3e113fa33797e774a2b\n"
       " (HEAD, testing, repo, master)\n"
       "Marshall Banana\n"
       "test@example.com\n"
       "Fri, 20 Jul 2012 18:59:31 -0700\n"
       "Victoria Terpsichore\n"
       "vt@example.com\n"
       "Fri, 20 Jul 2012 18:59:31 -0700\n"
       "\0file list parsing in XTRepository\0\n\n"
       "Xit/XTFileListDataSource.m\0"
       "Xit/XTRepository+Parsing.h\0"
       "Xit/XTRepository+Parsing.m\0";
  NSData *outputData = [output dataUsingEncoding:NSUTF8StringEncoding];
  NSDictionary *header = nil;
  NSString *message = nil;
  NSArray *files = nil;
  id mockRepo = [OCMockObject partialMockForObject:repository];
  NSArray *args = @[ @"show", @"-z", @"--summary", @"--name-only",
                     kHeaderFormat, @"master" ];

  [[[mockRepo expect] andReturn:outputData]
      executeGitWithArgs:args
                  writes:NO
                   error:[OCMArg setTo:nil]];
  STAssertTrue([mockRepo parseCommit:@"master"
                          intoHeader:&header
                             message:&message
                               files:&files],
               @"");

  NSDictionary *expectedHeader =
      @{ @"sha":@"e8cab5650bd1ab770d6ef48c47b1fd6bb3094a92",
         @"tree":@"bc6eeceec6b97132b5e1755f022f69d5c245b15f",
         @"parents":@[ @"ab60534fdef2a1e8d191e3e113fa33797e774a2b" ], @"refs" :
         [NSSet setWithObjects:@"HEAD", @"testing", @"repo", @"master", nil],
         @"authorname":@"Marshall Banana",
         @"authoremail":@"test@example.com",
         @"authordate":[NSDate dateWithString:@"2012-07-20 18:59:31 -0700"],
         @"committername":@"Victoria Terpsichore",
         @"committeremail":@"vt@example.com", @"committerdate" :
         [NSDate dateWithString:@"2012-07-20 18:59:31 -0700"] };
  NSArray *expectedFiles =
      @[ @"Xit/XTFileListDataSource.m", @"Xit/XTRepository+Parsing.h",
         @"Xit/XTRepository+Parsing.m" ];

  STAssertEqualObjects(header, expectedHeader, @"mismatched header");
  STAssertEqualObjects(files, expectedFiles, @"mismatched files");
  STAssertEqualObjects(message, @"file list parsing in XTRepository",
                       @"mismatched description");
}

- (void)testContents {
  [super addInitialRepoContent];

  NSData *contentsData = [repository contentsOfFile:@"file1.txt"
                                           atCommit:@"HEAD"];

  STAssertNotNil(contentsData, @"");

  NSString *contentsString = [[NSString alloc]
      initWithData:contentsData encoding:NSUTF8StringEncoding];

  STAssertEqualObjects(contentsString, @"some text", @"");
}

- (void)testWriteLock {
  [super addInitialRepoContent];

  // Stage
  [self writeTextToFile1:@"modification"];
  repository.isWriting = YES;
  STAssertFalse([repository stageFile:file1Path], nil);
  repository.isWriting = NO;
  STAssertTrue([repository stageFile:file1Path], nil);

  // Unstage
  repository.isWriting = YES;
  STAssertFalse([repository unstageFile:file1Path], nil);
  repository.isWriting = NO;
  STAssertTrue([repository unstageFile:@"file1.txt"], nil);

  // Stash
  NSString *stash0 = @"stash@{0}";
  
  repository.isWriting = YES;
  STAssertFalse([repository saveStash:@"stashname"], nil);
  repository.isWriting = NO;
  STAssertTrue([repository saveStash:@"stashname"], nil);
  repository.isWriting = YES;
  STAssertFalse([repository applyStash:stash0 error:NULL], nil);
  repository.isWriting = NO;
  STAssertTrue([repository applyStash:stash0 error:NULL], nil);
  repository.isWriting = YES;
  STAssertFalse([repository dropStash:stash0 error:NULL], nil);
  repository.isWriting = NO;
  STAssertTrue([repository dropStash:stash0 error:NULL], nil);
  [self writeTextToFile1:@"modification"];
  STAssertTrue([repository saveStash:@"stashname"], nil);
  repository.isWriting = YES;
  STAssertFalse([repository popStash:stash0 error:NULL], nil);
  repository.isWriting = NO;
  STAssertTrue([repository popStash:stash0 error:NULL], nil);

  // Commit
  [self writeTextToFile1:@"modification"];
  STAssertTrue([repository stageFile:file1Path], nil);
  repository.isWriting = YES;
  STAssertFalse([repository commitWithMessage:@"blah"
                                        amend:NO
                                  outputBlock:NULL
                                        error:NULL], nil);
  repository.isWriting = NO;
  STAssertTrue([repository commitWithMessage:@"blah"
                                       amend:NO
                                 outputBlock:NULL
                                       error:NULL], nil);

  // Branches
  NSString *masterBranch = @"master";
  NSString *testBranch1 = @"testbranch", *testBranch2 = @"testBranch2";
  NSError *error = nil;
  
  repository.isWriting = YES;
  STAssertFalse([repository createBranch:testBranch1], nil);
  repository.isWriting = NO;
  STAssertTrue([repository createBranch:testBranch1], nil);
  repository.isWriting = YES;
  STAssertFalse([repository renameBranch:testBranch1 to:testBranch2], nil);
  repository.isWriting = NO;
  STAssertTrue([repository renameBranch:testBranch1 to:testBranch2], nil);
  repository.isWriting = YES;
  STAssertFalse([repository checkout:masterBranch error:NULL], nil);
  repository.isWriting = NO;
  STAssertTrue([repository checkout:masterBranch error:NULL], nil);
  repository.isWriting = YES;
  STAssertFalse([repository deleteBranch:testBranch2 error:&error], nil);
  repository.isWriting = NO;
  STAssertTrue([repository deleteBranch:testBranch2 error:&error], nil);

  // Tags
  NSString *testTagName = @"testtag";
  
  repository.isWriting = YES;
  STAssertFalse([repository createTag:testTagName withMessage:@"tag msg"], nil);
  repository.isWriting = NO;
  STAssertTrue([repository createTag:testTagName withMessage:@"tag msg"], nil);
  repository.isWriting = YES;
  STAssertFalse([repository deleteTag:testTagName error:&error], nil);
  repository.isWriting = NO;
  STAssertTrue([repository deleteTag:testTagName error:&error], nil);

  // Remotes
  NSString *testRemoteName = @"testremote";
  NSString *testRemoteName2 = @"testremote2";

  repository.isWriting = YES;
  STAssertFalse([repository addRemote:testRemoteName withUrl:@"fakeurl"], nil);
  repository.isWriting = NO;
  STAssertTrue([repository addRemote:testRemoteName withUrl:@"fakeurl"], nil);
  repository.isWriting = YES;
  STAssertFalse([repository renameRemote:testRemoteName to:testRemoteName2],
                nil);
  repository.isWriting = NO;
  STAssertTrue([repository renameRemote:testRemoteName to:testRemoteName2],
                nil);
  repository.isWriting = YES;
  STAssertFalse([repository deleteRemote:testRemoteName2 error:&error], nil);
  repository.isWriting = NO;
  STAssertTrue([repository deleteRemote:testRemoteName2 error:&error], nil);
}

- (void)testChangesForRef
{
  [super addInitialRepoContent];

  NSArray *changes = [repository changesForRef:@"master" parent:nil];

  STAssertEquals([changes count], 1UL, nil);

  XTFileChange *change = changes[0];

  STAssertEqualObjects(change.path, [file1Path lastPathComponent], nil);
  STAssertEquals(change.change, XitChangeAdded, nil);

  NSError *error = nil;
  NSString *file2Path = [repoPath stringByAppendingPathComponent:@"file2.txt"];

  [self writeTextToFile1:@"changes!"];
  [@"new file 2" writeToFile:file2Path
                  atomically:YES
                    encoding:NSUTF8StringEncoding
                       error:&error];
  STAssertNil(error, nil);
  STAssertTrue([repository stageFile:file1Path], nil);
  STAssertTrue([repository stageFile:file2Path], nil);
  [repository commitWithMessage:@"#2" amend:NO outputBlock:NULL error:&error];
  STAssertNil(error, nil);

  changes = [repository changesForRef:@"master" parent:nil];
  STAssertEquals([changes count], 2UL, nil);
  change = changes[0];
  STAssertEqualObjects(change.path, [file1Path lastPathComponent], nil);
  STAssertEquals(change.change, XitChangeModified, nil);
  change = changes[1];
  STAssertEqualObjects(change.path, [file2Path lastPathComponent], nil);
  STAssertEquals(change.change, XitChangeAdded, nil);

  [[NSFileManager defaultManager] removeItemAtPath:file1Path error:&error];
  STAssertNil(error, nil);
  STAssertTrue([repository stageFile:file1Path], nil);
  [repository commitWithMessage:@"#3" amend:NO outputBlock:NULL error:&error];
  STAssertNil(error, nil);

  changes = [repository changesForRef:@"master" parent:nil];
  STAssertEquals([changes count], 1UL, nil);
  change = changes[0];
  STAssertEqualObjects(change.path, [file1Path lastPathComponent], nil);
  STAssertEquals(change.change, XitChangeDeleted, nil);
}

@end
