#import "XTHistoryViewController.h"
#import "XTCommitViewController.h"
#import "XTHistoryDataSource.h"
#import "XTHistoryItem.h"
#import "XTLocalBranchItem.h"
#import "XTRemoteBranchItem.h"
#import "XTRemoteItem.h"
#import "XTRemotesItem.h"
#import "XTRepository.h"
#import "XTRepository+Commands.h"
#import "XTSideBarDataSource.h"
#import "XTSideBarOutlineView.h"
#import "XTSideBarTableCellView.h"
#import "XTStatusView.h"
#import "XTTagItem.h"
#import "NSAttributedString+XTExtensions.h"
#import "PBGitRevisionCell.h"

@interface XTHistoryViewController ()

- (void)editSelectedSidebarRow;

@end

@implementation XTHistoryViewController

@synthesize sideBarDS;
@synthesize historyDS;

- (id)initWithRepository:(XTRepository *)repository
                 sidebar:(XTSideBarOutlineView *)sidebar
{
  if ((self = [self init]) == nil)
    return nil;

  self->repo = repository;
  self->sidebarOutline = sidebar;
  self->sideBarDS = [[XTSideBarDataSource alloc] init];
  self->savedSidebarWidth = 180;
  return self;
}

- (void)awakeFromNib
{
  // Remove intercell spacing so the history lines will connect
  NSSize cellSpacing = [historyTable intercellSpacing];
  cellSpacing.height = 0;
  [historyTable setIntercellSpacing:cellSpacing];

  // Without this, the first group title moves when you hide its contents
  [sidebarOutline setFloatsGroupRows:NO];

  NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
  [menu addItemWithTitle:@"item" action:NULL keyEquivalent:@""];
  [sidebarOutline setMenu:menu];
}

- (NSString *)nibName
{
  NSLog(@"nibName: %@ (%@)", [super nibName], [self class]);
  return NSStringFromClass([self class]);
}

- (void)setRepo:(XTRepository *)newRepo
{
  repo = newRepo;
  [sideBarDS setRepo:newRepo];
  [historyDS setRepo:newRepo];
  [commitViewController setRepo:newRepo];
  [[commitViewController view] setFrame:NSMakeRect(
      0, 0, [commitView frame].size.width, [commitView frame].size.height)];
  [commitView addSubview:[commitViewController view]];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
  const SEL action = [menuItem action];
  XTSideBarItem *item =
      (XTSideBarItem *)[sidebarOutline itemAtRow:sidebarOutline.contextMenuRow];

  if ((action == @selector(checkOutBranch:)) ||
      (action == @selector(renameBranch:)) ||
      (action == @selector(mergeBranch:)) ||
      (action == @selector(deleteBranch:))) {
    if (![item isKindOfClass:[XTLocalBranchItem class]])
      return NO;
    if (action == @selector(deleteBranch:))
      return ![[repo currentBranch] isEqualToString:[item title]];
    if (action == @selector(mergeBranch:)) {
      NSString *clickedBranch = [item title];
      NSString *currentBranch = [repo currentBranch];

      if ([item isKindOfClass:[XTRemoteBranchItem class]]) {
        clickedBranch = [NSString stringWithFormat:
            @"%@/%@", [(XTRemoteBranchItem *)item remote], clickedBranch];
      } else if ([item isKindOfClass:[XTLocalBranchItem class]]) {
        if ([clickedBranch isEqualToString:currentBranch]) {
          [menuItem setAttributedTitle:nil];
          [menuItem setTitle:@"Merge"];
          return NO;
        }
      } else {
        return NO;
      }

      NSDictionary *menuFontAttributes =
          @{ NSFontAttributeName:[NSFont menuFontOfSize:0] };
      NSDictionary *obliqueAttributes = @{ NSObliquenessAttributeName:@0.15f };
      // TODO: handle detached HEAD case
      // "~" is used to guarantee that the placeholders are not valid branch
      // names.
      NSAttributedString *mergeTitle = [NSAttributedString
          attributedStringWithFormat:@"Merge @~1 into @~2"
                        placeholders:@[ @"@~1", @"@~2" ]
                        replacements:@[ clickedBranch, currentBranch ]
                          attributes:menuFontAttributes
               replacementAttributes:obliqueAttributes];

      [menuItem setAttributedTitle:mergeTitle];
    }
    if (action == @selector(deleteBranch:)) {
      // disable if it's the current branch
    }
    return YES;
  }
  if ((action == @selector(renameTag:)) || (action == @selector(deleteTag:))) {
    return [item isKindOfClass:[XTTagItem class]];
  }
  if ((action == @selector(renameRemote:)) ||
      (action == @selector(deleteRemote:))) {
    return [sidebarOutline parentForItem:item] ==
           (sideBarDS.roots)[XTRemotesGroupIndex];
  }
  if ((action == @selector(popStash:)) || (action == @selector(applyStash:)) ||
      (action == @selector(dropStash:))) {
    return [item isKindOfClass:[XTStashItem class]];
  }

  return NO;
}

- (NSInteger)targetRow
{
  NSInteger row = sidebarOutline.contextMenuRow;

  if (row != -1)
    return row;
  return sidebarOutline.selectedRow;
}

- (void)callCMBlock:(void (^)(XTSideBarItem *item, NSError **error))block
     verifyingClass:(Class) class
        errorString:(NSString *)errorString {
  XTSideBarItem *item = [sidebarOutline itemAtRow:[self targetRow]];

  if ([item isKindOfClass:class]) {
    dispatch_async(repo.queue, ^{
      NSError *error = nil;

      block(item, &error);
      if (error != nil)
        [XTStatusView
            updateStatus:errorString
                 command:[[error userInfo] valueForKey:XTErrorArgsKey]
                  output:[[error userInfo] valueForKey:XTErrorOutputKey]
           forRepository:repo];
    });
  }
}

- (IBAction) checkOutBranch : (id) sender
{
  [self callCMBlock:^(XTSideBarItem *item, NSError *__autoreleasing *error) {
    [repo checkout:[item title] error:error];
  }
     verifyingClass:[XTLocalBranchItem class]
        errorString:@"Checkout failed"];
}

- (IBAction)renameBranch:(id)sender
{
  [self editSelectedSidebarRow];
}

- (IBAction)mergeBranch:(id)sender
{
  NSString *branch = [self selectedBranch];

  if (branch == nil)
    return;

  NSError *error = nil;

  if ([repo merge:branch error:&error]) {
    NSString *mergeStatus =[NSString stringWithFormat:
        @"Merged %@ into %@", branch, [repo currentBranch]];

    [XTStatusView updateStatus:mergeStatus
                       command:nil
                        output:nil
                 forRepository:repo];
  } else {
    NSDictionary *errorInfo = [error userInfo];

    [XTStatusView updateStatus:@"Merge failed"
                       command:errorInfo[XTErrorArgsKey]
                        output:errorInfo[XTErrorOutputKey]
                 forRepository:repo];
  }
}

- (IBAction)deleteBranch:(id)sender
{
  [self callCMBlock:^(XTSideBarItem *item, NSError *__autoreleasing *error) {
    [repo deleteBranch:[item title] error:error];
  }
     verifyingClass:[XTLocalBranchItem class]
        errorString:@"Delete branch failed"];
}

- (IBAction)renameTag:(id)sender
{
  [self editSelectedSidebarRow];
}

- (IBAction)deleteTag:(id)sender
{
  [self callCMBlock:^(XTSideBarItem *item, NSError *__autoreleasing *error) {
    [repo deleteTag:[item title] error:error];
  }
     verifyingClass:[XTTagItem class]
        errorString:@"Delete tag failed"];
}

- (IBAction)renameRemote:(id)sender
{
  [self editSelectedSidebarRow];
}

- (IBAction)deleteRemote:(id)sender
{
  [self callCMBlock:^(XTSideBarItem *item, NSError *__autoreleasing *error) {
    [repo deleteRemote:[item title] error:error];
  }
     verifyingClass:[XTRemoteItem class]
        errorString:@"Delete remote failed"];
}

- (IBAction)popStash:(id)sender
{
  [self callCMBlock:^(XTSideBarItem *item, NSError *__autoreleasing *error) {
    [repo popStash:[item title] error:error];
  }
     verifyingClass:[XTStashItem class]
        errorString:@"Pop stash failed"];
}

- (IBAction)applyStash:(id)sender
{
  [self callCMBlock:^(XTSideBarItem *item, NSError **error) {
    [repo applyStash:[item title] error:error];
  }
     verifyingClass:[XTStashItem class]
        errorString:@"Apply stash failed"];
}

- (IBAction)dropStash:(id)sender
{
  [self callCMBlock:^(XTSideBarItem *item, NSError **error) {
    [repo dropStash:[item title] error:error];
  }
     verifyingClass:[XTStashItem class]
        errorString:@"Drop stash failed"];
}

- (IBAction)toggleLayout:(id)sender
{
  // TODO: improve it
  NSLog(@"toggleLayout, %lu,%d", ((NSButton *)sender).state,
        (((NSButton *)sender).state == 1));
  [mainSplitView setVertical:(((NSButton *)sender).state == 1)];
  [mainSplitView adjustSubviews];
}

- (IBAction)toggleSideBar:(id)sender
{
  const CGFloat newWidth =
      ([sender state] == NSOnState) ? savedSidebarWidth : 0;
  if ([sender state] == NSOffState)
    savedSidebarWidth = [[sidebarSplitView subviews][0] frame].size.width;
  [sidebarSplitView setPosition:newWidth ofDividerAtIndex:0];
}

- (IBAction)sideBarItemRenamed:(id)sender
{
  XTSideBarTableCellView *cellView =
      (XTSideBarTableCellView *)[sender superview];
  XTSideBarItem *editedItem = cellView.item;
  NSString *newName = [sender stringValue];
  NSString *oldName = [editedItem title];

  if ([newName isEqualToString:oldName])
    return;

  switch ([editedItem refType]) {

    case XTRefTypeBranch:
      [repo renameBranch:oldName to:newName];
      break;

    case XTRefTypeTag:
      [repo renameTag:oldName to:newName];
      break;

    case XTRefTypeRemote:
      [repo renameRemote:oldName to:newName];
      break;

    default:
      break;
  }
}

- (void)editSelectedSidebarRow
{
  [sidebarOutline editColumn:0 row:[self targetRow] withEvent:nil select:YES];
}

- (NSString *)selectedBranch
{
  id selection = [sidebarOutline itemAtRow:[sidebarOutline selectedRow]];

  if (selection == nil)
    return nil;
  if ([selection isKindOfClass:[XTLocalBranchItem class]])
    return [(XTLocalBranchItem *)selection title];
  return nil;
}

- (void)selectBranch:(NSString *)branch
{
  XTLocalBranchItem *branchItem =
      (XTLocalBranchItem *)[sideBarDS itemNamed:branch
                                        inGroup:XTBranchesGroupIndex];

  if (branchItem != nil) {
    [sidebarOutline expandItem:[sidebarOutline itemAtRow:XTBranchesGroupIndex]];

    const NSInteger row = [sidebarOutline rowForItem:branchItem];

    if (row != -1)
      [sidebarOutline selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
                  byExtendingSelection:NO];
  }
}

#pragma mark - NSTableViewDelegate

- (void)tableViewSelectionDidChange:(NSNotification *)note
{
  NSLog(@"%@", note);
  NSTableView *table = (NSTableView *)[note object];
  const NSInteger selectedRow = table.selectedRow;

  if (selectedRow >= 0) {
    XTHistoryItem *item = (historyDS.items)[selectedRow];
    repo.selectedCommit = item.sha;
  }
}

// These values came from measuring where the Finder switches styles.
const NSUInteger kFullStyleThreshold = 280, kLongStyleThreshold = 210,
                 kMediumStyleThreshold = 170, kShortStyleThreshold = 150;

- (void)tableView:(NSTableView *)tableView
  willDisplayCell:(id)cell
   forTableColumn:(NSTableColumn *)column
              row:(NSInteger)rowIndex
{
  [cell setFont:[NSFont labelFontOfSize:12]];

  if ([[column identifier] isEqualToString:@"subject"]) {
    XTHistoryItem *item = (historyDS.items)[rowIndex];

    ((PBGitRevisionCell *)cell).objectValue = item;
  } else if ([[column identifier] isEqualToString:@"date"]) {
    const CGFloat width = [column width];
    NSDateFormatterStyle dateStyle = NSDateFormatterShortStyle;
    NSDateFormatterStyle timeStyle = NSDateFormatterShortStyle;

    if (width > kFullStyleThreshold)
      dateStyle = NSDateFormatterFullStyle;
    else if (width > kLongStyleThreshold)
      dateStyle = NSDateFormatterLongStyle;
    else if (width > kMediumStyleThreshold)
      dateStyle = NSDateFormatterMediumStyle;
    else if (width > kShortStyleThreshold)
      dateStyle = NSDateFormatterShortStyle;
    else {
      dateStyle = NSDateFormatterShortStyle;
      timeStyle = NSDateFormatterNoStyle;
    }
    [[cell formatter] setDateStyle:dateStyle];
    [[cell formatter] setTimeStyle:timeStyle];
  }
}

@end
