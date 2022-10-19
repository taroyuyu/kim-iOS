//
//  KIMChatSession.h
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/31.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KIMUser.h"
#import "KIMChatMessage.h"
@class KIMChatModule;
@protocol KIMChatSessionDelegate;
@interface KIMChatSession : NSObject<NSCopying,NSCoding>
@property(nonatomic,readonly)KIMUser * currentUser;
@property(nonatomic,readonly)KIMUser * opponent;
@property(nonatomic,weak)NSObject<KIMChatSessionDelegate> * delegate;//Delegate会在主线程被调用
-(KIMChatMessage*)sendTextMessage:(NSString*)textMessage;
/**
 * @description 加载最新的消息,回调会在主线程执行
 * @param maxCount 本次最多加载多少条
 */
-(void)loadLastedMessageWithMaxCount:(NSUInteger)maxCount completion:(void(^)(KIMChatSession * chatSession,NSArray<KIMChatMessage*> * messageList))completionBlock;
/**
 * @description 加载消息,回调会在主线程执行
 * @param maxCount 本次最多加载多少条
 * @param maxMessageId 消息Id的最大值
 */
-(void)loadMessage:(NSUInteger)maxCount withMaxMessageId:(uint64_t)maxMessageId completion:(void(^)(KIMChatSession * chatSession,NSArray<KIMChatMessage*> * messageList))completionBlock;
@end

@protocol KIMChatSessionDelegate
@optional
-(void)didChatSessionReceivedMessage:(KIMChatSession*)chatSession message:(KIMChatMessage*)chatMessage;
@end
