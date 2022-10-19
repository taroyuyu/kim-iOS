//
//  KIMRosterDeleteFriendRequest.m
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/30.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMRosterDeleteFriendRequest.h"

@implementation KIMRosterDeleteFriendRequest
-(instancetype)initWithUser:(KIMUser*)targetUser completion:(KIMRosterDeleteFriendRequestCompletion)completion andCallbackQueue:(NSOperationQueue*)callbackQueue
{
    if (!targetUser.account.length) {
        return nil;
    }
    
    self = [super init];
    
    if (self) {
        self.targetUser = targetUser;
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
