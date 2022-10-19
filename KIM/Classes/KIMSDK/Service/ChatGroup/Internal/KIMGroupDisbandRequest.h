//
//  GroupDisbandRequest.h
//  HUTLife
//
//  Created by taroyuyu on 2018/6/6.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KIMChatGroup.h"

@class KIMGroupDisbandRequest;

typedef NS_ENUM(NSUInteger,KIMGroupDisbandRequestState)
{
    KIMGroupDisbandRequestState_Timeout,//超时
    KIMGroupDisbandRequestState_ServerInternalError,//服务器内部错误
    KIMGroupDisbandRequestState_Success,//成功
};

typedef void(^KIMGroupDisbandRequestCompletion)(KIMGroupDisbandRequest * request,KIMGroupDisbandRequestState state);

@interface KIMGroupDisbandRequest : NSObject
@property(nonatomic,strong)KIMChatGroup * chatGroup;
@property(nonatomic,strong)KIMGroupDisbandRequestCompletion completion;
@property(nonatomic,strong)NSOperationQueue * callbackQueue;
-(instancetype)initWithChatGroup:(KIMChatGroup*)chatGroup completion:(KIMGroupDisbandRequestCompletion)completion andCallbackQueue:(NSOperationQueue*)callbackQueue;
@end
