//
//  GroupMemberListViewController.h
//  HUTLife
//
//  Created by Kakawater on 2018/4/25.
//  Copyright © 2018年 Kakawater. All rights reserved.
//

#import <UIKit/UIKit.h>
@class KIMChatGroup;
@interface GroupMemberListViewController : UICollectionViewController
@property(nonatomic,strong)KIMChatGroup * chatGroup;
+(instancetype)groupMemberListViewControllerWithChatGroup:(KIMChatGroup*)chatGroup;
@end
