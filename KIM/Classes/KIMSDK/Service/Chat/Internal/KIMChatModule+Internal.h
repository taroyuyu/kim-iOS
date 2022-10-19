//
//  KIMChatModule+Internal.h
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/31.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMChatModule.h"
@class KIMChatMessage;
@class KIMChatGroupMessage;
@class KIMChatSession;
@class KIMChatGroupSession;

@interface KIMChatModule (Internal)
-(BOOL)sendChatMessage:(KIMChatMessage*)chatMessage fromSession:(KIMChatSession*)chatSession;
-(BOOL)sendChatGroupMessage:(KIMChatGroupMessage*)chatGroupMessage fromSession:(KIMChatGroupSession*)chatGroupSession;
/**
 * @description 获取和指定用户的最新消息,回调会在主线程执行
 */
-(void)loadLastedChatMessageWithUser:(KIMUser*)opponent maxCount:(NSUInteger)maxCount completion:(void(^)(KIMChatModule * chatModule,NSArray<KIMChatMessage*> * messageList))completionBlock;
-(void)loadChatMessageWithUser:(KIMUser*)opponent maxCount:(NSUInteger)maxCount maxMessageId:(uint64_t)maxMessageId completion:(void(^)(KIMChatModule * chatModule,NSArray<KIMChatMessage*> * messageList))completionBlock;
/**
 * @description 获取聊天群的最新消息,回调会在主线程执行
 */
-(void)loadLastedChatGroupMessage:(KIMChatGroup*)chatGroup maxCount:(NSUInteger)maxCount completion:(void(^)(KIMChatModule * chatModule,NSArray<KIMChatGroupMessage*> * messageList))completionBlock;
-(void)loadChatGroupMessage:(KIMChatGroup*)chatGroup maxCount:(NSUInteger)maxCount maxMessageId:(uint64_t)maxMessageId completion:(void(^)(KIMChatModule * chatModule,NSArray<KIMChatGroupMessage*> * messageList))completionBlock;
@end
