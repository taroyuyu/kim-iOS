//
//  GroupCreateRequest.m
//  HUTLife
//
//  Created by taroyuyu on 2018/6/6.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMGroupCreateRequest.h"

@implementation KIMGroupCreateRequest
-(instancetype)initWithGroupName:(NSString*)groupName groupDescription:(NSString*)groupDescription completion:(KIMGroupCreateRequestCompletion)completion andCallbackQueue:(NSOperationQueue*)callbackQueue
{
    if (![groupName hasContent]) {
        return nil;
    }
    
    self = [super init];
    
    if (self) {
        self.groupName = groupName;
        self.groupDescription = groupDescription;
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
