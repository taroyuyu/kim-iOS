//
//  KIMGroupQuitRequest.h
//  HUTLife
//
//  Created by taroyuyu on 2018/6/6.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "KIMChatGroup.h"

@class KIMGroupQuitRequest;

typedef NS_ENUM(NSUInteger,KIMGroupQuitRequestState)
{
    KIMGroupQuitRequestState_Timeout,//超时
    KIMGroupQuitRequestState_ServerInternalError,//服务器内部错误
    KIMGroupQuitRequestState_Success,//成功
};

typedef void(^KIMGroupQuitRequestCompletion)(KIMGroupQuitRequest * request,KIMGroupQuitRequestState state);

@interface KIMGroupQuitRequest : NSObject
@property(nonatomic,strong)KIMChatGroup * chatGroup;
@property(nonatomic,strong)KIMGroupQuitRequestCompletion completion;
@property(nonatomic,strong)NSOperationQueue * callbackQueue;
-(instancetype)initWithChatGroup:(KIMChatGroup*)chatGroup completion:(KIMGroupQuitRequestCompletion)completion andCallbackQueue:(NSOperationQueue*)callbackQueue;
@end
