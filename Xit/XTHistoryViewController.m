#import "XTHistoryViewController.h"
#import "XTFileViewController.h"
#import "XTRepository.h"
#import "XTRepository+Commands.h"
#import "XTSideBarDataSource.h"
#import "XTSideBarOutlineView.h"
#import "XTSideBarTableCellView.h"
#import "XTStatusView.h"
#import "Xit-Swift.h"
#import "NSAttributedString+XTExtensions.h"

@interface XTHistoryViewController ()

- (void)editSelectedSidebarRow;

@end

@implementation XTHistoryViewController

- (instancetype)initWithRepository:(XTRepository *)repository
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
  NSView *lowerPane = self.mainSplitView.subviews[1];
  
  _fileViewController = [[XTFileViewController alloc]
      initWithNibName:@"XTFileViewController" bundle:nil];
  [lowerPane addSubview:_fileViewController.view];
  [_fileViewController.view setFrameSize:lowerPane.frame.size];
  [[NSNotificationCenter defaultCenter]
      addObserver:_fileViewController
         selector:@selector(commitSelected:)
             name:NSTableViewSelectionDidChangeNotification
           object:_historyTable];

  // Remove intercell spacing so the history lines will connect
  NSSize cellSpacing = _historyTable.intercellSpacing;
  
  cellSpacing.height = 0;
  _historyTable.intercellSpacing = cellSpacing;

  // Without this, the first group title moves when you hide its contents
  [_sidebarOutline setFloatsGroupRows:NO];
}

- (NSString*)nibName
{
  NSLog(@"nibName: %@ (%@)", super.nibName, [self class]);
  return NSStringFromClass([self class]);
}

- (void)windowDidLoad
{
  [_fileViewController windowDidLoad];
}

- (void)setRepo:(XTRepository*)newRepo
{
  _repo = newRepo;
  [_sideBarDS setRepo:newRepo];
  [_fileViewController setRepo:newRepo];
  self.tableController.repository = newRepo;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
  const SEL action = menuItem.action;
  XTSideBarItem *item =
      (XTSideBarItem *)[_sidebarOutline itemAtRow:_sidebarOutline.contextMenuRow];

  if ((action == @selector(checkOutBranch:)) ||
      (action == @selector(renameBranch:)) ||
      (action == @selector(mergeBranch:)) ||
      (action == @selector(deleteBranch:))) {
    if ((item.refType != XTRefTypeBranch) &&
        (item.refType != XTRefTypeRemoteBranch))
      return NO;
    if (_repo.isWriting)
      return NO;
    if (action == @selector(deleteBranch:))
      return ![[_repo currentBranch] isEqualToString:item.title];
    if (action == @selector(mergeBranch:)) {
      NSString *clickedBranch = item.title;
      NSString *currentBranch = [_repo currentBranch];

      if (item.refType == XTRefTypeRemoteBranch) {
        clickedBranch = [NSString stringWithFormat:
            @"%@/%@", ((XTRemoteBranchItem *)item).remote, clickedBranch];
      } else if (item.refType == XTRefTypeBranch) {
        if ([clickedBranch isEqualToString:currentBranch]) {
          menuItem.attributedTitle = nil;
          menuItem.title = @"Merge";
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

      menuItem.attributedTitle = mergeTitle;
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
           (_sideBarDS.roots)[XTGroupIndexRemotes];
  }
  if (action == @selector(copyRemoteURL:)) {
    return [_sidebarOutline parentForItem:item] ==
           (_sideBarDS.roots)[XTGroupIndexRemotes];
  }
  if ((action == @selector(popStash:)) || (action == @selector(applyStash:)) ||
      (action == @selector(dropStash:))) {
    if (_repo.isWriting)
      return NO;
    return [item isKindOfClass:[XTStashItem class]];
  }

  return NO;
}

- (NSInteger)targetRow
{
  NSInteger row = _sidebarOutline.contextMenuRow;

  if (row != -1)
    return row;
  return _sidebarOutline.selectedRow;
}

- (void)callCMBlock:(void (^)(XTSideBarItem *item,
                              NSUInteger index,
                              NSError **error))block
     verifyingClass:(Class) class
        errorString:(NSString *)errorString {
  XTSideBarItem *item = [_sidebarOutline itemAtRow:[self targetRow]];

  if ([item isKindOfClass:class]) {
    XTSideBarItem *parent = [_sidebarOutline parentForItem:item];
    const NSUInteger index = [parent.children indexOfObject:item];
    
    [_repo executeOffMainThread:^{
      NSError *error = nil;
      
      block(item, index, &error);
      if (error != nil)
        [XTStatusView
          updateStatus:errorString
               command:[error.userInfo valueForKey:XTErrorArgsKey]
                output:[error.userInfo valueForKey:XTErrorOutputKey]
         forRepository:_repo];
    }];
  }
}

- (IBAction) checkOutBranch:(id)sender
{
  [self callCMBlock:^(XTSideBarItem *item, NSUInteger index, NSError **error) {
                      [_repo checkout:item.title error:error]; }
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
    NSDictionary *errorInfo = error.userInfo;

    [XTStatusView updateStatus:@"Merge failed"
                       command:errorInfo[XTErrorArgsKey]
                        output:errorInfo[XTErrorOutputKey]
                 forRepository:_repo];
  }
}

- (IBAction)deleteBranch:(id)sender
{
  [self callCMBlock:^(XTSideBarItem *item, NSUInteger index, NSError **error) {
                      [_repo deleteBranch:item.title error:error]; }
     verifyingClass:[XTLocalBranchItem class]
        errorString:@"Delete branch failed"];
}

- (IBAction)renameTag:(id)sender
{
  [self editSelectedSidebarRow];
}

- (IBAction)deleteTag:(id)sender
{
  [self callCMBlock:^(XTSideBarItem *item, NSUInteger index, NSError **error) {
                      [_repo deleteTag:item.title error:error]; }
     verifyingClass:[XTTagItem class]
        errorString:@"Delete tag failed"];
}

- (IBAction)renameRemote:(id)sender
{
  [self editSelectedSidebarRow];
}

- (IBAction)deleteRemote:(id)sender
{
  [self callCMBlock:^(XTSideBarItem *item, NSUInteger index, NSError **error) {
                      [_repo deleteRemote:item.title error:error]; }
     verifyingClass:[XTRemoteItem class]
        errorString:@"Delete remote failed"];
}

- (IBAction)copyRemoteURL:(id)sender {
  NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];
  XTSideBarItem *item =
      [_sidebarOutline itemAtRow:_sidebarOutline.contextMenuRow];
  NSString *remoteName =
      [[NSString alloc] initWithFormat:@"remote.%@.url", item.title];
  NSString *remoteURL = [_repo urlStringForRemote:remoteName];
  
  [pasteBoard declareTypes:@[NSStringPboardType] owner:nil];
  
  if (remoteURL.length > 0) {
    [pasteBoard setString:remoteURL forType:NSStringPboardType];
  }
}

- (IBAction)popStash:(id)sender
{
  [self callCMBlock:^(XTSideBarItem *item, NSUInteger index, NSError **error) {
                      [_repo popStashIndex:index error:error]; }
     verifyingClass:[XTStashItem class]
        errorString:@"Pop stash failed"];
}

- (IBAction)applyStash:(id)sender
{
  [self callCMBlock:^(XTSideBarItem *item, NSUInteger index, NSError **error) {
                      [_repo applyStashIndex:index error:error]; }
     verifyingClass:[XTStashItem class]
        errorString:@"Apply stash failed"];
}

- (IBAction)dropStash:(id)sender
{
  [self callCMBlock:^(XTSideBarItem *item, NSUInteger index, NSError **error) {
                      [_repo dropStashIndex:index error:error]; }
     verifyingClass:[XTStashItem class]
        errorString:@"Drop stash failed"];
}

- (IBAction)toggleSideBar:(id)sender
{
  NSView *sidebarPane = self.sidebarSplitView.subviews[0];
  const bool isCollapsed = [self.sidebarSplitView isSubviewCollapsed:sidebarPane];
  const CGFloat newWidth = isCollapsed
      ? _savedSidebarWidth
      : [self.sidebarSplitView minPossiblePositionOfDividerAtIndex:0];

  if (!isCollapsed)
    _savedSidebarWidth = sidebarPane.frame.size.width;
  [self.sidebarSplitView setPosition:newWidth ofDividerAtIndex:0];
  sidebarPane.hidden = !isCollapsed;
}

- (IBAction)sideBarItemRenamed:(id)sender
{
  XTSideBarTableCellView *cellView =
      (XTSideBarTableCellView *)[sender superview];
  XTSideBarItem *editedItem = cellView.item;
  NSString *newName = [sender stringValue];
  NSString *oldName = editedItem.title;

  if ([newName isEqualToString:oldName])
    return;

  switch ([editedItem refType]) {

    case XTRefTypeBranch:
      [_repo renameBranch:oldName to:newName];
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

- (NSString*)selectedBranch
{
  XTLocalBranchItem *selection =
      [_sidebarOutline itemAtRow:_sidebarOutline.selectedRow];

  if ([selection isKindOfClass:[XTLocalBranchItem class]])
    return selection.title;
  return nil;
}

- (void)selectBranch:(NSString *)branch
{
  XTLocalBranchItem *branchItem = (XTLocalBranchItem*)
      [_sideBarDS itemNamed:branch
                    inGroup:XTGroupIndexBranches];

  if (branchItem != nil) {
    [_sidebarOutline expandItem:[_sidebarOutline itemAtRow:XTGroupIndexBranches]];

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
  return view != splitView.subviews[0];
}

#pragma mark - NSTabViewDelegate

- (void)tabView:(NSTabView *)tabView
    didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
  if ([tabViewItem.identifier isEqualToString:@"tree"])
    [_fileViewController refresh];
}

@end
