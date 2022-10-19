//
//  KIMChatGroupSession.h
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/31.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KIMChatGroup.h"
#import "KIMUser.h"
#import "KIMChatGroupMessage.h"
@class KIMChatModule;
@protocol KIMGroupChatSessionDelegate;
@interface KIMChatGroupSession : NSObject<NSCopying,NSCoding>
@property(nonatomic,readonly)KIMUser * currentUser;
@property(nonatomic,readonly)KIMChatGroup * currentChatGroup;
@property(nonatomic,weak)NSObject<KIMGroupChatSessionDelegate> * delegate;//Delegate会在主线程被调用
-(KIMChatGroupMessage*)sendTextMessage:(NSString*)textMessage;
/**
 * @description 加载最新的消息,回调会在主线程执行
 * @param maxCount 本次最多加载多少条
 */
-(void)loadLastedMessageWithMaxCount:(NSUInteger)maxCount completion:(void(^)(KIMChatGroupSession * chatGroupSession,NSArray<KIMChatGroupMessage*> * messageList))completionBlock;
/**
 * @description 加载消息,回调会在主线程执行
 * @param maxCount 本次最多加载多少条
 * @param maxMessageId 消息Id的最大值
 */
-(void)loadMessage:(NSUInteger)maxCount withMaxMessageId:(uint64_t)maxMessageId completion:(void(^)(KIMChatGroupSession * chatGroupSession,NSArray<KIMChatGroupMessage*> * messageList))completionBlock;
@end

@protocol KIMGroupChatSessionDelegate
@optional
-(void)didChatGroupSessionReceivedMessage:(KIMChatGroupSession*)groupChatSession message:(KIMChatGroupMessage*)chatGroupMessage;
@end
