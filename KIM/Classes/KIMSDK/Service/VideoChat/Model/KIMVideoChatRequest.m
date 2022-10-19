//
//  KIMVideoChatRequest.m
//  HUTLife
//
//  Created by taroyuyu on 2018/5/3.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMVideoChatRequest.h"
#import "KIMMediaSession.h"
@interface KIMVideoChatRequest()
@property(nonatomic,assign)BOOL isAcked;
@property(nonatomic,strong)NSString * requestIdentifier;
@property(nonatomic,strong)NSString * sponsorSessionId;
@property(nonatomic,weak)NSObject<KIMMediaSessionDelegate> * mediaSessionDelegate;
@end

@implementation KIMVideoChatRequest
-(instancetype)initWithSponsor:(KIMUser*)sponsor target:(KIMUser*)target
{
    self = [super init];
    
    if (self) {
        [self setSponsor:sponsor];
        [self setTarget:target];
        [self setSubmissionTime:[NSDate date]];
        [self setIsAcked:NO];
    }
    
    return self;
}
-(instancetype)initWithSponsor:(KIMUser *)sponsor target:(KIMUser *)target andSessionType:(KIMVideoChatRequestSessionType)sessionType
{
    self = [super init];
    
    if (self) {
        [self setSessionType:sessionType];
        [self setSponsor:sponsor];
        [self setTarget:target];
        [self setSubmissionTime:[NSDate date]];
        [self setIsAcked:NO];
    }
    
    return self;
}
@end
