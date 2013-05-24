#import "XTTest.h"
#import <Cocoa/Cocoa.h>
#import "OCMock/OCMock.h"
#import "XTRepository+Parsing.h"

@interface XTRepositoryTests : XTTest

@end

extern NSString *kHeaderFormat;  // From XTRepository+Parsing.m

@implementation XTRepositoryTests

- (void)addInitialRepoContent {
}

- (void)testEmptyRepositoryHead {
    STAssertNil([repository parseReference:@"HEAD"], @"");
    STAssertEqualObjects([repository parentTree], kEmptyTreeHash, @"");
}

- (void)testHeadRef {
    [super addInitialRepoContent];
    STAssertEqualObjects([repository headRef], @"refs/heads/master", @"");

    // The SHA will vary with the date, so just make sure it's valid.
    NSString *headSHA = [repository headSHA];
    NSCharacterSet *hexChars = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];

    STAssertEquals([headSHA length], (NSUInteger)40, nil);
    STAssertEqualObjects([headSHA stringByTrimmingCharactersInSet:hexChars], @"",
                         @"SHA should be only hex chars");
}

- (void)testParseCommit {
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
    NSArray *args = @[ @"show", 
                       @"-z", 
                       @"--summary", 
                       @"--name-only", 
                       kHeaderFormat, 
                       @"master" ];

    [[[mockRepo expect] andReturn:outputData] executeGitWithArgs:args error:[OCMArg setTo:nil]];
    STAssertTrue([mockRepo parseCommit:@"master" intoHeader:&header message:&message files:&files], @"");

    NSDictionary *expectedHeader = @{ @"sha": @"e8cab5650bd1ab770d6ef48c47b1fd6bb3094a92",
                                      @"tree": @"bc6eeceec6b97132b5e1755f022f69d5c245b15f",
                                      @"parents": @[ @"ab60534fdef2a1e8d191e3e113fa33797e774a2b" ],
                                      @"refs": [NSSet setWithObjects:@"HEAD", @"testing", @"repo", @"master", nil],
                                      @"authorname": @"Marshall Banana",
                                      @"authoremail": @"test@example.com",
                                      @"authordate": [NSDate dateWithString:@"2012-07-20 18:59:31 -0700"],
                                      @"committername": @"Victoria Terpsichore",
                                      @"committeremail": @"vt@example.com",
                                      @"committerdate": [NSDate dateWithString:@"2012-07-20 18:59:31 -0700"] };
    NSArray *expectedFiles = @[ @"Xit/XTFileListDataSource.m",
                                @"Xit/XTRepository+Parsing.h",
                                @"Xit/XTRepository+Parsing.m" ];

    STAssertEqualObjects(header, expectedHeader, @"mismatched header");
    STAssertEqualObjects(files, expectedFiles, @"mismatched files");
    STAssertEqualObjects(message, @"file list parsing in XTRepository", @"mismatched description");
}

@end
