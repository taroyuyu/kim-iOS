//
//  KIMGroupMemberListRequest.h
//  HUTLife
//
//  Created by taroyuyu on 2018/6/6.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import <Foundation/Foundation.h>
@class KIMChatGroup;
@class KIMGroupMemberListRequest;
@class KIMUser;
typedef NS_ENUM(NSUInteger,KIMGroupMemberListRequestState)
{
    KIMGroupMemberListRequestState_Timeout,//超时
    KIMGroupMemberListRequestState_ServerInternalError,//服务器内部错误
    KIMGroupMemberListRequestState_Success,//成功
};

typedef void(^KIMGroupMemberListRequestStateCompletion)(KIMGroupMemberListRequest * request,NSArray<KIMUser*> * memberList,KIMGroupMemberListRequestState state);

@interface KIMGroupMemberListRequest : NSObject
@property(nonatomic,strong)KIMChatGroup * chatGroup;
@property(nonatomic,strong)KIMGroupMemberListRequestStateCompletion completion;
@property(nonatomic,strong)NSOperationQueue * callbackQueue;
-(instancetype)initWithChatGroup:(KIMChatGroup*)chatGroup completion:(KIMGroupMemberListRequestStateCompletion)completion andCallbackQueue:(NSOperationQueue*)callbackQueue;
@end
