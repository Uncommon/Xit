#import "XTTest.h"
#import <Cocoa/Cocoa.h>
#import "XTConstants.h"
#import "XTRepository+Commands.h"
#import "XTRepository+Parsing.h"
#import "Xit-Swift.h"

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
  XCTAssertFalse([self.repository hasHeadReference], @"");
  XCTAssertEqualObjects([self.repository parentTree], kEmptyTreeHash, @"");
}

- (void)testHeadRef
{
  [super addInitialRepoContent];
  XCTAssertEqualObjects([self.repository headRef], @"refs/heads/master", @"");

  // The SHA will vary with the date, so just make sure it's valid.
  NSString *headSHA = [self.repository headSHA];
  NSCharacterSet *hexChars = [NSCharacterSet
      characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];

  XCTAssertEqual([headSHA length], (NSUInteger) 40);
  XCTAssertEqualObjects([headSHA stringByTrimmingCharactersInSet:hexChars], @"",
                       @"SHA should be only hex chars");
}

- (void)testDetachedCheckout
{
  [super addInitialRepoContent];

  NSString *firstSHA = [self.repository headSHA];
  NSError *error = nil;

  [@"mash" writeToFile:self.file1Path
            atomically:YES
              encoding:NSUTF8StringEncoding
                 error:&error];
  XCTAssertNil(error);
  [self.repository stageFile:self.file1Path error:&error];
  [self.repository commitWithMessage:@"commit 2"
                               amend:NO
                         outputBlock:NULL
                               error:&error];
  XCTAssertNil(error);

  [self.repository checkout:firstSHA error:&error];
  XCTAssertNil(error);

  NSString *detachedSHA = [self.repository headSHA];

  XCTAssertEqualObjects(firstSHA, detachedSHA);
}

- (void)testContents
{
  [super addInitialRepoContent];

  NSError *error = nil;
  NSData *contentsData = [self.repository contentsOfFile:@"file1.txt"
                                                atCommit:self.repository.headSHA
                                                   error:&error];

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

  [content writeToFile:self.file1Path
            atomically:NO
              encoding:encoding
                error:&error];
  XCTAssertNil(error);
  XCTAssertNil([self.repository contentsOfStagedFile:fileName error:&error]);
  error = nil;
  
  XCTAssertTrue([self.repository stageFile:fileName error:&error]);
  
  NSData *expectedContent = [content dataUsingEncoding:encoding];
  NSData *stagedContent = [self.repository contentsOfStagedFile:fileName
                                                          error:&error];
  NSString *stagedString =
      [[NSString alloc] initWithData:stagedContent encoding:encoding];
  
  XCTAssertEqualObjects(expectedContent, stagedContent);
  XCTAssertEqualObjects(content, stagedString);
  
  // Write to the workspace file, but don't stage it. The staged content
  // should be the same.
  NSString *newContent = @"new stuff";
  
  [newContent writeToFile:self.file1Path
               atomically:NO
                 encoding:encoding
                    error:&error];
  XCTAssertNil(error);
  stagedContent = [self.repository contentsOfStagedFile:fileName error:&error];
  stagedString =
      [[NSString alloc] initWithData:stagedContent encoding:encoding];
  XCTAssertEqualObjects(expectedContent, stagedContent);
  XCTAssertEqualObjects(content, stagedString);
}

- (void)testWriteLock {
  [super addInitialRepoContent];

  NSError *error = nil;

  // Stage
  [self writeTextToFile1:@"modification"];
  self.repository.isWriting = YES;
  XCTAssertFalse([self.repository stageFile:self.file1Path error:&error]);
  self.repository.isWriting = NO;
  XCTAssertTrue([self.repository stageFile:self.file1Path error:&error]);

  // Unstage
  self.repository.isWriting = YES;
  XCTAssertFalse([self.repository unstageFile:self.file1Path error:&error]);
  self.repository.isWriting = NO;
  XCTAssertTrue([self.repository unstageFile:self.file1Path error:&error]);

  // Stash
  self.repository.isWriting = YES;
  XCTAssertFalse([self.repository saveStash:@"stashname" includeUntracked:NO]);
  self.repository.isWriting = NO;
  XCTAssertTrue([self.repository saveStash:@"stashname" includeUntracked:NO]);
  self.repository.isWriting = YES;
  XCTAssertFalse([self.repository applyStashIndex:0 error:NULL]);
  self.repository.isWriting = NO;
  XCTAssertTrue([self.repository applyStashIndex:0 error:NULL]);
  self.repository.isWriting = YES;
  XCTAssertFalse([self.repository dropStashIndex:0 error:NULL]);
  self.repository.isWriting = NO;
  XCTAssertTrue([self.repository dropStashIndex:0 error:NULL]);
  [self writeTextToFile1:@"modification"];
  XCTAssertTrue([self.repository saveStash:@"stashname" includeUntracked:NO]);
  self.repository.isWriting = YES;
  XCTAssertFalse([self.repository popStashIndex:0 error:NULL]);
  self.repository.isWriting = NO;
  XCTAssertTrue([self.repository popStashIndex:0 error:NULL]);

  // Commit
  [self writeTextToFile1:@"modification"];
  XCTAssertTrue([self.repository stageFile:self.file1Path error:&error]);
  self.repository.isWriting = YES;
  XCTAssertFalse([self.repository commitWithMessage:@"blah"
                                        amend:NO
                                  outputBlock:NULL
                                        error:NULL]);
  self.repository.isWriting = NO;
  XCTAssertTrue([self.repository commitWithMessage:@"blah"
                                       amend:NO
                                 outputBlock:NULL
                                       error:NULL]);

  // Branches
  NSString *masterBranch = @"master";
  NSString *testBranch1 = @"testbranch", *testBranch2 = @"testBranch2";
  
  self.repository.isWriting = YES;
  XCTAssertFalse([self.repository createBranch:testBranch1]);
  self.repository.isWriting = NO;
  XCTAssertTrue([self.repository createBranch:testBranch1]);
  self.repository.isWriting = YES;
  XCTAssertFalse([self.repository renameBranch:testBranch1
                                            to:testBranch2
                                         error:&error]);
  self.repository.isWriting = NO;
  XCTAssertTrue([self.repository renameBranch:testBranch1
                                           to:testBranch2
                                        error:&error]);
  self.repository.isWriting = YES;
  XCTAssertFalse([self.repository checkout:masterBranch error:NULL]);
  self.repository.isWriting = NO;
  XCTAssertTrue([self.repository checkout:masterBranch error:NULL]);
  self.repository.isWriting = YES;
  XCTAssertFalse([self.repository deleteBranch:testBranch2 error:&error]);
  self.repository.isWriting = NO;
  XCTAssertTrue([self.repository deleteBranch:testBranch2 error:&error]);

  // Tags
  NSString *testTagName = @"testtag";
  
  self.repository.isWriting = YES;
  XCTAssertFalse([self.repository createTag:testTagName
                                  targetSHA:self.repository.headSHA
                                    message:@"tag msg"]);
  self.repository.isWriting = NO;
  XCTAssertTrue([self.repository createTag:testTagName
                                 targetSHA:self.repository.headSHA
                                   message:@"tag msg"]);
  self.repository.isWriting = YES;
  XCTAssertFalse([self.repository deleteTag:testTagName error:&error]);
  self.repository.isWriting = NO;
  XCTAssertTrue([self.repository deleteTag:testTagName error:&error]);

  // Remotes
  NSString *testRemoteName = @"testremote";
  NSString *testRemoteName2 = @"testremote2";

  self.repository.isWriting = YES;
  XCTAssertFalse([self.repository addRemote:testRemoteName withUrl:@"fakeurl"]);
  self.repository.isWriting = NO;
  XCTAssertTrue([self.repository addRemote:testRemoteName withUrl:@"fakeurl"]);
  self.repository.isWriting = YES;
  XCTAssertFalse([self.repository renameRemote:testRemoteName to:testRemoteName2]);
  self.repository.isWriting = NO;
  XCTAssertTrue([self.repository renameRemote:testRemoteName to:testRemoteName2]);
  self.repository.isWriting = YES;
  XCTAssertFalse([self.repository deleteRemote:testRemoteName2 error:&error]);
  self.repository.isWriting = NO;
  XCTAssertTrue([self.repository deleteRemote:testRemoteName2 error:&error]);
}

- (void)testChangesForRef
{
  [super addInitialRepoContent];

  NSArray *changes = [self.repository changesForRef:@"master" parent:nil];

  XCTAssertEqual([changes count], 1UL);

  XTFileChange *change = changes[0];

  XCTAssertEqualObjects(change.path, [self.file1Path lastPathComponent]);
  XCTAssertEqual(change.change, XitChangeAdded);

  NSError *error = nil;
  NSString *file2Path = [self.repoPath stringByAppendingPathComponent:@"file2.txt"];

  [self writeTextToFile1:@"changes!"];
  [@"new file 2" writeToFile:file2Path
                  atomically:YES
                    encoding:NSUTF8StringEncoding
                       error:&error];
  XCTAssertNil(error);
  XCTAssertTrue([self.repository stageFile:self.file1Path error:&error]);
  XCTAssertTrue([self.repository stageFile:file2Path error:&error]);
  [self.repository commitWithMessage:@"#2" amend:NO outputBlock:NULL error:&error];
  XCTAssertNil(error);

  changes = [self.repository changesForRef:@"master" parent:nil];
  XCTAssertEqual([changes count], 2UL);
  change = changes[0];
  XCTAssertEqualObjects(change.path, [self.file1Path lastPathComponent]);
  XCTAssertEqual(change.change, XitChangeModified);
  change = changes[1];
  XCTAssertEqualObjects(change.path, [file2Path lastPathComponent]);
  XCTAssertEqual(change.change, XitChangeAdded);

  [[NSFileManager defaultManager] removeItemAtPath:self.file1Path error:&error];
  XCTAssertNil(error);
  XCTAssertTrue([self.repository stageFile:self.file1Path error:&error]);
  [self.repository commitWithMessage:@"#3" amend:NO outputBlock:NULL error:&error];
  XCTAssertNil(error);

  changes = [self.repository changesForRef:@"master" parent:nil];
  XCTAssertEqual([changes count], 1UL);
  change = changes[0];
  XCTAssertEqualObjects(change.path, [self.file1Path lastPathComponent]);
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
  NSArray *keys = names.allKeys;
  NSArray *values = names.allValues;

  for (int i = 0; i < keys.count; ++i)
    XCTAssertEqualObjects(
        @([self.repository isTextFile:keys[i] commit:@"master"]),
        values[i],
        @"fileNameIsText should be %@ for %@",
        [values[i] boolValue] ? @"true" : @"false",
        keys[i]);
}

- (void)testStageUnstageAllStatus
{
  [super addInitialRepoContent];
  [self commitNewTextFile:@"file2.txt" content:@"blah"];
  
  NSString *file2Path = [self.repoPath stringByAppendingPathComponent:@"file2.txt"];
  NSString *file3Path = [self.repoPath stringByAppendingPathComponent:@"file3.txt"];
  NSError *error = nil;
  
  XCTAssertTrue([@"blah" writeToFile:self.file1Path
                          atomically:YES
                            encoding:NSASCIIStringEncoding
                               error:nil]);
  XCTAssertTrue([[NSFileManager defaultManager] removeItemAtPath:file2Path
                                                           error:nil]);
  XCTAssertTrue([@"blah" writeToFile:file3Path
                          atomically:YES
                            encoding:NSASCIIStringEncoding
                               error:nil]);
  [self.repository stageAllFilesWithError:&error];
  
  NSArray<XTFileChange*> *changes = [self.repository changesForRef:XTStagingSHA
                                                            parent:nil];
  
  XCTAssertEqual(changes.count, 3);
  XCTAssertEqual(changes[0].unstagedChange, XitChangeUnmodified); // file1
  XCTAssertEqual(changes[0].change, XitChangeModified);
  XCTAssertEqual(changes[1].unstagedChange, XitChangeUnmodified); // file2
  XCTAssertEqual(changes[1].change, XitChangeDeleted);
  XCTAssertEqual(changes[2].unstagedChange, XitChangeUnmodified); // file3
  XCTAssertEqual(changes[2].change, XitChangeAdded);
  
  [self.repository unstageAllFiles];
  changes = [self.repository changesForRef:XTStagingSHA parent:nil];
  XCTAssertEqual(changes.count, 3);
  XCTAssertEqual(changes[0].unstagedChange, XitChangeModified); // file1
  XCTAssertEqual(changes[0].change, XitChangeUnmodified);
  XCTAssertEqual(changes[1].unstagedChange, XitChangeDeleted); // file2
  XCTAssertEqual(changes[1].change, XitChangeUnmodified);
  XCTAssertEqual(changes[2].unstagedChange, XitChangeUntracked); // file3
  XCTAssertEqual(changes[2].change, XitChangeUnmodified);
}

@end
