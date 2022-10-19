//
//  KIMChatGroupMessage.h
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/31.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KIMUser.h"
#import "KIMChatGroup.h"
typedef NS_ENUM(NSUInteger,KIMChatGroupMessageType)
{
    KIMChatGroupMessageType_Text,//文本消息
};

typedef NS_ENUM(NSUInteger,KIMChatGroupMessageState){
    KIMChatGroupMessageState_Sending,//正在发送
    KIMChatGroupMessageState_Received,//服务器已收到
    KIMChatGroupMessageState_FromServer,//从服务器接收
};

@interface KIMChatGroupMessage : NSObject
@property(nonatomic,assign)KIMChatGroupMessageType type;
@property(nonatomic,assign)KIMChatGroupMessageState state;
@property(nonatomic,strong)KIMUser * sender;
@property(nonatomic,strong)KIMChatGroup * group;
@property(nonatomic,strong)NSString * content;
@property(nonatomic,strong)NSDate * timestamp;
@property(nonatomic,assign)uint64_t messageId;
@end
