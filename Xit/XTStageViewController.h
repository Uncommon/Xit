//
//  XTStageViewController.h
//  Xit
//
//  Created by German Laullon on 10/08/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Xit;
@class XTStagedDataSource;
@class XTUnstagedDataSource;

@interface XTStageViewController : NSViewController
{
    IBOutlet XTStagedDataSource *stageDS;
    IBOutlet XTUnstagedDataSource *unstageDS;
    @private
    Xit *repo;
}

- (void)setRepo:(Xit *)newRepo;
- (void)viewDidLoad;

@end
