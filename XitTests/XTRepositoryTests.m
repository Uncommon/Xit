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

@implementation XTRepositoryTests

- (void)addInitialRepoContent
{
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

@end
