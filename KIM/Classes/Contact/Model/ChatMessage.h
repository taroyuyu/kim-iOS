//
//  ChatMessage.h
//  HUTLife
//
//  Created by Kakawater on 2018/4/25.
//  Copyright © 2018年 Kakawater. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger,ChatMessageType)
{
    ChatMessageType_TextMessage,//文本消息
    ChatMessageType_ImageMessage//图像消息
};

@interface ChatMessage : NSObject
@property(nonatomic,assign)ChatMessageType type;
@property(nonatomic,strong)NSData * senderAvatar;
@property(nonatomic,strong)NSString * senderName;
@property(nonatomic,strong)NSString * textContent;
@property(nonatomic,strong)NSData * imageContent;
@property(nonatomic,strong)NSDate * timestamp;
@end
