//
//  FriendApplicationNotificationMessageModel.h
//  HUTLife
//
//  Created by Kakawater on 2018/12/27.
//  Copyright © 2018 Kakawater. All rights reserved.
//

#import "MessageModel.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger,FriendApplicationPeerRole)
{
    FriendApplicationPeerRole_Sponsor,
    FriendApplicationPeerRole_Target,
};

@interface FriendApplicationNotificationMessageModel : MessageModel
@property(nonatomic,copy)NSNumber * applicationId;
@property(nonatomic,assign)FriendApplicationPeerRole peerRole;
@property(nonatomic,copy)NSString * peerAccount;
@property(nonatomic,copy)NSString * introduction;
@end

NS_ASSUME_NONNULL_END
