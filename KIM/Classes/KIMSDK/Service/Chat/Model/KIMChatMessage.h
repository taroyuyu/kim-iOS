//
//  KIMChatMessage.h
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/31.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KIMUser.h"
typedef NS_ENUM(NSUInteger,KIMChatMessageType)
{
    KIMChatMessageType_Text,//文本消息
};

typedef NS_ENUM(NSUInteger,KIMChatMessageState){
    KIMChatMessageState_Sending,//正在发送
    KIMChatMessageState_Received,//服务器已收到
    KIMChatMessageState_FromServer,//从服务器拉取得到的
};

@interface KIMChatMessage : NSObject
@property(nonatomic,assign)KIMChatMessageType type;
@property(nonatomic,assign)KIMChatMessageState state;
@property(nonatomic,strong)KIMUser * sender;
@property(nonatomic,strong)KIMUser * receiver;
@property(nonatomic,strong)NSString * content;
@property(nonatomic,strong)NSDate * timestamp;
@property(nonatomic,assign)int64_t messageId;
@end
