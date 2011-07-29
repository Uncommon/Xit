//
//  XTHistoryDataSource.m
//  Xit
//
//  Created by German Laullon on 26/07/11.
//  Copyright 2011 VMware, Inc. All rights reserved.
//

#import "XTHistoryDataSource.h"
#import "Xit.h"
#import "XTHistoryItem.h"

@implementation XTHistoryDataSource

- (id)init
{
    self = [super init];
    if (self) {
        items=[NSMutableArray array];
        queue = dispatch_queue_create("com.xit.queue.history", DISPATCH_QUEUE_SERIAL);
    }
    
    return self;
}

-(void)setRepo:(Xit *)newRepo
{
    repo=newRepo;
    [repo addObserver:self forKeyPath:@"reload" options:NSKeyValueObservingOptionNew context:nil];
    [self reload];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if([keyPath isEqualToString:@"reload"]){
        NSArray *reload=[change objectForKey:NSKeyValueChangeNewKey];
        for(NSString *path in reload){
            if([path hasPrefix:@".git/logs/"]){
                [self reload];
                break;
            }
        }
    }
}

-(void)reload
{
    dispatch_async(queue, ^{
        NSMutableArray *newItems=[NSMutableArray array];
        [repo getCommitsWithArgs:[NSArray arrayWithObjects:@"--pretty=format:%H\n%ct\n%ce\n%s",@"--topo-order", nil]
      enumerateCommitsUsingBlock:^(NSString * line) { 
          NSArray *comps=[line componentsSeparatedByString:@"\n"]; 
          XTHistoryItem *item=[[XTHistoryItem alloc] init];
          if([comps count]==4){
              item.commit=[comps objectAtIndex:0];
              item.date=[comps objectAtIndex:1];
              item.email=[comps objectAtIndex:2];
              item.subject=[comps objectAtIndex:3];
              [newItems addObject:item];
              // put 100 first commints on the table as soon as possible.
              if([newItems count]==100){
                  items=[newItems copy];
                  [table reloadData];
              }
          }
      }
                           error:nil];
        NSLog(@"-> %lu",[newItems count]);
        items=newItems;
        [table reloadData];
    });
}

// only for unit test
-(void)waitUntilReloadEnd
{
    dispatch_sync(queue, ^{ });
}

#pragma mark - NSOutlineViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
    table=aTableView;
    return [items count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    XTHistoryItem *item=[items objectAtIndex:rowIndex];
    return [item valueForKey:aTableColumn.identifier];
}

@end
