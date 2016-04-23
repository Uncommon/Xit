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
  XCTAssertFalse([repository hasHeadReference], @"");
  XCTAssertEqualObjects([repository parentTree], kEmptyTreeHash, @"");
}

- (void)testHeadRef
{
  [super addInitialRepoContent];
  XCTAssertEqualObjects([repository headRef], @"refs/heads/master", @"");

  // The SHA will vary with the date, so just make sure it's valid.
  NSString *headSHA = [repository headSHA];
  NSCharacterSet *hexChars = [NSCharacterSet
      characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];

  XCTAssertEqual([headSHA length], (NSUInteger) 40);
  XCTAssertEqualObjects([headSHA stringByTrimmingCharactersInSet:hexChars], @"",
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
  XCTAssertNil(error);
  [repository stageFile:file1Path];
  [repository commitWithMessage:@"commit 2"
                          amend:NO
                    outputBlock:NULL
                          error:&error];
  XCTAssertNil(error);

  [repository checkout:firstSHA error:&error];
  XCTAssertNil(error);

  NSString *detachedSHA = [repository headSHA];

  XCTAssertEqualObjects(firstSHA, detachedSHA);
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
  XCTAssertTrue([mockRepo parseCommit:@"master"
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

  XCTAssertEqualObjects(header, expectedHeader, @"mismatched header");
  XCTAssertEqualObjects(files, expectedFiles, @"mismatched files");
  XCTAssertEqualObjects(message, @"file list parsing in XTRepository",
                       @"mismatched description");
}

- (void)testContents {
  [super addInitialRepoContent];

  NSData *contentsData = [repository contentsOfFile:@"file1.txt"
                                           atCommit:@"HEAD"];

  XCTAssertNotNil(contentsData, @"");

  NSString *contentsString = [[NSString alloc]
      initWithData:contentsData encoding:NSUTF8StringEncoding];

  XCTAssertEqualObjects(contentsString, @"some text", @"");
}

- (void)testStagedContents
{
  NSError *error = nil;
  NSString *fileName = @"file1.txt";
  NSString *content = @"some content";
  const NSStringEncoding encoding = NSASCIIStringEncoding;

  file1Path = [repoPath stringByAppendingPathComponent:fileName];
  [content writeToFile:file1Path
            atomically:YES
              encoding:encoding
                error:&error];
  XCTAssertNil(error);
  XCTAssertNil([repository contentsOfStagedFile:fileName]);
  
  XCTAssertTrue([repository stageFile:fileName]);
  
  NSData *expectedContent = [content dataUsingEncoding:encoding];
  NSData *stagedContent = [repository contentsOfStagedFile:fileName];
  NSString *stagedString =
      [[NSString alloc] initWithData:stagedContent encoding:encoding];
  
  XCTAssertEqualObjects(expectedContent, stagedContent);
  XCTAssertEqualObjects(content, stagedString);
}

- (void)testWriteLock {
  [super addInitialRepoContent];

  // Stage
  [self writeTextToFile1:@"modification"];
  repository.isWriting = YES;
  XCTAssertFalse([repository stageFile:file1Path]);
  repository.isWriting = NO;
  XCTAssertTrue([repository stageFile:file1Path]);

  // Unstage
  repository.isWriting = YES;
  XCTAssertFalse([repository unstageFile:file1Path]);
  repository.isWriting = NO;
  XCTAssertTrue([repository unstageFile:@"file1.txt"]);

  // Stash
  NSString *stash0 = @"stash@{0}";
  
  repository.isWriting = YES;
  XCTAssertFalse([repository saveStash:@"stashname"]);
  repository.isWriting = NO;
  XCTAssertTrue([repository saveStash:@"stashname"]);
  repository.isWriting = YES;
  XCTAssertFalse([repository applyStash:stash0 error:NULL]);
  repository.isWriting = NO;
  XCTAssertTrue([repository applyStash:stash0 error:NULL]);
  repository.isWriting = YES;
  XCTAssertFalse([repository dropStash:stash0 error:NULL]);
  repository.isWriting = NO;
  XCTAssertTrue([repository dropStash:stash0 error:NULL]);
  [self writeTextToFile1:@"modification"];
  XCTAssertTrue([repository saveStash:@"stashname"]);
  repository.isWriting = YES;
  XCTAssertFalse([repository popStash:stash0 error:NULL]);
  repository.isWriting = NO;
  XCTAssertTrue([repository popStash:stash0 error:NULL]);

  // Commit
  [self writeTextToFile1:@"modification"];
  XCTAssertTrue([repository stageFile:file1Path]);
  repository.isWriting = YES;
  XCTAssertFalse([repository commitWithMessage:@"blah"
                                        amend:NO
                                  outputBlock:NULL
                                        error:NULL]);
  repository.isWriting = NO;
  XCTAssertTrue([repository commitWithMessage:@"blah"
                                       amend:NO
                                 outputBlock:NULL
                                       error:NULL]);

  // Branches
  NSString *masterBranch = @"master";
  NSString *testBranch1 = @"testbranch", *testBranch2 = @"testBranch2";
  NSError *error = nil;
  
  repository.isWriting = YES;
  XCTAssertFalse([repository createBranch:testBranch1]);
  repository.isWriting = NO;
  XCTAssertTrue([repository createBranch:testBranch1]);
  repository.isWriting = YES;
  XCTAssertFalse([repository renameBranch:testBranch1 to:testBranch2]);
  repository.isWriting = NO;
  XCTAssertTrue([repository renameBranch:testBranch1 to:testBranch2]);
  repository.isWriting = YES;
  XCTAssertFalse([repository checkout:masterBranch error:NULL]);
  repository.isWriting = NO;
  XCTAssertTrue([repository checkout:masterBranch error:NULL]);
  repository.isWriting = YES;
  XCTAssertFalse([repository deleteBranch:testBranch2 error:&error]);
  repository.isWriting = NO;
  XCTAssertTrue([repository deleteBranch:testBranch2 error:&error]);

  // Tags
  NSString *testTagName = @"testtag";
  
  repository.isWriting = YES;
  XCTAssertFalse([repository createTag:testTagName withMessage:@"tag msg"]);
  repository.isWriting = NO;
  XCTAssertTrue([repository createTag:testTagName withMessage:@"tag msg"]);
  repository.isWriting = YES;
  XCTAssertFalse([repository deleteTag:testTagName error:&error]);
  repository.isWriting = NO;
  XCTAssertTrue([repository deleteTag:testTagName error:&error]);

  // Remotes
  NSString *testRemoteName = @"testremote";
  NSString *testRemoteName2 = @"testremote2";

  repository.isWriting = YES;
  XCTAssertFalse([repository addRemote:testRemoteName withUrl:@"fakeurl"]);
  repository.isWriting = NO;
  XCTAssertTrue([repository addRemote:testRemoteName withUrl:@"fakeurl"]);
  repository.isWriting = YES;
  XCTAssertFalse([repository renameRemote:testRemoteName to:testRemoteName2]);
  repository.isWriting = NO;
  XCTAssertTrue([repository renameRemote:testRemoteName to:testRemoteName2]);
  repository.isWriting = YES;
  XCTAssertFalse([repository deleteRemote:testRemoteName2 error:&error]);
  repository.isWriting = NO;
  XCTAssertTrue([repository deleteRemote:testRemoteName2 error:&error]);
}

- (void)testChangesForRef
{
  [super addInitialRepoContent];

  NSArray *changes = [repository changesForRef:@"master" parent:nil];

  XCTAssertEqual([changes count], 1UL);

  XTFileChange *change = changes[0];

  XCTAssertEqualObjects(change.path, [file1Path lastPathComponent]);
  XCTAssertEqual(change.change, XitChangeAdded);

  NSError *error = nil;
  NSString *file2Path = [repoPath stringByAppendingPathComponent:@"file2.txt"];

  [self writeTextToFile1:@"changes!"];
  [@"new file 2" writeToFile:file2Path
                  atomically:YES
                    encoding:NSUTF8StringEncoding
                       error:&error];
  XCTAssertNil(error);
  XCTAssertTrue([repository stageFile:file1Path]);
  XCTAssertTrue([repository stageFile:file2Path]);
  [repository commitWithMessage:@"#2" amend:NO outputBlock:NULL error:&error];
  XCTAssertNil(error);

  changes = [repository changesForRef:@"master" parent:nil];
  XCTAssertEqual([changes count], 2UL);
  change = changes[0];
  XCTAssertEqualObjects(change.path, [file1Path lastPathComponent]);
  XCTAssertEqual(change.change, XitChangeModified);
  change = changes[1];
  XCTAssertEqualObjects(change.path, [file2Path lastPathComponent]);
  XCTAssertEqual(change.change, XitChangeAdded);

  [[NSFileManager defaultManager] removeItemAtPath:file1Path error:&error];
  XCTAssertNil(error);
  XCTAssertTrue([repository stageFile:file1Path]);
  [repository commitWithMessage:@"#3" amend:NO outputBlock:NULL error:&error];
  XCTAssertNil(error);

  changes = [repository changesForRef:@"master" parent:nil];
  XCTAssertEqual([changes count], 1UL);
  change = changes[0];
  XCTAssertEqualObjects(change.path, [file1Path lastPathComponent]);
  XCTAssertEqual(change.change, XitChangeDeleted);
}

- (void)testIsTextFile
{
  NSDictionary *names = @{
      @"COPYING": @YES,
      @"a.txt": @YES,
      @"a.c": @YES,
      @"a.xml": @YES,
      @"a.html": @YES,
      @"a.jpg": @NO,
      @"a.png": @NO,
      @"a.ffff": @NO,
      @"AAAAA": @NO,
      };
  NSArray *keys = [names allKeys];
  NSArray *values = [names allValues];

  for (int i = 0; i < [keys count]; ++i)
    XCTAssertEqualObjects(
        @([repository isTextFile:keys[i] commit:@"master"]),
        values[i],
        @"fileNameIsText should be %@ for %@",
        [values[i] boolValue] ? @"true" : @"false",
        keys[i]);
}

@end
