//
//  KIMFriendApplication.h
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/27.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KIMUser.h"

typedef NS_ENUM(NSUInteger,KIMFriendApplicationState){
    KIMFriendApplicationState_Pending,//好友申请待处理
    KIMFriendApplicationState_Allowm,//好友申请已同意
    KIMFriendApplicationState_Reject//好友申请已拒绝
};

@interface KIMFriendApplication : NSObject
@property(nonatomic,strong)KIMUser * peerUser;
@property(nonatomic,strong)KIMUser * sponsor;
@property(nonatomic,strong)KIMUser * target;
@property(nonatomic,strong)NSString * introduction;
@property(nonatomic,assign)KIMFriendApplicationState state;
@property(nonatomic,assign)uint64_t  applicantId;
@property(nonatomic,strong)NSDate * submissionTime;
@end
