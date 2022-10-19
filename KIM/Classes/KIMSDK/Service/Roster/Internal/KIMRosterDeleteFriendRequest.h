//
//  KIMRosterDeleteFriendRequest.h
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/30.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMUser.h"

@class KIMRosterDeleteFriendRequest;

typedef NS_ENUM(NSUInteger,KIMRosterDeleteFriendRequestState)
{
    KIMRosterDeleteFriendRequestState_Timeout,//超时
    KIMRosterDeleteFriendRequestState_ServerInternalError,//服务器内部错误
    KIMRosterDeleteFriendRequestState_Success,//成功
};
typedef void(^KIMRosterDeleteFriendRequestCompletion)(KIMRosterDeleteFriendRequest * request,KIMRosterDeleteFriendRequestState state);
@interface KIMRosterDeleteFriendRequest : NSObject
@property(nonatomic,strong)KIMUser * targetUser;
@property(nonatomic,strong)KIMRosterDeleteFriendRequestCompletion completion;
@property(nonatomic,strong)NSOperationQueue * callbackQueue;
-(instancetype)initWithUser:(KIMUser*)targetUser completion:(KIMRosterDeleteFriendRequestCompletion)completion andCallbackQueue:(NSOperationQueue*)callbackQueue;
@end
