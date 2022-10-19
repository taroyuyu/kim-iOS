//
//  KIMGroupJoinApplication.h
//  HUTLife
//
//  Created by taroyuyu on 2018/4/23.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KIMChatGroup.h"
#import "KIMUser.h"

typedef NS_ENUM(NSUInteger,KIMGroupJoinApplicationState){
    KIMGroupJoinApplicationState_Pending,// 入群申请待处理
    KIMGroupJoinApplicationState_Allowm,//入群申请已同意
    KIMGroupJoinApplicationState_Reject//入群申请已拒绝
};

@interface KIMGroupJoinApplication : NSObject
@property(nonatomic,assign)ino64_t applicantId;
@property(nonatomic,strong)KIMChatGroup * chatGroup;
@property(nonatomic,strong)KIMUser * applicant;
@property(nonatomic,strong)NSString * introduction;
@property(nonatomic,assign)KIMGroupJoinApplicationState state;
@end
