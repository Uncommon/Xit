//
//  XTHistoryDataSource.m
//  Xit
//
//  Created by German Laullon on 26/07/11.
//

#import "XTHistoryDataSource.h"
#import "XTRepository.h"
#import "XTHistoryItem.h"
#import "XTStatusView.h"
#import "PBGitHistoryGrapher.h"
#import "PBGitRevisionCell.h"

@interface NSDate (RFC2822)
+ (NSDate *)dateFromRFC2822:(NSString *)rfc2822;
@end

@implementation XTHistoryDataSource

@synthesize items;

- (id)init {
    self = [super init];
    if (self) {
        items = [NSMutableArray array];
        index = [NSMutableDictionary dictionary];
    }

    return self;
}

- (void)setRepo:(XTRepository *)newRepo {
    repo = newRepo;
    [repo addObserver:self forKeyPath:@"reload" options:NSKeyValueObservingOptionNew context:nil];
    [repo addObserver:self forKeyPath:@"selectedCommit" options:NSKeyValueObservingOptionNew context:nil];
    [self reload];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"reload"]) {
        NSArray *reload = [change objectForKey:NSKeyValueChangeNewKey];
        for (NSString *path in reload) {
            if ([path hasPrefix:@".git/logs/"]) {
                [self reload];
                break;
            }
        }
    } else if ([keyPath isEqualToString:@"selectedCommit"]) {
        NSString *newSelectedCommit = [change objectForKey:NSKeyValueChangeNewKey];
        XTHistoryItem *item = [index objectForKey:newSelectedCommit];
        if (item != nil) {
            [table selectRowIndexes:[NSIndexSet indexSetWithIndex:item.index] byExtendingSelection:NO];
            [table scrollRowToVisible:item.index];
        } else {
            NSLog(@"commit '%@' not found!!", newSelectedCommit);
        }
    }
}

- (void)reload {
    if (repo == nil)
        return;
    dispatch_async(repo.queue, ^{
                       NSArray *args = [NSArray arrayWithObjects:@"--pretty=format:%H%n%P%n%cD%n%ce%n%s", @"--reverse", @"--tags", @"--all", @"--topo-order", nil];
                       NSMutableArray *newItems = [NSMutableArray array];

                       [XTStatusView updateStatus:@"Loading..." command:[args componentsJoinedByString:@" "] output:nil forRepository:repo];
                       [repo    getCommitsWithArgs:args
                        enumerateCommitsUsingBlock:^(NSString * line) {
                            [XTStatusView updateStatus:nil command:nil output:line forRepository:repo];

                            NSArray *comps = [line componentsSeparatedByString:@"\n"];
                            XTHistoryItem *item = [[XTHistoryItem alloc] init];
                            if ([comps count] == 5) {
                                item.sha = [comps objectAtIndex:0];
                                NSString *parentsStr = [comps objectAtIndex:1];
                                if (parentsStr.length > 0) {
                                    NSArray *parents = [parentsStr componentsSeparatedByString:@" "];
                                    [parents enumerateObjectsWithOptions:0 usingBlock:^(id obj, NSUInteger idx, BOOL * stop) {
                                         NSString *parentSha = (NSString *)obj;
                                         XTHistoryItem *parent = [index objectForKey:parentSha];
                                         if (parent != nil) {
                                             [item.parents addObject:parent];
                                         } else {
                                             NSLog(@"parent with sha:'%@' not found for commit with sha:'%@' idx=%lu", parentSha, item.sha, item.index);
                                         }
                                     }];
                                }
                                item.date = [NSDate dateFromRFC2822:[comps objectAtIndex:2]];
                                item.email = [comps objectAtIndex:3];
                                item.subject = [comps objectAtIndex:4];
                                [newItems addObject:item];
                                [index setObject:item forKey:item.sha];
                            } else {
                                [NSException raise:@"Invalid commint" format:@"Line ***\n%@\n*** is invalid", line];
                            }

                        }
                                             error:nil];

                       if ([newItems count] > 0) {
                           NSUInteger i = 0;
                           NSUInteger j = [newItems count] - 1;
                           while (i < j) {
                               [newItems exchangeObjectAtIndex:i++ withObjectAtIndex:j--];
                           }
                       }

                       PBGitGrapher *grapher = [[PBGitGrapher alloc] init];
                       [newItems enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL * stop) {
                            XTHistoryItem *item = (XTHistoryItem *)obj;
                            [grapher decorateCommit:item];
                            item.index = idx;
                        }];

                       [XTStatusView updateStatus:[NSString stringWithFormat:@"%d commits loaded", [newItems count]] command:nil output:@"" forRepository:repo];
                       NSLog (@"-> %lu", [newItems count]);
                       items = newItems;
                       [table reloadData];
                   });
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
    return [items count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
    XTHistoryItem *item = [items objectAtIndex:rowIndex];

    return [item valueForKey:aTableColumn.identifier];
}

// TODO: move this to the view controller
#pragma mark - NSTableViewDelegate

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
    NSLog(@"%@", aNotification);
    XTHistoryItem *item = [items objectAtIndex:table.selectedRow];
    repo.selectedCommit = item.sha;
}

// These values came from measuring where the Finder switches styles
const NSUInteger
    kFullStyleThreshold = 280,
    kLongStyleThreshold = 210,
    kMediumStyleThreshold = 170,
    kShortStyleThreshold = 150;
    // kShortestStyleThreshold = 145;

- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
    if ([[aTableColumn identifier] isEqualToString:@"subject"]) {
        XTHistoryItem *item = [items objectAtIndex:rowIndex];

        ((PBGitRevisionCell *)aCell).objectValue = item;
    } else if ([[aTableColumn identifier] isEqualToString:@"date"]) {
        // TODO: Shortest style - time for today, date for other days
        const CGFloat width = [aTableColumn width];
        NSDateFormatterStyle dateStyle = NSDateFormatterShortStyle;

        if (width > kFullStyleThreshold)
            dateStyle = NSDateFormatterFullStyle;
        else if (width > kLongStyleThreshold)
            dateStyle = NSDateFormatterLongStyle;
        else if (width > kMediumStyleThreshold)
            dateStyle = NSDateFormatterMediumStyle;
        [[aCell formatter] setDateStyle:dateStyle];
    }
}

@end

@implementation NSDate (RFC2822)

+ (NSDateFormatter *)rfc2822Formatter {
    static NSDateFormatter *formatter = nil;
    if (formatter == nil) {
        formatter = [[NSDateFormatter alloc] init];
        NSLocale *enUS = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
        [formatter setLocale:enUS];
        [enUS release];
        [formatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss ZZ"];
    }
    return formatter;
}

+ (NSDate *)dateFromRFC2822:(NSString *)rfc2822 {
    NSDateFormatter *formatter = [NSDate rfc2822Formatter];
    __block NSDate *result = nil;

    dispatch_sync(dispatch_get_main_queue(),
                  ^{ result = [formatter dateFromString:rfc2822]; });
    return result;
}

@end
