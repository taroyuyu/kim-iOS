//
//  GroupInfoUpdateRequest.m
//  HUTLife
//
//  Created by taroyuyu on 2018/6/6.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMGroupInfoUpdateRequest.h"

@implementation KIMGroupInfoUpdateRequest
-(instancetype)initWithChatGroupInfo:(KIMChatGroupInfo*)chatGroupInfo completion:(KIMGroupInfoUpdateRequestCompletion)completion andCallbackQueue:(NSOperationQueue*)callbackQueue
{
    if (!chatGroupInfo.chatGroup) {
        return nil;
    }
    
    if (self) {
        self.chatGroupInfo = chatGroupInfo;
        self.completion = completion;
        if (callbackQueue) {
            self.callbackQueue = callbackQueue;
        }else{
            self.callbackQueue = [[NSOperationQueue alloc] init];
        }
    }
    return self;
}
@end
