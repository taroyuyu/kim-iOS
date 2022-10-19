//
//  KIMChatModule.h
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/31.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KIMClientService.h"
#import "KIMChatSession.h"
#import "KIMChatGroupSession.h"
/**
 * KIMChatModule的通知将会在主线程发送
 */
extern NSString * const KIMChatModuleReceivedChatMessageNotificationName;
extern NSString * const KIMChatModuleReceivedGroupChatMessageNotificationName;

@interface KIMChatModule : NSObject<KIMClientService>
-(KIMChatSession*)getSessionWithUser:(KIMUser*)opponent;
-(KIMChatGroupSession*)getChatGroupSession:(KIMChatGroup*)chatGroup;
@end
