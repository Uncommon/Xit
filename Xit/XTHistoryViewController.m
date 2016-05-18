#import "XTHistoryViewController.h"
#import "XTDocController.h"
#import "XTFileViewController.h"
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

- (id)initWithRepository:(XTRepository *)repository
                 sidebar:(XTSideBarOutlineView *)sidebar
{
  if ((self = [self init]) == nil)
    return nil;

  _repo = repository;
  _sidebarOutline = sidebar;
  _sideBarDS = [[XTSideBarDataSource alloc] init];
  _savedSidebarWidth = 180;
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)loadView
{
  [super loadView];

  // Load the context menus
  NSNib *nib = [[NSNib alloc] initWithNibNamed:@"HistoryView Menus" bundle:nil];

  [nib instantiateWithOwner:self topLevelObjects:NULL];

  // Load the file list view
  NSView *lowerPane = [_mainSplitView subviews][1];
  
  _fileViewController = [[XTFileViewController alloc]
      initWithNibName:@"XTFileViewController" bundle:nil];
  [lowerPane addSubview:_fileViewController.view];
  [_fileViewController.view setFrameSize:[lowerPane frame].size];
  [[NSNotificationCenter defaultCenter]
      addObserver:_fileViewController
         selector:@selector(commitSelected:)
             name:NSTableViewSelectionDidChangeNotification
           object:_historyTable];

  // Remove intercell spacing so the history lines will connect
  NSSize cellSpacing = [_historyTable intercellSpacing];
  cellSpacing.height = 0;
  [_historyTable setIntercellSpacing:cellSpacing];

  // Without this, the first group title moves when you hide its contents
  [_sidebarOutline setFloatsGroupRows:NO];
}

- (NSString*)nibName
{
  NSLog(@"nibName: %@ (%@)", [super nibName], [self class]);
  return NSStringFromClass([self class]);
}

- (void)windowDidLoad
{
  [_fileViewController windowDidLoad];
  [self.view.window.windowController addObserver:self
                                      forKeyPath:@"selectedCommitSHA"
                                         options:NSKeyValueObservingOptionNew
                                         context:NULL];
}

- (void)setRepo:(XTRepository*)newRepo
{
  _repo = newRepo;
  [_sideBarDS setRepo:newRepo];
  [_historyDS setRepo:newRepo];
  [_fileViewController setRepo:newRepo];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
  const SEL action = [menuItem action];
  XTSideBarItem *item =
      (XTSideBarItem *)[_sidebarOutline itemAtRow:_sidebarOutline.contextMenuRow];

  if ((action == @selector(checkOutBranch:)) ||
      (action == @selector(renameBranch:)) ||
      (action == @selector(mergeBranch:)) ||
      (action == @selector(deleteBranch:))) {
    if (![item isKindOfClass:[XTLocalBranchItem class]])
      return NO;
    if (_repo.isWriting)
      return NO;
    if (action == @selector(deleteBranch:))
      return ![[_repo currentBranch] isEqualToString:[item title]];
    if (action == @selector(mergeBranch:)) {
      NSString *clickedBranch = [item title];
      NSString *currentBranch = [_repo currentBranch];

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
    if (_repo.isWriting)
      return NO;
    return [item isKindOfClass:[XTTagItem class]];
  }
  if ((action == @selector(renameRemote:)) ||
      (action == @selector(deleteRemote:))) {
    if (_repo.isWriting)
      return NO;
    return [_sidebarOutline parentForItem:item] ==
           (_sideBarDS.roots)[XTRemotesGroupIndex];
  }
  if (action == @selector(copyRemoteURL:)) {
    return [_sidebarOutline parentForItem:item] ==
           (_sideBarDS.roots)[XTRemotesGroupIndex];
  }
  if ((action == @selector(popStash:)) || (action == @selector(applyStash:)) ||
      (action == @selector(dropStash:))) {
    if (_repo.isWriting)
      return NO;
    return [item isKindOfClass:[XTStashItem class]];
  }

  return NO;
}

- (void)selectRowForSHA:(NSString*)sha
{
  // Assuming the first responder originated the change
  const id firstResponder = self.view.window.firstResponder;

  if (firstResponder != _sidebarOutline)
    [_sidebarOutline deselectAll:self];

  const NSUInteger historyRow = [_historyDS.shas indexOfObject:sha];
  
  if (historyRow == NSNotFound)
    [_historyTable deselectAll:self];
  else {
    [_historyTable selectRowIndexes:[NSIndexSet indexSetWithIndex:historyRow]
               byExtendingSelection:NO];
    if (firstResponder != _historyTable)
      [_historyTable scrollRowToVisible:historyRow];
  }
}

- (void)observeValueForKeyPath:(NSString*)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSString*,id>*)change
                       context:(void*)context
{
  if ([keyPath isEqualToString:@"selectedCommitSHA"]) {
    [self selectRowForSHA:change[NSKeyValueChangeNewKey]];
  }
}

- (NSInteger)targetRow
{
  NSInteger row = _sidebarOutline.contextMenuRow;

  if (row != -1)
    return row;
  return _sidebarOutline.selectedRow;
}

- (void)callCMBlock:(void (^)(XTSideBarItem *item, NSError **error))block
     verifyingClass:(Class) class
        errorString:(NSString *)errorString {
  XTSideBarItem *item = [_sidebarOutline itemAtRow:[self targetRow]];

  if ([item isKindOfClass:class]) {
    [_repo executeOffMainThread:^{
      NSError *error = nil;
      
      block(item, & error);
      if (error != nil)
        [XTStatusView
          updateStatus:errorString
               command:[[error userInfo] valueForKey:XTErrorArgsKey]
                output:[[error userInfo] valueForKey:XTErrorOutputKey]
         forRepository:_repo];
    }];
  }
}

- (IBAction) checkOutBranch:(id)sender
{
  [self callCMBlock:^(XTSideBarItem *item, NSError *__autoreleasing *error) {
                      [_repo checkout:[item title] error:error]; }
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

  if ([_repo merge:branch error:&error]) {
    NSString *mergeStatus =[NSString stringWithFormat:
        @"Merged %@ into %@", branch, [_repo currentBranch]];

    [XTStatusView updateStatus:mergeStatus
                       command:nil
                        output:nil
                 forRepository:_repo];
  } else {
    NSDictionary *errorInfo = [error userInfo];

    [XTStatusView updateStatus:@"Merge failed"
                       command:errorInfo[XTErrorArgsKey]
                        output:errorInfo[XTErrorOutputKey]
                 forRepository:_repo];
  }
}

- (IBAction)deleteBranch:(id)sender
{
  [self callCMBlock:^(XTSideBarItem *item, NSError *__autoreleasing *error) {
                      [_repo deleteBranch:[item title] error:error]; }
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
                      [_repo deleteTag:[item title] error:error]; }
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
                      [_repo deleteRemote:[item title] error:error]; }
     verifyingClass:[XTRemoteItem class]
        errorString:@"Delete remote failed"];
}

- (IBAction)copyRemoteURL:(id)sender {
  NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];
  XTSideBarItem *item =
      [_sidebarOutline itemAtRow:[_sidebarOutline contextMenuRow]];
  NSString *remoteName =
      [[NSString alloc] initWithFormat:@"remote.%@.url", [item title]];
  NSString *remoteURL = [_repo urlStringForRemote:remoteName];
  
  [pasteBoard declareTypes:@[NSStringPboardType] owner:nil];
  
  if ([remoteURL length] > 0) {
    [pasteBoard setString:remoteURL forType:NSStringPboardType];
  }
}

- (IBAction)popStash:(id)sender
{
  [self callCMBlock:^(XTSideBarItem *item, NSError *__autoreleasing *error) {
                      [_repo popStash:[item title] error:error]; }
     verifyingClass:[XTStashItem class]
        errorString:@"Pop stash failed"];
}

- (IBAction)applyStash:(id)sender
{
  [self callCMBlock:^(XTSideBarItem *item, NSError **error) {
                      [_repo applyStash:[item title] error:error]; }
     verifyingClass:[XTStashItem class]
        errorString:@"Apply stash failed"];
}

- (IBAction)dropStash:(id)sender
{
  [self callCMBlock:^(XTSideBarItem *item, NSError **error) {
                      [_repo dropStash:[item title] error:error]; }
     verifyingClass:[XTStashItem class]
        errorString:@"Drop stash failed"];
}

- (IBAction)toggleLayout:(id)sender
{
  [_mainSplitView setVertical:(((NSButton *)sender).state == 1)];
  [_mainSplitView adjustSubviews];
}

- (IBAction)toggleSideBar:(id)sender
{
  const NSInteger buttonState = [(NSButton *)sender state];
  const CGFloat newWidth = (buttonState == NSOnState) ? _savedSidebarWidth : 0;

  if (buttonState == NSOffState)
    _savedSidebarWidth = [[_sidebarSplitView subviews][0] frame].size.width;
  [_sidebarSplitView setPosition:newWidth ofDividerAtIndex:0];
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
      [_repo renameBranch:oldName to:newName];
      break;

    case XTRefTypeTag:
      [_repo renameTag:oldName to:newName];
      break;

    case XTRefTypeRemote:
      [_repo renameRemote:oldName to:newName];
      break;

    default:
      break;
  }
}

- (void)editSelectedSidebarRow
{
  [_sidebarOutline editColumn:0 row:[self targetRow] withEvent:nil select:YES];
}

- (NSString *)selectedBranch
{
  id selection = [_sidebarOutline itemAtRow:[_sidebarOutline selectedRow]];

  if (selection == nil)
    return nil;
  if ([selection isKindOfClass:[XTLocalBranchItem class]])
    return [(XTLocalBranchItem *)selection title];
  return nil;
}

- (void)selectBranch:(NSString *)branch
{
  XTLocalBranchItem *branchItem = (XTLocalBranchItem*)
      [_sideBarDS itemNamed:branch
                    inGroup:XTBranchesGroupIndex];

  if (branchItem != nil) {
    [_sidebarOutline expandItem:[_sidebarOutline itemAtRow:XTBranchesGroupIndex]];

    const NSInteger row = [_sidebarOutline rowForItem:branchItem];

    if (row != -1)
      [_sidebarOutline selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
                   byExtendingSelection:NO];
  }
}

#pragma mark - NSSplitViewDelegate

- (BOOL)splitView:(NSSplitView*)splitView
    shouldAdjustSizeOfSubview:(NSView*)view
{
  return view != [splitView subviews][0];
}

#pragma mark - NSTableViewDelegate

- (void)tableViewSelectionDidChange:(NSNotification *)note
{
  NSTableView *table = (NSTableView *)[note object];
  const NSInteger selectedRow = table.selectedRow;

  if (selectedRow >= 0) {
    XTDocController *controller = self.view.window.windowController;

    controller.selectedCommitSHA = _historyDS.shas[selectedRow];
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
    XTHistoryItem *item = [_historyDS itemAtIndex:rowIndex];

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

#pragma mark - NSTabViewDelegate

- (void)tabView:(NSTabView *)tabView
    didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
  if ([[tabViewItem identifier] isEqualToString:@"tree"])
    [_fileViewController refresh];
}

@end
