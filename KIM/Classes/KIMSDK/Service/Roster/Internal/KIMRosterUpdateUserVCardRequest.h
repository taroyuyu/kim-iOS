//
//  KIMRosterUpdateUserVCardRequest.h
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/30.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KIMUserVCard.h"
@class KIMRosterUpdateUserVCardRequest;

typedef NS_ENUM(NSUInteger,KIMRosterUpdateUserVCardRequestState)
{
    KIMRosterUpdateUserVCardRequestState_Timeout,//超时
    KIMRosterUpdateUserVCardRequestState_ServerInternalError,//服务器内部错误
    KIMRosterUpdateUserVCardRequestState_Success,//成功
};
typedef void(^KIMRosterUpdateUserVCardRequestCompletion)(KIMRosterUpdateUserVCardRequest * request,KIMRosterUpdateUserVCardRequestState state);

@interface KIMRosterUpdateUserVCardRequest : NSObject
@property(nonatomic,strong)KIMUserVCard * userVCard;
@property(nonatomic,strong)KIMRosterUpdateUserVCardRequestCompletion completion;
@property(nonatomic,strong)NSOperationQueue * callbackQueue;
-(instancetype)initWithUserVCard:(KIMUserVCard*)userVCard completion:(KIMRosterUpdateUserVCardRequestCompletion)completion andCallbackQueue:(NSOperationQueue*)callbackQueue;
@end
