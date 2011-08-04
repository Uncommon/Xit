//
//  XTCommitViewControllerTest.m
//  Xit
//
//  Created by German Laullon on 04/08/11.
//  Copyright 2011 VMware, Inc. All rights reserved.
//

#import "XTCommitViewControllerTest.h"
#import "Xit.h"
#import "GITBasic+Xit.h"
#import "XTSideBarItem.h"
#import "XTSideBarDataSource.h"
#import "XTCommitViewController.h"

@implementation XTCommitViewControllerTest

-(void)testCommitWithTag
{
    if(![xit createTag:@"t1" withMessage:@"msg"]){
        STFail(@"Create Tag 't1'");
    }
    
    XTSideBarDataSource *sbds=[[XTSideBarDataSource alloc] init];
    [sbds setRepo:xit];
    [sbds reload];
    
    id tags=[sbds outlineView:nil child:XT_TAGS ofItem:nil];    
    XTSideBarItem *tag=[sbds outlineView:nil child:0 ofItem:tags];
    
    XTCommitViewController *cvc=[[XTCommitViewController alloc] init];
    [cvc setRepo:xit];
    [cvc loadCommit:tag.sha];
}

@end