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
    cancel=YES;
    dispatch_sync(queue, ^{});
    cancel=NO;
    dispatch_async(queue, ^{
        if(!cancel){
            NSData *output=[repo exectuteGitWithArgs:[NSArray arrayWithObjects:@"log",@"--pretty=format:%H %ct %ce %s",@"--topo-order", nil] error:nil];
            if(output){
                NSMutableArray *newItems=[NSMutableArray array];
                NSString *refs = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
                NSScanner *scan = [NSScanner scannerWithString:refs];
                NSString *commit, *date, *email, *subject;
                while ([scan scanUpToString:@" " intoString:&commit] && !cancel) {
                    [scan scanUpToString:@" " intoString:&date];
                    [scan scanUpToString:@" " intoString:&email];
                    [scan scanUpToString:@"\n" intoString:&subject];
                    XTHistoryItem *item=[[XTHistoryItem alloc] init];
                    item.commit=commit;
                    item.date=date;
                    item.email=email;
                    item.subject=subject;
                    [newItems addObject:item];
                    if(([newItems count]%100)==0)
                        NSLog(@"-> %lu",[newItems count]);
                }
                if(!cancel)
                {
                    [self willChangeValueForKey:@"reload"];
                    items=newItems;
                    [table reloadData];
                    [self didChangeValueForKey:@"reload"];
                }
            }
        }
    });
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
