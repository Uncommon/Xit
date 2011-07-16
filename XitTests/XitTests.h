//
//  XitTests.h
//  XitTests
//
//  Created by glaullon on 7/15/11.
//  Copyright 2011 VMware, Inc. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "Xit.h"
#import "GITBasic+Xit.h"

@interface XitTests : SenTestCase {
@private
    NSString *path;
    Xit *xit;
}

@end
