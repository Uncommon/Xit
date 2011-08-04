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
#import "PBGitHistoryGrapher.h"
#import "PBGitRevisionCell.h"

@implementation XTHistoryDataSource

@synthesize items;

- (id)init
{
    self = [super init];
    if (self) {
        items=[NSMutableArray array];
        queue = dispatch_queue_create("com.xit.queue.history", nil);
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

        [repo getCommitsWithArgs:[NSArray arrayWithObjects:@"--pretty=format:%H%n%P%n%ct%n%ce%n%s",@"--all",@"--topo-order", nil]
      enumerateCommitsUsingBlock:^(NSString * line) { 
          
          NSArray *comps=[line componentsSeparatedByString:@"\n"];
//          NSLog(@"line: %@",[comps componentsJoinedByString:@" - "]);
          XTHistoryItem *item=[[XTHistoryItem alloc] init];
          if([comps count]==5){
              item.sha=[comps objectAtIndex:0];
              NSString *parentsStr=[comps objectAtIndex:1];
              if(parentsStr.length>0){
                  item.parents=[parentsStr componentsSeparatedByString:@" "];
              }else{
                  item.parents=[NSArray array];
              }
              item.date=[comps objectAtIndex:2];
              item.email=[comps objectAtIndex:3];
              item.subject=[comps objectAtIndex:4];
              [newItems addObject:item];
          }else{
              [NSException raise:@"Invalid commint" format:@"Line ***\n%@\n*** is invalid", line];
          }
          
      }
                           error:nil];
                
        PBGitGrapher *grapher = [[PBGitGrapher alloc] init];
        [newItems enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [grapher decorateCommit:obj];
        }];

        NSLog(@"-> %lu",[newItems count]);
        items=newItems;
        [table reloadData];
    });
}

// only for unit test
-(void)waitUntilReloadEnd
{
    dispatch_sync(queue, ^{ });
    [items enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        XTHistoryItem *item=(XTHistoryItem *)obj;
        NSLog(@"numColumns=%lu - parents=%lu - %@",item.lineInfo.numColumns,item.parents.count,item.subject);
    }];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
    table=aTableView;
    [table setDelegate:self];
    return [items count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    XTHistoryItem *item=[items objectAtIndex:rowIndex];
    return [item valueForKey:aTableColumn.identifier];
}

#pragma mark - NSTableViewDelegate

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
    NSLog(@"%@",aNotification);
    XTHistoryItem *item=[items objectAtIndex:table.selectedRow];
    repo.selectedCommit=item.sha;
}

- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    XTHistoryItem *item=[items objectAtIndex:rowIndex];
    ((PBGitRevisionCell *)aCell).objectValue=item;
}

@end
