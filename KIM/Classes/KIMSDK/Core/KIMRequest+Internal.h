//
//  KIMRequest+Internal.h
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/26.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMRequest.h"

typedef NS_ENUM(NSUInteger,KIMRequestFailedType)
{
    KIMRequestConnectionToServerFailed,//连接服务器失败
    KIMRequestCanceled,//请求被取消
    KIMRequesConnectionBroken,//连接断开
    KIMRequestTimeout,//连接超时
};

@class GPBMessage;

@interface KIMRequest (Internal)
-(void)failedWithError:(KIMRequestFailedType)failedType;
-(GPBMessage*)requestMessage;
-(void)handleResponse:(GPBMessage*)message;
@end
