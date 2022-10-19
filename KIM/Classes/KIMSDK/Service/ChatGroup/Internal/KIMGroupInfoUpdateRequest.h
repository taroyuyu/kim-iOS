//
//  GroupInfoUpdateRequest.h
//  HUTLife
//
//  Created by taroyuyu on 2018/6/6.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KIMChatGroupInfo.h"

@class KIMGroupInfoUpdateRequest;

typedef NS_ENUM(NSUInteger,KIMGroupInfoUpdateRequestState)
{
    KIMGroupInfoUpdateRequestState_Timeout,//超时
    KIMGroupInfoUpdateRequestState_InfomationNotMatch,
    KIMGroupInfoUpdateRequestState_AuthorizationNotMath,
    KIMGroupInfoUpdateRequestState_ServerInternalError,//服务器内部错误
    KIMGroupInfoUpdateRequestState_Success,//成功
};

typedef void(^KIMGroupInfoUpdateRequestCompletion)(KIMGroupInfoUpdateRequest * request,KIMGroupInfoUpdateRequestState state);

@interface KIMGroupInfoUpdateRequest : NSObject
@property(nonatomic,strong)KIMChatGroupInfo * chatGroupInfo;
@property(nonatomic,strong)KIMGroupInfoUpdateRequestCompletion completion;
@property(nonatomic,strong)NSOperationQueue * callbackQueue;
-(instancetype)initWithChatGroupInfo:(KIMChatGroupInfo*)chatGroupInfo completion:(KIMGroupInfoUpdateRequestCompletion)completion andCallbackQueue:(NSOperationQueue*)callbackQueue;
@end
