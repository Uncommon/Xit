//
//  XTConstants.h
//  Xit
//
//  Created by David Catmull on 1/24/13.
//
//

typedef enum {
    XTRefTypeBranch,
    XTRefTypeActiveBranch,
    XTRefTypeRemote,
    XTRefTypeTag,
    XTRefTypeUnknown
} XTRefType;

typedef enum {
    XTBranchesGroupIndex,
    XTTagsGroupIndex,
    XTRemotesGroupIndex,
    XTStashesGroupIndex
} XTSideBarRootItems;
