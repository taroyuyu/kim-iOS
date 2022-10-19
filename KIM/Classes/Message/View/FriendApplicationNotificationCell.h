//
//  FriendApplicationNotificationCell.h
//  HUTLife
//
//  Created by Kakawater on 2018/12/27.
//  Copyright © 2018 Kakawater. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FriendApplicationNotificationMessageModel.h"
NS_ASSUME_NONNULL_BEGIN

@interface FriendApplicationNotificationCell : UITableViewCell
@property(nonatomic,strong)FriendApplicationNotificationMessageModel * model;
@end

NS_ASSUME_NONNULL_END
