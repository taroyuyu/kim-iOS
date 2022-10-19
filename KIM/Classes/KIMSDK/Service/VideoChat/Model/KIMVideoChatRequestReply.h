//
//  KIMVideoChatRequestReply.h
//  HUTLife
//
//  Created by taroyuyu on 2018/5/3.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KIMUser.h"
typedef NS_ENUM(NSUInteger,KIMVideoChatRequestReplyType){
    KIMVideoChatRequestReplyType_Accept,//接受
    KIMVideoChatRequestReplyType_Reject,//拒绝
    KIMVideoChatRequestReplyType_NoAnser,//无人接听
};

@interface KIMVideoChatRequestReply : NSObject
@property(nonatomic,assign)uint64_t offerId;
@property(nonatomic,strong)KIMUser * sponsor;
@property(nonatomic,strong)KIMUser * target;
@property(nonatomic,assign)KIMVideoChatRequestReplyType reply;
@property(nonatomic,strong)NSDate * submissionTime;
@end
