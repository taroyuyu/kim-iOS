//
//  KIMVideoChatRequest.h
//  HUTLife
//
//  Created by taroyuyu on 2018/5/3.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KIMUser.h"

typedef NS_ENUM(NSUInteger,KIMVideoChatRequestSessionType)
{
    KIMVideoChatRequestSessionType_Voice,//语音通话
    KIMVideoChatRequestSessionType_Video,//视频通话
};

@interface KIMVideoChatRequest : NSObject
@property(nonatomic,assign)uint64_t offerId;
@property(nonatomic,assign)KIMVideoChatRequestSessionType sessionType;
@property(nonatomic,strong)KIMUser * sponsor;
@property(nonatomic,strong)KIMUser * target;
@property(nonatomic,strong)NSDate * submissionTime;
-(instancetype)initWithSponsor:(KIMUser*)sponsor target:(KIMUser*)target;
-(instancetype)initWithSponsor:(KIMUser *)sponsor target:(KIMUser *)target andSessionType:(KIMVideoChatRequestSessionType)sessionType;
@end
