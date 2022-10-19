//
//  KIMRosterUpdateUserVCardRequest.m
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/30.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMRosterUpdateUserVCardRequest.h"

@implementation KIMRosterUpdateUserVCardRequest
-(instancetype)initWithUserVCard:(KIMUserVCard*)userVCard completion:(KIMRosterUpdateUserVCardRequestCompletion)completion andCallbackQueue:(NSOperationQueue*)callbackQueue
{
    if (!userVCard.user.account.length) {
        return nil;
    }
    
    self = [super init];
    
    if (self) {
        self.userVCard = userVCard;
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
