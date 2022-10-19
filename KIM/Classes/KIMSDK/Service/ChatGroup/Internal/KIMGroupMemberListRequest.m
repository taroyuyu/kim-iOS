//
//  KIMGroupMemberListRequest.m
//  HUTLife
//
//  Created by taroyuyu on 2018/6/6.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMGroupMemberListRequest.h"

@implementation KIMGroupMemberListRequest
-(instancetype)initWithChatGroup:(KIMChatGroup*)chatGroup completion:(KIMGroupMemberListRequestStateCompletion)completion andCallbackQueue:(NSOperationQueue*)callbackQueue
{
    if (!chatGroup) {
        return nil;
    }
    
    self = [super init];
    
    if (self) {
        self.chatGroup = chatGroup;
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
