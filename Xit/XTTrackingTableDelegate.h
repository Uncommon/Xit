//
//  XTTrackingTableDelegate.h
//  Xit
//
//  Created by German Laullon Padilla on 13/10/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
@class XTTrackingTableView;

@protocol XTTrackingTableDelegate <NSObject>

- (void)tableView:(XTTrackingTableView *)aTable mouseOverRow:(NSInteger)row;

@end
