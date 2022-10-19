//
//  GroupCreateRequest.h
//  HUTLife
//
//  Created by taroyuyu on 2018/6/6.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import <Foundation/Foundation.h>
@class KIMGroupCreateRequest;

typedef NS_ENUM(NSUInteger,KIMGroupCreateRequestState)
{
    KIMGroupCreateRequestState_Timeout,//超时
    KIMGroupCreateRequestState_ServerInternalError,//服务器内部错误
    KIMGroupCreateRequestState_Success,//成功
};

typedef void(^KIMGroupCreateRequestCompletion)(KIMGroupCreateRequest * request,NSString * groupId,KIMGroupCreateRequestState state);

@interface KIMGroupCreateRequest : NSObject
@property(nonatomic,strong)NSString * groupName;
@property(nonatomic,strong)NSString * groupDescription;
@property(nonatomic,strong)KIMGroupCreateRequestCompletion completion;
@property(nonatomic,strong)NSOperationQueue * callbackQueue;
-(instancetype)initWithGroupName:(NSString*)groupName groupDescription:(NSString*)groupDescription completion:(KIMGroupCreateRequestCompletion)completion andCallbackQueue:(NSOperationQueue*)callbackQueue;
@end
