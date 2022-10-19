//
//  KIMNodeRequest.m
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/26.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMNodeRequest.h"
#import "KakaImclientPresident.pbobjc.h"
#import "KIMRequest+Internal.h"
@interface KIMNodeRequest ()
@property(nonatomic,strong)KIMNodeRequestCompletion completionCallback;
@end

@implementation KIMNodeRequest
-(instancetype)initWithServerAddr:(NSString*const)serverAddr serverPort:(const unsigned short)serverPort userAccount:(NSString*const)userAccount longitude:(const float)longitude latitude:(const float)latitude andCompletion:(KIMNodeRequestCompletion)completion
{
    self = [super initWithServerAddr:serverAddr serverPort:serverPort];
    
    if (self && [userAccount length]) {
        self.userAccount = userAccount;
        self.longitude = longitude;
        self.latitude = latitude;
        self.completionCallback = completion;
    }
    
    return self;
}
-(void)failedWithError:(KIMRequestFailedType)failedType
{
    //在主队列中中调用回调函数
    if (self.completionCallback) {
        __weak KIMNodeRequest * weakSelf = self;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            weakSelf.completionCallback(weakSelf, [NSError errorWithDomain:@"KIMNodeRequest" code:failedType userInfo:nil], nil);
        });
    }
}
-(GPBMessage*)requestMessage
{
    KIMProtoRequestNodeMessage * message = [[KIMProtoRequestNodeMessage alloc] init];
    message.userAccount = self.userAccount;
    message.longitude = self.longitude;
    message.latitude = self.latitude;
    return message;
}
-(void)handleResponse:(GPBMessage*)message
{
    if (!self.completionCallback) {
        return;
    }
    if (![message.descriptor.fullName isEqualToString:KIMProtoResponseNodeMessage.descriptor.fullName]) {
        self.completionCallback(self,[NSError errorWithDomain:NSStringFromClass(self.class) code:-2 userInfo:nil], nil);
        return;
    }
    KIMProtoResponseNodeMessage * responseMessage = (KIMProtoResponseNodeMessage*)message;
    
    if ([responseMessage hasErrorType]) {
        if (self.completionCallback) {
            __weak KIMNodeRequest * weakSelf = self;
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                weakSelf.completionCallback(weakSelf, [NSError errorWithDomain:@"KIMNodeRequest" code:1 userInfo:nil], nil);
            });
        }
        return;
    }
    
    NSMutableArray<NSDictionary*> * nodeList = [NSMutableArray<NSDictionary*> array];
    for (KIMProtoNodeInfo * nodeInfo in responseMessage.nodeArray) {
        [nodeList addObject:@{@"ipAddr":nodeInfo.ipAddr,@"port":[NSNumber numberWithUnsignedLong:nodeInfo.port]}];
    }
    
    if (self.completionCallback) {
        __weak KIMNodeRequest * weakSelf = self;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            weakSelf.completionCallback(weakSelf, nil, nodeList);
        });
    }
}
@end
