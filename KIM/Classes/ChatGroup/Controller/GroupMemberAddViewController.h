//
//  GroupMemberAddViewController.h
//  HUTLife
//
//  Created by Kakawater on 2018/12/25.
//  Copyright © 2018 Kakawater. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
@class KIMChatGroup;
@interface GroupMemberAddViewController : UITableViewController
@property(nonatomic,strong)KIMChatGroup * chatGroup;
+(instancetype)groupMemberAddViewControllerWithChatGroup:(KIMChatGroup*)chatGroup;
@end

NS_ASSUME_NONNULL_END
